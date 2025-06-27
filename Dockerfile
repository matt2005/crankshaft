FROM --platform=${BUILDPLATFORM} debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get -y update && \
    apt-get -y install \
        git vim parted curl wget \
        qemu-user-static debootstrap zerofree zip dosfstools \
        tar libcap2-bin rsync grep udev xz-utils xxd file kmod bc \
        systemd-container fdisk gdisk \
        python3 python3-pip \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install rpi-image-gen from stable release
RUN git clone --depth 1 https://github.com/Nature40/rpi-image-gen.git /rpi-image-gen && \
    cd /rpi-image-gen && \
    chmod +x rpi-image-gen.sh && \
    # Verify installation
    ./rpi-image-gen.sh --help >/dev/null || true

# Set up workspace
WORKDIR /workspace

# Copy project files
COPY . /workspace/

# Create required directories
RUN mkdir -p /workspace/work /workspace/deploy

# Set up proper permissions
RUN chmod +x /workspace/build-rpi-image-gen.sh 2>/dev/null || true

VOLUME [ "/workspace/work", "/workspace/deploy"]

# Default command
CMD ["/workspace/build-rpi-image-gen.sh"]
