#!/bin/bash
# Startup script for Clock & Weather Display (FBI version)
# This script ensures framebuffer is ready before starting the application

LOG_FILE="/tmp/fbi_startup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "Starting Clock & Weather Display (FBI version)..."

# Wait for system to be ready
log_message "Waiting for system initialization..."
sleep 5

# Check if framebuffer device exists
if [ ! -e "/dev/fb0" ]; then
    log_message "ERROR: Framebuffer device /dev/fb0 not found"
    exit 1
fi

# Check framebuffer permissions
if [ ! -w "/dev/fb0" ]; then
    log_message "WARNING: No write permission to /dev/fb0, attempting to fix..."
    chmod 666 /dev/fb0 2>/dev/null || true
fi

# Clear framebuffer
log_message "Clearing framebuffer..."
dd if=/dev/zero of=/dev/fb0 bs=1M count=1 2>/dev/null || true

# Check if FBI is installed
if ! which fbi >/dev/null 2>&1; then
    log_message "ERROR: FBI not found. Installing..."
    apt-get update && apt-get install -y fbi
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to install FBI"
        exit 1
    fi
fi

# Kill any existing FBI processes
log_message "Stopping any existing FBI processes..."
killall fbi 2>/dev/null || true
sleep 1

# Check network connectivity before starting
log_message "Testing network connectivity..."
if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    log_message "Network is available"
else
    log_message "WARNING: Network may not be available yet"
fi

# Set console to not blank
log_message "Configuring console settings..."
echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null || true
setterm -blank 0 -powerdown 0 -powersave off 2>/dev/null || true

# Start the clock weather application
log_message "Starting clock weather application..."
cd /home/pi
exec python3 /home/pi/clock_weather_fbi.py