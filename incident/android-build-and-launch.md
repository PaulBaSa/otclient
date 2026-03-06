# Incident: Android Build & Launch Failures

**Date:** 2026-03-05 / 2026-03-06
**Branch:** `claude/fix-build-debug-skin-rsugF`
**Status:** Resolved

---

## Summary

The Android release APK failed to install ("App not installed as package appears to be invalid"), then crashed on launch through a series of native library and resource loading failures. All issues were resolved; the app now launches successfully to the language selection screen.

---

## Issues & Fixes

### 1. APK Install Failure — "Package appears to be invalid"

**Cause:** A previous installation with a different signing key conflicted.
**Fix:** Use `adb install -r` (replace) or uninstall via `adb uninstall` before installing.

---

### 2. Missing Native Symbols on Launch (UnsatisfiedLinkError)

Multiple successive native symbol resolution failures, each fixed by correcting `src/CMakeLists.txt`:

| Symbol | Root Cause | Fix |
|---|---|---|
| `FT_Init_FreeType` | `Freetype::Freetype` missing from Android `target_link_libraries` | Added `Freetype::Freetype` |
| `alGenBuffers` | `${OpenAL_LIBRARY}` was empty on Android | Changed to `OpenAL::OpenAL` CMake target |
| `lua_call`, `lua_getfenv`, etc. | Android was using WASM-built `liblua.a` (wrong arch) | Compiled Lua 5.1.5 for ARM64 using NDK clang, bundled at `android/libs/arm64-v8a/liblua.a` |

**Note on LuaJIT:** LuaJIT cannot be cross-compiled for Android on macOS due to assembler directive issues. Lua 5.1.5 is used instead. `vcpkg.json` excludes LuaJIT on Android: `"platform": "!android & !wasm32"`.

**Lua 5.1.5 compilation (for reference):**
```bash
# From /private/tmp/lua-5.1.5/src with NDK clang
NDK=~/.android/ndk/29.0.13599879
aarch64-linux-android21-clang -O2 -DLUA_USE_LINUX -c *.c
llvm-ar rcs liblua.a *.o
cp liblua.a otclient/android/libs/arm64-v8a/liblua.a
```

---

### 3. CMake / Toolchain Failures — NDK Path Not Found

**Cause:** `ANDROID_NDK_HOME` environment variable not set during Gradle-invoked CMake configure.

**Files changed:**
- `cmake/android-ndk-no-gold.toolchain.cmake` — Added fallback to `ANDROID_NDK` and `CMAKE_ANDROID_NDK` cmake variables
- `cmake/clang-no-gold.sh` — Added fallback: `NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK:-${CMAKE_ANDROID_NDK}}}"`

---

### 4. Crash: "Unable to find work directory"

**Cause:** `unzipper::extract()` is a no-op on Android (stub), so `data.zip` was never extracted and `init.lua` was never found by `discoverWorkDir`.

**Fix (two-part):**

**Part A** — Write `data.zip` to internal storage instead of extracting
`src/framework/platform/androidmanager.cpp` — `unZipAssetData()` now writes `data.zip` from Android assets to `internalDataPath/data.zip` using `AAssetManager`.

**Part B** — Add zip path to PhysFS search
`src/framework/core/resourcemanager.cpp` — Added `g_resources.getBaseDir() + "/data.zip"` to `discoverWorkDir`'s `possiblePaths[]` so PhysFS can mount and read the zip directly.

---

### 5. Crash: "Unable to add data directory to the search path"

**Cause (root):** `discoverWorkDir` found `init.lua` inside `data.zip` and set `m_workDir` to the zip file path (e.g., `/files/data.zip`) **without a trailing slash**. Then `init.lua` concatenated `getWorkDir() .. 'data'` = `.../data.zipdata` — an invalid path.

**Fix (two-part):**

**Part A** — Extract zip to filesystem using PhysFS
Added `AndroidManager::extractZipToFilesystem()` in `androidmanager.cpp`:
- Mounts `data.zip` via PhysFS (which reads zips natively)
- Recursively extracts all files to `internalDataPath/`
- Unmounts `data.zip`
- Skips extraction if `init.lua` already exists (first-run only)

Called from `src/main.cpp` after `g_resources.init(nullptr)`:
```cpp
g_androidManager.unZipAssetData();
g_resources.init(nullptr);
g_androidManager.extractZipToFilesystem();  // extract using PhysFS
```

**Part B** — Ensure workDir always has a trailing slash
`src/framework/core/resourcemanager.cpp` — `discoverWorkDir()` now normalizes `m_workDir`:
```cpp
if (!m_workDir.empty() && m_workDir.back() != '/')
    m_workDir += '/';
```

---

## Files Changed

| File | Change |
|---|---|
| `src/CMakeLists.txt` | Added `Freetype::Freetype`, `OpenAL::OpenAL`; replaced empty Lua vars with bundled `liblua.a` |
| `src/main.cpp` | Added `g_androidManager.extractZipToFilesystem()` call on Android |
| `src/framework/core/resourcemanager.cpp` | Added `data.zip` to `discoverWorkDir` paths; normalize `m_workDir` trailing slash |
| `src/framework/core/unzipper.cpp` | Android stub kept as no-op (zip extraction handled by PhysFS now) |
| `src/framework/platform/androidmanager.h` | Added `extractZipToFilesystem()` declaration |
| `src/framework/platform/androidmanager.cpp` | `unZipAssetData()` writes zip to disk; `extractZipToFilesystem()` extracts via PhysFS |
| `cmake/android-ndk-no-gold.toolchain.cmake` | Added fallback NDK path resolution from cmake variables |
| `cmake/clang-no-gold.sh` | Added fallback NDK path resolution |
| `android/libs/arm64-v8a/liblua.a` | Lua 5.1.5 compiled for ARM64 Android (new file) |
| `android/app/src/main/assets/data.zip` | Packed game assets: `init.lua`, `data/`, `modules/`, `mods/`, etc. (new file) |

---

## Known Remaining Issues

- **`game_wheel` module fails to load** — `modules/game_wheel/classes/wheelclass.lua` uses the `continue` keyword which is not valid in Lua 5.1 (only in LuaJIT/Lua 5.2+). The module is skipped; the rest of the app functions normally.

---

## Build & Deploy Commands

```bash
# Build release APK
cd android && ./gradlew assembleRelease

# Install on device
adb install -r android/app/build/outputs/apk/release/app-release.apk

# Launch
adb shell am start -n com.github.otclient/com.otclient.MainActivity

# Monitor logs
adb logcat | grep OTClientMobile
```

## Repacking data.zip (when game assets change)

```bash
cd /path/to/otclient
zip -r android/app/src/main/assets/data.zip \
    init.lua otclientrc.lua data/ modules/ mods/ cacert.pem config.ini
```
