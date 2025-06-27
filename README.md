# Crankshaft

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)

A turnkey GNU/Linux solution that transforms a Raspberry Pi to an Android Auto head unit.

**Now powered by the official Raspberry Pi rpi-image-gen for modern, reliable builds!**

🌐 https://getcrankshaft.com/

## Quick Start

Ready to build? Get started in 3 commands:

```bash
# 1. Validate your environment
./scripts/validate-rpi-image-gen.sh

# 2. Copy and customize configuration
cp config.rpi-image-gen.example config

# 3. Build with Docker (recommended)
./build-docker-rpi-image-gen.sh

# Images will be created in the deploy/ directory
```

## Build Systems

### Modern Build System (Official rpi-image-gen) - Recommended

Uses the official [Raspberry Pi rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen):

**Advantages:**
- Official Raspberry Pi Foundation tool
- YAML-based configuration layers
- Faster builds with better caching
- Modern Docker integration
- Better support for multiple architectures
- Comprehensive SBOM generation
- CVE vulnerability scanning

**Quick Start:**
```bash
cp config.rpi-image-gen.example config
./build-docker-rpi-image-gen.sh
```

### Legacy Build System (pi-gen)

The traditional pi-gen based build system (deprecated):

```bash
cp config.example config
./build-docker.sh
```
