#!/bin/bash -eu

# Test script to verify cross-compilation setup
# This script checks if binfmt_misc and QEMU are properly configured

echo "=== Cross-Compilation Setup Test ==="
echo "Date: $(date)"
echo "Host: $(uname -a)"
echo ""

# Test 1: Check kernel module
echo "1. Checking binfmt_misc kernel module..."
if lsmod | grep -q binfmt_misc; then
    echo "   ✓ binfmt_misc module is loaded"
else
    echo "   ✗ binfmt_misc module is NOT loaded"
    echo "   Attempting to load..."
    if sudo modprobe binfmt_misc 2>/dev/null; then
        echo "   ✓ Successfully loaded binfmt_misc module"
    else
        echo "   ✗ Failed to load binfmt_misc module"
    fi
fi
echo ""

# Test 2: Check filesystem
echo "2. Checking binfmt_misc filesystem..."
if [ -d "/proc/sys/fs/binfmt_misc" ]; then
    echo "   ✓ /proc/sys/fs/binfmt_misc directory exists"
    
    if [ "$(ls -A /proc/sys/fs/binfmt_misc 2>/dev/null)" ]; then
        echo "   ✓ binfmt_misc filesystem is mounted and populated"
        echo "   Available interpreters:"
        ls -la /proc/sys/fs/binfmt_misc/ | head -10
    else
        echo "   ⚠ binfmt_misc directory exists but is empty"
        echo "   Attempting to mount..."
        if sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null; then
            echo "   ✓ Successfully mounted binfmt_misc"
        else
            echo "   ✗ Failed to mount binfmt_misc"
        fi
    fi
else
    echo "   ✗ /proc/sys/fs/binfmt_misc directory does not exist"
fi
echo ""

# Test 3: Check Docker
echo "3. Checking Docker availability..."
if command -v docker >/dev/null 2>&1; then
    echo "   ✓ Docker command available"
    
    if docker ps >/dev/null 2>&1; then
        echo "   ✓ Docker daemon accessible"
        
        # Test QEMU registration
        echo "   Testing QEMU registration..."
        if docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null; then
            echo "   ✓ QEMU registration successful"
        else
            echo "   ⚠ QEMU registration failed, trying alternative..."
            if docker run --rm --privileged multiarch/qemu-user-static -p yes 2>/dev/null; then
                echo "   ✓ Alternative QEMU registration successful"
            else
                echo "   ✗ QEMU registration failed"
            fi
        fi
    else
        echo "   ✗ Docker daemon not accessible"
    fi
else
    echo "   ✗ Docker command not available"
fi
echo ""

# Test 4: Check QEMU static binaries
echo "4. Checking QEMU static binaries..."
for arch in aarch64 arm; do
    binary="/usr/bin/qemu-${arch}-static"
    if [ -x "${binary}" ]; then
        echo "   ✓ ${binary} available"
    else
        echo "   ✗ ${binary} not found"
    fi
done
echo ""

# Test 5: Check binfmt handlers
echo "5. Checking QEMU binfmt handlers..."
if [ -d "/proc/sys/fs/binfmt_misc" ]; then
    for handler in qemu-aarch64 qemu-arm; do
        handler_file="/proc/sys/fs/binfmt_misc/${handler}"
        if [ -f "${handler_file}" ]; then
            echo "   ✓ ${handler} handler registered"
            echo "      $(head -1 "${handler_file}")"
        else
            echo "   ✗ ${handler} handler not found"
        fi
    done
else
    echo "   ⚠ Cannot check handlers (binfmt_misc not mounted)"
fi
echo ""

# Test 6: Test actual emulation
echo "6. Testing emulation functionality..."
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    echo "   Testing ARM64 emulation..."
    if docker run --rm --platform linux/arm64 alpine:latest uname -m 2>/dev/null | grep -q aarch64; then
        echo "   ✓ ARM64 emulation working"
    else
        echo "   ✗ ARM64 emulation failed"
    fi
    
    echo "   Testing ARMHF emulation..."
    if docker run --rm --platform linux/arm/v7 alpine:latest uname -m 2>/dev/null | grep -q armv7; then
        echo "   ✓ ARMHF emulation working"
    else
        echo "   ✗ ARMHF emulation failed"
    fi
else
    echo "   ⚠ Skipping emulation test (Docker not available)"
fi
echo ""

echo "=== Test Summary ==="
echo "If you see mostly ✓ marks above, cross-compilation should work."
echo "If you see ✗ marks, you may need to:"
echo "- Run with sudo/root privileges"
echo "- Load kernel modules manually"
echo "- Use Docker in privileged mode"
echo "- Check if your system supports binfmt_misc"
echo ""
