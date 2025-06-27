#!/bin/bash

# Crankshaft rpi-image-gen Validation Script
# Validates the build environment and configuration for official Raspberry Pi rpi-image-gen

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="$(dirname "${DIR}")"

echo "Crankshaft rpi-image-gen Validation"
echo "===================================="
echo "Using official Raspberry Pi rpi-image-gen"

# Check if we're in the right directory
if [ ! -f "${ROOT_DIR}/build-rpi-image-gen.sh" ]; then
    echo "❌ ERROR: Not in the correct Crankshaft directory"
    echo "   Expected to find build-rpi-image-gen.sh in ${ROOT_DIR}"
    exit 1
fi

echo "✅ Found Crankshaft root directory: ${ROOT_DIR}"

# Check for required files
REQUIRED_FILES=(
    "build-rpi-image-gen.sh"
    "build-docker-rpi-image-gen.sh"
    "config.rpi-image-gen.example"
    "Dockerfile"
)

echo ""
echo "Checking required files:"
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "${ROOT_DIR}/${file}" ]; then
        echo "✅ ${file}"
    else
        echo "❌ Missing: ${file}"
        exit 1
    fi
done

# Check for stage directories (needed for file copying)
echo ""
echo "Checking Crankshaft stage directories:"
STAGE_DIRS=(
    "stage3/03-crankshaft-base"
    "stage3/04-crankshaft-bluetooth"
    "stage3/05-crankshaft-x11"
)

for stage_dir in "${STAGE_DIRS[@]}"; do
    if [ -d "${ROOT_DIR}/${stage_dir}" ]; then
        echo "✅ ${stage_dir}"
        # Check for files subdirectory
        if [ -d "${ROOT_DIR}/${stage_dir}/files" ]; then
            echo "  ✅ ${stage_dir}/files"
        else
            echo "  ⚠️  Missing: ${stage_dir}/files"
        fi
    else
        echo "⚠️  Missing: ${stage_dir} (required for full functionality)"
    fi
done

# Check Docker availability
echo ""
echo "Checking Docker availability:"
if command -v docker >/dev/null 2>&1; then
    if docker ps >/dev/null 2>&1; then
        echo "✅ Docker is available and running"
        
        # Check Docker version
        DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo "  ℹ️  Docker version: ${DOCKER_VERSION}"
        
        # Check for platform support
        if docker buildx version >/dev/null 2>&1; then
            echo "  ✅ Docker BuildKit available"
        else
            echo "  ⚠️  Docker BuildKit not available (recommended for better builds)"
        fi
    else
        echo "⚠️  Docker is installed but not running"
        echo "   Try: sudo systemctl start docker"
        echo "   Or: sudo service docker start"
    fi
else
    echo "⚠️  Docker not found - required for containerized builds"
    echo "   Install from: https://docs.docker.com/get-docker/"
fi

# Check for podman (alternative to docker)
if command -v podman >/dev/null 2>&1; then
    echo "  ℹ️  Podman also available as Docker alternative"
fi

# Check configuration
echo ""
echo "Configuration check:"
if [ -f "${ROOT_DIR}/config" ]; then
    echo "✅ Configuration file exists: config"
    # Validate config syntax
    if bash -n "${ROOT_DIR}/config" 2>/dev/null; then
        echo "✅ Configuration syntax is valid"
        
        # Check for required variables
        source "${ROOT_DIR}/config"
        if [ -n "${TARGET_ARCH}" ]; then
            echo "  ✅ TARGET_ARCH=${TARGET_ARCH}"
        fi
        if [ -n "${DEBIAN_RELEASE}" ]; then
            echo "  ✅ DEBIAN_RELEASE=${DEBIAN_RELEASE}"
        fi
    else
        echo "⚠️  Configuration syntax may have issues"
    fi
else
    echo "ℹ️  No config file found - will use defaults"
    echo "   Copy config.rpi-image-gen.example to config to customize"
fi

# Check rpi-image-gen availability (for native builds)
echo ""
echo "Native build environment:"
if [ -f "/rpi-image-gen/build.sh" ]; then
    echo "✅ rpi-image-gen found at /rpi-image-gen/"
    RPI_IMAGE_GEN_VERSION=$(/rpi-image-gen/build.sh --version 2>/dev/null || echo "unknown")
    echo "  ℹ️  Version: ${RPI_IMAGE_GEN_VERSION}"
elif command -v rpi-image-gen >/dev/null 2>&1; then
    echo "✅ rpi-image-gen found in PATH"
else
    echo "ℹ️  rpi-image-gen not found locally - will use Docker builds"
    echo "   For native builds, install from: https://github.com/raspberrypi/rpi-image-gen"
fi

# Check disk space
echo ""
echo "Disk space check:"
AVAILABLE_SPACE=$(df "${ROOT_DIR}" | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [ "${AVAILABLE_GB}" -gt 15 ]; then
    echo "✅ Excellent disk space: ${AVAILABLE_GB}GB available"
elif [ "${AVAILABLE_GB}" -gt 10 ]; then
    echo "✅ Sufficient disk space: ${AVAILABLE_GB}GB available"
elif [ "${AVAILABLE_GB}" -gt 5 ]; then
    echo "⚠️  Limited disk space: ${AVAILABLE_GB}GB available (recommend 10GB+)"
else
    echo "❌ Insufficient disk space: ${AVAILABLE_GB}GB available (need 10GB+ minimum)"
    exit 1
fi

# Architecture check
echo ""
echo "Architecture recommendations:"
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64|amd64)
        echo "✅ Build host: ${ARCH} (recommended for cross-compilation)"
        echo "  ℹ️  Can build both arm64 and armhf targets efficiently"
        ;;
    aarch64|arm64)
        echo "✅ Build host: ${ARCH} (native arm64 builds possible)"
        echo "  ℹ️  Excellent for arm64 targets, can also build armhf"
        ;;
    armv7l|armhf)
        echo "⚠️  Build host: ${ARCH} (slower builds expected)"
        echo "  ℹ️  Consider using a more powerful machine for faster builds"
        ;;
    *)
        echo "❓ Build host: ${ARCH} (untested architecture)"
        echo "  ⚠️  May encounter compatibility issues"
        ;;
esac

# Check system dependencies for native builds
echo ""
echo "System dependencies:"
DEPS=("git" "python3" "debootstrap" "qemu-user-static")
for dep in "${DEPS[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        echo "  ✅ $dep"
    else
        echo "  ⚠️  Missing: $dep (needed for native builds)"
    fi
done

# Check for binfmt support (needed for cross-compilation)
if [ -f "/proc/sys/fs/binfmt_misc/qemu-aarch64" ] || [ -f "/proc/sys/fs/binfmt_misc/qemu-arm" ]; then
    echo "  ✅ binfmt_misc configured for cross-compilation"
else
    echo "  ⚠️  binfmt_misc may not be configured (see binfmt-misc.md)"
fi

echo ""
echo "Validation complete!"
echo ""

# Provide specific recommendations
echo "Recommendations:"
if [ "${AVAILABLE_GB}" -lt 10 ]; then
    echo "  🔄 Free up disk space (need 10GB minimum)"
fi

if ! docker ps >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
    echo "  📦 Install Docker for containerized builds"
fi

if [ ! -f "${ROOT_DIR}/config" ]; then
    echo "  ⚙️  Create configuration: cp config.rpi-image-gen.example config"
fi

echo ""
echo "Quick start commands:"
echo "  1. Configure: cp config.rpi-image-gen.example config"
echo "  2. Edit config: nano config"
echo "  3. Build: ./build-docker-rpi-image-gen.sh"
echo ""
echo "For more information:"
echo "  - README.md - Getting started guide"
echo "  - docs/RPI_IMAGE_GEN_MIGRATION.md - Migration from pi-gen"
echo "  - https://github.com/raspberrypi/rpi-image-gen - Official documentation"
