#!/bin/bash

# Fix Console Display on PiTFT
# This script ensures text console is properly displayed on the TFT

echo "=== Fixing Console Display on PiTFT ==="
echo ""

# Method 1: Set console to explicitly use fb1
echo "Configuring console to use fb1..."

# Check current console mapping
echo "Current fbcon mapping:"
cat /sys/class/graphics/fbcon/cursor_blink 2>/dev/null || echo "fbcon info not available"

# Force console to fb1
echo "Setting console font and forcing fb1..."
sudo con2fbmap 1 1 2>/dev/null || echo "con2fbmap not available"

# Try setting a visible font
sudo setfont /usr/share/consolefonts/Uni2-Terminus16.psf.gz 2>/dev/null || echo "setfont not available"

# Alternative: Use fbset to ensure correct mode
echo ""
echo "Setting framebuffer mode..."
sudo fbset -fb /dev/fb1 -g 320 480 320 480 16

# Clear and test display
echo ""
echo "Clearing display and testing..."
sudo sh -c 'cat /dev/zero > /dev/fb1' 2>/dev/null &
sleep 1
sudo pkill -f "cat /dev/zero"

# Try to show something on the display
echo ""
echo "Drawing test pattern..."
sudo sh -c 'for i in {1..100}; do echo -e "\e[3${i}m████████████████████████████████\e[0m"; done > /dev/tty1'

# Check if we can write text to fb1 directly
echo ""
echo "Testing direct text output..."
echo "CerberusGo Display Test" | sudo tee /dev/tty1

echo ""
echo "=== Configuration Applied ==="
echo ""
echo "If you still don't see text:"
echo "1. The console might need logo removed from cmdline.txt"
echo "2. Try: sudo systemctl restart getty@tty1"
echo "3. Or edit /boot/firmware/cmdline.txt to remove 'quiet splash'"
echo ""
read -p "Remove 'quiet splash' from boot to show boot messages? [y/N]: " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing quiet splash..."
    sudo sed -i 's/ quiet splash//' /boot/firmware/cmdline.txt
    sudo sed -i 's/ plymouth.ignore-serial-consoles//' /boot/firmware/cmdline.txt
    echo "✓ Boot messages will now be visible"
    echo ""
    read -p "Reboot now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Rebooting..."
        sudo reboot
    fi
else
    echo "Console configuration complete"
    echo "Try: sudo systemctl restart getty@tty1"
fi
