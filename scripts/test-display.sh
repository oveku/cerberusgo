#!/bin/bash
###############################################################################
# Display Test Script for PiTFT 3.5"
#
# Tests the display functionality and shows diagnostic information
#
# Usage: sudo bash test-display.sh
###############################################################################

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "PiTFT 3.5\" Display Test"
echo "========================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Warning: Some tests require root privileges${NC}"
fi

# Test 1: Check SPI
echo "Test 1: SPI Interface"
if ls /dev/spi* &> /dev/null; then
    echo -e "${GREEN}✓${NC} SPI devices found:"
    ls -l /dev/spi*
else
    echo -e "${RED}✗${NC} No SPI devices found"
    echo "  Run: sudo raspi-config → Interface Options → SPI → Enable"
fi
echo ""

# Test 2: Check framebuffer
echo "Test 2: Framebuffer Device"
if [ -e /dev/fb1 ]; then
    echo -e "${GREEN}✓${NC} Display framebuffer found: /dev/fb1"
    echo "  Display information:"
    fbset -fb /dev/fb1 | grep -E "mode|geometry"
else
    echo -e "${RED}✗${NC} Display framebuffer not found: /dev/fb1"
    echo "  Check /boot/config.txt for pitft35-resistive overlay"
fi
echo ""

# Test 3: Check device tree overlay
echo "Test 3: Device Tree Overlay"
if grep -q "pitft35-resistive" /boot/config.txt; then
    echo -e "${GREEN}✓${NC} PiTFT overlay found in /boot/config.txt:"
    grep "pitft35-resistive" /boot/config.txt
else
    echo -e "${RED}✗${NC} PiTFT overlay not found in /boot/config.txt"
fi
echo ""

# Test 4: Check for display driver in kernel
echo "Test 4: Display Driver"
if dmesg | grep -qi "fb1"; then
    echo -e "${GREEN}✓${NC} Display driver loaded"
    echo "  Kernel messages:"
    dmesg | grep -i "fb1" | tail -n 3
else
    echo -e "${YELLOW}!${NC} No fb1 messages in kernel log"
fi
echo ""

# Test 5: Check touch device
echo "Test 5: Touch Input Device"
if ls /dev/input/event* &> /dev/null; then
    echo -e "${GREEN}✓${NC} Input devices found:"
    for device in /dev/input/event*; do
        echo "  $device"
    done
    echo ""
    echo "  Touch controller info:"
    if cat /proc/bus/input/devices | grep -A 5 "stmpe" &> /dev/null; then
        cat /proc/bus/input/devices | grep -A 5 "stmpe"
    else
        echo -e "${YELLOW}  ! STMPE touch controller not found${NC}"
    fi
else
    echo -e "${RED}✗${NC} No input devices found"
fi
echo ""

# Test 6: Display test pattern
echo "Test 6: Display Test Pattern"
if [ -e /dev/fb1 ]; then
    if command -v fbi &> /dev/null; then
        echo "Displaying test image for 3 seconds..."
        if [ -f /usr/share/pixmaps/debian-logo.png ]; then
            timeout 3 fbi -T 1 -d /dev/fb1 -noverbose -a /usr/share/pixmaps/debian-logo.png 2>/dev/null
            echo -e "${GREEN}✓${NC} Test image displayed"
        else
            echo -e "${YELLOW}!${NC} Test image not found, creating pattern..."
            # Create simple test pattern
            echo "Test Pattern" > /tmp/test.txt
            timeout 3 fbi -T 1 -d /dev/fb1 -noverbose /tmp/test.txt 2>/dev/null || true
        fi
    else
        echo -e "${YELLOW}!${NC} fbi not installed"
        echo "  Install with: sudo apt-get install fbi"
    fi
else
    echo -e "${RED}✗${NC} Cannot test - /dev/fb1 not found"
fi
echo ""

# Test 7: Check backlight
echo "Test 7: Backlight Control"
if [ -e /sys/class/backlight/soc:backlight/brightness ]; then
    current=$(cat /sys/class/backlight/soc:backlight/brightness)
    echo -e "${GREEN}✓${NC} Backlight control available"
    echo "  Current brightness: $current"
else
    echo -e "${YELLOW}!${NC} Backlight control not found"
fi
echo ""

# Test 8: Check configuration files
echo "Test 8: Configuration Files"
if [ -f /etc/X11/xorg.conf.d/99-calibration.conf ]; then
    echo -e "${GREEN}✓${NC} Touch calibration file exists"
else
    echo -e "${YELLOW}!${NC} Touch calibration file not found"
    echo "  Run: xinput_calibrator"
fi

if [ -f /usr/share/X11/xorg.conf.d/99-fbdev.conf ]; then
    echo -e "${GREEN}✓${NC} X11 framebuffer config exists"
else
    echo -e "${YELLOW}!${NC} X11 framebuffer config not found"
fi
echo ""

# Test 9: Check for FBCP
echo "Test 9: FBCP (Framebuffer Copy)"
if [ -f /usr/local/bin/fbcp ]; then
    echo -e "${GREEN}✓${NC} FBCP installed"
    if pgrep -x fbcp > /dev/null; then
        echo "  FBCP is running (PID: $(pgrep -x fbcp))"
    else
        echo "  FBCP is not running"
    fi
else
    echo -e "${YELLOW}!${NC} FBCP not installed"
fi
echo ""

# Summary
echo "========================"
echo "Test Summary"
echo "========================"
echo ""

# Count issues
issues=0

[ ! -e /dev/spi0.0 ] && ((issues++))
[ ! -e /dev/fb1 ] && ((issues++))
[ ! -e /dev/input/event0 ] && ((issues++))

if [ $issues -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed!${NC}"
    echo ""
    echo "Your PiTFT should be working."
    echo "If you don't see output on the display, try:"
    echo "  1. Reboot the Raspberry Pi"
    echo "  2. Check physical connections"
    echo "  3. Run: pitft-test"
else
    echo -e "${YELLOW}Found $issues potential issue(s)${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Ensure display is properly connected"
    echo "  2. Check /boot/config.txt configuration"
    echo "  3. Verify SPI is enabled in raspi-config"
    echo "  4. Reboot and run this test again"
    echo "  5. See: docs/guides/TROUBLESHOOTING.md"
fi
echo ""

# System info
echo "System Information:"
echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
echo "  Pi Model: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')"
echo ""
