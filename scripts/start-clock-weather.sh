#!/bin/bash
# Startup script for Clock & Weather Display
# This script ensures X server is running before starting the application

echo "Starting Clock & Weather Display..."

# Wait for system to be ready
sleep 3

# Kill any existing X server on display :0
killall X 2>/dev/null
sleep 1

# Start X server on framebuffer with configuration
echo "Starting X server on framebuffer..."
xinit /home/pi/clock_weather.py -- :0 -config /home/pi/xorg.conf.pitft vt1 &

# Give it time to start
sleep 3

echo "X server started with clock application"
