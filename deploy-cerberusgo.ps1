#!/usr/bin/env powershell
# Deploy CerberusGo fixes to Raspberry Pi server
# This script deploys the hang fixes and reboots the server

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "pi",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

$ErrorActionPreference = "Stop"

# Configuration
$LocalSourcePath = "c:\source\cerberusgo"
$RemoteBasePath = "/home/pi"
$LogFile = "deployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    $logEntry | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function Test-SSHConnection {
    param([string]$Server, [string]$User, [string]$Key)
    
    Write-Log "Testing SSH connection to $Server..."
    try {
        $result = ssh -i $Key -o ConnectTimeout=10 -o BatchMode=yes "$User@$Server" "echo 'Connection test successful'"
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SSH connection successful"
            return $true
        } else {
            Write-Log "SSH connection failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "SSH connection error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Copy-FileToServer {
    param([string]$LocalPath, [string]$RemotePath, [string]$Server, [string]$User, [string]$Key)
    
    Write-Log "Copying $LocalPath to $Server:$RemotePath"
    try {
        scp -i $Key "$LocalPath" "$User@${Server}:$RemotePath"
        if ($LASTEXITCODE -eq 0) {
            Write-Log "File copied successfully"
            return $true
        } else {
            Write-Log "File copy failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "File copy error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Execute-RemoteCommand {
    param([string]$Command, [string]$Server, [string]$User, [string]$Key, [bool]$Sudo = $false)
    
    if ($Sudo) {
        $Command = "sudo $Command"
    }
    
    Write-Log "Executing remote command: $Command"
    try {
        ssh -i $Key "$User@$Server" $Command
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Command executed successfully"
            return $true
        } else {
            Write-Log "Command failed with exit code $LASTEXITCODE" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Command execution error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Deploy-PythonFiles {
    param([string]$Server, [string]$User, [string]$Key)
    
    Write-Log "Deploying Python application files..."
    
    # Copy Python files
    $pythonFiles = @(
        "src\clock_weather.py",
        "src\clock_weather_fb.py", 
        "src\clock_weather_direct.py"
    )
    
    foreach ($file in $pythonFiles) {
        $localFile = Join-Path $LocalSourcePath $file
        $remoteFile = "$RemoteBasePath/$(Split-Path $file -Leaf)"
        
        if (Test-Path $localFile) {
            if (-not (Copy-FileToServer $localFile $remoteFile $Server $User $Key)) {
                throw "Failed to copy $file"
            }
            
            # Make executable
            Execute-RemoteCommand "chmod +x $remoteFile" $Server $User $Key | Out-Null
        } else {
            Write-Log "Warning: $localFile not found" "WARN"
        }
    }
    
    Write-Log "Python files deployed successfully"
}

function Deploy-ServiceFiles {
    param([string]$Server, [string]$User, [string]$Key)
    
    Write-Log "Deploying service configuration files..."
    
    # Copy service files to temp location first
    $serviceFiles = @(
        "config\clock-weather.service",
        "config\clock-weather-fb.service",
        "config\cerberusgo-monitor.service"
    )
    
    foreach ($file in $serviceFiles) {
        $localFile = Join-Path $LocalSourcePath $file
        $tempFile = "/tmp/$(Split-Path $file -Leaf)"
        
        if (Test-Path $localFile) {
            if (-not (Copy-FileToServer $localFile $tempFile $Server $User $Key)) {
                throw "Failed to copy $file"
            }
            
            # Move to systemd directory with sudo
            $serviceName = Split-Path $file -Leaf
            Execute-RemoteCommand "mv $tempFile /etc/systemd/system/$serviceName" $Server $User $Key $true | Out-Null
        } else {
            Write-Log "Warning: $localFile not found" "WARN"
        }
    }
    
    Write-Log "Service files deployed successfully"
}

function Deploy-Scripts {
    param([string]$Server, [string]$User, [string]$Key)
    
    Write-Log "Deploying monitoring scripts..."
    
    $scriptFiles = @(
        "scripts\monitor-cerberusgo.sh"
    )
    
    foreach ($file in $scriptFiles) {
        $localFile = Join-Path $LocalSourcePath $file
        $remoteFile = "$RemoteBasePath/$(Split-Path $file -Leaf)"
        
        if (Test-Path $localFile) {
            if (-not (Copy-FileToServer $localFile $remoteFile $Server $User $Key)) {
                throw "Failed to copy $file"
            }
            
            # Make executable
            Execute-RemoteCommand "chmod +x $remoteFile" $Server $User $Key | Out-Null
        } else {
            Write-Log "Warning: $localFile not found" "WARN"
        }
    }
    
    Write-Log "Scripts deployed successfully"
}

function Configure-Services {
    param([string]$Server, [string]$User, [string]$Key)
    
    Write-Log "Configuring systemd services..."
    
    # Reload systemd daemon
    Execute-RemoteCommand "systemctl daemon-reload" $Server $User $Key $true | Out-Null
    
    # Stop existing services
    Execute-RemoteCommand "systemctl stop clock-weather.service 2>/dev/null || true" $Server $User $Key $true | Out-Null
    Execute-RemoteCommand "systemctl stop clock-weather-fb.service 2>/dev/null || true" $Server $User $Key $true | Out-Null
    
    # Enable and start monitoring service
    Execute-RemoteCommand "systemctl enable cerberusgo-monitor.service" $Server $User $Key $true | Out-Null
    
    # Enable the main clock service (user can choose which one to use)
    Execute-RemoteCommand "systemctl enable clock-weather.service" $Server $User $Key $true | Out-Null
    
    Write-Log "Services configured successfully"
}

function Backup-ExistingFiles {
    param([string]$Server, [string]$User, [string]$Key)
    
    Write-Log "Creating backup of existing files..."
    
    $backupDir = "/home/pi/backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Execute-RemoteCommand "mkdir -p $backupDir" $Server $User $Key | Out-Null
    
    # Backup existing Python files
    Execute-RemoteCommand "cp /home/pi/clock_weather*.py $backupDir/ 2>/dev/null || true" $Server $User $Key | Out-Null
    
    # Backup existing service files
    Execute-RemoteCommand "cp /etc/systemd/system/clock-weather*.service $backupDir/ 2>/dev/null || true" $Server $User $Key $true | Out-Null
    
    Write-Log "Backup created in $backupDir"
}

# Main deployment process
try {
    Write-Log "Starting CerberusGo deployment to $ServerIP"
    Write-Log "Deployment log: $LogFile"
    
    # Validate parameters
    if (-not (Test-Path $KeyPath)) {
        throw "SSH key not found at $KeyPath"
    }
    
    if (-not (Test-Path $LocalSourcePath)) {
        throw "Source directory not found at $LocalSourcePath"
    }
    
    # Test SSH connection
    if (-not (Test-SSHConnection $ServerIP $Username $KeyPath)) {
        throw "Cannot establish SSH connection to server"
    }
    
    # Create backup
    Backup-ExistingFiles $ServerIP $Username $KeyPath
    
    # Deploy files
    Deploy-PythonFiles $ServerIP $Username $KeyPath
    Deploy-ServiceFiles $ServerIP $Username $KeyPath
    Deploy-Scripts $ServerIP $Username $KeyPath
    
    # Configure services
    Configure-Services $ServerIP $Username $KeyPath
    
    # Copy documentation
    $docFile = Join-Path $LocalSourcePath "HANG_FIXES_SUMMARY.md"
    if (Test-Path $docFile) {
        Copy-FileToServer $docFile "/home/pi/HANG_FIXES_SUMMARY.md" $ServerIP $Username $KeyPath | Out-Null
    }
    
    Write-Log "Deployment completed successfully!"
    Write-Log "The server will be rebooted in 10 seconds to apply all changes..."
    
    # Countdown for reboot
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host "Rebooting in $i seconds... (Press Ctrl+C to cancel)" -ForegroundColor Yellow
        Start-Sleep 1
    }
    
    # Reboot the server
    Write-Log "Initiating server reboot..."
    Execute-RemoteCommand "reboot" $ServerIP $Username $KeyPath $true | Out-Null
    
    Write-Log "Server reboot initiated. The system should come back online in 2-3 minutes."
    Write-Log "After reboot, check status with: ssh $Username@$ServerIP 'sudo systemctl status clock-weather.service'"
    
} catch {
    Write-Log "Deployment failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Deployment failed. Check $LogFile for details." -ForegroundColor Red
    exit 1
}

Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
Write-Host "Check the log file: $LogFile" -ForegroundColor Cyan