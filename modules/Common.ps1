# Common.ps1 - Shared installer functions.
# Requires PowerShell 7+. Importing it has no side effects.

# Current run log path, set once per process.
$script:InstallLogPath = $null

function Initialize-InstallLog {
    [CmdletBinding()]
    param()

    if ($script:InstallLogPath -and (Test-Path (Split-Path -Parent $script:InstallLogPath))) {
        return $script:InstallLogPath
    }

    # $PSScriptRoot here is the modules/ folder.
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $logsDir = Join-Path -Path $repoRoot -ChildPath "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:InstallLogPath = Join-Path -Path $logsDir -ChildPath "install-$timestamp.log"
    return $script:InstallLogPath
}

function Write-InstallLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $logPath = Initialize-InstallLog
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$date] [$Level] $Message"

    Add-Content -Path $logPath -Value $logLine -Encoding UTF8

    # Mirror errors/warnings to the console and flag failures for the exit code.
    if ($Level -eq "ERROR") {
        $global:InstallHadErrors = $true
        Write-Error $Message
    } elseif ($Level -eq "WARNING") {
        Write-Warning $Message
    } else {
        Write-Verbose $Message
    }
}

function Test-AppInstalled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    $output = winget list --id $AppId --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    # Escape dots in $AppId so they are not treated as regex.
    $pattern = [regex]::Escape($AppId)
    if ($output | Select-String -Pattern $pattern -Quiet) {
        return $true
    }
    return $false
}

function Install-WingetApp {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    if (Test-AppInstalled -AppId $AppId) {
        Write-InstallLog -Message "Program $AppName ($AppId) is already installed. Skipping." -Level "INFO"
        return
    }

    if ($PSCmdlet.ShouldProcess($AppName, "Install via winget")) {
        Write-InstallLog -Message "Starting installation of $AppName ($AppId)..." -Level "INFO"

        winget install --exact --id $AppId --accept-source-agreements --accept-package-agreements --silent
        $wingetExit = $LASTEXITCODE

        if ($wingetExit -ne 0) {
            Write-InstallLog -Message "winget returned code $wingetExit while installing: $AppName ($AppId). Check the console." -Level "ERROR"
            return
        }

        if (Test-AppInstalled -AppId $AppId) {
            Write-InstallLog -Message "Installation succeeded: $AppName" -Level "INFO"
        } else {
            Write-InstallLog -Message "Failed to install: $AppName ($AppId). winget exited without error but the app is missing from 'winget list'." -Level "ERROR"
        }
    } else {
        Write-InstallLog -Message "Simulation mode enabled. Would install: $AppName ($AppId)" -Level "INFO"
    }
}
