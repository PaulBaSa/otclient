#!/bin/bash
# Wrapper around Android NDK clang++ that filters out unsupported -fuse-ld=gold
# Usage: sets CMAKE_CXX_COMPILER to this script via CMake arguments.

NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK:-${CMAKE_ANDROID_NDK}}}"
if [ -z "$NDK_PATH" ]; then
    echo "ERROR: ANDROID_NDK_HOME (or ANDROID_NDK) not set" >&2
    exit 1
fi

real="$NDK_PATH/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang++"
if [ ! -x "$real" ]; then
    echo "ERROR: clang++ not found at $real" >&2
    exit 1
fi

filtered=()
for arg in "$@"; do
    if [ "$arg" = "-fuse-ld=gold" ]; then
        filtered+=("-fuse-ld=lld")
    else
        filtered+=("$arg")
    fi
done

exec "$real" "${filtered[@]}"