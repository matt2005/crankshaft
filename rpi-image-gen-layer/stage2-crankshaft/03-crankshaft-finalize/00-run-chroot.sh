#!/bin/bash -e

# Finalize Crankshaft installation

echo "Finalizing Crankshaft configuration..."

# Set up log directories with proper permissions
mkdir -p /opt/crankshaft/logs
chown -R crankshaft:crankshaft /opt/crankshaft/logs
chmod 755 /opt/crankshaft/logs

# Create version information file
cat > /opt/crankshaft/version << EOF
CRANKSHAFT_VERSION=${CRANKSHAFT_VERSION}
BUILD_DATE=$(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)
TARGET_ARCH=${TARGET_ARCH}
DEBIAN_RELEASE=${DEBIAN_RELEASE}
BUILD_TYPE=${CRANKSHAFT_BUILD_TYPE}
EOF

# Create Crankshaft configuration file
cat > /opt/crankshaft/config/crankshaft.conf << EOF
# Crankshaft Configuration File
# Generated during image build

[system]
version=${CRANKSHAFT_VERSION}
architecture=${TARGET_ARCH}
debian_release=${DEBIAN_RELEASE}

[audio]
enable_pulseaudio=${ENABLE_PULSEAUDIO}
audio_output=${AUDIO_OUTPUT}

[network]
enable_hotspot=${ENABLE_HOTSPOT}
enable_bluetooth=${ENABLE_BLUETOOTH}

[hardware]
enable_gpio=${ENABLE_GPIO}
enable_i2c=${ENABLE_I2C}
enable_spi=${ENABLE_SPI}
enable_camera=${ENABLE_CAMERA}
gpu_memory=${GPU_MEM}

[user]
default_user=${FIRST_USER_NAME}
EOF

# Set proper permissions for config files
chown root:root /opt/crankshaft/config/crankshaft.conf
chmod 644 /opt/crankshaft/config/crankshaft.conf

# Create basic hardware initialization script
cat > /opt/crankshaft/scripts/init-hardware.sh << 'EOF'
#!/bin/bash

# Initialize hardware for Crankshaft
echo "Initializing Crankshaft hardware $(date)" >> /opt/crankshaft/logs/hardware.log

# Load required kernel modules
modprobe i2c-dev 2>/dev/null || true
modprobe spi-dev 2>/dev/null || true

# Set up USB permissions for Android devices
if [ -f /etc/udev/rules.d/51-android.rules ]; then
    udevadm control --reload-rules
    udevadm trigger
fi

echo "Hardware initialization completed" >> /opt/crankshaft/logs/hardware.log
EOF

# Create automotive services startup script
cat > /opt/crankshaft/scripts/start-automotive.sh << 'EOF'
#!/bin/bash

# Start Android Auto and CarPlay services
echo "Starting automotive services $(date)" >> /opt/crankshaft/logs/automotive.log

# Monitor for Android devices
echo "Monitoring for Android Auto devices..." >> /opt/crankshaft/logs/automotive.log

# Monitor for iOS devices  
echo "Monitoring for CarPlay devices..." >> /opt/crankshaft/logs/automotive.log

# This is a placeholder - actual implementation would go here
while true; do
    # Check for connected devices
    sleep 5
    
    # Log device status periodically
    if [ $(($(date +%s) % 60)) -eq 0 ]; then
        echo "Device monitoring active $(date)" >> /opt/crankshaft/logs/automotive.log
    fi
done
EOF

chmod +x /opt/crankshaft/scripts/*.sh

# Enable all Crankshaft services
systemctl daemon-reload
systemctl enable crankshaft.service
systemctl enable crankshaft-hotspot.service

# Set up automatic login for pi user if SSH is disabled
if [ "${ENABLE_SSH}" != "1" ]; then
    # Configure automatic login
    systemctl set-default multi-user.target
    
    # Create autologin service for pi user
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${FIRST_USER_NAME} --noclear %I \$TERM
EOF
fi

# Create welcome message
cat > /etc/motd << EOF

 ██████╗██████╗  █████╗ ███╗   ██╗██╗  ██╗███████╗██╗  ██╗ █████╗ ███████╗████████╗
██╔════╝██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝██╔════╝██║  ██║██╔══██╗██╔════╝╚══██╔══╝
██║     ██████╔╝███████║██╔██╗ ██║█████╔╝ ███████╗███████║███████║█████╗     ██║   
██║     ██╔══██╗██╔══██║██║╚██╗██║██╔═██╗ ╚════██║██╔══██║██╔══██║██╔══╝     ██║   
╚██████╗██║  ██║██║  ██║██║ ╚████║██║  ██╗███████║██║  ██║██║  ██║██║        ██║   
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝   

Android Auto and CarPlay for Raspberry Pi
Version: ${CRANKSHAFT_VERSION}
Architecture: ${TARGET_ARCH}

For support and documentation, visit: https://github.com/opencardev/crankshaft

EOF

# Clean up temporary files
rm -rf /tmp/crankshaft-files

echo "Crankshaft installation finalized successfully"
