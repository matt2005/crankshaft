# Crankshaft rpi-image-gen Layer

This directory contains a custom layer for the official Raspberry Pi `rpi-image-gen` build system that creates Crankshaft images.

## Overview

The Crankshaft layer integrates seamlessly with the official Raspberry Pi image generation tools to create custom Raspberry Pi images with Android Auto and CarPlay support.

## Layer Structure

```
rpi-image-gen-layer/
├── layer.conf                         # Layer configuration
├── stage2-crankshaft/                 # Main Crankshaft stage
│   ├── prerun.sh                      # Stage setup script
│   ├── 00-crankshaft-packages/        # Package installation
│   │   ├── 00-packages               # Package list
│   │   ├── 00-run.sh                 # Copy packages to chroot
│   │   └── 01-run-chroot.sh          # Install packages in chroot
│   ├── 01-crankshaft-core/           # Core installation
│   │   ├── 00-run.sh                 # Copy core files
│   │   └── 01-run-chroot.sh          # Install core components
│   ├── 02-crankshaft-network/        # Network configuration
│   │   ├── 00-run.sh                 # Prepare network config
│   │   └── 01-run-chroot.sh          # Apply network settings
│   ├── 03-crankshaft-finalize/       # Final configuration
│   │   └── 00-run-chroot.sh          # Finalize installation
│   └── EXPORT_IMAGE                  # Export marker
└── build-layer.sh                    # Layer build script
```

## Features

The Crankshaft layer provides:

- **Android Auto Support**: USB and wireless Android Auto connectivity
- **CarPlay Support**: USB and wireless CarPlay connectivity  
- **WiFi Hotspot**: Automatic hotspot for wireless connections
- **Bluetooth Audio**: High-quality Bluetooth audio streaming
- **Hardware Integration**: GPIO, I2C, SPI, and camera support
- **Audio System**: PulseAudio with automotive-optimized configuration
- **Network Management**: Intelligent switching between client and hotspot modes

## Usage

### Quick Start

```bash
# Build with default settings (arm64, bookworm)
./build-layer.sh

# Build for specific architecture
./build-layer.sh -a armhf -r bookworm

# Build with custom name
./build-layer.sh -n my-crankshaft -a arm64
```

### Advanced Usage

```bash
# Use custom configuration file
./build-layer.sh -c my-config.conf

# Specify rpi-image-gen directory
./build-layer.sh -d /path/to/rpi-image-gen

# Verbose output
./build-layer.sh -v
```

### Configuration

The layer uses the same configuration format as the main Crankshaft project. Key options:

```bash
# Basic settings
IMG_NAME='crankshaft-ng'
TARGET_ARCH='arm64'              # arm64 or armhf
DEBIAN_RELEASE='bookworm'        # bookworm or bullseye

# Crankshaft features
ENABLE_HOTSPOT=1                 # WiFi hotspot
ENABLE_BLUETOOTH=1               # Bluetooth support
ENABLE_PULSEAUDIO=1              # Audio system

# Hardware
ENABLE_GPIO=1                    # GPIO access
ENABLE_I2C=1                     # I2C bus
ENABLE_SPI=1                     # SPI bus
ENABLE_CAMERA=1                  # Camera support
GPU_MEM=128                      # GPU memory (MB)

# Network (optional)
WPA_ESSID='MyNetwork'            # WiFi network name
WPA_PASSWORD='MyPassword'        # WiFi password
WPA_COUNTRY='GB'                 # WiFi country code
```

## Stage Details

### stage2-crankshaft

This stage builds on top of the standard `stage0` (base system) and `stage1` (boot configuration) to add Crankshaft-specific functionality:

1. **00-crankshaft-packages**: Installs required packages for Android Auto, CarPlay, audio, and network functionality
2. **01-crankshaft-core**: Sets up the core Crankshaft system, user accounts, services, and basic configuration
3. **02-crankshaft-network**: Configures WiFi hotspot, DHCP, DNS, and network management
4. **03-crankshaft-finalize**: Finalizes the installation, sets up logging, creates startup scripts, and applies final configuration

### Integration with Existing Stages

The layer is designed to work with existing Crankshaft stage directories:

- Automatically copies files from `stage3/03-crankshaft-base/files/`
- Integrates prebuilt components from `prebuilts/`
- Maintains compatibility with existing configuration files

## Build Process

The layer build process:

1. **Setup**: Clones official `rpi-image-gen` if not present
2. **Configuration**: Generates layer-specific configuration
3. **Integration**: Copies custom stage into `rpi-image-gen`
4. **Build**: Runs official build system with custom layer
5. **Output**: Generates bootable Crankshaft images

## Output

After a successful build:

- **Images**: `.img` files in `deploy/` directory
- **Archives**: `.zip` files if `DEPLOY_ZIP=1`
- **Logs**: Build logs in `work/build.log`
- **Artifacts**: Additional build artifacts in `work/`

## Compatibility

- **rpi-image-gen**: Compatible with latest official version
- **Raspberry Pi**: Pi 3, Pi 4, Pi 5 (arm64 recommended for Pi 4/5)
- **Debian**: Bookworm (recommended), Bullseye
- **Architectures**: arm64, armhf

## Integration with CI/CD

The layer is designed to work with GitHub Actions and other CI/CD systems:

```bash
# In CI environment
./build-layer.sh -a arm64 -r bookworm -n crankshaft-ci-build
```

## Troubleshooting

### Common Issues

- **Missing rpi-image-gen**: The script will automatically clone it
- **Permission errors**: Ensure script has execute permissions
- **Package failures**: Check network connectivity and package availability
- **Build failures**: Review `work/build.log` for detailed error messages

### Debug Mode

Enable verbose output for debugging:

```bash
./build-layer.sh -v
```

This will show detailed build progress and help identify issues.

## Contributing

To modify the layer:

1. Edit files in `rpi-image-gen-layer/stage2-crankshaft/`
2. Update `layer.conf` for configuration changes
3. Test with `./build-layer.sh`
4. Submit pull requests for improvements

## License

This layer follows the same license as the main Crankshaft project.
