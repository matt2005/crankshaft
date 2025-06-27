# Migration Guide: pi-gen to rpi-image-gen

This guide explains how to migrate from the traditional pi-gen build system to the modern rpi-image-gen approach.

## Overview

The new rpi-image-gen build system offers several advantages over the traditional pi-gen approach:

- **Modular Design**: Pifile-based configuration instead of complex shell scripts
- **Better Performance**: Improved caching and parallel execution
- **Easier Maintenance**: Declarative configuration vs imperative scripts
- **Modern Docker Integration**: Cleaner container workflow
- **Multi-Architecture Support**: Better handling of arm64 and armhf builds

## Key Differences

### File Structure

| pi-gen (Legacy) | rpi-image-gen (Modern) |
|-----------------|------------------------|
| `build.sh` | `build-rpi-image-gen.sh` |
| `build-docker.sh` | `build-docker-rpi-image-gen.sh` |
| `config.example` | `config.rpi-image-gen.example` |
| `stage*/` directories | Single `*.Pifile` |
| Complex shell scripts | Declarative Pifile syntax |

### Configuration Syntax

**pi-gen (Legacy)**:
```bash
# config
IMG_NAME='crankshaft-ng'
ENABLE_SSH=0
STAGE_LIST="stage0 stage1 stage2 stage3 stage4"
```

**rpi-image-gen (Modern)**:
```bash
# config
IMG_NAME='crankshaft-ng'
TARGET_ARCH='arm64'
DEBIAN_RELEASE='trixie'
ENABLE_SSH=0
```

### Build Process

**pi-gen (Legacy)**:
```bash
./build-docker.sh -c config
```

**rpi-image-gen (Modern)**:
```bash
./build-docker-rpi-image-gen.sh -c config -a arm64 -r trixie
```

## Migration Steps

### 1. Update Configuration

Copy your existing configuration:
```bash
cp config config.backup
cp config.rpi-image-gen.example config
```

Migrate your settings from the old config:
- `IMG_NAME` → remains the same
- `ENABLE_SSH` → remains the same
- Add `TARGET_ARCH='arm64'` (or `armhf` for legacy)
- Add `DEBIAN_RELEASE='trixie'` (or `bookworm`)

### 2. Update Build Scripts

Replace build commands:
```bash
# Old way
./build-docker.sh

# New way
./build-docker-rpi-image-gen.sh
```

### 3. Customize Pifile (Optional)

For advanced customization, create a custom Pifile:
```bash
cp crankshaft.Pifile.template my-custom.Pifile
# Edit my-custom.Pifile as needed
```

### 4. Update CI/CD Pipelines

Update your automation scripts:
```yaml
# GitHub Actions example
- name: Build Crankshaft
  run: ./build-docker-rpi-image-gen.sh -a arm64 -r trixie
```

## Feature Mapping

### Stage Conversion

| pi-gen Stage | rpi-image-gen Equivalent |
|--------------|--------------------------|
| `stage0` (APT config) | `TO /etc/apt/sources.list` + `RUN apt-get update` |
| `stage1` (Boot files) | `TO /boot/config.txt` + `TO /boot/cmdline.txt` |
| `stage2` (Packages) | `RUN apt-get install` commands |
| `stage3` (Crankshaft) | `INSTALL` + `RUN systemctl enable` |
| `stage4` (Arch fixes) | Architecture-specific `RUN` commands |

### Custom Scripts

Convert shell scripts to Pifile commands:

**pi-gen (stage3/03-crankshaft-base/01-run.sh)**:
```bash
install -m 755 files/usr/local/bin/autoapp "${ROOTFS_DIR}/usr/local/bin/"
```

**rpi-image-gen (Pifile)**:
```pifile
INSTALL files/usr/local/bin/autoapp /usr/local/bin/autoapp
RUN chmod +x /usr/local/bin/autoapp
```

### Package Installation

**pi-gen (00-packages)**:
```
bluetooth
bluez
pulseaudio
```

**rpi-image-gen (Pifile)**:
```pifile
RUN apt-get install -y bluetooth bluez pulseaudio
```

## Advanced Migration

### Custom Stages

If you have custom stages in pi-gen, convert them to Pifile sections:

1. **Analyze Dependencies**: Determine what your stage depends on
2. **Convert to Pifile**: Use appropriate Pifile commands
3. **Test Incrementally**: Build and test each section

### Binary Files

For architecture-specific binaries:

**pi-gen**: Separate files in `stage*/files/`
**rpi-image-gen**: Conditional installation based on `TARGET_ARCH`

```pifile
# Conditional binary installation
RUN if [ "${TARGET_ARCH}" = "arm64" ]; then \
      wget -O /usr/local/bin/autoapp https://example.com/autoapp-arm64; \
    else \
      wget -O /usr/local/bin/autoapp https://example.com/autoapp-armhf; \
    fi
```

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   - Ensure all packages are listed in `RUN apt-get install` commands
   - Check that custom repositories are properly configured

2. **File Permissions**
   - Use `RUN chmod` commands after `INSTALL` operations
   - Ensure proper ownership with `RUN chown`

3. **Service Configuration**
   - Use `RUN systemctl enable` for services
   - Ensure services are properly configured before enabling

### Debugging

Enable debug mode in config:
```bash
DEBUG_MODE=1
```

Check build logs:
```bash
# Logs are in work/build.log
tail -f work/*/build.log
```

## Benefits After Migration

1. **Faster Builds**: Improved caching reduces rebuild times
2. **Better Debugging**: Clearer error messages and logging
3. **Easier Customization**: Declarative configuration
4. **Modern Architecture**: Better support for arm64 and newer Debian releases
5. **Simplified Maintenance**: Less complex than shell-based stages

## Rollback Plan

If you need to rollback to pi-gen:
1. Keep your old config files
2. Use the legacy build scripts: `./build-docker.sh`
3. The old stage directories remain functional

## Timeline

- **Current**: Both systems supported
- **Future**: pi-gen system will be deprecated
- **Migration Period**: 6 months to migrate existing setups
- **End of Life**: pi-gen support will be removed in future major version

## Getting Help

- Check the [rpi-image-gen documentation](https://github.com/Nature40/rpi-image-gen)
- Review `crankshaft.Pifile.template` for examples
- Open an issue on GitHub for migration-specific questions
- Join the community discussion for tips and best practices
