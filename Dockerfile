FROM debian:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get -y update && \
    apt-get -y install \
        git vim parted curl wget \
        qemu-user-static binfmt-support debootstrap zerofree zip dosfstools \
        tar libcap2-bin rsync grep udev xz-utils xxd file kmod bc \
        systemd-container fdisk gdisk \
        python3 python3-pip python3-yaml python3-venv \
        ca-certificates \
        build-essential \
        lsb-release \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# Note: QEMU/binfmt setup is handled by the host system in GitHub Actions
# The qemu-user-static and binfmt-support packages are installed above

# Install official Raspberry Pi rpi-image-gen
RUN git clone --depth 1 https://github.com/raspberrypi/rpi-image-gen.git /rpi-image-gen

# Install dependencies manually - many rpi-image-gen deps aren't in Debian Bookworm
RUN apt-get update && apt-get install -y \
    # Essential build tools available in Bookworm
    coreutils quilt parted debootstrap zerofree \
    dosfstools libarchive-tools libcap2-bin rsync xz-utils file git curl bc \
    gpg pigz xxd \
    # Additional tools that are available
    crudini pv util-linux \
    # Python packages
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Try to install additional packages that might be available
RUN apt-get update && \
    (apt-get install -y bdebstrap mmdebstrap 2>/dev/null || echo "Modern debootstrap tools not available") && \
    (apt-get install -y zstd dbus-user-session uuid-runtime 2>/dev/null || echo "Some utility packages not available") && \
    (apt-get install -y genimage mtools btrfs-progs dctrl-tools 2>/dev/null || echo "Some build tools not available") && \
    (apt-get install -y podman 2>/dev/null || echo "Podman not available, will use docker") && \
    (apt-get install -y python-is-python3 2>/dev/null || echo "python-is-python3 not available") && \
    rm -rf /var/lib/apt/lists/*

# Try to run install_deps.sh but continue on failure
RUN cd /rpi-image-gen && \
    chmod +x install_deps.sh && \
    (./install_deps.sh 2>/dev/null || echo "install_deps.sh failed, continuing with available tools")

# Make build script executable
RUN cd /rpi-image-gen && chmod +x build.sh

# Check what dependencies are actually available
RUN echo "=== Checking available dependencies ===" && \
    cd /rpi-image-gen && \
    ls -la && \
    echo "=== Available commands ===" && \
    which mmdebstrap || echo "mmdebstrap not available" && \
    which bdebstrap || echo "bdebstrap not available" && \
    which debootstrap || echo "debootstrap available" && \
    echo "=== This build will need to use alternative methods ==="

COPY . /workspace/

WORKDIR /workspace

# Make scripts executable
RUN chmod +x /workspace/*.sh 2>/dev/null || true

# Set up volumes with proper permissions
RUN mkdir -p /workspace/work /workspace/deploy && \
    chmod 755 /workspace/work /workspace/deploy

VOLUME [ "/workspace/work", "/workspace/deploy"]

# Default command for debugging
CMD ["/bin/bash"]
