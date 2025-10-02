#!/bin/bash -e

# Configure network settings in the chroot environment

echo "Configuring Crankshaft network settings..."

# Install network configuration files
if [ -d "/tmp/network-config" ]; then
    # Install hostapd configuration
    if [ -f "/tmp/network-config/hostapd.conf" ]; then
        cp "/tmp/network-config/hostapd.conf" "/etc/hostapd/hostapd.conf"
        
        # Configure hostapd daemon
        sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
        
        systemctl enable hostapd
        echo "Configured hostapd for WiFi hotspot"
    fi
    
    # Install dnsmasq configuration
    if [ -f "/tmp/network-config/dnsmasq.conf" ]; then
        cp "/tmp/network-config/dnsmasq.conf" "/etc/dnsmasq.conf"
        systemctl enable dnsmasq
        echo "Configured dnsmasq for DHCP"
    fi
    
    # Install WiFi configuration
    if [ -f "/tmp/network-config/wpa_supplicant.conf" ]; then
        cp "/tmp/network-config/wpa_supplicant.conf" "/etc/wpa_supplicant/wpa_supplicant.conf"
        chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
        echo "Configured WiFi client settings"
    fi
    
    # Install network interface configuration
    if [ -f "/tmp/network-config/dhcpcd.conf" ]; then
        cp "/tmp/network-config/dhcpcd.conf" "/etc/dhcpcd.conf"
        echo "Configured network interfaces"
    fi
fi

# Enable IP forwarding for hotspot
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# Configure iptables for hotspot NAT
if [ "${ENABLE_HOTSPOT}" = "1" ]; then
    # Create iptables rules
    mkdir -p /etc/iptables
    
    cat > /etc/iptables/rules.v4 << EOF
# Crankshaft iptables rules
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
-A POSTROUTING -o wlan1 -j MASQUERADE
COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i wlan0 -o eth0 -j ACCEPT
-A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i wlan0 -o wlan1 -j ACCEPT
-A FORWARD -i wlan1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
COMMIT
EOF
    
    # Enable iptables restore on boot
    systemctl enable netfilter-persistent
    
    echo "Configured iptables for hotspot NAT"
fi

# Create Crankshaft network management service
cat > /etc/systemd/system/crankshaft-hotspot.service << EOF
[Unit]
Description=Crankshaft WiFi Hotspot Management
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/crankshaft/scripts/start-hotspot.sh
ExecStop=/opt/crankshaft/scripts/stop-hotspot.sh

[Install]
WantedBy=multi-user.target
EOF

# Create hotspot management scripts
mkdir -p /opt/crankshaft/scripts

cat > /opt/crankshaft/scripts/start-hotspot.sh << 'EOF'
#!/bin/bash
echo "Starting Crankshaft hotspot..." >> /opt/crankshaft/logs/network.log
systemctl start hostapd
systemctl start dnsmasq
iptables-restore < /etc/iptables/rules.v4
EOF

cat > /opt/crankshaft/scripts/stop-hotspot.sh << 'EOF'
#!/bin/bash
echo "Stopping Crankshaft hotspot..." >> /opt/crankshaft/logs/network.log
systemctl stop hostapd
systemctl stop dnsmasq
EOF

chmod +x /opt/crankshaft/scripts/*.sh

# Clean up temporary files
rm -rf /tmp/network-config

echo "Crankshaft network configuration completed"
