# Automatic Windows 11 64-bit installer.
# Usage: .\install.ps1 [-Category Base|Dev|Gaming|All] [-WhatIf] [-GitUserName "Name"] [-GitUserEmail "email@example.com"]
# Requires: 64-bit Windows 11, PowerShell 7, winget, Administrator execution.
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
    [string]$Category = 'All',

    [string]$GitUserName = "",

    [string]$GitUserEmail = ""
)

$RepoRoot = $PSScriptRoot
$AppsConfigPath = Join-Path -Path $RepoRoot -ChildPath "config/apps.json"
$ExtensionsConfigPath = Join-Path -Path $RepoRoot -ChildPath "config/vscode/extensions.json"

function Update-SessionPath {
    # Merge process + Machine + User PATH so newly installed tools are found.
    try {
        $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $user = [Environment]::GetEnvironmentVariable("Path", "User")
        $current = $env:Path
        $combined = @()
        foreach ($part in @($current, $machine, $user)) {
            if ([string]::IsNullOrWhiteSpace($part)) { continue }
            foreach ($entry in ($part -split ';')) {
                $trimmed = $entry.Trim()
                if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
                if ($combined -inotcontains $trimmed) {
                    $combined += $trimmed
                }
            }
        }
        if ($combined.Count -gt 0) {
            $env:Path = $combined -join ';'
        }
    } catch {
        Write-Warning "Could not refresh session PATH: $_"
    }
}

# 1. Administrator check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges. Open PowerShell as Administrator and try again."
    exit 1
}

# 2. 64-bit Windows 11 check (OS, not just CPU).
# OSArchitecture is localized ("64-bit" vs "64 bits"), so match on '64'.
$os = Get-CimInstance Win32_OperatingSystem
if ($null -eq $os) {
    Write-Error "Could not query operating system info. Run this script in PowerShell 7 as Administrator."
    exit 1
}
$detectedBuild = [int]$os.BuildNumber
$detectedArch = [string]$os.OSArchitecture
$is64BitEnv = [Environment]::Is64BitOperatingSystem
$isWin11 = $detectedBuild -ge 22000
$is64BitOS = $is64BitEnv -and ($detectedArch -match '64')

if (-not ($isWin11 -and $is64BitOS)) {
    Write-Error "This script is designed exclusively for 64-bit Windows 11 (Build >= 22000, 64-bit OS). Detected: Build=$detectedBuild, Architecture='$detectedArch', OS64bit=$is64BitEnv. Execution aborted."
    exit 1
}

# 3. winget availability check
if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    Write-Error "The winget tool is not available on this system. Install it (App Installer from Microsoft Store) to continue."
    exit 1
}

# 4. Import base module
$CommonModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Common.ps1")
if (Test-Path $CommonModulePath) {
    . $CommonModulePath
} else {
    Write-Error "Base module not found at: $CommonModulePath. Execution aborted."
    exit 1
}

# 5. Start activity log
$global:InstallHadErrors = $false
Initialize-InstallLog | Out-Null
Write-InstallLog -Message "Starting automatic installer. Selected category: $Category" -Level "INFO"

# 6. Import category module
$CategoryModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Install-Category.ps1")
if (Test-Path $CategoryModulePath) {
    . $CategoryModulePath
} else {
    Write-InstallLog -Message "Critical failure: Install-Category module not found at: $CategoryModulePath." -Level "ERROR"
    exit 1
}

# 7. Run winget installation ($WhatIfPreference propagates automatically)
Invoke-InstallCategory -Category $Category -AppsConfigPath $AppsConfigPath

# Refresh PATH so newly installed git/code are found without restarting.
Update-SessionPath

# 8. Git configuration (Dev or All only)
$GitModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Config-Git.ps1")
if (Test-Path $GitModulePath) {
    . $GitModulePath

    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        Invoke-GitConfig -UserName $GitUserName -UserEmail $GitUserEmail
    }
} else {
    Write-InstallLog -Message "Git configuration module not found at: $GitModulePath" -Level "WARNING"
}

# 9. VSCode configuration (Dev or All only)
$VSCodeModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Config-VSCode.ps1")
if (Test-Path $VSCodeModulePath) {
    . $VSCodeModulePath

    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        Invoke-VSCodeConfig -ExtensionsConfigPath $ExtensionsConfigPath
    }
} else {
    Write-InstallLog -Message "VSCode configuration module not found at: $VSCodeModulePath" -Level "WARNING"
}

# 10. Finish
Write-InstallLog -Message "Installer execution finished." -Level "INFO"
if ($global:InstallHadErrors) {
    Write-Host "Process completed with errors. Check the logs/ folder for details." -ForegroundColor Red
    exit 1
}
Write-Host "Process completed. Check the logs/ folder for details." -ForegroundColor Green
