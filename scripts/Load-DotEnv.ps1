# Load Environment Variables from .env file
# This script loads variables from .env file into PowerShell environment
# Usage: . .\scripts\Load-DotEnv.ps1

function Load-DotEnv {
    param(
        [string]$EnvFilePath = ".env"
    )
    
    # Check if running from project root or scripts directory
    $possiblePaths = @(
        $EnvFilePath,
        (Join-Path $PSScriptRoot "..\$EnvFilePath"),
        (Join-Path (Get-Location) $EnvFilePath)
    )
    
    $foundPath = $null
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $foundPath = $path
            break
        }
    }
    
    if (-not $foundPath) {
        Write-Warning ".env file not found. Please copy .env.example to .env and configure it."
        Write-Warning "Searched locations:"
        $possiblePaths | ForEach-Object { Write-Warning "  - $_" }
        return $false
    }
    
    Write-Host "Loading environment from: $foundPath" -ForegroundColor Green
    
    Get-Content $foundPath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -eq '' -or $line.StartsWith('#')) {
            return
        }
        
        # Parse KEY=VALUE
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Remove quotes if present
            $value = $value -replace '^["'']|["'']$', ''
            
            # Set environment variable
            [Environment]::SetEnvironmentVariable($key, $value, [EnvironmentVariableTarget]::Process)
            
            Write-Verbose "Set $key = $value"
        }
    }
    
    Write-Host "Environment variables loaded successfully!" -ForegroundColor Green
    return $true
}

# Auto-load if not already loaded
if (-not $env:PRODUCTION_IP) {
    Load-DotEnv
}
