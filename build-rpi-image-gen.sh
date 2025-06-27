#!/bin/bash -eu

# Crankshaft Build Script using rpi-image-gen
# This replaces the traditional pi-gen approach with a more modern, modular system

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Default configuration
IMG_NAME="${IMG_NAME:-crankshaft-ng}"
IMG_DATE="${IMG_DATE:-$(date +%Y-%m-%d)}"
IMG_VERSION="${IMG_VERSION:-v1-${IMG_NAME}}"
IMG_FILENAME="${IMG_FILENAME:-${IMG_DATE}-${IMG_NAME}}"
ZIP_FILENAME="${ZIP_FILENAME:-${IMG_FILENAME}}"

# Architecture configuration
TARGET_ARCH="${TARGET_ARCH:-arm64}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-trixie}"

# Build directories
WORK_DIR="${WORK_DIR:-${DIR}/work/${IMG_FILENAME}}"
DEPLOY_DIR="${DEPLOY_DIR:-${DIR}/deploy}"
LOG_FILE="${WORK_DIR}/build.log"

# Git information
GIT_HASH="${GIT_HASH:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
GIT_BRANCH="${GIT_BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"

# Ensure directories exist
mkdir -p "${WORK_DIR}" "${DEPLOY_DIR}"

# Load user configuration if it exists
if [ -f "${DIR}/config" ]; then
    echo "Loading configuration from ${DIR}/config"
    source "${DIR}/config"
fi

# Export environment variables for rpi-image-gen
export IMG_NAME IMG_DATE IMG_VERSION IMG_FILENAME ZIP_FILENAME
export TARGET_ARCH DEBIAN_RELEASE
export WORK_DIR DEPLOY_DIR LOG_FILE
export GIT_HASH GIT_BRANCH

# User configuration
export FIRST_USER_NAME="${FIRST_USER_NAME:-pi}"
export FIRST_USER_PASS="${FIRST_USER_PASS:-raspberry}"
export ENABLE_SSH="${ENABLE_SSH:-0}"
export TIMEZONE_DEFAULT="${TIMEZONE_DEFAULT:-Europe/London}"
export LOCALE_DEFAULT="${LOCALE_DEFAULT:-en_GB.UTF-8}"
export KEYBOARD_KEYMAP="${KEYBOARD_KEYMAP:-gb}"
export KEYBOARD_LAYOUT="${KEYBOARD_LAYOUT:-English (UK)}"

# WiFi configuration
export WPA_ESSID="${WPA_ESSID:-}"
export WPA_PASSWORD="${WPA_PASSWORD:-}"
export WPA_COUNTRY="${WPA_COUNTRY:-GB}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Main build function
build_image() {
    log "Starting Crankshaft build with rpi-image-gen"
    log "Configuration:"
    log "  Image: ${IMG_FILENAME}"
    log "  Architecture: ${TARGET_ARCH}"
    log "  Debian Release: ${DEBIAN_RELEASE}"
    log "  Git Hash: ${GIT_HASH}"
    log "  Git Branch: ${GIT_BRANCH}"
    
    # Create the main Pifile for crankshaft
    create_main_pifile
    
    # Use rpi-image-gen to build the image
    log "Executing rpi-image-gen build..."
    /rpi-image-gen/rpi-image-gen.sh "${WORK_DIR}/crankshaft.Pifile"
    
    # Post-process the image
    post_process_image
    
    log "Build completed successfully!"
}

# Create the main Pifile that combines all stages
create_main_pifile() {
    local pifile="${WORK_DIR}/crankshaft.Pifile"
    
    log "Creating main Pifile: ${pifile}"
    
    cat > "${pifile}" << EOF
# Crankshaft Image Generation Pifile
# Generated on $(date)
# Target: ${TARGET_ARCH} / ${DEBIAN_RELEASE}

# Base image selection based on architecture
EOF

    if [ "${TARGET_ARCH}" = "arm64" ]; then
        cat >> "${pifile}" << EOF
FROM https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-11/2023-12-05-raspios-bookworm-arm64-lite.zip
EOF
    else
        cat >> "${pifile}" << EOF
FROM https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-12-11/2023-12-05-raspios-bookworm-armhf-lite.zip
EOF
    fi

    cat >> "${pifile}" << EOF

# Expand filesystem
PUMP 2000M

# Stage 0: Configure APT sources
$(generate_stage0_commands)

# Stage 1: Boot files and basic system setup
$(generate_stage1_commands)

# Stage 2: System tweaks and packages
$(generate_stage2_commands)

# Stage 3: Crankshaft installation
$(generate_stage3_commands)

# Stage 4: Architecture-specific fixes
$(generate_stage4_commands)

# Final cleanup and optimization
$(generate_cleanup_commands)
EOF

    log "Main Pifile created successfully"
}

# Generate Stage 0 commands (APT configuration)
generate_stage0_commands() {
    cat << EOF
# Update APT sources for ${DEBIAN_RELEASE}
TO /etc/apt/sources.list
deb http://deb.debian.org/debian/ ${DEBIAN_RELEASE} main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DEBIAN_RELEASE}-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ ${DEBIAN_RELEASE}-updates main contrib non-free non-free-firmware

TO /etc/apt/sources.list.d/raspi.list
deb http://archive.raspberrypi.org/debian/ bookworm main

# Update package lists
RUN apt-get update && apt-get -y dist-upgrade
EOF
}

# Generate Stage 1 commands (Boot configuration)
generate_stage1_commands() {
    cat << EOF
# Configure boot files
TO /boot/config.txt
# Crankshaft boot configuration
dtparam=audio=on
dtparam=spi=on
dtparam=i2c_arm=on
gpu_mem=128
disable_overscan=1
hdmi_force_hotplug=1
hdmi_drive=2

[pi4]
dtoverlay=vc4-fkms-v3d
max_framebuffers=2

[all]

TO /boot/cmdline.txt
console=serial0,115200 console=tty1 root=PARTUUID=ROOTDEV-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait logo.nologo loglevel=0 vt.global_cursor_default=0 splash plymouth.ignore-serial-consoles

# Enable SSH if configured
EOF
    if [ "${ENABLE_SSH}" = "1" ]; then
        echo "RUN systemctl enable ssh"
    else
        echo "RUN systemctl disable ssh"
    fi
}

# Generate Stage 2 commands (System packages and configuration)
generate_stage2_commands() {
    cat << EOF
# Install essential packages for Crankshaft
RUN apt-get install -y \\
    systemd-timesyncd systemd-resolved \\
    bluetooth bluez bluez-tools \\
    pulseaudio pulseaudio-module-bluetooth \\
    hostapd dnsmasq \\
    triggerhappy \\
    plymouth plymouth-themes \\
    git curl wget unzip \\
    python3-dev python3-pip \\
    build-essential cmake \\
    libprotobuf-dev protobuf-compiler \\
    libopenssl-dev libusb-1.0-0-dev \\
    libboost-all-dev \\
    qtbase5-dev qtdeclarative5-dev qtmultimedia5-dev \\
    qml-module-qtquick2 qml-module-qtquick-controls \\
    qml-module-qtquick-controls2 qml-module-qtquick-layouts \\
    qtgstreamer-plugins-qt5 \\
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \\
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \\
    gstreamer1.0-libav \\
    omxplayer

# Install crankshaft specific packages
RUN apt-get install -y \\
    libqt5multimedia5-plugins \\
    libqt5multimediawidgets5 \\
    libqt5qml5 \\
    libqt5quick5 \\
    qml-module-qtmultimedia

# Create user and configure permissions
RUN useradd -m -G audio,video,input,dialout,plugdev,netdev,bluetooth,pulse-access ${FIRST_USER_NAME} || true
RUN echo "${FIRST_USER_NAME}:${FIRST_USER_PASS}" | chpasswd

# Configure timezone and locale
RUN echo "${TIMEZONE_DEFAULT}" > /etc/timezone && \\
    dpkg-reconfigure -f noninteractive tzdata
RUN locale-gen ${LOCALE_DEFAULT}
RUN update-locale LANG=${LOCALE_DEFAULT}

# Set hostname
RUN echo "CRANKSHAFT-NG" > /etc/hostname
RUN sed -i 's/raspberrypi/CRANKSHAFT-NG/g' /etc/hosts

# Configure read-only filesystem support
RUN systemctl disable systemd-random-seed.service
RUN systemctl disable apt-daily.service apt-daily.timer
RUN systemctl disable apt-daily-upgrade.service apt-daily-upgrade.timer
RUN systemctl mask systemd-journald-audit.socket

# Setup overlay filesystem for logs
RUN mkdir -p /var/lib/systemd/system-generators
EOF
}

# Generate Stage 3 commands (Crankshaft specific installation)
generate_stage3_commands() {
    cat << EOF
# Create crankshaft directories
RUN mkdir -p /opt/crankshaft
RUN mkdir -p /boot/crankshaft
RUN mkdir -p /boot/crankshaft/custom

# Install crankshaft base files
INSTALL ${DIR}/stage3/03-crankshaft-base/files/opt/crankshaft/ /opt/crankshaft/
INSTALL ${DIR}/stage3/03-crankshaft-base/files/etc/ /etc/
INSTALL ${DIR}/stage3/03-crankshaft-base/files/usr/ /usr/
INSTALL ${DIR}/stage3/03-crankshaft-base/files/lib/ /lib/
INSTALL ${DIR}/stage3/03-crankshaft-base/files/boot/ /boot/

# Install crankshaft bluetooth files
INSTALL ${DIR}/stage3/04-crankshaft-bluetooth/files/etc/ /etc/
INSTALL ${DIR}/stage3/04-crankshaft-bluetooth/files/opt/ /opt/

# Install crankshaft X11 files  
INSTALL ${DIR}/stage3/05-crankshaft-x11/files/etc/ /etc/
INSTALL ${DIR}/stage3/05-crankshaft-x11/files/opt/ /opt/

# Enable essential systemd services
RUN systemctl enable crankshaft.service || true
RUN systemctl enable openauto.service || true
RUN systemctl enable csng-bluetooth.service || true
RUN systemctl enable pulseaudio.service || true
RUN systemctl enable regensshkeys.service || true
RUN systemctl enable nightmode.timer || true

# Configure PulseAudio
RUN usermod -a -G pulse,pulse-access ${FIRST_USER_NAME}

# Build information
RUN echo "${IMG_DATE}" > /etc/crankshaft.date
RUN echo "${GIT_HASH}" > /etc/crankshaft.build
RUN echo "${GIT_BRANCH}" > /etc/crankshaft.branch
EOF
}

# Generate Stage 4 commands (Architecture-specific fixes)
generate_stage4_commands() {
    if [ "${TARGET_ARCH}" = "arm64" ]; then
        cat << EOF
# ARM64 specific library links
RUN ln -sf /opt/vc/lib/libbrcmEGL.so /usr/lib/aarch64-linux-gnu/libEGL.so || true
RUN ln -sf /opt/vc/lib/libbrcmGLESv2.so /usr/lib/aarch64-linux-gnu/libGLESv2.so || true
RUN ln -sf /opt/vc/lib/libbrcmOpenVG.so /usr/lib/aarch64-linux-gnu/libOpenVG.so || true
RUN ln -sf /opt/vc/lib/libbrcmWFC.so /usr/lib/aarch64-linux-gnu/libWFC.so || true
EOF
    else
        cat << EOF
# ARMHF specific library links
RUN ln -sf /opt/vc/lib/libbrcmEGL.so /usr/lib/arm-linux-gnueabihf/libEGL.so || true
RUN ln -sf /opt/vc/lib/libbrcmGLESv2.so /usr/lib/arm-linux-gnueabihf/libGLESv2.so || true
RUN ln -sf /opt/vc/lib/libbrcmOpenVG.so /usr/lib/arm-linux-gnueabihf/libOpenVG.so || true
RUN ln -sf /opt/vc/lib/libbrcmWFC.so /usr/lib/arm-linux-gnueabihf/libWFC.so || true
EOF
    fi
}

# Generate cleanup commands
generate_cleanup_commands() {
    cat << EOF
# Final system cleanup
RUN apt-get autoremove -y
RUN apt-get autoclean
RUN rm -rf /var/lib/apt/lists/*
RUN rm -rf /tmp/*
RUN rm -rf /var/tmp/*

# Configure for first boot
RUN systemctl enable systemd-resolved
RUN systemctl enable systemd-timesyncd

# Set permissions
RUN chown -R ${FIRST_USER_NAME}:${FIRST_USER_NAME} /home/${FIRST_USER_NAME}
RUN chmod -R 755 /opt/crankshaft
EOF
}

# Post-process the generated image
post_process_image() {
    log "Post-processing image..."
    
    # Find the generated image
    local generated_image=$(find "${WORK_DIR}" -name "*.img" | head -1)
    
    if [ -z "${generated_image}" ]; then
        log "ERROR: No generated image found!"
        exit 1
    fi
    
    log "Found generated image: ${generated_image}"
    
    # Copy to deploy directory with proper name
    local final_image="${DEPLOY_DIR}/${IMG_FILENAME}.img"
    cp "${generated_image}" "${final_image}"
    
    # Generate checksums
    cd "${DEPLOY_DIR}"
    md5sum "$(basename "${final_image}")" > "${IMG_FILENAME}.img.md5"
    sha1sum "$(basename "${final_image}")" > "${IMG_FILENAME}.img.sha1"
    sha256sum "$(basename "${final_image}")" > "${IMG_FILENAME}.img.sha256"
    
    # Create ZIP if requested
    if [ "${DEPLOY_ZIP:-1}" = "1" ]; then
        log "Creating ZIP archive..."
        zip "${ZIP_FILENAME}.zip" \\
            "${IMG_FILENAME}.img" \\
            "${IMG_FILENAME}.img.md5" \\
            "${IMG_FILENAME}.img.sha1" \\
            "${IMG_FILENAME}.img.sha256"
    fi
    
    log "Image post-processing completed"
    log "Final image: ${final_image}"
}

# Main execution
main() {
    echo "Crankshaft Build System"
    echo "======================="
    echo "Using rpi-image-gen for modern Raspberry Pi image creation"
    echo ""
    
    # Check if we're running in Docker
    if [ -f "/.dockerenv" ]; then
        log "Running inside Docker container"
        build_image
    else
        log "Running on host system - consider using build-docker.sh for containerized builds"
        build_image
    fi
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
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -c, --config FILE    Use configuration file"
            echo "  -a, --arch ARCH      Target architecture (arm64, armhf)"
            echo "  -r, --release REL    Debian release (trixie, bookworm)"
            echo "  -h, --help           Show this help"
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
