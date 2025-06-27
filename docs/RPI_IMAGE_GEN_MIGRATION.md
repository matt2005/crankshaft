# Migration Guide: pi-gen to Official Raspberry Pi rpi-image-gen

This guide helps you migrate from the legacy pi-gen build system to the official Raspberry Pi Foundation's rpi-image-gen.

## Overview

The official [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen) is the modern successor to pi-gen, providing:

- **YAML-based configuration**: More maintainable than shell scripts
- **Better performance**: Improved caching and parallel execution
- **Official support**: Maintained by the Raspberry Pi Foundation
- **Security features**: Built-in SBOM generation and CVE scanning
- **Modern tooling**: Uses bdebstrap, mmdebstrap, and genimage

## Key Differences

| Feature | pi-gen (Legacy) | rpi-image-gen (Modern) |
|---------|-----------------|------------------------|
| **Configuration** | Shell scripts in stages | YAML layers and profiles |
| **Base System** | Raspbian/Raspberry Pi OS | Debian + RPi repositories |
| **Architecture** | Primarily armhf | Native arm64 + armhf support |
| **Toolchain** | Custom scripts | bdebstrap + mmdebstrap |
| **Caching** | Limited | Advanced layer caching |
| **Security** | Manual | Built-in SBOM + CVE scanning |
| **Maintenance** | Community | Official Raspberry Pi Foundation |

## Migration Steps

### 1. Update Your Environment

**Old (pi-gen):**
```bash
cp config.example config
./build-docker.sh
```

**New (rpi-image-gen):**
```bash
cp config.rpi-image-gen.example config
./build-docker-rpi-image-gen.sh
```

### 2. Configuration Changes

**Old config format (shell variables):**
```bash
IMG_NAME='crankshaft'
TARGET_HOSTNAME='crankshaft'
FIRST_USER_NAME='pi'
```

**New config format (same shell variables, different defaults):**
```bash
IMG_NAME='crankshaft-ng'
TARGET_ARCH='arm64'          # New: explicit architecture
DEBIAN_RELEASE='bookworm'    # New: Debian-based
FIRST_USER_NAME='pi'
```

### 3. Architecture Support

**Old (pi-gen):**
- Primarily armhf (32-bit)
- Limited arm64 support
- Raspberry Pi OS base

**New (rpi-image-gen):**
- Native arm64 (64-bit) - recommended
- Full armhf compatibility
- Debian base with RPi repositories

### 4. Stage Migration

The new system automatically handles stage-like functionality through YAML layers:

**Old stages (pi-gen):**
```
stage0/ - APT configuration
stage1/ - Boot files
stage2/ - System packages
stage3/ - Crankshaft installation
stage4/ - Architecture fixes
```

**New layers (rpi-image-gen):**
```
crankshaft/base.yaml        - Base system
crankshaft/multimedia.yaml  - Qt5 + multimedia
crankshaft/bluetooth.yaml   - Bluetooth stack
crankshaft/services.yaml    - Systemd services
```

### 5. File Installation

**Old (pi-gen) - manual copying in scripts:**
```bash
install -m 644 files/service.service "${ROOTFS_DIR}/etc/systemd/system/"
```

**New (rpi-image-gen) - automatic via rootfs-overlay:**
```
device/crankshaft-arm64/device/rootfs-overlay/
├── etc/systemd/system/service.service
├── opt/crankshaft/
└── usr/local/bin/
```

## Build Command Comparison

### Legacy pi-gen Build

```bash
# Configure
cp config.example config
edit config

# Build
./build-docker.sh

# Output
work/*/deploy/*.img
```

### New rpi-image-gen Build

```bash
# Configure  
cp config.rpi-image-gen.example config
edit config

# Build
./build-docker-rpi-image-gen.sh

# Output
deploy/crankshaft-ng-*.img
deploy/crankshaft-ng-*.sbom    # New: Software Bill of Materials
```

## Advanced Features

### SBOM Generation

The new system automatically generates Software Bill of Materials:

```bash
# View installed packages
syft packages ./deploy/crankshaft-ng-*.sbom

# Scan for vulnerabilities
grype ./deploy/crankshaft-ng-*.sbom
```

### Custom YAML Layers

Create custom functionality:

```yaml
# meta/crankshaft/custom.yaml
---
name: my-custom-layer
mmdebstrap:
  packages:
    - my-package
  customize-hook: |
    chroot $1 bash << 'EOCHROOT'
    # Custom configuration
    systemctl enable my-service
    EOCHROOT
```

### Architecture-Specific Builds

```bash
# Build for arm64 (Pi 4/5)
./build-docker-rpi-image-gen.sh -a arm64 -r bookworm

# Build for armhf (Pi 3 and older)
./build-docker-rpi-image-gen.sh -a armhf -r bookworm
```

## Troubleshooting Migration

### Common Issues

1. **Package availability**: Some packages may have different names in Debian vs Raspberry Pi OS
2. **Service names**: Systemd service names might differ
3. **File paths**: Library paths differ between armhf and arm64

### Compatibility Notes

- **Precompiled binaries**: ARM64 binaries need recompilation for arm64 builds
- **Library paths**: Different between `/usr/lib/arm-linux-gnueabihf/` (armhf) and `/usr/lib/aarch64-linux-gnu/` (arm64)
- **Service dependencies**: Some systemd services may have different names

### Getting Help

1. **Check logs**: Build logs are more detailed in rpi-image-gen
2. **Validate config**: Use the validation script:
   ```bash
   ./scripts/validate-rpi-image-gen.sh
   ```
3. **Compare outputs**: Inspect generated YAML and configuration files in work directory

## Benefits of Migration

### Performance Improvements
- **Faster builds**: Better caching and parallel execution
- **Smaller images**: More efficient package selection
- **Better compression**: Modern compression algorithms

### Maintenance Benefits
- **Official support**: Backed by Raspberry Pi Foundation
- **Regular updates**: Active development and bug fixes  
- **Better documentation**: Comprehensive official docs

### Security Enhancements
- **SBOM generation**: Track all installed components
- **CVE scanning**: Automatic vulnerability detection
- **Reproducible builds**: Consistent, auditable results

## Legacy Support

The old pi-gen build system remains available but is deprecated:

```bash
# Still works, but not recommended
cp config.example config
./build-docker.sh
```

**Recommendation**: Migrate to rpi-image-gen for new projects and updates.

## Next Steps

1. **Test the new build**: Start with default configuration
2. **Migrate customizations**: Port your specific modifications to YAML layers
3. **Validate functionality**: Test all features work as expected
4. **Update documentation**: Update any build instructions for your team
5. **Set up CI/CD**: Integrate new build system into automation

For detailed examples and advanced configuration, see:
- [config.rpi-image-gen.example](config.rpi-image-gen.example)
- [Official rpi-image-gen documentation](https://github.com/raspberrypi/rpi-image-gen)
- [Troubleshooting guide](docs/RPI_IMAGE_GEN_TROUBLESHOOTING.md)
