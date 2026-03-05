#!/bin/bash
# Wrapper around Android NDK clang++ that filters out unsupported -fuse-ld=gold
# Usage: sets CMAKE_CXX_COMPILER to this script via CMake arguments.

if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "ERROR: ANDROID_NDK_HOME not set" >&2
    exit 1
fi

real="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang++"
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