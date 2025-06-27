#!/bin/bash -eu

# Crankshaft Build Script using official Raspberry Pi rpi-image-gen
# Uses the official rpi-image-gen from https://github.com/raspberrypi/rpi-image-gen

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Default configuration
IMG_NAME="${IMG_NAME:-crankshaft-ng}"
IMG_DATE="${IMG_DATE:-$(date +%Y-%m-%d)}"
TARGET_ARCH="${TARGET_ARCH:-arm64}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-bookworm}"

# Build directories
WORK_DIR="${WORK_DIR:-${DIR}/work}"
DEPLOY_DIR="${DEPLOY_DIR:-${DIR}/deploy}"

# Git information
GIT_HASH="${GIT_HASH:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
GIT_BRANCH="${GIT_BRANCH:-$(git branch --show-current 2>/dev/null || echo 'main')}"

# Ensure directories exist
mkdir -p "${WORK_DIR}" "${DEPLOY_DIR}"

# Load user configuration if it exists
if [ -f "${DIR}/config" ]; then
    echo "Loading configuration from ${DIR}/config"
    source "${DIR}/config"
fi

# User configuration defaults
FIRST_USER_NAME="${FIRST_USER_NAME:-pi}"
FIRST_USER_PASS="${FIRST_USER_PASS:-raspberry}"
ENABLE_SSH="${ENABLE_SSH:-0}"
TIMEZONE_DEFAULT="${TIMEZONE_DEFAULT:-Europe/London}"
LOCALE_DEFAULT="${LOCALE_DEFAULT:-en_GB.UTF-8}"
KEYBOARD_KEYMAP="${KEYBOARD_KEYMAP:-gb}"
KEYBOARD_LAYOUT="${KEYBOARD_LAYOUT:-English (UK)}"

# WiFi configuration
WPA_ESSID="${WPA_ESSID:-}"
WPA_PASSWORD="${WPA_PASSWORD:-}"
WPA_COUNTRY="${WPA_COUNTRY:-GB}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Create a minimal rpi-image-gen configuration for Crankshaft
create_config() {
    local config_file="${WORK_DIR}/crankshaft.cfg"
    
    log "Creating rpi-image-gen config: ${config_file}"
    
    # Choose appropriate device class based on architecture
    local device_class="pi5"  # Default for arm64
    if [ "${TARGET_ARCH}" = "armhf" ]; then
        device_class="pi4"  # Use pi4 for armhf builds
    fi
    
    cat > "${config_file}" << EOF
# Crankshaft configuration for rpi-image-gen
# Generated on $(date)

[image]
layout=mbr/simple_dual
boot_part_size=200%
root_part_size=300%
name=${IMG_NAME}

[device]
class=${device_class}
profile=crankshaft

[sys]
outputdir=${WORK_DIR}/output
deploydir=${DEPLOY_DIR}
EOF

    echo "${config_file}"
}

# Create minimal device definition (not needed since we'll use pi5)
create_device_definition() {
    log "Using existing pi5 device class - no custom device definition needed"
}

# Create profile for Crankshaft based on existing minimal profile
create_profile() {
    local profile_dir="/rpi-image-gen/profile"
    local profile_file="${profile_dir}/crankshaft"
    
    log "Creating Crankshaft profile: ${profile_file}"
    mkdir -p "${profile_dir}"
    
    # Determine the correct base layer and kernel package based on architecture
    local base_layer=""
    local kernel_package=""
    
    if [ "${TARGET_ARCH}" = "armhf" ]; then
        base_layer="raspbian/bookworm/base-apt"
        kernel_package="linux-image-v7l"
    else
        base_layer="debian/bookworm/arm64/base-apt"
        kernel_package="linux-image-v8"
    fi
    
    # Create profile based on the existing minimal system with our additions
    cat > "${profile_file}" << EOF
# Crankshaft profile based on bookworm minimal system
# Contains minimal system + Crankshaft additions

# Base system
${base_layer}
rpi/debian/bookworm/apt
rpi/misc-utils
rpi/base/essential
rpi/boot-firmware
rpi/${TARGET_ARCH}/${kernel_package}
rpi/user-credentials
rpi/misc-skel
sys-apps/systemd-net-min
sys-apps/fake-hwclock

# Crankshaft additions
crankshaft/base
EOF
}

# Create minimal YAML layer for Crankshaft
create_yaml_layer() {
    local meta_dir="/rpi-image-gen/meta/crankshaft"
    
    log "Creating Crankshaft YAML layer in ${meta_dir}"
    mkdir -p "${meta_dir}"
    
    # Base layer with Crankshaft-specific packages and configuration
    cat > "${meta_dir}/base.yaml" << EOF
---
name: crankshaft-base
mmdebstrap:
  packages:
    # Additional packages for Crankshaft
    - python3-dev
    - python3-setuptools
    - python3-wheel
    - pkg-config
    - cmake
    - bluetooth
    - bluez
    - pulseaudio
    - alsa-utils
  customize-hook: |
    chroot \$1 bash << 'EOCHROOT'
    # Set hostname to Crankshaft
    echo "CRANKSHAFT-NG" > /etc/hostname
    sed -i 's/\bdebian\b/CRANKSHAFT-NG/g' /etc/hosts
    
    # Enable bluetooth service
    systemctl enable bluetooth
    
    # Create Crankshaft build info
    echo "${IMG_DATE}" > /etc/crankshaft.date
    echo "${GIT_HASH}" > /etc/crankshaft.build
    echo "${GIT_BRANCH}" > /etc/crankshaft.branch
    echo "Built with rpi-image-gen" > /etc/crankshaft.builder
    
    # Add user to audio/bluetooth groups (user already created by rpi/user-credentials)
    if id "${FIRST_USER_NAME}" >/dev/null 2>&1; then
        usermod -a -G audio,bluetooth ${FIRST_USER_NAME}
    fi
    EOCHROOT
EOF
}

# Main build function
build_image() {
    log "Starting Crankshaft build with official rpi-image-gen"
    log "Configuration:"
    log "  Image: ${IMG_NAME}"
    log "  Architecture: ${TARGET_ARCH}"
    log "  Debian Release: ${DEBIAN_RELEASE}"
    log "  Git Hash: ${GIT_HASH}"
    log "  Git Branch: ${GIT_BRANCH}"
    
    # Check if rpi-image-gen is available
    if [ ! -d "/rpi-image-gen" ]; then
        log "ERROR: rpi-image-gen not found at /rpi-image-gen"
        exit 1
    fi
    
    # Set up rpi-image-gen components
    create_device_definition  # This just logs that we're using pi5
    create_profile            # Creates our custom profile
    create_yaml_layer         # Creates our Crankshaft layer
    
    # Create configuration file
    local config_file=$(create_config)
    
    # Change to rpi-image-gen directory
    cd /rpi-image-gen
    
    # Check if build script exists
    if [ ! -f "./build.sh" ]; then
        log "ERROR: rpi-image-gen build.sh not found"
        exit 1
    fi
    
    chmod +x ./build.sh
    
    log "Contents of rpi-image-gen directory:"
    ls -la
    
    # Run the build
    log "Executing rpi-image-gen build..."
    if [ "${VERBOSE:-0}" = "1" ]; then
        ./build.sh -c "${config_file}" -v
    else
        ./build.sh -c "${config_file}"
    fi
    
    # Post-process the image
    post_process_image
    
    log "Build completed successfully!"
}

# Post-process the generated image
post_process_image() {
    log "Post-processing image..."
    
    # Based on rpi-image-gen docs, images should be in work/<name>/artefacts/
    local output_base="${WORK_DIR}/output"
    local generated_image=""
    
    # First try the standard rpi-image-gen output structure
    if [ -d "${output_base}" ]; then
        log "Searching for images in output directory: ${output_base}"
        # Look for the image in the artefacts subdirectory
        generated_image=$(find "${output_base}" -name "*.img" -type f | head -1)
    fi
    
    # If not found in output, search broader
    if [ -z "${generated_image}" ]; then
        log "No image found in ${output_base}, searching broader..."
        
        # Check all possible locations
        for search_dir in "${DEPLOY_DIR}" "${WORK_DIR}" "/rpi-image-gen/work" "/rpi-image-gen/deploy" .; do
            if [ -d "${search_dir}" ]; then
                log "Searching: ${search_dir}"
                found_image=$(find "${search_dir}" -name "*.img" -type f | head -1)
                if [ -n "${found_image}" ]; then
                    generated_image="${found_image}"
                    break
                fi
            fi
        done
    fi
    
    if [ -z "${generated_image}" ]; then
        log "ERROR: No generated image found"
        log "Output directory structure:"
        if [ -d "${output_base}" ]; then
            find "${output_base}" -type f | head -20
        else
            echo "Output directory ${output_base} does not exist"
        fi
        log "Available .img and .zip files:"
        find . -name "*.img" -o -name "*.zip" 2>/dev/null | head -20 || true
        exit 1
    fi
    
    log "Found generated image: ${generated_image}"
    
    # Copy to deploy directory with proper name
    local final_image="${DEPLOY_DIR}/${IMG_NAME}-${IMG_DATE}.img"
    
    # Ensure deploy directory exists
    mkdir -p "${DEPLOY_DIR}"
    
    # Copy image if it's not already in the right place
    if [ "${generated_image}" != "${final_image}" ]; then
        log "Copying image to final location: ${final_image}"
        cp "${generated_image}" "${final_image}"
    fi
    
    # Generate checksums
    cd "${DEPLOY_DIR}"
    log "Generating checksums..."
    md5sum "$(basename "${final_image}")" > "${IMG_NAME}-${IMG_DATE}.img.md5"
    sha1sum "$(basename "${final_image}")" > "${IMG_NAME}-${IMG_DATE}.img.sha1"
    sha256sum "$(basename "${final_image}")" > "${IMG_NAME}-${IMG_DATE}.img.sha256"
    
    # Create ZIP if requested
    if [ "${DEPLOY_ZIP:-1}" = "1" ]; then
        log "Creating ZIP archive..."
        zip "${IMG_NAME}-${IMG_DATE}.zip" \
            "${IMG_NAME}-${IMG_DATE}.img" \
            "${IMG_NAME}-${IMG_DATE}.img.md5" \
            "${IMG_NAME}-${IMG_DATE}.img.sha1" \
            "${IMG_NAME}-${IMG_DATE}.img.sha256"
    fi
    
    # Display final results
    log "Image post-processing completed"
    log "Final image: ${final_image}"
    log "Generated artifacts:"
    ls -lh "${DEPLOY_DIR}/${IMG_NAME}-${IMG_DATE}."*
}

# Main execution
main() {
    echo "Crankshaft Build System"
    echo "======================="
    echo "Using official Raspberry Pi rpi-image-gen"
    echo ""
    
    # Check if we're running in Docker
    if [ -f "/.dockerenv" ]; then
        log "Running inside Docker container"
    else
        log "Running on host system"
        
        # Check if rpi-image-gen is available
        if [ ! -d "/rpi-image-gen" ]; then
            log "ERROR: rpi-image-gen not found at /rpi-image-gen"
            log "Please install rpi-image-gen or use Docker build"
            exit 1
        fi
    fi
    
    build_image
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            if [ -f "${CONFIG_FILE}" ]; then
                source "${CONFIG_FILE}"
            fi
            shift 2
            ;;
        -a|--arch)
            TARGET_ARCH="$2"
            shift 2
            ;;
        -r|--release)
            DEBIAN_RELEASE="$2"
            shift 2
            ;;
        -n|--name)
            IMG_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -c, --config FILE    Use configuration file"
            echo "  -a, --arch ARCH      Target architecture (arm64, armhf)"
            echo "  -r, --release REL    Debian release (bookworm, bullseye)"
            echo "  -n, --name NAME      Image name"
            echo "  -h, --help           Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 -c config -a arm64 -r bookworm"
            echo "  $0 -n my-crankshaft -a armhf"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main
