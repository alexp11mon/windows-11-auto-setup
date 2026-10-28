# bootstrap.ps1 - Online installer for windows-11-auto-setup.
# Downloads the repo ZIP from GitHub, extracts it, auto-elevates to
# Administrator if needed, and runs install.ps1 with the given parameters.
# Usage (PowerShell 7):
#   .\bootstrap.ps1 [-Category Base|Dev|Gaming|All] [-WhatIf]
#                   [-GitUserName "Name"] [-GitUserEmail "email@example.com"]
#                   [-SkipGit] [-SkipVSCode] [-SkipOpenCode] [-SkipBrave] [-Branch "master"|"v1.0.0"] [-KeepDownload]
#                   [-Sha256 <hex>] [-Apps "Id1","Id2"]
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

    [switch]$SkipVSCode,

    [switch]$SkipOpenCode,

    [switch]$SkipBrave,

    # Expected SHA256 of the downloaded ZIP (published in each release's notes).
    # Empty must stay valid: under iex the param block runs as code with the empty default.
    [ValidatePattern('^([0-9a-fA-F]{64})?$')]
    [string]$Sha256,

    # Custom per-app selection: install only these winget IDs.
    [string[]]$Apps = @()
)

# Under iex ($PSCommandPath is empty) plain exit would close the user's
# console, so every exit below returns instead and leaves $LASTEXITCODE set.
$isIex = [string]::IsNullOrWhiteSpace($PSCommandPath)

# "pwsh -File ... -Apps a,b" passes one string "a,b"; winget IDs never contain commas.
$Apps = @($Apps | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

function ConvertTo-PSLiteral {
    param ([string]$Value)
    "'" + ($Value -replace "'", "''") + "'"
}

function Get-ElevatedCommand {
    # Command for the elevated child, sent via -EncodedCommand so values with
    # spaces or quotes survive (Start-Process does not quote arguments). Under
    # iex the child downloads this same script instead of a temp copy that a
    # non-elevated process could tamper with before UAC.
    param (
        [string]$ScriptPath,
        [string]$RawUrl,
        [System.Collections.IDictionary]$Params,
        [string[]]$Switches = @()
    )
    $paramText = ''
    foreach ($name in $Params.Keys) {
        $values = @($Params[$name] | ForEach-Object { ConvertTo-PSLiteral $_ })
        $paramText += " -$name $($values -join ',')"
    }
    foreach ($switch in $Switches) { $paramText += " -$switch" }
    if ($ScriptPath) {
        return "& $(ConvertTo-PSLiteral $ScriptPath)$paramText; exit `$LASTEXITCODE"
    }
    "try { `$code = Invoke-RestMethod -Uri $(ConvertTo-PSLiteral $RawUrl) -ErrorAction Stop } catch { Write-Error `$_; exit 1 }; & ([scriptblock]::Create(`$code))$paramText; exit `$LASTEXITCODE"
}

function Save-RunLogs {
    # The work folder is deleted after the run: keep install logs somewhere stable.
    param (
        [string]$SourceDir,
        [string]$Destination
    )
    $logs = @(Get-ChildItem -Path $SourceDir -Filter '*.log' -File -ErrorAction SilentlyContinue)
    if ($logs.Count -eq 0) { return }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $logs | Copy-Item -Destination $Destination -Force
    Write-Host "Logs saved to: $Destination" -ForegroundColor Cyan
}

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

$ZipUrl = "https://github.com/$Repo/archive/$Branch.zip"
# archive/<ref>.zip resolves both branches and release tags.
$LogArchiveDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "win11-setup\logs"

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

$interactive = ($PSBoundParameters.Count -eq 0) -and [Environment]::UserInteractive -and (-not $WhatIfPreference)

if ($interactive) {
    $scope = Invoke-Menu -Title "What do you want to install?" -Options @('All', 'Base', 'Dev', 'Gaming', 'Custom per-app')
    if ($null -eq $scope) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
    if ($scope -eq 4) {
        $Category = 'All'
        $appsUrl = "https://raw.githubusercontent.com/$Repo/$Branch/config/apps.json"
        try {
            $appsData = Invoke-RestMethod -Uri $appsUrl
        } catch {
            Write-Error "Could not download the app list from: $appsUrl. $_"
            $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
        }
        $flat = @($appsData.Base) + @($appsData.Dev) + @($appsData.Gaming)
        $Apps = Invoke-Menu -Title "Mark apps with Space, Enter to confirm" -Options $flat -Multi
        if ($null -eq $Apps -or $Apps.Count -eq 0) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
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
    $openCodeChoice = Invoke-Menu -Title "OpenCode configuration?" -Options @('Install and configure OpenCode', 'Skip OpenCode configuration')
    if ($null -eq $openCodeChoice) { Write-Host "Cancelled." -ForegroundColor Yellow; $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 } }
    if ($openCodeChoice -eq 1) {
        $SkipOpenCode = $true
    }
    # Brave extensions apply automatically on Base/All without asking.
    $braveApplies = (($Category -eq 'Base') -or ($Category -eq 'All')) -and (-not $SkipBrave)
    $confirm = Invoke-Menu -Title "Ready: Category=$Category Apps=$(if ($Apps.Count) { $Apps.Count } else { 'all' }) Git=$(if ($SkipGit) { 'skipped' } else { $GitUserName }) VSCode=$(if ($SkipVSCode) { 'skipped' } else { 'extensions' }) OpenCode=$(if ($SkipOpenCode) { 'skipped' } else { 'install' }) Brave=$(if ($braveApplies) { 'forced extensions (machine policy, not removable from Brave)' } else { 'skipped' })" -Options @('Install now', 'Simulate first (-WhatIf)', 'Cancel')
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
    if ($SkipGit) { $previewArgs += " -SkipGit" }
    if ($SkipVSCode) { $previewArgs += " -SkipVSCode" }
    if ($SkipOpenCode) { $previewArgs += " -SkipOpenCode" }
    if ($SkipBrave) { $previewArgs += " -SkipBrave" }
    if ($Sha256) { Write-Host "Would verify ZIP SHA256: $Sha256" -ForegroundColor Cyan }
    if ($Apps.Count) { Write-Host "Would keep only these apps: $($Apps -join ', ')" -ForegroundColor Cyan }
    Write-Host "Would extract it and run: install.ps1 $previewArgs" -ForegroundColor Cyan
    $global:LASTEXITCODE = 0; if ($isIex) { return } else { exit 0 }
}

# 3. Auto-elevation to Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $elevParams = [ordered]@{ Category = $Category; Repo = $Repo; Branch = $Branch }
    if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $elevParams.GitUserName = $GitUserName }
    if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $elevParams.GitUserEmail = $GitUserEmail }
    if ($Sha256) { $elevParams.Sha256 = $Sha256 }
    if ($Apps.Count) { $elevParams.Apps = $Apps }
    $elevSwitches = @()
    if ($KeepDownload) { $elevSwitches += 'KeepDownload' }
    if ($SkipGit) { $elevSwitches += 'SkipGit' }
    if ($SkipVSCode) { $elevSwitches += 'SkipVSCode' }
    if ($SkipOpenCode) { $elevSwitches += 'SkipOpenCode' }
    if ($SkipBrave) { $elevSwitches += 'SkipBrave' }
    $rawUrl = "https://raw.githubusercontent.com/$Repo/$Branch/bootstrap.ps1"
    $elevCommand = Get-ElevatedCommand -ScriptPath $PSCommandPath -RawUrl $rawUrl -Params $elevParams -Switches $elevSwitches
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($elevCommand))
    try {
        # -Verb RunAs cannot be combined with -Redirect*: the child writes its own log (Save-RunLogs).
        $child = Start-Process -FilePath "pwsh" -ArgumentList @('-NoProfile', '-EncodedCommand', $encoded) -Verb RunAs -Wait -PassThru
        Write-Host "Elevated installer exited with code: $($child.ExitCode) (logs: $LogArchiveDir)" -ForegroundColor Cyan
        if ($child.ExitCode -ne 0) {
            Get-ChildItem -Path $LogArchiveDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content -Tail 20
        }
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
if ($Sha256) {
    $actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    # -ne is case-insensitive, so upper/lower-case hex both match.
    if ($actualHash -ne $Sha256) {
        Write-Error "ZIP SHA256 mismatch. Expected: $Sha256. Actual: $actualHash. Aborting without extracting."
        Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
    }
    Write-Host "ZIP SHA256 verified." -ForegroundColor Green
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
if ($Apps.Count -gt 0) {
    $extractedApps = Get-ChildItem -Path $extractDir -Recurse -Filter "apps.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $extractedApps) {
        $cfg = Get-Content -Path $extractedApps.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $kept = 0
        foreach ($prop in @('Base', 'Dev', 'Gaming')) {
            $cfg.$prop = @($cfg.$prop | Where-Object { $Apps -contains $_ })
            $kept += $cfg.$prop.Count
        }
        if ($kept -eq 0) {
            Write-Warning "None of the selected apps exist in apps.json ($($Apps -join ', ')). Keeping the full list."
        } else {
            $cfg | ConvertTo-Json -Depth 3 | Set-Content -Path $extractedApps.FullName -Encoding UTF8
            Write-Host "Custom selection: $kept apps." -ForegroundColor Cyan
        }
    }
}
Write-Host "Running: $($installScript.FullName) -Category $Category" -ForegroundColor Green

# 6. Run the installer and propagate its exit code. Direct invocation (not
# Start-Process) so values with spaces, like "Ana Lopez", stay one argument.
$installArgs = @('-NoProfile', '-File', $installScript.FullName, '-Category', $Category)
if (-not [string]::IsNullOrWhiteSpace($GitUserName)) { $installArgs += @('-GitUserName', $GitUserName) }
if (-not [string]::IsNullOrWhiteSpace($GitUserEmail)) { $installArgs += @('-GitUserEmail', $GitUserEmail) }
if ($SkipGit) { $installArgs += '-SkipGit' }
if ($SkipVSCode) { $installArgs += '-SkipVSCode' }
if ($SkipOpenCode) { $installArgs += '-SkipOpenCode' }
if ($SkipBrave) { $installArgs += '-SkipBrave' }
& pwsh @installArgs
$installExit = $LASTEXITCODE

# 7. Keep the logs, then clean up unless requested otherwise
Save-RunLogs -SourceDir (Join-Path -Path $installScript.DirectoryName -ChildPath "logs") -Destination $LogArchiveDir
if ($KeepDownload) {
    Write-Host "Keeping downloaded files at: $workDir" -ForegroundColor Yellow
} else {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

$global:LASTEXITCODE = $installExit; if ($isIex) { return } else { exit $installExit }
