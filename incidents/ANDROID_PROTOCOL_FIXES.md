# Android Protocol & Rendering Fixes — OTCv8 / TFS 1.5 Server

**Date**: March 12, 2026
**Project**: OTClient Android — Connecting to custom "Ot Server Store TFS - Version 1.5" (OTCv8 fork)
**Protocol Version**: 1098
**Platform**: Android (Adreno 830, arm64-v8a)

---

## Overview

After successfully building the Android APK and getting the app to launch, three major issues
remained before the game was playable:

1. **Login failed** — "Invalid account name." / "Invalid authentication token."
2. **Stats packet desync** — Unhandled opcode warnings after entering game world
3. **Map rendering corruption** — Colored vertical stripes covering the entire map viewport

All three have been resolved. This document covers root causes, fixes, and validation steps.

---

## Issue 1: Login Failed — "Invalid account name." / "Invalid authentication token."

### Problem
After entering credentials and clicking Login, the server rejected the login with:
- First attempt: "Invalid account name."
- After partial fix: "Invalid authentication token."

### Root Cause
The server is an OTCv8 fork. Its login RSA block format differs from standard OTClient:

**Standard OTClient RSA block:**
```
U8(0x00) + XTEA key (16 bytes) + account string + password string + padding
```

**This server expects:**
```
U8(0x00) + XTEA key (16 bytes) + U8(0) packet_type + account string + password string
         + "OTCv8" string + U16(version) + padding
```

Additionally, the server always expects a second RSA block (auth token / 2FA block) even when
the account has no 2FA configured (secret = NULL). `GameAuthenticator` (>= 1072) and
`GameSessionKey` (>= 1074) must be enabled unconditionally.

The server also uses a custom RSA modulus — NOT the widely-known standard `OTSERV_RSA`. The
correct key is stored at `/Users/pbanuelos/TuInsomnia/otclient/key.pem` and its modulus
must match the `OTSERV_RSA` constant in `android/data/modules/gamelib/const.lua`.

### Fix

**File**: `android/data/modules/gamelib/protocollogin.lua`

Inside the RSA block (after writing XTEA key):
```lua
-- 1. Add packet_type byte before account name
msg:addU8(0)

-- 2. Write account and password as usual, then add OTCv8 identifier
msg:addString(account)
msg:addString(password)
msg:addString("OTCv8")
msg:addU16(version)
```

**File**: `android/data/modules/game_features/features.lua`

The `GameAuthenticator` and `GameSessionKey` features must be enabled (they're already handled
by the version-gated blocks at >= 1072 and >= 1074 respectively — confirm they are NOT
disabled anywhere for this server version).

### Validation
- `[DEBUG] loginWorld account=...` appears in logcat → login succeeded
- No "Invalid account name." or "Invalid authentication token." errors

---

## Issue 2: Stats Packet Desync — Unhandled Opcode After Entering World

### Symptom
After login, logcat showed repeating warnings every ~2 seconds:
```
WARNING: [1098] Unhandled opcode 0x2E (46) with 84 unread bytes; previous opcode: 0xA0 (160)
```
Later mutated to:
```
WARNING: [1098] Unhandled opcode 0x00 (0) with 74 unread bytes; previous opcode: 0xD0 (208)
```

### Root Cause
The server's `AddPlayerStats` (opcode `0xA0`) sends more bytes than standard OTClient parses:

| Field | Standard OTClient | This server |
|-------|------------------|-------------|
| health | U16 | U32 |
| maxHealth | U16 | U32 |
| mana | U16 | U32 |
| maxMana | U16 | U32 |
| attackSpeed | not sent | U32 |
| armor | not sent | U32 |

Total extra bytes: **16** (4 from each health/mana field × 2 = 8, plus attackSpeed + armor = 8).

### Fix

**Part A — Health/Mana as U32** (`GameDoubleHealth` feature):

**File**: `android/data/modules/game_features/features.lua`
Add unconditionally at the top of `onClientVersionChange`:
```lua
-- Custom TFS 1.5 / OTCv8: server always sends health/mana/manaShield as U32
g_game.enableFeature(GameDoubleHealth)
```

**Part B — Extra attackSpeed + armor fields** (C++ change):

**File**: `src/client/protocolgameparse.cpp`, in function `parsePlayerStats`
After the store boost fields (`>= 1097` block), before the `>= 1281` block:
```cpp
// Custom TFS 1.5 / OTCv8: server sends 2 extra U32 fields after store boost
// (attackSpeed U32 + armor U32) that standard OTClient doesn't consume
if (g_game.getClientVersion() >= 1098 && g_game.getClientVersion() < 1281) {
    msg->getU32(); // attackSpeed (custom field)
    msg->getU32(); // armor (custom field)
}
```

### Byte Count Verification
Server's `AddPlayerStats` total extra bytes vs standard parse:
- health: +2 bytes (U32 - U16)
- maxHealth: +2 bytes
- mana: +2 bytes
- maxMana: +2 bytes
- attackSpeed: +4 bytes
- armor: +4 bytes
- **Total**: 16 extra bytes consumed by `GameDoubleHealth` (+8) + explicit reads (+8) ✓

### Validation
No more `Unhandled opcode` warnings in logcat after entering the game world.

---

## Issue 3: Map Rendering Corruption — Colored Vertical Stripes

### Symptom
After entering the game world, the entire map viewport showed evenly-spaced colored vertical
stripes (green, blue, black bands) over the map content. The right-panel UI (HP bar, skills,
inventory) rendered correctly. The stripes persisted regardless of player movement.

### Root Cause
The custom server's sprite file (`Tibia.spr`) uses **RGBA format** (4 bytes per colored pixel)
rather than the standard RGB format (3 bytes per pixel).

OTClient's `GameSpritesAlphaChannel` feature flag controls sprite decoding in
`src/client/spritemanager.cpp`:
- **Disabled** (our default): reads 3 bytes/pixel → misaligned after first pixel → garbage colors
- **Enabled** (Windows client): reads 4 bytes/pixel → correct RGBA data

Without this flag, every single sprite in the game was decoded with wrong pixel data, producing
the colored stripe artifacts.

This was identified by comparing with the reference Windows client
(`windowsClient/TibiaOG/ClienttibiaOG/modules/game_features/features.lua`) which explicitly
enables `GameSpritesAlphaChannel` unconditionally.

### Fix

**File**: `android/data/modules/game_features/features.lua`
Add unconditionally at the top of `onClientVersionChange`:
```lua
-- Custom TFS 1.5 / OTCv8: sprites use RGBA (4 bytes/pixel) not RGB (3 bytes/pixel)
-- Without this, sprite pixel data is misaligned causing colored vertical stripes
g_game.enableFeature(GameSpritesAlphaChannel)
```

### Validation
After installing the updated APK and clearing app data (`adb shell pm clear com.github.otclient`),
the map renders correctly with proper tile graphics, walls, and creatures visible.

### Why This Wasn't Found Earlier
`GameSpritesAlphaChannel` does not affect packet parsing (no logcat warnings) — it only affects
the client-side sprite texture decoding. There are no error logs when sprites are decoded
incorrectly; the result is purely visual.

---

## Feature Flags Summary

All custom feature flags added to `android/data/modules/game_features/features.lua`
(enabled unconditionally, before any version-gated blocks):

```lua
g_game.enableFeature(GameFormatCreatureName)
-- Health/mana always sent as U32 by this server
g_game.enableFeature(GameDoubleHealth)
-- Item wire format: [U16 clientId][U8 0xFF mark][U8 count?][U8 animPhase?][U8 rarity]
g_game.enableFeature(GameThingMarks)
g_game.enableFeature(GameItemAnimationPhase)
g_game.enableFeature(GameItemRarity)
-- AddCreature always includes personalStore mode+name
g_game.enableFeature(GameCreaturePersonalStore)
-- Magic effects sent as U16
g_game.enableFeature(GameMagicEffectU16)
-- Sprites use RGBA 4-bytes/pixel format
g_game.enableFeature(GameSpritesAlphaChannel)
```

---

## C++ Changes Summary

### `src/client/protocolgameparse.cpp`

Function `parsePlayerStats` — consume 2 extra U32 fields sent by this server:

```cpp
if (g_game.getClientVersion() >= 1097) {
    m_localPlayer->setStoreExpBoostTime(msg->getU16()); // xp boost time (seconds)
    msg->getU8(); // enables exp boost in the store
}

// Custom TFS 1.5 / OTCv8: server sends 2 extra U32 fields after store boost
// (attackSpeed U32 + armor U32) that standard OTClient doesn't consume
if (g_game.getClientVersion() >= 1098 && g_game.getClientVersion() < 1281) {
    msg->getU32(); // attackSpeed (custom field)
    msg->getU32(); // armor (custom field)
}

if (g_game.getClientVersion() >= 1281) {
    // ... standard >= 1281 fields ...
```

---

## Server Protocol Reference

Key differences between this custom TFS 1.5 server and standard OTClient protocol for v1098:

### Item Wire Format (`networkmessage.cpp → addItem()`)
```
U16(clientId) + U8(0xFF mark) + [U8(count) if stackable] + [U8(fluid) if splash/fluid]
             + [U8(0xFE animPhase) if isAnimation] + U8(rarity)
```

### Creature Wire Format (`protocolgame.cpp → AddCreature()`)
personalStore (mode U8 + name string) is sent unconditionally in `AddCreature` for all creatures.
Wings/aura only sent when `otclientV8 != 0` on the server (disabled in our setup).

### Player Stats Wire Format (`protocolgame.cpp → AddPlayerStats()`)
All health/mana values are sent as U32 (not U16). Two extra fields at the end of the standard
block: `attackSpeed (U32)` + `armor (U32)`.

### Tile Description (`protocolgame.cpp → GetTileDescription()`)
Each tile starts with `U16(0x00)` environmental effect before the item list. This is handled
by `GameEnvironmentEffect` which is already enabled at version >= 910.

---

## Deployment Workflow

### Lua-Only Changes (no C++ change needed)
```bash
# 1. Edit files in android/data/modules/ or android/data/mods/
# 2. Update data.zip
cd android/data
zip -u data.zip modules/path/to/changed/file.lua

# 3. Copy to APK assets
cp data.zip ../app/src/main/assets/data.zip

# 4. Build
cd ..
./gradlew assembleDebug

# 5. Install
adb install -r app/build/outputs/apk/debug/app-debug.apk

# 6. Clear app data to force re-extraction of data.zip
adb shell pm clear com.github.otclient

# 7. Re-push config.ini (pm clear wipes it)
cat data/config.ini | adb shell "run-as com.github.otclient tee /data/user/0/com.github.otclient/files/config.ini"

# 8. Launch
adb shell monkey -p com.github.otclient -c android.intent.category.LAUNCHER 1
```

### C++ Changes (full rebuild required)
Same as above but step 4 will trigger a full C++ recompile (~5-10 minutes for single ABI).

---

## Configuration Files

### `android/data/config.ini` (extracted to device on first run)
```ini
[graphics]
maxAtlasSize = 8192
mapAtlasSize = 4096       ; explicit size to avoid Adreno GPU returning huge auto value
foregroundAtlasSize = 2048

[font]
widget = verdana-bold|10|0|black
static-text = verdana-11px-rounded
animated-text = verdana-11px-rounded
creature-text = verdana-11px-rounded
```

Note: `mapAtlasSize = 0` (auto) with `maxAtlasSize = 8192` would allocate an 8192×8192 texture
(268 MB VRAM). Setting it explicitly to 4096 reduces VRAM usage to ~67 MB.

---

## Reference Files

| File | Purpose |
|------|---------|
| `windowsClient/TibiaOG/ClienttibiaOG/modules/game_features/features.lua` | Working Windows client feature flags — ground truth for this server |
| `windowsClient/TibiaOG/ClienttibiaOG/modules/gamelib/protocollogin.lua` | Working Windows login protocol |
| `actualServer/tibiaOG/src/protocolgame.cpp` | Server-side protocol implementation |
| `actualServer/tibiaOG/src/networkmessage.cpp` | Server-side item/creature serialization |
| `key.pem` | Server's RSA private key (modulus must match `OTSERV_RSA` in const.lua) |
| `android/data/modules/game_features/features.lua` | Our Android feature flags (customized) |
| `android/data/modules/gamelib/protocollogin.lua` | Our Android login protocol (customized) |
| `src/client/protocolgameparse.cpp` | C++ protocol parser |
| `src/client/spritemanager.cpp` | Sprite decoder (GameSpritesAlphaChannel controls RGBA vs RGB) |

---

## Debugging Techniques Used

### Logcat Monitoring
```bash
# Live warnings/errors for current session
adb logcat | grep "OTClientMobile" | grep "WARNING\|ERROR\|FATAL"

# Check specific PID (find PID from "Startup done" log line)
adb logcat -d | grep "OTClientMobile" | grep " <PID> " | grep "WARNING"

# Watch unhandled opcodes
adb logcat | grep "Unhandled opcode"
```

### Packet Byte Analysis
When an `Unhandled opcode 0xXX` warning appears, the "next bytes" hex dump shows the start
of the following packet. Count forward from the known packet start to find the byte offset
and identify which fields are being skipped.

### Adding C++ Debug Logging
Temporary debug prints in `protocolgameparse.cpp`:
```cpp
g_logger.info("[DEBUG] parseXxx: field={} pos={} unread={}", value, msg->getReadPos(), msg->getUnreadSize());
```

### Screenshot Comparison
`adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png /tmp/screen.png`

Compare with Windows client screenshots to identify rendering differences.

---

## Future Improvements

1. Consider enabling additional Windows client features for visual parity:
   - `GameNewCreatureStacking` — creature layering on tiles
   - `GameFasterAnimations` / `GameIdleAnimations` — smoother animations
   - `GameExtendedOpcode` — if the server uses extended opcodes
2. Investigate whether `GameOTCv8WingsAuras` can be enabled without triggering server-side
   packet compression mode (currently disabled to avoid that issue)
3. Add server-side `otclientV8` flag support so wings/auras can be enabled safely
