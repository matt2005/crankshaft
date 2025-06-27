# Crankshaft

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)

A turnkey GNU/Linux solution that transforms a Raspberry Pi to an Android Auto head unit.

https://getcrankshaft.com/

## Supported Platforms

- **Debian Trixie (arm64)**: Current stable release for Raspberry Pi 4/5 (64-bit)
- **Debian Buster (armhf)**: Legacy support for older Raspberry Pi models (32-bit)

For migration information and technical details, see [TRIXIE_MIGRATION.md](TRIXIE_MIGRATION.md).

# Docker build image

- Ensure binfmt support installed [binfmt-support](binfmt-misc.md)

- Create config for pi-gen
```bash
cp config.example config
```
- Build image
```bash
./build-docker.sh
```
