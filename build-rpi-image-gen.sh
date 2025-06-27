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
export KEYBOARD_KEYMAP="${KEYBOARD_KEYMAP:-gb}"
KEYBOARD_KEYMAP="${KEYBOARD_KEYMAP:-gb}"
KEYBOARD_LAYOUT="${KEYBOARD_LAYOUT:-English (UK)}"

# WiFi configuration
WPA_ESSID="${WPA_ESSID:-}"
WPA_PASSWORD="${WPA_PASSWORD:-}"
WPA_COUNTRY="${WPA_COUNTRY:-GB}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Create rpi-image-gen configuration
create_rpi_image_gen_config() {
    local config_file="${WORK_DIR}/crankshaft.cfg"
    
    log "Creating rpi-image-gen config: ${config_file}"
    
    cat > "${config_file}" << EOF
# Crankshaft configuration for rpi-image-gen
# Generated on $(date)

[device]
class=crankshaft-${TARGET_ARCH}
profile=crankshaft

[image]
layout=default
name=${IMG_NAME}
version=${IMG_DATE}

[sys]
outputdir=${WORK_DIR}/output
deploydir=${DEPLOY_DIR}
EOF
}

# Create custom device definition for Crankshaft
create_device_definition() {
    local device_dir="/rpi-image-gen/device/crankshaft-${TARGET_ARCH}"
    
    log "Creating device definition: ${device_dir}"
    mkdir -p "${device_dir}"
    
    # Create device build defaults
    cat > "${device_dir}/build.defaults" << EOF
# Crankshaft ${TARGET_ARCH} device configuration
class=crankshaft-${TARGET_ARCH}
profile=crankshaft
EOF

    # Create device-specific rootfs overlay
    mkdir -p "${device_dir}/device/rootfs-overlay"
    
    # Copy Crankshaft files to device overlay
    if [ -d "${DIR}/stage3/03-crankshaft-base/files" ]; then
        log "Copying Crankshaft base files"
        cp -r "${DIR}/stage3/03-crankshaft-base/files/"* "${device_dir}/device/rootfs-overlay/" 2>/dev/null || true
    fi
    
    if [ -d "${DIR}/stage3/04-crankshaft-bluetooth/files" ]; then
        log "Copying Crankshaft bluetooth files"  
        cp -r "${DIR}/stage3/04-crankshaft-bluetooth/files/"* "${device_dir}/device/rootfs-overlay/" 2>/dev/null || true
    fi
    
    if [ -d "${DIR}/stage3/05-crankshaft-x11/files" ]; then
        log "Copying Crankshaft X11 files"
        cp -r "${DIR}/stage3/05-crankshaft-x11/files/"* "${device_dir}/device/rootfs-overlay/" 2>/dev/null || true
    fi
}

# Create Crankshaft profile for rpi-image-gen
create_profile() {
    local profile_dir="/rpi-image-gen/profile"
    local profile_file="${profile_dir}/crankshaft"
    
    log "Creating Crankshaft profile: ${profile_file}"
    mkdir -p "${profile_dir}"
    
    cat > "${profile_file}" << EOF
# Crankshaft profile for rpi-image-gen
# This defines the layers to include in the build

# Base Debian system
base/${DEBIAN_RELEASE}-${TARGET_ARCH}

# Essential packages
crankshaft/base
crankshaft/multimedia
crankshaft/bluetooth
crankshaft/services
EOF
}

# Create Crankshaft YAML layers
create_yaml_layers() {
    local meta_dir="/rpi-image-gen/meta/crankshaft"
    
    log "Creating Crankshaft YAML layers in ${meta_dir}"
    mkdir -p "${meta_dir}"
    
    # Base layer
    cat > "${meta_dir}/base.yaml" << EOF
---
name: crankshaft-base
mmdebstrap:
  packages:
    - systemd-timesyncd
    - systemd-resolved
    - git
    - curl
    - wget
    - unzip
    - python3
    - python3-pip
  customize-hook: |
    chroot \$1 bash << 'EOCHROOT'
    # Create crankshaft user
    useradd -m -G audio,video,input,dialout,plugdev,netdev ${FIRST_USER_NAME} || true
    echo "${FIRST_USER_NAME}:${FIRST_USER_PASS}" | chpasswd
    
    # Set timezone and locale
    echo "${TIMEZONE_DEFAULT}" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata
    locale-gen ${LOCALE_DEFAULT}
    update-locale LANG=${LOCALE_DEFAULT}
    
    # Set hostname
    echo "CRANKSHAFT-NG" > /etc/hostname
    sed -i 's/raspberrypi/CRANKSHAFT-NG/g' /etc/hosts
    EOCHROOT
EOF

    # Multimedia layer
    cat > "${meta_dir}/multimedia.yaml" << EOF
---
name: crankshaft-multimedia
mmdebstrap:
  packages:
    - qtbase5-dev
    - qtdeclarative5-dev
    - qtmultimedia5-dev
    - qml-module-qtquick2
    - qml-module-qtquick-controls
    - qml-module-qtquick-controls2
    - qml-module-qtquick-layouts
    - gstreamer1.0-plugins-base
    - gstreamer1.0-plugins-good
    - gstreamer1.0-plugins-bad
    - gstreamer1.0-plugins-ugly
    - gstreamer1.0-libav
EOF

    # Bluetooth layer  
    cat > "${meta_dir}/bluetooth.yaml" << EOF
---
name: crankshaft-bluetooth
mmdebstrap:
  packages:
    - bluetooth
    - bluez
    - bluez-tools
    - pulseaudio
    - pulseaudio-module-bluetooth
  customize-hook: |
    chroot \$1 bash << 'EOCHROOT'
    usermod -a -G bluetooth,pulse-access ${FIRST_USER_NAME}
    EOCHROOT
EOF

    # Services layer
    cat > "${meta_dir}/services.yaml" << EOF
---
name: crankshaft-services
mmdebstrap:
  customize-hook: |
    chroot \$1 bash << 'EOCHROOT'
    # Enable essential services
    systemctl enable systemd-resolved
    systemctl enable systemd-timesyncd
    systemctl enable bluetooth
    systemctl enable pulseaudio
    
    # Build information
    echo "${IMG_DATE}" > /etc/crankshaft.date
    echo "${GIT_HASH}" > /etc/crankshaft.build
    echo "${GIT_BRANCH}" > /etc/crankshaft.branch
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
    
    # Set up rpi-image-gen components
    create_rpi_image_gen_config
    create_device_definition
    create_profile
    create_yaml_layers
    
    # Run rpi-image-gen build
    log "Executing rpi-image-gen build..."
    cd /rpi-image-gen
    ./build.sh -c "${WORK_DIR}/crankshaft.cfg"
    
    # Post-process the image
    post_process_image
    
    log "Build completed successfully!"
}

# Post-process the generated image
post_process_image() {
    log "Post-processing image..."
    
    # Find the generated image in rpi-image-gen output
    local output_dir="${WORK_DIR}/output"
    local generated_image=$(find "${output_dir}" -name "*.img" | head -1)
    
    if [ -z "${generated_image}" ]; then
        log "ERROR: No generated image found in ${output_dir}"
        exit 1
    fi
    
    log "Found generated image: ${generated_image}"
    
    # Copy to deploy directory with proper name
    local final_image="${DEPLOY_DIR}/${IMG_NAME}-${IMG_DATE}.img"
    cp "${generated_image}" "${final_image}"
    
    # Generate checksums
    cd "${DEPLOY_DIR}"
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
    
    log "Image post-processing completed"
    log "Final image: ${final_image}"
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
