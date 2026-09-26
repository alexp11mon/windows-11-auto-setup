# Automatic Windows 11 64-bit setup.
# Usage: .\install.ps1 [-Category Base|Dev|Gaming|All] [-WhatIf] [-GitUserName "Name"] [-GitUserEmail "email@example.com"] [-SkipGit] [-SkipVSCode]
# Requires: Windows 11 64-bit, PowerShell 7, winget, Administrator session.
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
    [string]$Category = 'All',

    [string]$GitUserName = "",

    [string]$GitUserEmail = "",

    [switch]$SkipGit,

    [switch]$SkipVSCode
)

$RepoRoot = $PSScriptRoot
$AppsConfigPath = Join-Path -Path $RepoRoot -ChildPath "config/apps.json"
$ExtensionsConfigPath = Join-Path -Path $RepoRoot -ChildPath "config/vscode/extensions.json"

function Update-SessionPath {
    # Apps installed via winget in this same session (git, code) are missing
    # from the process PATH. Merge process + Machine + User PATHs, deduplicated.
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
        Write-Warning "Could not refresh the session PATH: $_"
    }
}

# 1. Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Administrator privileges are required. Open PowerShell as Administrator and try again."
    exit 1
}

# 2. Windows 11 64-bit OS check. Win32_OperatingSystem.OSArchitecture is
# localized ("64-bit" in English, "64 bits" in Spanish), so match '64'
# instead of comparing the exact string.
$os = Get-CimInstance Win32_OperatingSystem
if ($null -eq $os) {
    Write-Error "Could not query operating system information. Run this script in PowerShell 7 as Administrator."
    exit 1
}
$detectedBuild = [int]$os.BuildNumber
$detectedArch = [string]$os.OSArchitecture
$is64BitEnv = [Environment]::Is64BitOperatingSystem
$isWin11 = $detectedBuild -ge 22000
$is64BitOS = $is64BitEnv -and ($detectedArch -match '64')

if (-not ($isWin11 -and $is64BitOS)) {
    Write-Error "This script targets 64-bit Windows 11 only (Build >= 22000, 64-bit OS). Detected: Build=$detectedBuild, Architecture='$detectedArch', OS64bit=$is64BitEnv. Aborting."
    exit 1
}

# 3. winget availability
if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    Write-Error "winget is not available on this system. Install it (App Installer from the Microsoft Store) to continue."
    exit 1
}

# 4. Import shared module
$CommonModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Common.ps1")
if (Test-Path $CommonModulePath) {
    . $CommonModulePath
} else {
    Write-Error "Shared module not found at: $CommonModulePath. Aborting."
    exit 1
}

# 5. Start timestamped logging
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

# 7. Run winget installation (-WhatIf flows through $WhatIfPreference)
Invoke-InstallCategory -Category $Category -AppsConfigPath $AppsConfigPath

# Refresh PATH so same-run git/code installs are detectable without a restart.
Update-SessionPath

# 8. Git configuration (Dev or All only)
$GitModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Config-Git.ps1")
if (Test-Path $GitModulePath) {
    . $GitModulePath

    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        if ($SkipGit) {
            Write-InstallLog -Message "Git configuration skipped via -SkipGit flag." -Level "INFO"
        } else {
            Invoke-GitConfig -UserName $GitUserName -UserEmail $GitUserEmail
        }
    }
} else {
    Write-InstallLog -Message "Git configuration module not found at: $GitModulePath" -Level "WARNING"
}

# 9. VSCode configuration (Dev or All only)
$VSCodeModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Config-VSCode.ps1")
if (Test-Path $VSCodeModulePath) {
    . $VSCodeModulePath

    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        if ($SkipVSCode) {
            Write-InstallLog -Message "VSCode configuration skipped via -SkipVSCode flag." -Level "INFO"
        } else {
            Invoke-VSCodeConfig -ExtensionsConfigPath $ExtensionsConfigPath
        }
    }
} else {
    Write-InstallLog -Message "VSCode configuration module not found at: $VSCodeModulePath" -Level "WARNING"
}

# 10. Exit
Write-InstallLog -Message "Installer run finished." -Level "INFO"
if ($global:InstallHadErrors) {
    Write-Host "Completed with errors. Check the logs/ folder for details." -ForegroundColor Red
    exit 1
}
Write-Host "Completed successfully. Check the logs/ folder for details." -ForegroundColor Green
