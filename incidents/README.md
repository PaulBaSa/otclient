# Incidents Directory

This directory contains documented issues, their solutions, and preventive measures for known build and runtime problems encountered during OTClient development.

## Files in This Directory

### 🔴 [ANDROID_BUILD_ISSUES.md](ANDROID_BUILD_ISSUES.md)
**Comprehensive guide to Android build problems and solutions**

Contains detailed analysis of 6 major issues encountered when building OTClient for Android:
1. Missing pkg-config tool
2. Invalid linker flag `-fuse-ld=gold`
3. Multiple ABI compilation performance
4. Missing Lua headers
5. Missing minizip library
6. CMake variable syntax errors

Each issue includes:
- Problem description
- Root cause analysis
- Step-by-step solution
- Files affected
- Related error messages
- Preventive tips

**When to use**: Debug a specific Android build error; understand the full context of Android build requirements

---

### ⚡ [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
**Fast lookup for common errors and their solutions**

Organized by error message for quick navigation:
- Error → Solution mappings
- Pre-build checklist
- Environment setup instructions
- Common build commands
- Success indicators

**When to use**: You have an error message and need a quick fix; setting up a new Android build environment

---

### 📝 [CODE_CHANGES.md](CODE_CHANGES.md)
**Exact code modifications for all solutions**

Line-by-line breakdown of every code change:
- Before/after code samples
- Exact file locations and line numbers
- Validation steps
- Impact assessment
- Applicable to other projects

**When to use**: Applying solutions to a different branch or project; understanding what changed and why

---

### 📋 [README.md](README.md) ← You are here
**Navigation guide for incident reports**

---

## Quick Decision Tree

```
"I have an Android build error"
    ↓
"I have the exact error message"
    → Go to QUICK_REFERENCE.md (find error, get solution)
    
"I want to understand what happened"
    → Go to ANDROID_BUILD_ISSUES.md (full analysis)
    
"I need to apply the fix to my code"
    → Go to CODE_CHANGES.md (exact code samples)
    
"I'm setting up a new build environment"
    → Read QUICK_REFERENCE.md (Pre-Build Checklist section)
```

---

## Common Scenarios

### Scenario 1: Build fails with unfamiliar error

1. Get the exact error message from build output
2. Search for the error in **QUICK_REFERENCE.md**
3. Apply the solution
4. If that doesn't work, read **ANDROID_BUILD_ISSUES.md** for that issue number

### Scenario 2: Applying fixes to another branch

1. Open **CODE_CHANGES.md**
2. Find the relevant file you need to modify
3. Copy the "After" code
4. Apply to your branch

### Scenario 3: Helping team member set up Android build

1. Send them **QUICK_REFERENCE.md** (Environment Setup section)
2. Guide them through the checklist
3. Refer to **ANDROID_BUILD_ISSUES.md** if they hit an unsupported NDK version

### Scenario 4: Creating Android build for new version

1. Check if original commits are still in history
2. If reverting: Apply **CODE_CHANGES.md** again
3. If new version: Cross-reference issues to see if they still apply

---

## Recording New Incidents

When encountering new build or runtime issues:

1. **Document the error** - Get exact error message and context
2. **Investigate root cause** - Why did this happen?
3. **Find solution** - What fixed it?
4. **Create summary** - Add to this incidents/ directory:
   - Problem description
   - Error messages
   - Root cause
   - Solution steps
   - Files modified
   - Prevention tips

5. **Update tracking** - Add reference to top of README.md

---

## Related Files in Codebase

| Purpose | File | Relevance |
|---------|------|-----------|
| Android build config | `CMakeLists.txt` | Core changes documented here |
| Android CMake | `src/CMakeLists.txt` | Lua config for Android |
| Lua integration | `src/framework/luaengine/luainterface.h` | Header detection |
| Runtime resources | `src/framework/core/unzipper.cpp` | Stub for Android |
| Gradle config | `android/app/build.gradle.kts` | ABI target settings |
| Main CMake presets | `CMakePresets.json` | Android preset configuration |
| Dependency manifest | `vcpkg.json` | Android-excluded packages |

---

## Version Info

**Last Updated**: March 5, 2026  
**OTClient Version**: Tested on latest main branch  
**NDK Version**: 29.0.13599879 (macOS)  
**Gradle Version**: 8.14.2  
**CMake Version**: 3.22.1  
**Platform**: macOS (Apple Silicon compatible)  

---

## Maintenance Notes

- **Check on NDK updates** - Newer NDK versions might change linker behavior
- **Monitor vcpkg changes** - New versions might handle Android differently
- **Test with clean checkout** - Periodically rebuild from scratch to catch hidden issues
- **Keep Lua current** - If upgrading Lua version, update paths in all references

---

## Additional Resources

- [Android NDK Documentation](https://developer.android.com/ndk)
- [CMake Android Support](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-android)
- [vcpkg Android Guide](https://github.com/Microsoft/vcpkg/blob/master/docs/users/android.md)
- CLAUDE.md - Full OTClient project guide
- `/builder.log` - Full build logs from successful compilation

---

## Contact & Escalation

If you encounter a new error not documented here:

1. Save the full build output/error logs
2. Document the steps you took
3. Add to this incidents directory for team reference
4. File an issue on the project repository if it's framework-level

---

## Checklist: Before Filing Build Issue

- [ ] Verified ANDROID_NDK_HOME is set correctly
- [ ] Verified VCPKG_ROOT is set correctly
- [ ] Ran `brew install pkg-config`
- [ ] Ran `./gradlew clean`
- [ ] Verified all code changes from CODE_CHANGES.md are applied
- [ ] Checked QUICK_REFERENCE.md for the exact error message
- [ ] Confirmed error persists after clean build

