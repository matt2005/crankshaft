#!/bin/bash -e

# Crankshaft Package Installation Script

echo "Installing Crankshaft packages..."

# Update package lists
apt-get update

# Install packages with error handling
while read -r package; do
    # Skip empty lines and comments
    [[ "$package" =~ ^[[:space:]]*$ ]] && continue
    [[ "$package" =~ ^[[:space:]]*# ]] && continue
    
    echo "Installing package: $package"
    if ! apt-get install -y "$package"; then
        echo "WARNING: Failed to install package: $package"
        echo "Continuing with build..."
    fi
done < /tmp/packages.list

# Clean up package cache
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Package installation completed"
