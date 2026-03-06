# Code Changes Summary

This document lists all the exact code changes made to resolve Android build issues. Use this as a reference when applying solutions to other versions or projects.

---

## Modified File: CMakeLists.txt

**Purpose**: Remove invalid `-fuse-ld=gold` linker flag for Android builds

**Location**: Lines 33-38 (after `project(otclient)` declaration)

**Change Type**: Added code block

```cmake
# Remove unsupported linker flags when targeting Android
if(ANDROID)
    foreach(flag_var CMAKE_CXX_FLAGS CMAKE_C_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS)
        string(REPLACE "-fuse-ld=gold" "" ${flag_var} "${${flag_var}}")
    endforeach()
endif()
```

**Before**: 
```cmake
project(otclient CXX C)
```

**After**:
```cmake
project(otclient CXX C)

# Remove unsupported linker flags when targeting Android
if(ANDROID)
    foreach(flag_var CMAKE_CXX_FLAGS CMAKE_C_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS)
        string(REPLACE "-fuse-ld=gold" "" ${flag_var} "${${flag_var}}")
    endforeach()
endif()
```

**Validation**: Build should not report `invalid linker name in argument '-fuse-ld=gold'`

---

## Modified File: src/CMakeLists.txt

### Change 1: Lua Library Configuration for Android

**Location**: Lines 182-195 (Android-specific library setup)

**Change Type**: Modified existing `if(ANDROID)` block

**Before**:
```cmake
if(ANDROID)
  # Android-specific lib setup
endif()
```

**After**:
```cmake
if(ANDROID)
  set(LUA_LIBRARY ${LUA_LIBRARY} ${CMAKE_SOURCE_DIR}/browser/include/lua51/liblua.a)
  find_package(game-activity REQUIRED CONFIG)
  find_package(EGL REQUIRED)
else()
  if(NOT WASM)
    find_package(OpenGL REQUIRED)
    find_package(GLEW REQUIRED)
    find_package(LuaJIT REQUIRED)
  else()
    set(LUA_LIBRARY ${LUA_LIBRARY} ${CMAKE_SOURCE_DIR}/browser/include/lua51/liblua.a)
    set(BROWSER_INCLUDE_DIR ${BROWSER_INCLUDE_DIR} ${CMAKE_SOURCE_DIR}/browser/include)
  endif()
endif()
```

**Key Points**:
- Uses `${CMAKE_SOURCE_DIR}/browser/include/lua51/liblua.a` instead of LuaJIT (not available on Android)
- Adds game-activity and EGL dependencies for Android
- Separates Android path from desktop (Windows/Linux/macOS) path

**Validation**: Should find lua.h during compilation, no "Cannot detect luajit library" error

---

## Modified File: src/framework/luaengine/luainterface.h

**Purpose**: Add Android-specific Lua header detection (plain C headers instead of lua.hpp)

**Location**: Lines 25-45 (top of file, after includes)

**Change Type**: Added Android #ifdef block and modified header detection

**Original Code**:
```cpp
#if defined(__has_include)

#if __has_include("luajit/lua.hpp")
#include <luajit/lua.hpp>
#elif __has_include(<lua.hpp>)
#include <lua.hpp>
#elif defined(__EMSCRIPTEN__)
extern "C" {
#include <lua51/lua.h>
#include <lua51/lualib.h>
#include <lua51/lauxlib.h>
}
#define LUAJIT_VERSION "LUA 5.1"
#else
#error "Cannot detect luajit library"
#endif

#else
#include <lua.hpp>
#endif
```

**Updated Code**:
```cpp
#ifdef ANDROID
// On Android we ship a static Lua 5.1 library, not LuaJIT. Use C headers directly.
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}
#define LUAJIT_VERSION "LUA 5.1"
#elif defined(__has_include)

#if __has_include("luajit/lua.hpp")
#include <luajit/lua.hpp>
#elif __has_include(<lua.hpp>)
#include <lua.hpp>
#elif defined(__EMSCRIPTEN__)
extern "C" {
#include <lua51/lua.h>
#include <lua51/lualib.h>
#include <lua51/lauxlib.h>
}
#define LUAJIT_VERSION "LUA 5.1"
#else
#error "Cannot detect luajit library"
#endif

#else
#include <lua.hpp>
#endif
```

**Key Changes**:
- Added `#ifdef ANDROID` at the start
- Uses plain C headers (`lua.h`, `lualib.h`, `lauxlib.h`) wrapped in `extern "C"`
- Sets `LUAJIT_VERSION` macro for compatibility
- Placed before other header detection to take precedence on Android

**Validation**: `lua.h` should be found, no compilation errors in Lua binding code

---

## Modified File: src/framework/core/unzipper.cpp

**Purpose**: Provide stub implementation for Android (minizip not available)

**Location**: Lines 23-110 (entire implementation)

**Change Type**: Added Android conditional compilation wrapper

**Original Code**:
```cpp
// ... using minizip library includes and functions ...
void unzipper::extract(const char* fileBuffer, uint fileLength, std::string& destinationPath) {
    // ... minizip code ...
}
```

**Updated Code**:
```cpp
#ifdef ANDROID

// On Android we ship resources differently and don't need full minizip support.
// Provide a stub implementation that simply logs and returns. This avoids
// pulling in the minizip headers and library which are not available on the
// Android build environment.
#include "unzipper.h"
#include "logger.h"
#include "resourcemanager.h"
#include <filesystem>

void unzipper::extract(const char* /*fileBuffer*/, uint /*fileLength*/, std::string& /*destinationPath*/) {
    g_logger.warning("unzipper.extract called on Android - operation is a no-op");
}

#else
// ... existing minizip-based implementation below ...

void unzipper::extract(const char* fileBuffer, uint fileLength, std::string& destinationPath) {
    // ... original minizip code (unchanged) ...
}

#endif
```

**Key Changes**:
- Wraps entire function in `#ifdef ANDROID ... #else ... #endif`
- Stub version logs warning but doesn't attempt to extract
- Original minizip code untouched on non-Android platforms

**Validation**: No compilation error for `ioapi.h`, warning appears in logs if unzipper is called

---

## Modified File: android/app/build.gradle.kts

**Purpose**: Reduce build time by targeting single ABI for development

**Location**: ndk block (approximately lines 20-25)

**Change Type**: Modified `abiFilters` list

**Before**:
```gradle-kotlin-dsl
ndk {
    abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
}
```

**After**:
```gradle-kotlin-dsl
ndk {
    abiFilters += listOf("arm64-v8a")
}
```

**Alternative for Production**:
```gradle-kotlin-dsl
ndk {
    abiFilters += listOf("arm64-v8a", "armeabi-v7a")  // 32 and 64 bit ARM
    // or for all ABIs:
    // abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
}
```

**Impact**: Development builds ~4× faster with single ABI

**Validation**: Should see single ABI build instead of 4 parallel compilations

---

## New Directory: android/app/libs/include/

**Purpose**: Store Lua 5.1 headers for Android compilation

**Contents** (copy from browser/include/lua51/):
- `lua.h`
- `lualib.h`
- `lauxlib.h`
- `luaconf.h`

**Creation Command**:
```bash
mkdir -p /Users/pbanuelos/TuInsomnia/otclient/android/app/libs/include/
cp /Users/pbanuelos/TuInsomnia/otclient/browser/include/lua51/*.h \
   /Users/pbanuelos/TuInsomnia/otclient/android/app/libs/include/
```

**Usage**: CMake includes this directory so `#include <lua.h>` resolves correctly

---

## Summary Table

| File | Issue | Type | Lines Affected | Severity |
|------|-------|------|---|---|
| CMakeLists.txt | Invalid linker flag | Add block | 33-38 | CRITICAL |
| src/CMakeLists.txt | Missing Lua library | Modify block | 182-195 | CRITICAL |
| src/framework/luaengine/luainterface.h | Lua header detection | Add condition | 25-45 | CRITICAL |
| src/framework/core/unzipper.cpp | Missing minizip | Add wrapper | 23-110 | HIGH |
| android/app/build.gradle.kts | Slow build | Modify list | 20-25 | MEDIUM |
| android/app/libs/include/ | Header location | Create dir | N/A | MEDIUM |

---

## Applying to Other Projects

1. **Copy relevant blocks** from this document
2. **Adapt paths** to match your project structure
3. **Test each change** incrementally
4. **Run `./gradlew clean assembleDebug`** after each change
5. **Verify no new errors** appear

---

## Testing Changes

After applying each change:

```bash
# Full clean build
rm -rf android/app/.cxx build
cmake --preset android-debug

# Or with Gradle
./gradlew clean assembleDebug --stacktrace
```

Expected output:
- No `error:` lines
- APK generated at `android/app/build/outputs/apk/debug/app-debug.apk`
- Build completes in < 15 minutes

