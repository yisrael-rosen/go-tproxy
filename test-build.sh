#!/bin/bash
# Test build script for Zig TProxy
# This script will download Zig if not present and build the project

set -e

ZIG_VERSION="0.13.0"
ZIG_DIR="zig-linux-x86_64-${ZIG_VERSION}"
ZIG_ARCHIVE="${ZIG_DIR}.tar.xz"
ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/${ZIG_ARCHIVE}"

echo "=== Zig TProxy Build Test ==="
echo ""

# Check if zig is already in PATH
if command -v zig &> /dev/null; then
    echo "✓ Zig found in PATH:"
    zig version
else
    echo "Zig not found in PATH"

    # Check if we have a local installation
    if [ -f "./${ZIG_DIR}/zig" ]; then
        echo "✓ Found local Zig installation in ./${ZIG_DIR}"
        export PATH="${PWD}/${ZIG_DIR}:${PATH}"
        zig version
    else
        echo "Downloading Zig ${ZIG_VERSION}..."

        # Try wget first, then curl
        if command -v wget &> /dev/null; then
            wget "${ZIG_URL}" -O "${ZIG_ARCHIVE}"
        elif command -v curl &> /dev/null; then
            curl -L "${ZIG_URL}" -o "${ZIG_ARCHIVE}"
        else
            echo "Error: Neither wget nor curl found. Please install one of them."
            exit 1
        fi

        echo "Extracting Zig..."
        tar -xf "${ZIG_ARCHIVE}"

        echo "Cleaning up archive..."
        rm "${ZIG_ARCHIVE}"

        export PATH="${PWD}/${ZIG_DIR}:${PATH}"
        echo "✓ Zig installed locally"
        zig version
    fi
fi

echo ""
echo "Building project..."
zig build

echo ""
echo "✓ Build successful!"
echo ""
echo "To run the example (requires root for TPROXY):"
echo "  sudo zig build run"
echo ""
echo "Or run the compiled binary directly:"
echo "  sudo ./zig-out/bin/tproxy_example"
