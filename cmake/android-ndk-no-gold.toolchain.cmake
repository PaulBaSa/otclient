#
# android-ndk-no-gold.toolchain.cmake
#
# Wrapper around the Android NDK toolchain that removes the -fuse-ld=gold flag
# which is not available on all NDK builds (e.g., macOS)
#

# This wrapper acts as the primary CMake toolchain on Android when using
# the macOS NDK. It loads the vcpkg toolchain (if present) and then the
# official Android NDK toolchain. After both are loaded we scrub any
# lingering "-fuse-ld=gold" flags which will otherwise break with clang.

# include vcpkg toolchain first so that our wrapper is chainloaded later
if(DEFINED ENV{VCPKG_ROOT})
    include($ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake)
endif()

# now load the standard android toolchain from the NDK
include($ENV{ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake)

# After both toolchains are processed, remove unsupported gold linker flags
foreach(flag_var CMAKE_CXX_FLAGS CMAKE_C_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS
                   CMAKE_CXX_FLAGS_DEBUG CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE CMAKE_C_FLAGS_RELEASE
                   CMAKE_CXX_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_C_FLAGS_MINSIZEREL)
    if(DEFINED ${flag_var})
        string(REPLACE "-fuse-ld=gold" "-fuse-ld=lld" ${flag_var} "${${flag_var}}")
    endif()
endforeach()

message(STATUS "Custom Android NDK toolchain: gold linker references replaced with lld")
