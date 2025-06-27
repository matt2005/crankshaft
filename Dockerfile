FROM debian:bookworm

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

# Set up QEMU for cross-compilation
RUN update-binfmts --enable

# Install official Raspberry Pi rpi-image-gen
RUN git clone --depth 1 https://github.com/raspberrypi/rpi-image-gen.git /rpi-image-gen && \
    cd /rpi-image-gen && \
    chmod +x build.sh install_deps.sh && \
    ./install_deps.sh

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
