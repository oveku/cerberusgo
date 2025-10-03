# Deploy Clock & Weather App with Auto-Start Service
# This script uploads the app, installs dependencies, and sets up systemd service

# Load environment variables from .env
. "$PSScriptRoot\Load-DotEnv.ps1"

$PI_HOST = $env:PRODUCTION_IP
$PI_USER = $env:PI_USERNAME

if (-not $PI_HOST -or $PI_HOST -eq "192.168.1.XXX") {
    Write-Error "Please configure your .env file with PRODUCTION_IP"
    Write-Host "Copy .env.example to .env and set your Raspberry Pi's IP address." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Deploying Clock & Weather App to Raspberry Pi ===" -ForegroundColor Cyan
Write-Host ""

# Check if source files exist
$scriptPath = "src\clock_weather.py"
$servicePath = "config\clock-weather.service"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Script file not found: $scriptPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $servicePath)) {
    Write-Host "ERROR: Service file not found: $servicePath" -ForegroundColor Red
    exit 1
}

# Step 1: Upload Python script
Write-Host "1. Uploading clock_weather.py to Pi..." -ForegroundColor Yellow
scp $scriptPath "${PI_USER}@${PI_HOST}:~/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ERROR: Failed to upload script" -ForegroundColor Red
    exit 1
}
Write-Host "   Success - Script uploaded" -ForegroundColor Green

# Step 2: Upload service file
Write-Host ""
Write-Host "2. Uploading systemd service file..." -ForegroundColor Yellow
scp $servicePath "${PI_USER}@${PI_HOST}:~/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ERROR: Failed to upload service file" -ForegroundColor Red
    exit 1
}
Write-Host "   Success - Service file uploaded" -ForegroundColor Green

# Step 3: Make script executable
Write-Host ""
Write-Host "3. Setting permissions..." -ForegroundColor Yellow
ssh "${PI_USER}@${PI_HOST}" "chmod +x ~/clock_weather.py"
Write-Host "   Success - Script is executable" -ForegroundColor Green

# Step 4: Install dependencies
Write-Host ""
Write-Host "4. Installing dependencies..." -ForegroundColor Yellow
Write-Host "   (This may take a few minutes)" -ForegroundColor Gray

$installCmd = @'
echo "   - Updating package list..."
sudo apt update -qq
echo "   - Installing pip..."
sudo apt install -y python3-pip > /dev/null 2>&1
echo "   - Installing Python packages..."
pip3 install requests pillow --break-system-packages --quiet
echo "   - Installing X11 packages for display..."
sudo apt install -y xserver-xorg xinit xserver-xorg-video-fbdev > /dev/null 2>&1
echo "   SUCCESS: All dependencies installed"
'@

ssh "${PI_USER}@${PI_HOST}" $installCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "   WARNING: Some dependencies may have failed" -ForegroundColor Yellow
} else {
    Write-Host "   Success - All dependencies installed" -ForegroundColor Green
}

# Step 5: Install and enable systemd service
Write-Host ""
Write-Host "5. Setting up auto-start service..." -ForegroundColor Yellow

$serviceSetup = @'
# Move service file to systemd directory
sudo mv ~/clock-weather.service /etc/systemd/system/

# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable clock-weather.service

# Start the service now
sudo systemctl start clock-weather.service

# Check status
sudo systemctl status clock-weather.service --no-pager -l
'@

ssh "${PI_USER}@${PI_HOST}" $serviceSetup

if ($LASTEXITCODE -ne 0) {
    Write-Host "   WARNING: Service setup may have issues" -ForegroundColor Yellow
} else {
    Write-Host "   Success - Service installed and started" -ForegroundColor Green
}

# Step 6: Verify service status
Write-Host ""
Write-Host "6. Verifying service status..." -ForegroundColor Yellow

$statusCheck = ssh "${PI_USER}@${PI_HOST}" "systemctl is-active clock-weather.service" 2>$null

if ($statusCheck -eq "active") {
    Write-Host "   Success - Service is running!" -ForegroundColor Green
} else {
    Write-Host "   Status: $statusCheck" -ForegroundColor Yellow
    Write-Host "   Note: Service may take a few seconds to start" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Clock & Weather app is now installed and running!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Service Management:" -ForegroundColor Yellow
Write-Host "  Check status:  ssh pi@$PI_HOST 'sudo systemctl status clock-weather'" -ForegroundColor White
Write-Host "  Stop service:  ssh pi@$PI_HOST 'sudo systemctl stop clock-weather'" -ForegroundColor White
Write-Host "  Start service: ssh pi@$PI_HOST 'sudo systemctl start clock-weather'" -ForegroundColor White
Write-Host "  View logs:     ssh pi@$PI_HOST 'sudo journalctl -u clock-weather -f'" -ForegroundColor White
Write-Host ""
Write-Host "The app will automatically start on every reboot!" -ForegroundColor Green
Write-Host ""
Write-Host "To test the display, you can reboot the Pi:" -ForegroundColor Cyan
Write-Host "  ssh pi@$PI_HOST 'sudo reboot'" -ForegroundColor White
