#!/bin/bash

# Fix PiTFT Display Configuration
# This script properly configures the Adafruit PiTFT 3.5" display

set -e

echo "=== Fixing PiTFT 3.5\" Display Configuration ==="
echo ""

CONFIG_FILE="/boot/firmware/config.txt"

# Enable SPI
echo "Enabling SPI interface..."
if ! grep -q "^dtparam=spi=on" "$CONFIG_FILE"; then
    echo "dtparam=spi=on" | sudo tee -a "$CONFIG_FILE"
    echo "✓ SPI enabled"
else
    echo "✓ SPI already enabled"
fi

# Check if pitft overlay exists
if grep -q "dtoverlay=pitft35-resistive" "$CONFIG_FILE"; then
    echo "✓ PiTFT overlay already configured"
else
    echo "Adding PiTFT overlay..."
    sudo bash -c "cat >> $CONFIG_FILE << 'EOF'

# PiTFT 3.5\" Display Configuration
dtoverlay=pitft35-resistive,rotate=90,speed=32000000,fps=30
EOF"
    echo "✓ PiTFT overlay added"
fi

# Configure console to use the TFT
echo ""
echo "Configuring console output..."
if [ -f /boot/firmware/cmdline.txt ]; then
    CMDLINE_FILE="/boot/firmware/cmdline.txt"
elif [ -f /boot/cmdline.txt ]; then
    CMDLINE_FILE="/boot/cmdline.txt"
else
    echo "Warning: cmdline.txt not found"
    CMDLINE_FILE=""
fi

if [ -n "$CMDLINE_FILE" ]; then
    # Backup cmdline.txt
    if [ ! -f "${CMDLINE_FILE}.backup" ]; then
        sudo cp "$CMDLINE_FILE" "${CMDLINE_FILE}.backup"
        echo "✓ Backed up cmdline.txt"
    fi
    
    # Check if fbcon settings are already there
    if ! grep -q "fbcon=map:10" "$CMDLINE_FILE"; then
        # Add console mapping to use fb1
        sudo sed -i 's/$/ fbcon=map:10 fbcon=font:VGA8x8/' "$CMDLINE_FILE"
        echo "✓ Console configured to use TFT display"
    else
        echo "✓ Console already configured"
    fi
fi

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Changes made:"
echo "1. SPI interface enabled"
echo "2. PiTFT device tree overlay configured"
echo "3. Console output mapped to TFT display"
echo ""
echo "Current configuration:"
echo "---"
grep -i "spi\|pitft" "$CONFIG_FILE"
echo "---"
echo ""
echo "⚠ REBOOT REQUIRED to apply changes"
echo ""
read -p "Reboot now? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 3 seconds..."
    sleep 3
    sudo reboot
else
    echo "Remember to reboot manually: sudo reboot"
fi
