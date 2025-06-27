# Crankshaft NG

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)

A turnkey GNU/Linux solution that transforms a Raspberry Pi to an Android Auto head unit.

**Now with modern rpi-image-gen build system for faster, more reliable builds!**

🌐 https://getcrankshaft.com/

## Quick Start (New Build System)

Ready to build? Get started in 3 commands:

```bash
# 1. Validate your environment
./scripts/validate-rpi-image-gen.sh

# 2. Copy and customize configuration
cp config.rpi-image-gen.example config

# 3. Build with Docker (recommended)
./build-docker-rpi-image-gen.sh
```

Images will be created in the `deploy/` directory when complete.

## Supported Platforms

- **Debian Trixie (arm64)**: Current stable release for Raspberry Pi 4/5 (64-bit) ✅ Recommended
- **Debian Buster (armhf)**: Legacy support for older Raspberry Pi models (32-bit) ⚠️ Deprecated

For migration information and technical details, see [TRIXIE_MIGRATION.md](TRIXIE_MIGRATION.md).

## Build Systems

Crankshaft supports two build approaches:

### Modern Build System (rpi-image-gen) - Recommended

The new build system uses [rpi-image-gen](https://github.com/Nature40/rpi-image-gen) for a more modular, maintainable approach:

```bash
# Copy and customize configuration
cp config.rpi-image-gen.example config

# Build with Docker (recommended)
./build-docker-rpi-image-gen.sh

# Or build natively (requires rpi-image-gen installed)
./build-rpi-image-gen.sh
```

**Advantages:**
- Modular Pifile-based configuration
- Faster builds with better caching
- Modern Docker integration
- Easier to customize and maintain
- Better support for multiple architectures

### Legacy Build System (pi-gen)

The traditional pi-gen based build system:

```bash
# Copy and customize configuration  
cp config.example config

# Build with Docker
./build-docker.sh
```

**Note:** The legacy system will be deprecated in future releases.

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/opencardev/crankshaft.git
   cd crankshaft
   ```

2. **Configure the build**
   ```bash
   cp config.rpi-image-gen.example config
   # Edit config file as needed
   ```

3. **Build the image**
   ```bash
   ./build-docker-rpi-image-gen.sh
   ```

4. **Flash to SD card**
   ```bash
   # Image will be in deploy/ directory
   dd if=deploy/YYYY-MM-DD-crankshaft-ng.img of=/dev/sdX bs=4M status=progress
   ```

## Configuration Options

The new build system supports extensive customization through the config file:

- **Architecture**: Choose between arm64 (Pi 4/5) or armhf (older models)
- **Debian Release**: Select trixie (modern) or bookworm (stable)
- **Features**: Enable/disable WiFi hotspot, Bluetooth, camera support
- **Localization**: Set timezone, locale, keyboard layout
- **Hardware**: Configure GPIO, I2C, SPI support
- **Performance**: Adjust GPU memory, audio settings

See `config.rpi-image-gen.example` for all available options.

## Requirements

- Docker (recommended) or Linux build environment
- 8GB+ free disk space
- Internet connection for downloading packages
