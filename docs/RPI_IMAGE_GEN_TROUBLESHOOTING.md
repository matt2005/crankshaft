# rpi-image-gen Build Troubleshooting

This guide covers common issues when using the new rpi-image-gen build system.

## Common Issues and Solutions

### Build Environment

#### Docker Build Fails
**Error**: `error connecting to docker:`
**Solution**: 
1. Ensure Docker is installed and running
2. Add your user to the docker group: `sudo usermod -aG docker $USER`
3. Restart your session or run: `newgrp docker`
4. Try using sudo: `sudo ./build-docker-rpi-image-gen.sh`

#### Insufficient Disk Space
**Error**: Build stops with disk space errors
**Solution**:
1. Free up at least 10GB of disk space
2. Remove old Docker images: `docker system prune -a`
3. Clear work directory: `rm -rf work/`

### Configuration Issues

#### Invalid Configuration File
**Error**: Build fails with configuration syntax errors
**Solution**:
1. Validate syntax: `bash -n config`
2. Check for missing quotes or invalid characters
3. Compare with `config.rpi-image-gen.example`

#### Missing Architecture Binaries
**Error**: autoapp or other binaries not found
**Solution**:
1. Ensure arm64 binaries are available in stage files
2. Check architecture matches TARGET_ARCH setting
3. Recompile binaries for target architecture if needed

### rpi-image-gen Specific Issues

#### Pifile Syntax Errors
**Error**: rpi-image-gen fails to parse Pifile
**Solution**:
1. Check generated Pifile in work directory
2. Validate Pifile syntax manually
3. Review stage file paths and permissions

#### Base Image Download Fails
**Error**: Cannot download Raspberry Pi OS image
**Solution**:
1. Check internet connectivity
2. Verify image URL is current
3. Manually download and cache image
4. Use alternative mirror

#### Mount/Unmount Issues
**Error**: Image mounting fails during build
**Solution**:
1. Ensure running with sufficient privileges
2. Check for leftover loop devices: `losetup -a`
3. Clean up: `sudo losetup -D`
4. Restart Docker daemon

### Performance Issues

#### Slow Builds
**Symptoms**: Build takes extremely long time
**Solutions**:
1. Use SSD storage instead of traditional hard drives
2. Increase Docker memory allocation
3. Use multi-core Docker builds if available
4. Build on x86_64 host for cross-compilation

#### Out of Memory Errors
**Error**: Build kills due to OOM
**Solution**:
1. Increase Docker memory limits
2. Close other applications during build
3. Use swap space if available
4. Consider building on machine with more RAM

### Architecture-Specific Issues

#### ARM64 vs ARMHF Confusion
**Error**: Wrong architecture binaries
**Solution**:
1. Verify TARGET_ARCH matches your Pi model
2. Pi 4/5: use arm64
3. Pi 3 and older: use armhf
4. Ensure all binaries match target architecture

#### Missing Library Links
**Error**: OpenGL/graphics libraries not found
**Solution**:
1. Check stage4 library linking commands
2. Verify VideoCore libraries are properly linked
3. Match library paths to target architecture

## Debugging Steps

### Enable Verbose Logging
Add to your config file:
```bash
# Enable debug output
set -x
VERBOSE=1
```

### Examine Generated Files
Check these locations for debugging:
```bash
# Generated Pifile
cat work/*/crankshaft.Pifile

# Build logs
tail -f work/*/build.log

# Container logs (if using Docker)
docker logs crankshaft-builder
```

### Manual Pifile Testing
Test Pifile generation without full build:
```bash
# Generate Pifile only
./build-rpi-image-gen.sh --generate-pifile-only

# Test with rpi-image-gen directly
/rpi-image-gen/rpi-image-gen.sh work/crankshaft.Pifile --dry-run
```

### Container Debugging
Enter build container for investigation:
```bash
# Start container with shell
docker run -it --privileged --rm \
  -v "$(pwd)/work":/workspace/work \
  -v "$(pwd)/deploy":/workspace/deploy \
  crankshaft-rpi-image-gen /bin/bash

# Then run build steps manually
cd /workspace
./build-rpi-image-gen.sh
```

## Getting Help

### Check Logs
Always include these when asking for help:
1. Full build log output
2. Contents of generated Pifile
3. Your config file (with sensitive data removed)
4. System information: OS, Docker version, available disk/memory

### Validate Environment
Run the validation script:
```bash
./scripts/validate-rpi-image-gen.sh
```

### Compare with Legacy Build
If rpi-image-gen build fails, try legacy pi-gen:
```bash
cp config.example config
./build-docker.sh
```

### Community Support
- GitHub Issues: Report bugs and feature requests
- Documentation: Check README.md and migration guides
- Examples: Review config.rpi-image-gen.example and crankshaft.Pifile.template

## Migration from pi-gen

See [RPI_IMAGE_GEN_MIGRATION.md](RPI_IMAGE_GEN_MIGRATION.md) for detailed migration steps.

## Performance Tips

### Optimal Build Environment
- Use x86_64 host for cross-compilation
- SSD storage with 20GB+ free space
- 8GB+ RAM recommended
- Docker with sufficient memory allocation

### Caching Strategies
- Keep work directory between builds for caching
- Use Docker layer caching
- Cache base Raspberry Pi OS images locally

### Parallel Builds
- Use Docker BuildKit for parallel layer builds
- Consider building multiple configurations simultaneously
- Use separate work directories for different targets
