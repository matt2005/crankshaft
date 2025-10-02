#!/bin/bash -eu

# Crankshaft Layer Build Script for rpi-image-gen
# This script builds Crankshaft using the official Raspberry Pi image generation system

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LAYER_DIR="${DIR}/rpi-image-gen-layer"

# Default configuration
TARGET_ARCH="${TARGET_ARCH:-arm64}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-bookworm}"
IMG_NAME="${IMG_NAME:-crankshaft-ng}"
RPI_IMAGE_GEN_DIR="${RPI_IMAGE_GEN_DIR:-./rpi-image-gen}"

# Parse command line options
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -a ARCH      Target architecture (arm64, armhf)"
    echo "  -r RELEASE   Debian release (bookworm, bullseye)"
    echo "  -n NAME      Image name"
    echo "  -d DIR       rpi-image-gen directory"
    echo "  -c CONFIG    Configuration file"
    echo "  -v           Verbose output"
    echo "  -h           Show help"
    echo ""
    echo "Examples:"
    echo "  $0 -a arm64 -r bookworm"
    echo "  $0 -c config -n my-crankshaft"
    exit 0
}

while getopts "a:r:n:d:c:vh" flag; do
    case "${flag}" in
        a) TARGET_ARCH="${OPTARG}" ;;
        r) DEBIAN_RELEASE="${OPTARG}" ;;
        n) IMG_NAME="${OPTARG}" ;;
        d) RPI_IMAGE_GEN_DIR="${OPTARG}" ;;
        c) CONFIG_FILE="${OPTARG}" ;;
        v) VERBOSE=1 ;;
        h) usage ;;
        *) echo "Unknown option: -${flag}"; usage ;;
    esac
done

echo "Building Crankshaft with rpi-image-gen layer"
echo "============================================="
echo "Architecture: ${TARGET_ARCH}"
echo "Debian Release: ${DEBIAN_RELEASE}"
echo "Image Name: ${IMG_NAME}"
echo "Layer Directory: ${LAYER_DIR}"
echo ""

# Check if rpi-image-gen exists
if [ ! -d "${RPI_IMAGE_GEN_DIR}" ]; then
    echo "Cloning official rpi-image-gen..."
    git clone --depth 1 https://github.com/raspberrypi/rpi-image-gen.git "${RPI_IMAGE_GEN_DIR}"
fi

# Create configuration file for the layer build
CONFIG_FILE="${CONFIG_FILE:-${DIR}/config-layer}"

cat > "${CONFIG_FILE}" << EOF
# Crankshaft Layer Configuration
# Generated automatically by build-layer.sh

IMG_NAME='${IMG_NAME}'
IMG_DATE='\$(date +%Y-%m-%d)'

# Target platform
TARGET_ARCH='${TARGET_ARCH}'
DEBIAN_RELEASE='${DEBIAN_RELEASE}'

# Use standard stages plus our Crankshaft layer
STAGE_LIST="stage0 stage1 stage2-crankshaft"

# Build configuration
DEPLOY_ZIP=1
DEPLOY_DIR='${DIR}/deploy'
WORK_DIR='${DIR}/work'

# User configuration
FIRST_USER_NAME='pi'
FIRST_USER_PASS='raspberry'
ENABLE_SSH=0

# Crankshaft-specific settings
CRANKSHAFT_VERSION='5.0.0'
CRANKSHAFT_BUILD_TYPE='release'

# Hardware features
ENABLE_GPIO=1
ENABLE_I2C=1
ENABLE_SPI=1
ENABLE_CAMERA=1
ENABLE_BLUETOOTH=1
ENABLE_HOTSPOT=1
ENABLE_PULSEAUDIO=1

# Performance settings
GPU_MEM=128
HDMI_FORCE_HOTPLUG=1
AUDIO_OUTPUT='auto'

# Network settings (optional)
WPA_ESSID=''
WPA_PASSWORD=''
WPA_COUNTRY='GB'

# Localization
TIMEZONE_DEFAULT='Europe/London'
LOCALE_DEFAULT='en_GB.UTF-8'
KEYBOARD_KEYMAP='gb'
KEYBOARD_LAYOUT='English (UK)'

# Build system settings
VERBOSE=${VERBOSE:-0}
CONTINUE=0

# Layer configuration
LAYER_DIR='${LAYER_DIR}'
BASE_DIR='${DIR}'
EOF

echo "Generated configuration file: ${CONFIG_FILE}"

# Copy our custom layer into rpi-image-gen
echo "Setting up Crankshaft layer in rpi-image-gen..."
cp -r "${LAYER_DIR}/stage2-crankshaft" "${RPI_IMAGE_GEN_DIR}/"

# Create work and deploy directories
mkdir -p "${DIR}/work" "${DIR}/deploy"

# Change to rpi-image-gen directory and run the build
cd "${RPI_IMAGE_GEN_DIR}"

echo "Starting rpi-image-gen build with Crankshaft layer..."
echo "Build log will be available at: ${DIR}/work/build.log"

# Export required environment variables
export IMG_NAME
export TARGET_ARCH
export DEBIAN_RELEASE
export LAYER_DIR
export BASE_DIR="${DIR}"

# Run the build
if [ "${VERBOSE:-0}" = "1" ]; then
    ./build.sh -c "${CONFIG_FILE}" 2>&1 | tee "${DIR}/work/build.log"
else
    ./build.sh -c "${CONFIG_FILE}" > "${DIR}/work/build.log" 2>&1
fi

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    echo ""
    echo "Build completed successfully!"
    echo "Generated images:"
    ls -la "${DIR}/deploy/"*.img 2>/dev/null || echo "No .img files found in deploy directory"
    echo ""
    echo "Build artifacts available in: ${DIR}/deploy/"
else
    echo ""
    echo "Build failed with exit code: $BUILD_RESULT"
    echo "Check the build log: ${DIR}/work/build.log"
    echo ""
    echo "Last 50 lines of build log:"
    tail -50 "${DIR}/work/build.log" 2>/dev/null || echo "Could not read build log"
    exit $BUILD_RESULT
fi
