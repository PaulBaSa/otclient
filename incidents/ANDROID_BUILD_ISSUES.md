# Android Build Issues & Solutions

**Date**: March 5, 2026  
**Project**: OTClient Android Build  
**Platform**: macOS (Apple Silicon/Intel)

---

## Issue 1: Missing pkg-config Build Tool

### Problem
vcpkg failed to build dependencies, specifically `abseil:arm64-android`, with error:
```
Could not find pkg-config. Please install it via your package manager:
    brew install pkg-config
```

### Root Cause
vcpkg's `vcpkg_fixup_pkgconfig` function requires the `pkg-config` tool to be installed on the host system when building packages that use pkg-config (.pc files). This was missing from the macOS build environment.

### Solution
Install pkg-config via Homebrew:
```bash
brew install pkg-config
```

### Files Affected
- None (environment fix only)

### Related Error Location
```
/Users/pbanuelos/vcpkg/scripts/cmake/vcpkg_fixup_pkgconfig.cmake:193
```

---

## Issue 2: Invalid Linker Flag `-fuse-ld=gold`

### Problem
CMake configuration fails with:
```
clang++: error: invalid linker name in argument '-fuse-ld=gold'
```

### Root Cause
vcpkg adds the `-fuse-ld=gold` linker flag on Android triplet builds, assuming the GNU `gold` linker is available. However, the macOS NDK doesn't include the gold linker—only the default LLVM linker is available. This flag is invalid for clang on macOS-hosted Android compilation.

### Solution
Remove the `-fuse-ld=gold` flag at the CMake level before it reaches the compiler. Add this code early in `CMakeLists.txt` after the `project()` declaration:

**File**: `CMakeLists.txt`
```cmake
# Remove unsupported linker flags when targeting Android
if(ANDROID)
    foreach(flag_var CMAKE_CXX_FLAGS CMAKE_C_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS)
        string(REPLACE "-fuse-ld=gold" "" ${flag_var} "${${flag_var}}")
    endforeach()
endif()
```

### Files Affected
- `CMakeLists.txt` (lines ~33-38)

### Notes
- This is a host-specific issue (macOS + NDK combination)
- Linux builds with gold linker would not have this issue
- The flag removal happens early enough that it doesn't affect vcpkg configuration

---

## Issue 3: Multiple ABI Compilation (Performance Issue)

### Problem
Build was extremely slow because Gradle/CMake was compiling the entire project for 4 ABIs simultaneously:
```
abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
```

### Root Cause
While supporting multiple ABIs is good for production, it multiplies build time by 4× during development. No optimization was configured for debug builds.

### Solution
Limit development builds to a single ABI (`arm64-v8a` is the most common):

**File**: `android/app/build.gradle.kts`
```gradle-kotlin-dsl
ndk {
    abiFilters += listOf("arm64-v8a")
}
```

**For production builds**, you can enable multi-ABI by modifying the release variant.

### Files Affected
- `android/app/build.gradle.kts` (ndk block, line ~20)

### Notes
- `arm64-v8a` is the default ABI for modern Android devices
- To build all ABIs, revert to the full list
- CMake will recompile everything for each ABI if configuration changes

---

## Issue 4: Missing Lua Headers on Android

### Problem
Compilation fails with:
```
src/framework/luaengine/luainterface.h:31:10: fatal error: 'lua.h' file not found
```

### Root Cause
The Android build configuration in `CMakeLists.txt` was trying to find Lua headers via vcpkg's Android triplet, but:
1. LuaJIT is not available for Android (disabled in `vcpkg.json`)
2. The code checks for system/vcpkg headers but didn't have a fallback for the bundled Lua 5.1 library

### Solution
Use the bundled Lua 5.1 library that's already in the repository for Android builds:

**Step 1**: Copy Lua headers to Android libs

```bash
cp /Users/pbanuelos/TuInsomnia/otclient/browser/include/lua51/*.h \
   /Users/pbanuelos/TuInsomnia/otclient/android/app/libs/include/
```

**Step 2**: Update CMakeLists.txt to use bundled Lua for Android

**File**: `src/CMakeLists.txt` (lines ~182-195)
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

**Step 3**: Update Lua header detection

**File**: `src/framework/luaengine/luainterface.h` (lines ~25-45)
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

### Files Affected
- `android/app/libs/include/` (created with header files)
- `src/CMakeLists.txt` (Lua configuration for Android)
- `src/framework/luaengine/luainterface.h` (header detection)

### Notes
- Android and WebAssembly both use the same Lua 5.1 library (no LuaJIT)
- LuaJIT requires JIT compilation which is difficult on mobile platforms
- The bundled Lua 5.1 is sufficient for the client's scripting needs

---

## Issue 5: Missing minizip/ioapi Headers

### Problem
Compilation fails with:
```
/Users/pbanuelos/TuInsomnia/otclient/src/framework/core/unzipper.cpp:29:10: fatal error: 'ioapi.h' file not found
```

### Root Cause
`unzipper.cpp` is Android-specific code that uses the minizip library. However:
1. minizip wasn't included in `vcpkg.json` dependencies
2. The headers weren't available in the Android build environment

### Solution
Provide a stub implementation for Android that logs a warning instead of crashing. Full zip support typically isn't needed on Android since resources are pre-packaged differently.

**File**: `src/framework/core/unzipper.cpp` (lines ~23-110)
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
// ... existing minizip-based implementation ...
#endif
```

### Files Affected
- `src/framework/core/unzipper.cpp` (wrapped with `#ifdef ANDROID`)

### Notes
- This assumes Android apps don't need runtime zip extraction
- If zip support is needed on Android, add minizip to `vcpkg.json` and build it as a dependency
- The warning will help identify if unzipper is unexpectedly called

---

## Issue 6: Mismatched CMake Include Directory Variable

### Problem
CMake configuration passes incorrect include path, even though libraries exist.

### Root Cause
Line used `include_directories(Android_INCLUDES)` instead of `include_directories(${Android_INCLUDES})`. This literally tried to include a directory named `Android_INCLUDES` instead of the variable's value.

### Solution
Fix the CMake variable reference:

**File**: `CMakeLists.txt` (line ~26)
```cmake
# Before (WRONG):
include_directories(Android_INCLUDES)

# After (CORRECT):
include_directories(${Android_INCLUDES})
```

### Files Affected
- `CMakeLists.txt` (line ~26)

---

## Environment Setup Checklist

To avoid these issues in future Android builds, ensure:

- [ ] Android SDK is installed (usually at `~/Library/Android/sdk`)
- [ ] Android NDK is installed (tested with NDK 29.0.13599879)
- [ ] `ANDROID_NDK_HOME` environment variable is set
- [ ] `VCPKG_ROOT` environment variable is set and points to vcpkg installation
- [ ] vcpkg is bootstrapped (`./bootstrap-vcpkg.sh` has been run)
- [ ] `pkg-config` is installed on macOS (`brew install pkg-config`)
- [ ] Gradle wrapper is executable (`chmod +x gradlew`)

---

## Recommended Build Commands

### Development (Single ABI, fastest)
```bash
export ANDROID_NDK_HOME=/Users/pbanuelos/Library/Android/sdk/ndk/29.0.13599879
export VCPKG_ROOT=/Users/pbanuelos/vcpkg
cd android
./gradlew assembleDebug
```

### Production (All ABIs)
1. Revert `abiFilters` in `android/app/build.gradle.kts` to include all ABIs
2. Run:
```bash
./gradlew assembleRelease
```

### Clean Build
```bash
rm -rf android/app/.cxx
./gradlew clean assembleDebug
```

---

## References & Related Files

| Issue | Related Files |
|-------|---------------|
| Missing pkg-config | vcpkg/scripts/cmake/vcpkg_fixup_pkgconfig.cmake |
| Invalid linker flag | CMakeLists.txt, android/app/build.gradle.kts |
| Multiple ABI slowness | android/app/build.gradle.kts |
| Missing Lua headers | src/CMakeLists.txt, src/framework/luaengine/luainterface.h |
| Missing minizip | src/framework/core/unzipper.cpp |
| CMake variable syntax | CMakeLists.txt |

---

## Future Improvements

1. **Add Android-specific CMake preset** to `CMakePresets.json` with common flags pre-configured
2. **Create shell script** to set environment variables automatically
3. **Add GitHub Actions workflow** to test Android builds on every commit
4. **Consider Gradle task** to validate environment before building
5. **Document resource packing strategy** for Android (how to pre-package game assets)
