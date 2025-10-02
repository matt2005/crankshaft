#!/bin/bash -e

# Crankshaft Core Installation Script

echo "Setting up Crankshaft core system..."

# Create crankshaft user
if ! id "crankshaft" &>/dev/null; then
    useradd -m -s /bin/bash crankshaft
    usermod -a -G audio,bluetooth,dialout,gpio,i2c,spi,video crankshaft
    echo "Created crankshaft user"
fi

# Set up crankshaft directories
mkdir -p /opt/crankshaft
mkdir -p /opt/crankshaft/bin
mkdir -p /opt/crankshaft/config
mkdir -p /opt/crankshaft/logs
mkdir -p /opt/crankshaft/scripts

# Set up systemd services directory
mkdir -p /etc/systemd/system

# Copy configuration files
if [ -d "/tmp/crankshaft-files" ]; then
    echo "Copying Crankshaft configuration files..."
    cp -r /tmp/crankshaft-files/* /
    
    # Set proper permissions
    chown -R root:root /opt/crankshaft
    chmod +x /opt/crankshaft/bin/* 2>/dev/null || true
    chmod +x /opt/crankshaft/scripts/* 2>/dev/null || true
    
    # Set permissions for service files
    if [ -d "/etc/systemd/system" ]; then
        chmod 644 /etc/systemd/system/crankshaft*.service 2>/dev/null || true
    fi
fi

# Enable systemd services
systemctl daemon-reload

# Enable Crankshaft services (if they exist)
if [ -f "/etc/systemd/system/crankshaft.service" ]; then
    systemctl enable crankshaft.service
    echo "Enabled crankshaft.service"
fi

if [ -f "/etc/systemd/system/crankshaft-hotspot.service" ]; then
    systemctl enable crankshaft-hotspot.service
    echo "Enabled crankshaft-hotspot.service"
fi

# Configure audio
if [ "${ENABLE_PULSEAUDIO}" = "1" ]; then
    # Add pulse user to audio group
    usermod -a -G audio pulse
    
    # Set up PulseAudio for system-wide access
    sed -i 's/^#system-instance = no/system-instance = yes/' /etc/pulse/daemon.conf
    
    echo "Configured PulseAudio for Crankshaft"
fi

# Configure Bluetooth
if [ "${ENABLE_BLUETOOTH}" = "1" ]; then
    # Add crankshaft user to bluetooth group
    usermod -a -G bluetooth crankshaft
    
    # Enable Bluetooth service
    systemctl enable bluetooth.service
    
    echo "Configured Bluetooth for Crankshaft"
fi

# Configure GPIO access
if [ "${ENABLE_GPIO}" = "1" ]; then
    # Add crankshaft user to gpio group
    usermod -a -G gpio crankshaft
    
    echo "Configured GPIO access for Crankshaft"
fi

# Set up boot configuration
if [ -f "/boot/config.txt" ]; then
    echo "Updating boot configuration for Crankshaft..."
    
    # GPU memory
    if ! grep -q "gpu_mem=" /boot/config.txt; then
        echo "gpu_mem=${GPU_MEM:-128}" >> /boot/config.txt
    fi
    
    # Enable hardware features
    if [ "${ENABLE_I2C}" = "1" ] && ! grep -q "dtparam=i2c_arm=on" /boot/config.txt; then
        echo "dtparam=i2c_arm=on" >> /boot/config.txt
    fi
    
    if [ "${ENABLE_SPI}" = "1" ] && ! grep -q "dtparam=spi=on" /boot/config.txt; then
        echo "dtparam=spi=on" >> /boot/config.txt
    fi
    
    if [ "${ENABLE_CAMERA}" = "1" ] && ! grep -q "start_x=1" /boot/config.txt; then
        echo "start_x=1" >> /boot/config.txt
    fi
    
    # HDMI configuration
    if [ "${HDMI_FORCE_HOTPLUG}" = "1" ] && ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then
        echo "hdmi_force_hotplug=1" >> /boot/config.txt
    fi
fi

echo "Crankshaft core installation completed"
