# Deploy Clock & Weather App to Raspberry Pi
# This script uploads the clock_weather.py script and installs dependencies

# Load environment variables from .env
. "$PSScriptRoot\Load-DotEnv.ps1"

$PI_HOST = $env:PRODUCTION_IP
$PI_USER = $env:PI_USERNAME
$PI_TARGET = "~/"

if (-not $PI_HOST -or $PI_HOST -eq "192.168.1.XXX") {
    Write-Error "Please configure your .env file with PRODUCTION_IP"
    Write-Host "Copy .env.example to .env and set your Raspberry Pi's IP address." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Deploying Clock & Weather App to Raspberry Pi ===" -ForegroundColor Cyan
Write-Host ""

# Check if source file exists
$scriptPath = "src\clock_weather.py"
if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Script file not found: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "1. Uploading clock_weather.py to Pi..." -ForegroundColor Yellow
scp $scriptPath "${PI_USER}@${PI_HOST}:${PI_TARGET}"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to upload script" -ForegroundColor Red
    exit 1
}
Write-Host "   Success - Upload complete" -ForegroundColor Green

Write-Host ""
Write-Host "2. Making script executable..." -ForegroundColor Yellow
ssh "${PI_USER}@${PI_HOST}" "chmod +x ~/clock_weather.py"
Write-Host "   Success - Permissions set" -ForegroundColor Green

Write-Host ""
Write-Host "3. Installing dependencies..." -ForegroundColor Yellow
Write-Host "   (This may take a few minutes)" -ForegroundColor Gray

$installCmd = "sudo apt update && sudo apt install -y python3-pip && pip3 install requests pillow --break-system-packages"

ssh "${PI_USER}@${PI_HOST}" $installCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "   WARNING: Some dependencies may have failed" -ForegroundColor Yellow
    Write-Host "   You may need to install manually" -ForegroundColor Yellow
} else {
    Write-Host "   Success - All dependencies installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Cyan
Write-Host "  ssh pi@$PI_HOST" -ForegroundColor White
Write-Host "  export DISPLAY=:0" -ForegroundColor White
Write-Host "  python3 ~/clock_weather.py" -ForegroundColor White
Write-Host ""
Write-Host "To test from SSH with X forwarding:" -ForegroundColor Cyan
Write-Host "  ssh -X pi@$PI_HOST" -ForegroundColor White
Write-Host "  python3 ~/clock_weather.py" -ForegroundColor White
Write-Host ""
Write-Host "Press Escape to exit the application" -ForegroundColor Gray
