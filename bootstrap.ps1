# bootstrap.ps1 - Online installer for windows-11-auto-setup.
# Downloads the repo ZIP from GitHub, extracts it, auto-elevates to
# Administrator if needed, and runs install.ps1 with the given parameters.
# Usage (PowerShell 7):
#   .\bootstrap.ps1 [-Category Base|Dev|Gaming|All] [-WhatIf]
#                   [-GitUserName "Name"] [-GitUserEmail "email@example.com"]
#                   [-SkipGit] [-SkipVSCode] [-Branch "master"] [-KeepDownload]
# One-line interactive mode (no download, arrow-key menu):
#   irm https://raw.githubusercontent.com/alexp11mon/windows-11-auto-setup/master/bootstrap.ps1 | iex
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

    [switch]$KeepDownload,

    [switch]$SkipGit,

    [switch]$SkipVSCode
)

# Under iex ($PSCommandPath is empty) plain exit would close the user's
# console, so every exit below returns instead and leaves $LASTEXITCODE set.
$isIex = [string]::IsNullOrWhiteSpace($PSCommandPath)

function Show-Menu {
    param (
        [string]$Title,
        [string[]]$Options,
        [switch]$Multi
    )
    $selected = 0
    $checked = @($false) * $Options.Count
    while ($true) {
        Clear-Host
        Write-Host $Title -ForegroundColor Cyan
        Write-Host "Use ↑/↓, Space to mark, Enter to confirm, Esc to cancel" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $cursor = if ($i -eq $selected) { ">" } else { " " }
            $mark = if ($Multi -and $checked[$i]) { "[x]" } else { "[ ]" }
            $prefix = if ($Multi) { "$cursor $mark" } else { "$cursor" }
            if ($i -eq $selected) {
                Write-Host "$prefix $($Options[$i])" -ForegroundColor Green
            } else {
                Write-Host "$prefix $($Options[$i])"
            }
        }
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { $selected = ($selected - 1 + $Options.Count) % $Options.Count }
            'DownArrow' { $selected = ($selected + 1) % $Options.Count }
            'Spacebar'  { if ($Multi) { $checked[$selected] = -not $checked[$selected] } }
            'Enter'     {
                if ($Multi) { return ,@($Options | Where-Object { $checked[$Options.IndexOf($_)] }) }
                return $selected
            }
            'Escape'    { return $null }
        }
    }
}

function Show-NumberedMenu {
    # Fallback when no console is available (ISE, redirected input).
    param (
        [string]$Title,
        [string[]]$Options,
        [switch]$Multi
    )
    Write-Host $Title -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $Options[$i])
    }
    if ($Multi) {
        $answer = Read-Host "Enter numbers separated by commas (empty cancels)"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $null }
        $picked = @()
        foreach ($n in ($answer -split ',')) {
            $idx = 0
            if ([int]::TryParse($n.Trim(), [ref]$idx) -and $idx -ge 1 -and $idx -le $Options.Count) {
                $picked += $Options[$idx - 1]
            }
        }
        if ($picked.Count -eq 0) { return $null }
        return ,$picked
    }
    $answer = Read-Host ("Enter a number 1-{0} (empty cancels)" -f $Options.Count)
    if ([string]::IsNullOrWhiteSpace($answer)) { return $null }
    $idx = 0
    if (-not [int]::TryParse($answer.Trim(), [ref]$idx) -or $idx -lt 1 -or $idx -gt $Options.Count) { return $null }
    return ($idx - 1)
}

$ZipUrl = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"

# 1. Require PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "PowerShell 7 (pwsh) is required to run the online installer. Install it with: winget install --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements"
    $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
}

$menuFallback = $false
try { $null = [Console]::KeyAvailable } catch { $menuFallback = $true }
function Invoke-Menu {
    # Arrow-key menu when a console exists, numbered fallback otherwise.
    param (
        [string]$Title,
        [string[]]$Options,
        [switch]$Multi
    )
    if ($menuFallback) { Show-NumberedMenu -Title $Title -Options $Options -Multi:$Multi }
    else { Show-Menu -Title $Title -Options $Options -Multi:$Multi }
}

$customApps = @()
$interactive = ($PSBoundParameters.Count -eq 0) -and [Environment]::UserInteractive -and (-not $WhatIfPreference)

if ($interactive) {
    $scope = Invoke-Menu -Title "What do you want to install?" -Options @('All', 'Base', 'Dev', 'Gaming', 'Custom per-app')
    if ($null -eq $scope) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
    if ($scope -eq 4) {
        $Category = 'All'
        $customApps = @()
        $appsUrl = "https://raw.githubusercontent.com/$Repo/$Branch/config/apps.json"
        try {
            $appsData = Invoke-RestMethod -Uri $appsUrl
        } catch {
            Write-Error "Could not download the app list from: $appsUrl. $_"
            $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
        }
        $flat = @($appsData.Base) + @($appsData.Dev) + @($appsData.Gaming)
        $customApps = Invoke-Menu -Title "Mark apps with Space, Enter to confirm" -Options $flat -Multi
        if ($null -eq $customApps -or $customApps.Count -eq 0) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
    } else {
        $Category = @('All', 'Base', 'Dev', 'Gaming')[$scope]
    }
    $gitChoice = Invoke-Menu -Title "Git configuration?" -Options @('Enter name/email', 'Skip Git configuration')
    if ($null -eq $gitChoice) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
    if ($gitChoice -eq 0) {
        $GitUserName = Read-Host "Enter your user name for Git"
        $GitUserEmail = Read-Host "Enter your email address for Git"
    } else {
        $SkipGit = $true
    }
    $codeChoice = Invoke-Menu -Title "VSCode configuration?" -Options @('Install extensions', 'Skip VSCode configuration')
    if ($null -eq $codeChoice) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
    if ($codeChoice -eq 1) {
        $SkipVSCode = $true
    }
    $confirm = Invoke-Menu -Title "Ready: Category=$Category Apps=$(if ($customApps.Count) { $customApps.Count } else { 'all' }) Git=$(if ($SkipGit) { 'skipped' } else { $GitUserName }) VSCode=$(if ($SkipVSCode) { 'skipped' } else { 'extensions' })" -Options @('Install now', 'Simulate first (-WhatIf)', 'Cancel')
    if ($null -eq $confirm -or $confirm -eq 2) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
    if ($confirm -eq 1) {
        Write-Host "Would download: $ZipUrl" -ForegroundColor Cyan
        $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 }
    }
}

# 2. Simulation mode: only describe what would happen, no side effects
if ($WhatIfPreference) {
    Write-Host "Would download: $ZipUrl" -ForegroundColor Cyan
    $previewArgs = "-Category $Category"
    if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $previewArgs += " -GitUserName `"$GitUserName`"" }
    if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $previewArgs += " -GitUserEmail `"$GitUserEmail`"" }
    Write-Host "Would extract it and run: install.ps1 $previewArgs" -ForegroundColor Cyan
    $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 }
}

# 3. Auto-elevation to Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    # Under iex there is no script file, so persist our own code first.
    $selfPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($selfPath)) {
        $selfPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "bootstrap-iex.ps1"
        $MyInvocation.MyCommand.ScriptBlock.ToString() | Set-Content -Path $selfPath -Encoding UTF8
    }
    $elevArgs = @('-NoProfile', '-File', "`"$selfPath`"", '-Category', $Category, '-Repo', $Repo, '-Branch', $Branch)
    if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $elevArgs += @('-GitUserName', "`"$GitUserName`"") }
    if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $elevArgs += @('-GitUserEmail', "`"$GitUserEmail`"") }
    if ($KeepDownload) { $elevArgs += '-KeepDownload' }
    if ($SkipGit) { $elevArgs += '-SkipGit' }
    if ($SkipVSCode) { $elevArgs += '-SkipVSCode' }
    try {
        $child = Start-Process -FilePath "pwsh" -ArgumentList $elevArgs -Verb RunAs -Wait -PassThru
        $global:LASTEXITCODE = $child.ExitCode; if ($isIex) { return } else { exit $child.ExitCode }
    } catch {
        Write-Error "Elevation failed or was cancelled: $_"
        $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
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
    $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
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
    $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
}

# 5. Extract and locate install.ps1
try {
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
} catch {
    Write-Error "Could not extract the repository ZIP: $_"
    $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
}
$installScript = Get-ChildItem -Path $extractDir -Recurse -Filter "install.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $installScript) {
    Write-Error "install.ps1 not found in the downloaded archive."
    $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
}

# Custom per-app mode: keep only the selected IDs in the extracted apps.json.
if ($customApps -and $customApps.Count -gt 0) {
    $extractedApps = Get-ChildItem -Path $extractDir -Recurse -Filter "apps.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $extractedApps) {
        $cfg = Get-Content -Path $extractedApps.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in @('Base', 'Dev', 'Gaming')) {
            $cfg.$prop = @($cfg.$prop | Where-Object { $customApps -contains $_ })
        }
        $cfg | ConvertTo-Json -Depth 3 | Set-Content -Path $extractedApps.FullName -Encoding UTF8
        Write-Host "Custom selection: $($customApps.Count) apps." -ForegroundColor Cyan
    }
}
Write-Host "Running: $($installScript.FullName) -Category $Category" -ForegroundColor Green

# 6. Run the installer and propagate its exit code
$installArgs = @('-NoProfile', '-File', "`"$($installScript.FullName)`"", '-Category', $Category)
if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $installArgs += @('-GitUserName', "`"$GitUserName`"") }
if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $installArgs += @('-GitUserEmail', "`"$GitUserEmail`"") }
if ($SkipGit) { $installArgs += '-SkipGit' }
if ($SkipVSCode) { $installArgs += '-SkipVSCode' }
$proc = Start-Process -FilePath "pwsh" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
$installExit = $proc.ExitCode

# 7. Cleanup unless requested otherwise
if ($KeepDownload) {
    Write-Host "Keeping downloaded files at: $workDir" -ForegroundColor Yellow
} else {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

$global:LASTEXITCODE = $installExit; if ($isIex) { return } else { exit $installExit }
