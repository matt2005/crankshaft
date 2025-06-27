# Debian Trixie arm64 Migration Notes

This document outlines the changes needed to fully support Debian Trixie with arm64 architecture.

## Architecture Changes

- **Base System**: Debian Buster (armhf) → Debian Trixie (arm64/aarch64)
- **Library Paths**: `/usr/lib/arm-linux-gnueabihf/` → `/usr/lib/aarch64-linux-gnu/`
- **QEMU**: `qemu-arm-static` → `qemu-aarch64-static`
- **Setarch**: `linux32` → `linux64`

## Binary Compatibility Issues

The following binaries need to be recompiled for arm64 architecture:

### Core Binaries
- `autoapp` - Android Auto application
- `btservice` - Bluetooth service
- `crankshaft` - Main crankshaft binary
- `autoapp_helper` - Android Auto helper
- `usbreset` - USB reset utility
- `gpio2kbd` - GPIO to keyboard mapper

### Plymouth Theme
- `csnganimation.so` - Plymouth animation library for arm64

### Qt5 Components
- Qt5 OpenGLES2 libraries compiled for arm64
- Currently using armhf prebuilt binaries that won't work on arm64

## Repository Updates

### APT Sources
- **Main**: `http://raspbian.raspberrypi.org/raspbian/` → `http://deb.debian.org/debian/`
- **Raspberry Pi**: Updated to use bookworm as trixie repos don't exist yet
- **Security**: Added trixie-security repositories
- **Updates**: Added trixie-updates repositories

### New Packages in Trixie
- `non-free-firmware` - New separate firmware repository
- `systemd-resolved` - Modern DNS resolution
- `systemd-timesyncd` - Modern time synchronization

## Build System Changes

### Docker
- Base image: `debian:buster` → `debian:trixie`
- Platform: `linux/i386` → `linux/amd64`

### Debootstrap
- Architecture: `armhf` → `arm64`
- Bootstrap command updated for 64-bit builds

### GitHub Workflows
- Added Trixie arm64 build configuration
- Maintains backward compatibility with Buster builds

## TODO: Remaining Work

1. **Compile binaries for arm64**:
   - Set up cross-compilation environment
   - Rebuild all C/C++ components for aarch64
   - Update prebuilt binary packages

2. **Qt5 for arm64**:
   - Compile Qt5 with OpenGLES2 support for arm64
   - Package as `Qt_5151_arm64_OpenGLES2.tar.xz`

3. **Testing**:
   - Test on Raspberry Pi 4/5 hardware
   - Verify Android Auto functionality
   - Test Bluetooth connectivity
   - Validate Plymouth themes

4. **Performance optimization**:
   - Take advantage of 64-bit performance improvements
   - Optimize for newer ARM64 CPU features

## Compatibility

- **Backward Compatible**: Buster armhf builds still supported
- **Forward Compatible**: Ready for future Debian releases
- **Hardware**: Optimized for Raspberry Pi 4/5 (64-bit capable)

## Migration Path

Users can migrate existing installations using the updater system:
1. Update apt sources to Trixie
2. Run `apt-get dist-upgrade`
3. Install new firmware packages
4. Reboot to new kernel
