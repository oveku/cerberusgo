#!/bin/bash
###############################################################################
# Touch Input Test Script for PiTFT 3.5"
#
# Tests touchscreen functionality and displays touch events
#
# Usage: sudo bash test-touch.sh
###############################################################################

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "PiTFT 3.5\" Touch Input Test"
echo "============================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: Please run as root (use sudo)${NC}"
    exit 1
fi

# Find touch device
TOUCH_DEVICE=""
echo "Searching for touch input device..."

# Method 1: Look for STMPE device
for device in /dev/input/event*; do
    if evtest --grab "$device" < /dev/null 2>&1 | grep -qi "stmpe"; then
        TOUCH_DEVICE=$device
        break
    fi
done

# Method 2: Check /proc/bus/input/devices
if [ -z "$TOUCH_DEVICE" ]; then
    TOUCH_DEVICE=$(cat /proc/bus/input/devices | grep -B 5 "stmpe" | grep "event" | sed 's/.*event/\/dev\/input\/event/' | head -n1)
fi

# Method 3: Try event0 as fallback
if [ -z "$TOUCH_DEVICE" ] && [ -e /dev/input/event0 ]; then
    echo -e "${YELLOW}Warning: STMPE device not found, trying /dev/input/event0${NC}"
    TOUCH_DEVICE="/dev/input/event0"
fi

if [ -z "$TOUCH_DEVICE" ] || [ ! -e "$TOUCH_DEVICE" ]; then
    echo -e "${RED}✗ Touch input device not found${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if touch controller is detected:"
    echo "     cat /proc/bus/input/devices | grep -i stmpe"
    echo "  2. Check kernel messages:"
    echo "     dmesg | grep -i stmpe"
    echo "  3. Verify display overlay in /boot/config.txt"
    echo "  4. Ensure display is properly connected"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Touch device found: $TOUCH_DEVICE"
echo ""

# Show device info
echo "Device Information:"
evtest --query "$TOUCH_DEVICE" EV_ABS ABS_X 2>/dev/null && echo "  Supports X axis" || true
evtest --query "$TOUCH_DEVICE" EV_ABS ABS_Y 2>/dev/null && echo "  Supports Y axis" || true
evtest --query "$TOUCH_DEVICE" EV_KEY BTN_TOUCH 2>/dev/null && echo "  Supports touch events" || true
echo ""

# Check if evtest is installed
if ! command -v evtest &> /dev/null; then
    echo -e "${RED}✗ evtest not installed${NC}"
    echo "  Installing evtest..."
    apt-get install -y evtest
fi

echo "Touch Test Options:"
echo "  1) Raw touch events (evtest)"
echo "  2) Simple touch detection"
echo "  3) Touch coordinate mapping"
echo "  4) Continuous touch monitoring"
echo ""
read -p "Select test [1-4]: " test_choice

case $test_choice in
    1)
        echo ""
        echo "Starting raw touch event monitoring..."
        echo "Touch the screen to see events. Press Ctrl+C to exit."
        echo ""
        sleep 2
        evtest "$TOUCH_DEVICE"
        ;;
    
    2)
        echo ""
        echo "Simple touch detection test"
        echo "Touch the screen. Press Ctrl+C to exit."
        echo ""
        
        touch_count=0
        evtest "$TOUCH_DEVICE" | while read line; do
            if echo "$line" | grep -q "BTN_TOUCH.*value 1"; then
                ((touch_count++))
                echo -e "${GREEN}✓${NC} Touch detected! (Count: $touch_count)"
            fi
        done
        ;;
    
    3)
        echo ""
        echo "Touch coordinate mapping test"
        echo "Touch different areas of the screen."
        echo "Press Ctrl+C to exit."
        echo ""
        
        x_val=0
        y_val=0
        
        evtest "$TOUCH_DEVICE" | while read line; do
            if echo "$line" | grep -q "ABS_X.*value"; then
                x_val=$(echo "$line" | grep -oP 'value \K\d+')
            fi
            if echo "$line" | grep -q "ABS_Y.*value"; then
                y_val=$(echo "$line" | grep -oP 'value \K\d+')
            fi
            if echo "$line" | grep -q "BTN_TOUCH.*value 1"; then
                echo -e "${BLUE}Touch at:${NC} X=$x_val, Y=$y_val"
            fi
        done
        ;;
    
    4)
        echo ""
        echo "Continuous touch monitoring"
        echo "This will show all touch events in real-time."
        echo "Press Ctrl+C to exit."
        echo ""
        sleep 2
        
        evtest "$TOUCH_DEVICE" | while read line; do
            if echo "$line" | grep -qE "ABS_X|ABS_Y|BTN_TOUCH"; then
                echo "$line"
            fi
        done
        ;;
    
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac
