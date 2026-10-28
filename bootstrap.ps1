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
# Menus return this to go back one step; $null means cancel.
$MenuBack = '<back>'

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

function Get-ConfigScope {
    # Which config blocks apply. Without a selection it mirrors install.ps1's
    # category gating; with one, each block follows the app it configures.
    param (
        [string]$Category,
        [string[]]$Apps = @(),
        $AppsData
    )
    if ($Apps.Count -eq 0) {
        $dev = $Category -in @('Dev', 'All')
        return @{ Git = $dev; VSCode = $dev; OpenCode = $dev; Brave = $Category -in @('Base', 'All') }
    }
    @{
        Git      = $Apps -contains 'Git.Git'
        VSCode   = $Apps -contains 'Microsoft.VisualStudioCode'
        Brave    = $Apps -contains 'Brave.Brave'
        # OpenCode is not a winget app: it applies when any Dev app is selected.
        OpenCode = @($Apps | Where-Object { @($AppsData.Dev) -contains $_ }).Count -gt 0
    }
}

function Read-MenuKey {
    # Wrapper so tests can feed keys without a console.
    [Console]::ReadKey($true)
}

function Show-Menu {
    # Returns the index (single) or the marked options (multi); Esc returns $MenuBack.
    param (
        [string]$Title,
        [string[]]$Options,
        [switch]$Multi,
        [string[]]$Checked = @(),
        [int]$Start = 0
    )
    $selected = $Start
    $marks = @($Options | ForEach-Object { $Checked -contains $_ })
    $toggled = $false
    while ($true) {
        Clear-Host
        Write-Host $Title -ForegroundColor Cyan
        $help = if ($Multi) { "Use ↑/↓ to move, Space toggles, Enter confirms, Esc goes back" } else { "Use ↑/↓ to move, Enter confirms, Esc goes back" }
        Write-Host $help -ForegroundColor DarkGray
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $cursor = if ($i -eq $selected) { ">" } else { " " }
            $mark = if ($Multi -and $marks[$i]) { "[x]" } else { "[ ]" }
            $prefix = if ($Multi) { "$cursor $mark" } else { "$cursor" }
            if ($i -eq $selected) {
                Write-Host "$prefix $($Options[$i])" -ForegroundColor Green
            } else {
                Write-Host "$prefix $($Options[$i])"
            }
        }
        $key = Read-MenuKey
        switch ($key.Key) {
            'UpArrow'   { $selected = ($selected - 1 + $Options.Count) % $Options.Count }
            'DownArrow' { $selected = ($selected + 1) % $Options.Count }
            'Spacebar'  { if ($Multi) { $marks[$selected] = -not $marks[$selected]; $toggled = $true } }
            'Enter'     {
                if (-not $Multi) { return $selected }
                $picked = @(for ($i = 0; $i -lt $Options.Count; $i++) { if ($marks[$i]) { $Options[$i] } })
                if ($picked.Count -gt 0) { return ,$picked }
                # Nothing marked: Enter picks the highlighted item, unless the user unmarked everything on purpose.
                if ($toggled) { return $null }
                return ,@($Options[$selected])
            }
            'Escape'    { return $MenuBack }
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
        $answer = Read-Host "Enter numbers separated by commas (0 goes back, empty cancels)"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $null }
        if ($answer.Trim() -eq '0') { return $MenuBack }
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
    $answer = Read-Host ("Enter a number 1-{0} (0 goes back, empty cancels)" -f $Options.Count)
    if ([string]::IsNullOrWhiteSpace($answer)) { return $null }
    $idx = 0
    if (-not [int]::TryParse($answer.Trim(), [ref]$idx) -or $idx -lt 0 -or $idx -gt $Options.Count) { return $null }
    if ($idx -eq 0) { return $MenuBack }
    return ($idx - 1)
}

function Format-InstallSummary {
    # Apps grouped by category plus the config blocks that will run.
    param (
        [hashtable]$Choices,
        $AppsData
    )
    $categories = if ($Choices.Category -eq 'All') { @('Base', 'Dev', 'Gaming') } else { @($Choices.Category) }
    $lines = @('Programs to install:')
    foreach ($cat in $categories) {
        $apps = @($AppsData.$cat | Where-Object { @($Choices.Apps).Count -eq 0 -or $Choices.Apps -contains $_ })
        if ($apps.Count) { $lines += "  ${cat}:"; $lines += $apps | ForEach-Object { "    - $_" } }
    }
    $git = if ($Choices.SkipGit) { 'skipped' } elseif ($Choices.GitUserName) { "$($Choices.GitUserName) <$($Choices.GitUserEmail)>" } else { 'asked during install' }
    $lines += 'Configuration:'
    $lines += "  Git: $git"
    $lines += "  VSCode: $(if ($Choices.SkipVSCode) { 'skipped' } else { 'install extensions' })"
    $lines += "  OpenCode: $(if ($Choices.SkipOpenCode) { 'skipped' } else { 'install and configure' })"
    $lines += "  Brave: $(if ($Choices.SkipBrave) { 'skipped' } else { 'forced extensions (machine policy, not removable from Brave)' })"
    $lines -join "`n"
}

function Invoke-InteractiveSetup {
    # Menu steps with Back (history stack). Returns the install choices, or $null to exit.
    param ($AppsData)
    $categories = @('All', 'Base', 'Dev', 'Gaming')
    $order = @('Category', 'Apps', 'Git', 'VSCode', 'OpenCode', 'Summary')
    $a = @{ CategoryIndex = 0; Picked = $null; GitChoice = 0; CodeChoice = 0; OpenCodeChoice = 0; GitUserName = ''; GitUserEmail = '' }
    $history = [System.Collections.Generic.List[string]]::new()
    $step = 'Category'
    $readState = {
        $category = $categories[$a.CategoryIndex]
        $categoryApps = if ($category -eq 'All') { @($AppsData.Base) + @($AppsData.Dev) + @($AppsData.Gaming) } else { @($AppsData.$category) }
        # The whole category needs no -Apps filter.
        $apps = if ($a.Picked -and @($a.Picked).Count -lt $categoryApps.Count) { @($a.Picked) } else { @() }
        $scope = Get-ConfigScope -Category $category -Apps $apps -AppsData $AppsData
    }
    while ($true) {
        . $readState
        $move = 'next'
        switch ($step) {
            'Category' {
                $r = Invoke-Menu -Title "What do you want to install?" -Options ($categories + 'Exit') -Start $a.CategoryIndex
                if ($r -isnot [int] -or $r -eq 4) { return $null }
                if ($r -ne $a.CategoryIndex) { $a.Picked = $null }
                $a.CategoryIndex = $r
            }
            'Apps' {
                $checked = if ($a.Picked) { @($a.Picked) } else { $categoryApps }
                $r = Invoke-Menu -Title "Apps to install ($category). Unmark the ones you do not want:" -Options $categoryApps -Multi -Checked $checked
                if ($null -eq $r -or @($r).Count -eq 0) { return $null }
                if ($r -is [string] -and $r -eq $MenuBack) { $move = 'back' } else { $a.Picked = @($r) }
            }
            'Git' {
                $r = Invoke-Menu -Title "Git configuration?" -Options @('Enter name/email', 'Skip Git configuration', 'Back') -Start $a.GitChoice
                if ($null -eq $r) { return $null }
                if ($r -isnot [int] -or $r -eq 2) { $move = 'back' }
                else {
                    $a.GitChoice = $r
                    if ($r -eq 0) {
                        # Enter keeps the previous answer when coming back.
                        $name = Read-Host ("Enter your user name for Git" + $(if ($a.GitUserName) { " (Enter keeps '$($a.GitUserName)')" }))
                        if ($name) { $a.GitUserName = $name }
                        $email = Read-Host ("Enter your email address for Git" + $(if ($a.GitUserEmail) { " (Enter keeps '$($a.GitUserEmail)')" }))
                        if ($email) { $a.GitUserEmail = $email }
                    }
                }
            }
            'VSCode' {
                $r = Invoke-Menu -Title "VSCode configuration?" -Options @('Install extensions', 'Skip VSCode configuration', 'Back') -Start $a.CodeChoice
                if ($null -eq $r) { return $null }
                if ($r -isnot [int] -or $r -eq 2) { $move = 'back' } else { $a.CodeChoice = $r }
            }
            'OpenCode' {
                $r = Invoke-Menu -Title "OpenCode configuration?" -Options @('Install and configure OpenCode', 'Skip OpenCode configuration', 'Back') -Start $a.OpenCodeChoice
                if ($null -eq $r) { return $null }
                if ($r -isnot [int] -or $r -eq 2) { $move = 'back' } else { $a.OpenCodeChoice = $r }
            }
            'Summary' {
                $skipGit = (-not $scope.Git) -or $a.GitChoice -eq 1
                $choices = @{
                    Category     = $category
                    Apps         = $apps
                    GitUserName  = $(if ($skipGit) { '' } else { $a.GitUserName })
                    GitUserEmail = $(if ($skipGit) { '' } else { $a.GitUserEmail })
                    SkipGit      = $skipGit
                    SkipVSCode   = (-not $scope.VSCode) -or $a.CodeChoice -eq 1
                    SkipOpenCode = (-not $scope.OpenCode) -or $a.OpenCodeChoice -eq 1
                    # Brave extensions apply without asking whenever Brave is part of the selection.
                    SkipBrave    = -not $scope.Brave
                }
                $title = (Format-InstallSummary -Choices $choices -AppsData $AppsData) + "`n`nAre you sure you want to install these programs?"
                $r = Invoke-Menu -Title $title -Options @('Install', 'Back', 'Cancel')
                if ($null -eq $r -or $r -eq 2) { return $null }
                if ($r -isnot [int] -or $r -eq 1) { $move = 'back' } else { return $choices }
            }
        }
        if ($move -eq 'back') {
            $step = $history[$history.Count - 1]
            $history.RemoveAt($history.Count - 1)
            continue
        }
        $history.Add($step)
        # The Apps step may have changed which questions apply.
        . $readState
        $i = $order.IndexOf($step) + 1
        while ($order[$i] -in @('Git', 'VSCode', 'OpenCode') -and -not $scope[$order[$i]]) { $i++ }
        $step = $order[$i]
    }
}

function Invoke-InstallRound {
    # One install in a child process (UAC when not admin); returns its exit code.
    param (
        [System.Collections.IDictionary]$Params,
        [string[]]$Switches = @(),
        [bool]$IsAdmin,
        [string]$ScriptPath,
        [string]$RawUrl,
        [string]$LogDir
    )
    $elevCommand = Get-ElevatedCommand -ScriptPath $ScriptPath -RawUrl $RawUrl -Params $Params -Switches $Switches
    $argList = @('-NoProfile', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($elevCommand)))
    try {
        # -Verb RunAs cannot be combined with -Redirect*: the child writes its own log (Save-RunLogs).
        if ($IsAdmin) {
            $child = Start-Process -FilePath "pwsh" -ArgumentList $argList -NoNewWindow -Wait -PassThru
        } else {
            Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
            $child = Start-Process -FilePath "pwsh" -ArgumentList $argList -Verb RunAs -Wait -PassThru
        }
    } catch {
        Write-Warning "Elevation failed or was cancelled: $_"
        return 1
    }
    Write-Host "Installer exited with code: $($child.ExitCode) (logs: $LogDir)" -ForegroundColor Cyan
    if ($child.ExitCode -ne 0) {
        Get-ChildItem -Path $LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content -Tail 20
    }
    $child.ExitCode
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
        [switch]$Multi,
        [string[]]$Checked = @(),
        [int]$Start = 0
    )
    if ($menuFallback) { Show-NumberedMenu -Title $Title -Options $Options -Multi:$Multi }
    else { Show-Menu -Title $Title -Options $Options -Multi:$Multi -Checked $Checked -Start $Start }
}

$interactive = ($PSBoundParameters.Count -eq 0) -and [Environment]::UserInteractive -and (-not $WhatIfPreference)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$rawUrl = "https://raw.githubusercontent.com/$Repo/$Branch/bootstrap.ps1"

if ($interactive) {
    $appsUrl = "https://raw.githubusercontent.com/$Repo/$Branch/config/apps.json"
    try {
        $appsData = Invoke-RestMethod -Uri $appsUrl
    } catch {
        Write-Error "Could not download the app list from: $appsUrl. $_"
        $global:LASTEXITCODE = 1; if ($isIex) { return } else { exit 1 }
    }
    # Each round installs in its own child process, so the menu can come back afterwards.
    $worstExit = 0
    while ($true) {
        $choices = Invoke-InteractiveSetup -AppsData $appsData
        if ($null -eq $choices) { Write-Host "Cancelled." -ForegroundColor Yellow; break }
        $roundParams = [ordered]@{ Category = $choices.Category; Repo = $Repo; Branch = $Branch }
        if ($choices.GitUserName) { $roundParams.GitUserName = $choices.GitUserName }
        if ($choices.GitUserEmail) { $roundParams.GitUserEmail = $choices.GitUserEmail }
        if ($choices.Apps.Count) { $roundParams.Apps = $choices.Apps }
        $roundSwitches = @(@('SkipGit', 'SkipVSCode', 'SkipOpenCode', 'SkipBrave') | Where-Object { $choices[$_] })
        $roundExit = Invoke-InstallRound -Params $roundParams -Switches $roundSwitches -IsAdmin $isAdmin -ScriptPath $PSCommandPath -RawUrl $rawUrl -LogDir $LogArchiveDir
        if ($roundExit -ne 0) { $worstExit = 1 }
        $next = Invoke-Menu -Title "Installation finished (exit code $roundExit). What next?" -Options @('Install something else', 'Exit')
        if ($next -isnot [int] -or $next -ne 0) { break }
    }
    $global:LASTEXITCODE = $worstExit; if ($isIex) { return } else { exit $worstExit }
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
if (-not $isAdmin) {
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
    $elevExit = Invoke-InstallRound -Params $elevParams -Switches $elevSwitches -IsAdmin $false -ScriptPath $PSCommandPath -RawUrl $rawUrl -LogDir $LogArchiveDir
    $global:LASTEXITCODE = $elevExit; if ($isIex) { return } else { exit $elevExit }
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
        # Config blocks follow the selected apps (same rule as the menu); read before filtering.
        $configScope = Get-ConfigScope -Category $Category -Apps $Apps -AppsData $cfg
        $kept = 0
        foreach ($prop in @('Base', 'Dev', 'Gaming')) {
            $cfg.$prop = @($cfg.$prop | Where-Object { $Apps -contains $_ })
            $kept += $cfg.$prop.Count
        }
        if ($kept -eq 0) {
            Write-Warning "None of the selected apps exist in apps.json ($($Apps -join ', ')). Keeping the full list."
        } else {
            if (-not $configScope.Git) { $SkipGit = $true }
            if (-not $configScope.VSCode) { $SkipVSCode = $true }
            if (-not $configScope.OpenCode) { $SkipOpenCode = $true }
            if (-not $configScope.Brave) { $SkipBrave = $true }
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
