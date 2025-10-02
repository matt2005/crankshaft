#!/bin/bash -e

# Copy Crankshaft core files to the chroot environment

echo "Copying Crankshaft core files..."

# Create temporary directory in chroot
mkdir -p "${ROOTFS_DIR}/tmp/crankshaft-files"

# Copy Crankshaft-specific files from the current stages
if [ -d "${BASE_DIR}/stage3/03-crankshaft-base/files" ]; then
    cp -r "${BASE_DIR}/stage3/03-crankshaft-base/files"/* "${ROOTFS_DIR}/tmp/crankshaft-files/" 2>/dev/null || true
fi

if [ -d "${BASE_DIR}/stage3/04-crankshaft-bluetooth/files" ]; then
    cp -r "${BASE_DIR}/stage3/04-crankshaft-bluetooth/files"/* "${ROOTFS_DIR}/tmp/crankshaft-files/" 2>/dev/null || true
fi

if [ -d "${BASE_DIR}/stage3/05-crankshaft-x11/files" ]; then
    cp -r "${BASE_DIR}/stage3/05-crankshaft-x11/files"/* "${ROOTFS_DIR}/tmp/crankshaft-files/" 2>/dev/null || true
fi

# Copy prebuilt files if they exist
if [ -d "${BASE_DIR}/prebuilts" ]; then
    echo "Copying prebuilt Crankshaft files..."
    
    # Copy udev rules
    if [ -d "${BASE_DIR}/prebuilts/udev" ]; then
        mkdir -p "${ROOTFS_DIR}/tmp/crankshaft-files/etc/udev/rules.d"
        cp "${BASE_DIR}/prebuilts/udev"/*.rules "${ROOTFS_DIR}/tmp/crankshaft-files/etc/udev/rules.d/" 2>/dev/null || true
    fi
    
    # Copy other prebuilt components
    find "${BASE_DIR}/prebuilts" -type f -name "*.sh" -exec chmod +x {} \;
fi

# Create basic Crankshaft service file
mkdir -p "${ROOTFS_DIR}/tmp/crankshaft-files/etc/systemd/system"

cat > "${ROOTFS_DIR}/tmp/crankshaft-files/etc/systemd/system/crankshaft.service" << EOF
[Unit]
Description=Crankshaft Android Auto and CarPlay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=crankshaft
WorkingDirectory=/opt/crankshaft
ExecStart=/opt/crankshaft/bin/crankshaft-main
Restart=always
RestartSec=5
Environment=DISPLAY=:0

[Install]
WantedBy=multi-user.target
EOF

# Create basic startup script
mkdir -p "${ROOTFS_DIR}/tmp/crankshaft-files/opt/crankshaft/bin"

cat > "${ROOTFS_DIR}/tmp/crankshaft-files/opt/crankshaft/bin/crankshaft-main" << 'EOF'
#!/bin/bash

# Crankshaft main startup script
echo "Starting Crankshaft $(date)" >> /opt/crankshaft/logs/crankshaft.log

# Initialize hardware
/opt/crankshaft/scripts/init-hardware.sh

# Start Android Auto/CarPlay detection
/opt/crankshaft/scripts/start-automotive.sh

# Keep the service running
while true; do
    sleep 60
done
EOF

chmod +x "${ROOTFS_DIR}/tmp/crankshaft-files/opt/crankshaft/bin/crankshaft-main"

echo "Crankshaft core files copied successfully"
