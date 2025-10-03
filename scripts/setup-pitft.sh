#!/bin/bash
###############################################################################
# PiTFT 3.5" Setup Script for Raspberry Pi 3B
# 
# This script automates the installation and configuration of the
# Adafruit PiTFT 3.5" resistive touchscreen display
#
# Usage: sudo bash setup-pitft.sh
#
# WARNING: This script will modify system configuration files
# Make sure to backup your system before running
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PiTFT 3.5\" Setup Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Ask for display rotation
echo "Select display rotation:"
echo "  1) 90 degrees  - Landscape (USB ports on right) [RECOMMENDED]"
echo "  2) 270 degrees - Landscape (USB ports on left)"
echo "  3) 0 degrees   - Portrait (USB ports on bottom)"
echo "  4) 180 degrees - Portrait (USB ports on top)"
read -p "Enter choice [1-4]: " rotation_choice

case $rotation_choice in
    1) ROTATION=90 ;;
    2) ROTATION=270 ;;
    3) ROTATION=0 ;;
    4) ROTATION=180 ;;
    *) 
        print_error "Invalid choice. Using default (90 degrees)"
        ROTATION=90
        ;;
esac

print_status "Using rotation: ${ROTATION} degrees"

# Ask for console output
read -p "Show console on PiTFT? (y/n): " console_choice
CONSOLE_ON_TFT=false
if [[ $console_choice =~ ^[Yy]$ ]]; then
    CONSOLE_ON_TFT=true
    print_status "Console will be shown on PiTFT"
else
    print_status "Console will remain on HDMI"
fi

# Ask for FBCP (HDMI mirroring)
read -p "Enable FBCP (mirror HDMI to PiTFT)? (y/n): " fbcp_choice
ENABLE_FBCP=false
if [[ $fbcp_choice =~ ^[Yy]$ ]]; then
    ENABLE_FBCP=true
    print_status "FBCP will be installed and enabled"
else
    print_status "FBCP will not be installed"
fi

echo ""
print_status "Starting installation..."
echo ""

# Update package list
print_status "Updating package list..."
apt-get update -qq

# Install required packages
print_status "Installing required packages..."
apt-get install -y -qq \
    python3-pip \
    python3-pil \
    python3-numpy \
    xinput-calibrator \
    evtest \
    fbi \
    cmake \
    git

# Enable SPI
print_status "Enabling SPI interface..."
raspi-config nonint do_spi 0

# Backup existing config.txt
if [ ! -f /boot/config.txt.backup ]; then
    print_status "Backing up /boot/config.txt..."
    cp /boot/config.txt /boot/config.txt.backup
fi

# Check if pitft overlay already exists
if grep -q "pitft35-resistive" /boot/config.txt; then
    print_warning "PiTFT overlay already exists in config.txt, updating..."
    sed -i '/pitft35-resistive/d' /boot/config.txt
fi

# Add display configuration to config.txt
print_status "Configuring display in /boot/config.txt..."
cat >> /boot/config.txt << EOF

# PiTFT 3.5" Display Configuration (added by setup script)
dtparam=spi=on
dtoverlay=pitft35-resistive,rotate=${ROTATION},speed=32000000,fps=30
EOF

# Configure console if requested
if [ "$CONSOLE_ON_TFT" = true ]; then
    print_status "Configuring console output on PiTFT..."
    
    # Backup cmdline.txt
    if [ ! -f /boot/cmdline.txt.backup ]; then
        cp /boot/cmdline.txt /boot/cmdline.txt.backup
    fi
    
    # Check if fbcon already configured
    if ! grep -q "fbcon=map:10" /boot/cmdline.txt; then
        # Add fbcon configuration
        sed -i 's/$/ fbcon=map:10 fbcon=font:VGA8x8/' /boot/cmdline.txt
        print_status "Console configured for PiTFT"
    else
        print_warning "Console already configured for PiTFT"
    fi
fi

# Install FBCP if requested
if [ "$ENABLE_FBCP" = true ]; then
    print_status "Installing FBCP (this may take a few minutes)..."
    
    # Check if already installed
    if [ ! -f /usr/local/bin/fbcp ]; then
        cd /tmp
        if [ -d rpi-fbcp ]; then
            rm -rf rpi-fbcp
        fi
        
        git clone https://github.com/tasanakorn/rpi-fbcp
        cd rpi-fbcp
        mkdir -p build
        cd build
        cmake ..
        make
        install fbcp /usr/local/bin/fbcp
        
        print_status "FBCP installed successfully"
        
        # Configure FBCP to start at boot
        if ! grep -q "/usr/local/bin/fbcp" /etc/rc.local; then
            sed -i 's/^exit 0$/\/usr\/local\/bin\/fbcp \&\nexit 0/' /etc/rc.local
            print_status "FBCP configured to start at boot"
        fi
    else
        print_warning "FBCP already installed"
    fi
fi

# Create X11 configuration directory if it doesn't exist
print_status "Configuring X11 for PiTFT..."
mkdir -p /usr/share/X11/xorg.conf.d

# Configure X11 to use framebuffer
cat > /usr/share/X11/xorg.conf.d/99-fbdev.conf << 'EOF'
Section "Device"
    Identifier "Adafruit PiTFT"
    Driver "fbdev"
    Option "fbdev" "/dev/fb1"
EndSection
EOF

print_status "X11 configured for PiTFT"

# Create calibration directory
print_status "Creating touchscreen calibration directory..."
mkdir -p /etc/X11/xorg.conf.d

# Create default calibration (user should recalibrate)
cat > /etc/X11/xorg.conf.d/99-calibration.conf << EOF
Section "InputClass"
    Identifier "calibration"
    MatchProduct "stmpe-ts"
    Option "Calibration" "3800 200 200 3800"
    Option "SwapAxes" "$([ $ROTATION -eq 90 ] || [ $ROTATION -eq 270 ] && echo "1" || echo "0")"
EndSection
EOF

print_status "Default touchscreen calibration created"

# Create helper scripts
print_status "Creating helper scripts..."

# Calibration script
cat > /usr/local/bin/pitft-calibrate << 'EOF'
#!/bin/bash
echo "Starting touchscreen calibration..."
echo "Follow the on-screen instructions and touch the calibration points."
DISPLAY=:0 xinput_calibrator
EOF
chmod +x /usr/local/bin/pitft-calibrate

# Backlight control script
cat > /usr/local/bin/pitft-backlight << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: pitft-backlight <0-255>"
    echo "  0   = Off"
    echo "  128 = 50%"
    echo "  255 = 100%"
    exit 1
fi
echo $1 > /sys/class/backlight/soc:backlight/brightness
echo "Backlight set to $1"
EOF
chmod +x /usr/local/bin/pitft-backlight

# Display test script
cat > /usr/local/bin/pitft-test << 'EOF'
#!/bin/bash
echo "Testing PiTFT display..."
if [ -e /dev/fb1 ]; then
    echo "✓ Display device found: /dev/fb1"
    fbset -fb /dev/fb1
    echo ""
    echo "Displaying test image..."
    fbi -T 1 -d /dev/fb1 -noverbose -a /usr/share/pixmaps/debian-logo.png
else
    echo "✗ Display device not found: /dev/fb1"
    echo "  Make sure the display is properly connected and reboot."
fi
EOF
chmod +x /usr/local/bin/pitft-test

print_status "Helper scripts created"
echo ""
echo "  pitft-calibrate - Calibrate touchscreen"
echo "  pitft-backlight - Control backlight brightness"
echo "  pitft-test      - Test display output"
echo ""

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Configuration summary:"
echo "  • Rotation: ${ROTATION} degrees"
echo "  • Console on TFT: ${CONSOLE_ON_TFT}"
echo "  • FBCP enabled: ${ENABLE_FBCP}"
echo ""
echo "Next steps:"
echo "  1. Reboot your Raspberry Pi: sudo reboot"
echo "  2. After reboot, test display: pitft-test"
echo "  3. Calibrate touchscreen: pitft-calibrate"
echo "  4. Adjust backlight: pitft-backlight 128"
echo ""
echo "Configuration files backed up with .backup extension"
echo "Documentation available in: docs/"
echo ""

read -p "Reboot now? (y/n): " reboot_choice
if [[ $reboot_choice =~ ^[Yy]$ ]]; then
    print_status "Rebooting..."
    reboot
else
    print_warning "Remember to reboot before using the display!"
fi
