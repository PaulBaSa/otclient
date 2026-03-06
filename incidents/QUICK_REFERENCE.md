# Quick Reference - Android Build Troubleshooting

## Error → Solution Lookup

### `pkg-config: command not found`
```bash
brew install pkg-config
```
**See**: Issue 1 in ANDROID_BUILD_ISSUES.md

---

### `invalid linker name in argument '-fuse-ld=gold'`
**Add to CMakeLists.txt** (after `project()` declaration):
```cmake
if(ANDROID)
    foreach(flag_var CMAKE_CXX_FLAGS CMAKE_C_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS)
        string(REPLACE "-fuse-ld=gold" "" ${flag_var} "${${flag_var}}")
    endforeach()
endif()
```
**See**: Issue 2 in ANDROID_BUILD_ISSUES.md

---

### `'lua.h' file not found`
1. Copy headers: `cp browser/include/lua51/*.h android/app/libs/include/`
2. Update `src/CMakeLists.txt` to use `${CMAKE_SOURCE_DIR}/browser/include/lua51/liblua.a` for Android
3. Add Android detection block in `src/framework/luaengine/luainterface.h`

**See**: Issue 4 in ANDROID_BUILD_ISSUES.md

---

### `'ioapi.h' file not found` (minizip)
**Add to src/framework/core/unzipper.cpp** (wrap body with `#ifdef ANDROID`):
```cpp
#ifdef ANDROID
void unzipper::extract(...) {
    g_logger.warning("unzipper.extract called on Android - operation is a no-op");
}
#else
// ... existing minizip code ...
#endif
```
**See**: Issue 5 in ANDROID_BUILD_ISSUES.md

---

### Build taking forever (> 30 minutes)
**Reduce ABI targets in android/app/build.gradle.kts**:
```gradle-kotlin-dsl
ndk {
    abiFilters += listOf("arm64-v8a")  // Single ABI for development
}
```
**See**: Issue 3 in ANDROID_BUILD_ISSUES.md

---

## Pre-Build Checklist

```bash
# 1. Verify NDK installation
echo $ANDROID_NDK_HOME

# 2. Verify vcpkg
echo $VCPKG_ROOT
ls $VCPKG_ROOT/vcpkg

# 3. Verify pkg-config
which pkg-config

# 4. Verify Gradle
./gradlew --version

# 5. Clean and retry
rm -rf android/app/.cxx
./gradlew assembleDebug
```

---

## Environment Setup (One-Time)

```bash
# 1. Install pkg-config
brew install pkg-config

# 2. Set environment variables (add to ~/.zshrc or similar)
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/<NDK_VERSION>"
export VCPKG_ROOT="$HOME/vcpkg"

# 3. Bootstrap vcpkg (one-time)
cd ~/vcpkg
./bootstrap-vcpkg.sh
```

---

## Success Indicators

✅ No `error:` lines in build output  
✅ APK file exists at `android/app/build/outputs/apk/debug/app-debug.apk`  
✅ Build completes in < 15 minutes (single ABI)  
✅ No unresolved symbols in linker output  

---

## Common Build Commands

```bash
# Debug build (single ABI)
./gradlew assembleDebug

# Debug build with output
./gradlew assembleDebug -v

# Debug build from scratch
rm -rf android/app/.cxx && ./gradlew assembleDebug

# Release build (multi-ABI, slow)
./gradlew assembleRelease

# Check dependencies
./gradlew dependencies

# View build output
./gradlew assembleDebug --stacktrace
```

---

## File Locations

| Component | Path |
|-----------|------|
| NDK | `~/Library/Android/sdk/ndk/<version>/` |
| Gradle wrapper | `otclient/android/gradlew` |
| Gradle config | `otclient/android/build.gradle.kts` |
| App config | `otclient/android/app/build.gradle.kts` |
| Lua headers (bundled) | `otclient/browser/include/lua51/` |
| Lua library (bundled) | `otclient/browser/include/lua51/liblua.a` |
| CMake config | `otclient/CMakeLists.txt` |
| Build output | `otclient/android/app/build/outputs/apk/` |

---

## Still Stuck?

1. Check full error messages in `ANDROID_BUILD_ISSUES.md`
2. Run `./gradlew clean assembleDebug --stacktrace` for detailed output
3. Verify all environment variables are set correctly
4. Ensure all directory paths exist and permissions are correct
5. Check NDK version compatibility (tested with 29.0.13599879)

