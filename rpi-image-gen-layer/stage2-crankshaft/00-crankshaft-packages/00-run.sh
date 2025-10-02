#!/bin/bash -e

# Copy package list to the chroot environment
cp "${STAGE_DIR}/00-crankshaft-packages/00-packages" "${ROOTFS_DIR}/tmp/packages.list"

echo "Copied package list to chroot environment"
