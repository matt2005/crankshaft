#!/bin/bash

# Crankshaft rpi-image-gen Validation Script
# Validates the build environment and configuration

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="$(dirname "${DIR}")"

echo "Crankshaft rpi-image-gen Validation"
echo "==================================="

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
    "crankshaft.Pifile.template"
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

# Check for stage directories
echo ""
echo "Checking stage directories:"
STAGE_DIRS=(
    "stage3/03-crankshaft-base"
    "stage3/04-crankshaft-bluetooth"
    "stage3/05-crankshaft-x11"
)

for stage_dir in "${STAGE_DIRS[@]}"; do
    if [ -d "${ROOT_DIR}/${stage_dir}" ]; then
        echo "✅ ${stage_dir}"
    else
        echo "⚠️  Optional: ${stage_dir} (required for full functionality)"
    fi
done

# Check Docker availability
echo ""
echo "Checking Docker availability:"
if command -v docker >/dev/null 2>&1; then
    if docker ps >/dev/null 2>&1; then
        echo "✅ Docker is available and running"
    else
        echo "⚠️  Docker is installed but not running (try: sudo systemctl start docker)"
    fi
else
    echo "⚠️  Docker not found - required for containerized builds"
fi

# Check configuration
echo ""
echo "Configuration check:"
if [ -f "${ROOT_DIR}/config" ]; then
    echo "✅ Configuration file exists: config"
    # Validate config syntax
    if bash -n "${ROOT_DIR}/config" 2>/dev/null; then
        echo "✅ Configuration syntax is valid"
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
if command -v rpi-image-gen.sh >/dev/null 2>&1; then
    echo "✅ rpi-image-gen.sh found in PATH"
elif [ -f "/rpi-image-gen/rpi-image-gen.sh" ]; then
    echo "✅ rpi-image-gen.sh found at /rpi-image-gen/"
else
    echo "ℹ️  rpi-image-gen.sh not found - use Docker builds instead"
fi

# Check disk space
echo ""
echo "Disk space check:"
AVAILABLE_SPACE=$(df "${ROOT_DIR}" | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [ "${AVAILABLE_GB}" -gt 10 ]; then
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
        ;;
    aarch64|arm64)
        echo "✅ Build host: ${ARCH} (native arm64 builds possible)"
        ;;
    armv7l|armhf)
        echo "⚠️  Build host: ${ARCH} (slow builds expected)"
        ;;
    *)
        echo "❓ Build host: ${ARCH} (untested architecture)"
        ;;
esac

echo ""
echo "Validation complete!"
echo ""
echo "Quick start commands:"
echo "  1. Copy configuration: cp config.rpi-image-gen.example config"
echo "  2. Edit configuration: nano config"
echo "  3. Start build: ./build-docker-rpi-image-gen.sh"
echo ""
echo "For more information, see README.md and RPI_IMAGE_GEN_MIGRATION.md"
