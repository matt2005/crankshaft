FROM --platform=${BUILDPLATFORM} debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update && \
    apt-get -y install \
        git vim parted curl wget \
        qemu-user-static debootstrap zerofree zip dosfstools \
        tar libcap2-bin rsync grep udev xz-utils xxd file kmod bc \
        systemd-container fdisk gdisk \
        python3 python3-pip python3-yaml \
        ca-certificates podman \
    && rm -rf /var/lib/apt/lists/*

# Install official Raspberry Pi rpi-image-gen
RUN git clone --depth 1 https://github.com/raspberrypi/rpi-image-gen.git /rpi-image-gen && \
    cd /rpi-image-gen && \
    chmod +x build.sh && \
    ./install_deps.sh

COPY . /workspace/

WORKDIR /workspace

VOLUME [ "/workspace/work", "/workspace/deploy"]
