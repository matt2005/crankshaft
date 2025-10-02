#!/bin/bash -e

# Copy network configuration files to chroot environment

echo "Setting up Crankshaft network configuration..."

# Create configuration directory
mkdir -p "${ROOTFS_DIR}/tmp/network-config"

# Create hostapd configuration if hotspot is enabled
if [ "${ENABLE_HOTSPOT}" = "1" ]; then
    cat > "${ROOTFS_DIR}/tmp/network-config/hostapd.conf" << EOF
# Crankshaft Hotspot Configuration
interface=wlan0
driver=nl80211
ssid=Crankshaft
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=crankshaft
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
fi

# Create dnsmasq configuration for hotspot
if [ "${ENABLE_HOTSPOT}" = "1" ]; then
    cat > "${ROOTFS_DIR}/tmp/network-config/dnsmasq.conf" << EOF
# Crankshaft DHCP Configuration
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=crankshaft.local
address=/crankshaft.local/192.168.4.1
EOF
fi

# Create WiFi configuration if specified
if [ -n "${WPA_ESSID}" ] && [ -n "${WPA_PASSWORD}" ]; then
    cat > "${ROOTFS_DIR}/tmp/network-config/wpa_supplicant.conf" << EOF
country=${WPA_COUNTRY:-GB}
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="${WPA_ESSID}"
    psk="${WPA_PASSWORD}"
}
EOF
fi

# Create network interface configuration
cat > "${ROOTFS_DIR}/tmp/network-config/dhcpcd.conf" << EOF
# Crankshaft network configuration
hostname
clientid
persistent
option rapid_commit
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option ntp_servers
require dhcp_server_identifier
slaac private

# Static IP for hotspot interface
interface wlan0
static ip_address=192.168.4.1/24
nohook wpa_supplicant
EOF

echo "Network configuration files prepared"
