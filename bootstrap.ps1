# bootstrap.ps1 - Online installer for windows-11-auto-setup.
# Downloads the repo ZIP from GitHub, extracts it, auto-elevates to
# Administrator if needed, and runs install.ps1 with the given parameters.
# Usage (PowerShell 7):
#   .\bootstrap.ps1 [-Category Base|Dev|Gaming|All] [-WhatIf]
#                   [-GitUserName "Name"] [-GitUserEmail "email@example.com"]
#                   [-Branch "master"] [-KeepDownload]
# Remote two-line mode (no local clone needed):
#   Invoke-WebRequest https://raw.githubusercontent.com/alexp11mon/windows-11-auto-setup/master/bootstrap.ps1 -OutFile bootstrap.ps1
#   .\bootstrap.ps1 -Category All -WhatIf
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
    [string]$Category = 'All',

    [string]$GitUserName = "",

    [string]$GitUserEmail = "",

    [string]$Repo = "alexp11mon/windows-11-auto-setup",

    [string]$Branch = "master",

    [switch]$KeepDownload
)

$ZipUrl = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"

# 1. Require PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "PowerShell 7 (pwsh) is required to run the online installer. Install it with: winget install --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements"
    exit 1
}

# 2. Simulation mode: only describe what would happen, no side effects
if ($WhatIfPreference) {
    Write-Host "Would download: $ZipUrl" -ForegroundColor Cyan
    $previewArgs = "-Category $Category"
    if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $previewArgs += " -GitUserName `"$GitUserName`"" }
    if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $previewArgs += " -GitUserEmail `"$GitUserEmail`"" }
    Write-Host "Would extract it and run: install.ps1 $previewArgs" -ForegroundColor Cyan
    exit 0
}

# 3. Auto-elevation to Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $elevArgs = @('-NoProfile', '-File', "`"$PSCommandPath`"", '-Category', $Category, '-Repo', $Repo, '-Branch', $Branch)
    if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $elevArgs += @('-GitUserName', "`"$GitUserName`"") }
    if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $elevArgs += @('-GitUserEmail', "`"$GitUserEmail`"") }
    if ($KeepDownload) { $elevArgs += '-KeepDownload' }
    try {
        $child = Start-Process -FilePath "pwsh" -ArgumentList $elevArgs -Verb RunAs -Wait -PassThru
        exit $child.ExitCode
    } catch {
        Write-Error "Elevation failed or was cancelled: $_"
        exit 1
    }
}

# 4. Download the repo ZIP (2 attempts)
$workDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("win11-setup-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$zipPath = Join-Path -Path $workDir -ChildPath "repo.zip"
$extractDir = Join-Path -Path $workDir -ChildPath "extracted"
try {
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
} catch {
    Write-Error "Could not create working directory: $workDir. $_"
    exit 1
}

$downloaded = $false
for ($attempt = 1; $attempt -le 2; $attempt++) {
    try {
        Write-Host "Downloading ($attempt/2): $ZipUrl" -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath -UseBasicParsing
        $downloaded = $true
        break
    } catch {
        Write-Warning "Download attempt $attempt failed: $_"
    }
}
if (-not $downloaded) {
    Write-Error "Could not download the repository ZIP from: $ZipUrl"
    exit 1
}

# 5. Extract and locate install.ps1
try {
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
} catch {
    Write-Error "Could not extract the repository ZIP: $_"
    exit 1
}
$installScript = Get-ChildItem -Path $extractDir -Recurse -Filter "install.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $installScript) {
    Write-Error "install.ps1 not found in the downloaded archive."
    exit 1
}
Write-Host "Running: $($installScript.FullName) -Category $Category" -ForegroundColor Green

# 6. Run the installer and propagate its exit code
$installArgs = @('-NoProfile', '-File', "`"$($installScript.FullName)`"", '-Category', $Category)
if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $installArgs += @('-GitUserName', "`"$GitUserName`"") }
if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $installArgs += @('-GitUserEmail', "`"$GitUserEmail`"") }
$proc = Start-Process -FilePath "pwsh" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
$installExit = $proc.ExitCode

# 7. Cleanup unless requested otherwise
if ($KeepDownload) {
    Write-Host "Keeping downloaded files at: $workDir" -ForegroundColor Yellow
} else {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit $installExit
