# Runner-Mock.ps1 - Dependency-free general test harness (no Pester 5 required).
# Fully mocked: installs nothing, touches no real git/vscode/winget state.
# Usage: pwsh -NoProfile -File tests/Runner-Mock.ps1
# Only creates temp logs under $env:TEMP plus one controlled real-log check (cleaned up).

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModulesDir = Join-Path $RepoRoot 'modules'
$AppsConfigPath = Join-Path $RepoRoot 'config/apps.json'
$ExtConfigPath = Join-Path $RepoRoot 'config/vscode/extensions.json'

$script:Total = 0
$script:Passed = 0
$script:Failed = 0
$script:Failures = @()
$script:CapturedLogs = @()

function Test-Assert {
    param([bool]$Condition, [string]$Name, [string]$Detail = '')
    $script:Total++
    if ($Condition) {
        $script:Passed++
        Write-Output "PASS: $Name"
    } else {
        $script:Failed++
        $script:Failures += $Name
        Write-Output "FAIL: $Name $Detail"
    }
}

function Reset-Capture {
    $script:CapturedLogs = @()
}

# Import real modules (dot-source)
. (Join-Path $ModulesDir 'Common.ps1')
. (Join-Path $ModulesDir 'Install-Category.ps1')
. (Join-Path $ModulesDir 'Config-Git.ps1')
. (Join-Path $ModulesDir 'Config-VSCode.ps1')

Write-Output '=== MOCKED GENERAL TEST - Instalador ==='
Write-Output "Repo: $RepoRoot"
Write-Output "pwsh: $($PSVersionTable.PSVersion) PSEdition=$($PSVersionTable.PSEdition)"
Write-Output ''

# ---------------------------------------------------------------------------
# BLOCK 1: Syntax + JSON (static checks re-run inside the harness)
# ---------------------------------------------------------------------------
Write-Output '--- Block 1: Static ---'
foreach ($f in @('install.ps1','modules/Common.ps1','modules/Install-Category.ps1','modules/Config-Git.ps1','modules/Config-VSCode.ps1')) {
    $full = Join-Path $RepoRoot $f
    $errs = $null; $toks = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$toks, [ref]$errs)
    Test-Assert ($errs.Count -eq 0) "Syntax OK: $f" "Errors: $($errs.Count)"
}
try {
    $apps = Get-Content $AppsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Test-Assert ($null -ne $apps.Base -and $null -ne $apps.Dev -and $null -ne $apps.Gaming) 'apps.json has Base/Dev/Gaming'
    $all = @($apps.Base) + @($apps.Dev) + @($apps.Gaming)
    Test-Assert ($all.Count -eq 14) "apps.json total=14 (actual=$($all.Count))"
    Test-Assert ((($all | Sort-Object -Unique).Count) -eq $all.Count) 'apps.json has no duplicates'
} catch {
    Test-Assert $false 'apps.json is valid' "$_"
}
try {
    $ext = Get-Content $ExtConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Test-Assert ($ext.extensions.Count -eq 10) "extensions.json total=10 (actual=$($ext.extensions.Count))"
    Test-Assert ((($ext.extensions | Sort-Object -Unique).Count) -eq $ext.extensions.Count) 'extensions.json has no duplicates'
    Test-Assert ($ext.extensions -contains 'ms-python.vscode-python-envs') 'extensions.json uses new vscode-python-envs ID'
    Test-Assert (-not ($ext.extensions -contains 'ms-python.python-envs')) 'extensions.json without obsolete python-envs ID'
} catch {
    Test-Assert $false 'extensions.json is valid' "$_"
}

# ---------------------------------------------------------------------------
# BLOCK 2: Common.ps1 - Write-InstallLog writes to a single file (controlled TEMP test)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Block 2: Common.ps1 ---'
# Redirect the log to TEMP by mocking Initialize-InstallLog for this block only
$origInit = Get-Command Initialize-InstallLog -CommandType Function
$tempLog = Join-Path ([System.IO.Path]::GetTempPath()) ("instalador-test-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
function Initialize-InstallLog { return $script:tempLogPath }
$script:tempLogPath = $tempLog
Write-InstallLog -Message 'line-test-1' -Level 'INFO'
Write-InstallLog -Message 'line-test-2' -Level 'WARNING' 3>$null
$logContent = Get-Content $tempLog -Raw -ErrorAction SilentlyContinue
Test-Assert ($logContent -match 'line-test-1' -and $logContent -match 'line-test-2') 'Write-InstallLog appends 2 lines to the same file'
Remove-Item $tempLog -Force -ErrorAction SilentlyContinue
# Restore the original function by re-importing
. (Join-Path $ModulesDir 'Common.ps1')
. (Join-Path $ModulesDir 'Install-Category.ps1')
. (Join-Path $ModulesDir 'Config-Git.ps1')
. (Join-Path $ModulesDir 'Config-VSCode.ps1')

# Error flag: ERROR sets InstallHadErrors, INFO does not (real log under logs/, cleaned up)
$global:InstallHadErrors = $false
Write-InstallLog -Message 'test-flag-error' -Level 'ERROR' 2>$null
Test-Assert ($global:InstallHadErrors -eq $true) 'Write-InstallLog ERROR sets InstallHadErrors'
$global:InstallHadErrors = $false
Write-InstallLog -Message 'test-flag-info' -Level 'INFO' -Verbose 4>$null
Test-Assert ($global:InstallHadErrors -eq $false) 'Write-InstallLog INFO does not set errors'
Get-ChildItem (Join-Path $RepoRoot 'logs') -Filter 'install-*.log' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$global:InstallHadErrors = $false

# ---------------------------------------------------------------------------
# BLOCK 3: Test-AppInstalled + Install-WingetApp with mocked winget
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Block 3: mocked winget ---'
# Mock winget: $MockInstalledIds and $MockInstallExit control it
$global:MockInstalledIds = @('Brave.Brave')
$global:MockInstallExit = 0
$global:MockInstallCalls = @()
function winget {
    param()
    $argStr = ($args -join ' ')
    if ($argStr -match '^\s*list\b') {
        $global:LASTEXITCODE = 0
        foreach ($id in $global:MockInstalledIds) { Write-Output "$id  1.0  winget" }
        return
    }
    if ($argStr -match '^\s*install\b') {
        $global:MockInstallCalls += $argStr
        $global:LASTEXITCODE = $global:MockInstallExit
        return
    }
    $global:LASTEXITCODE = 0
}
# Capture logs in memory to avoid disk writes: override Write-InstallLog
function Write-InstallLog {
    param([string]$Message, [string]$Level = 'INFO')
    $script:CapturedLogs += "[$Level] $Message"
    if ($Level -eq 'ERROR') { Write-Error $Message -ErrorAction SilentlyContinue }
}

Reset-Capture
$r1 = Test-AppInstalled -AppId 'Brave.Brave'
Test-Assert ($r1 -eq $true) 'Test-AppInstalled true when winget list contains it'
$r2 = Test-AppInstalled -AppId 'No.Existe'
Test-Assert ($r2 -eq $false) 'Test-AppInstalled false when missing'

# Idempotency: already installed => no install call
Reset-Capture; $global:MockInstallCalls = @()
Install-WingetApp -AppId 'Brave.Brave' -AppName 'Brave'
Test-Assert ($global:MockInstallCalls.Count -eq 0) 'Install-WingetApp skips when already installed'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Skipping') 'Log says Skipping when already installed'

# Not installed + WhatIf => no real install call, only simulation log
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @()
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam' -WhatIf
Test-Assert ($global:MockInstallCalls.Count -eq 0) 'WhatIf never runs winget install'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Simulation') 'WhatIf logs simulation'

# Not installed, no WhatIf, exit 0 but still missing afterwards => post-verification ERROR
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @(); $global:MockInstallExit = 0
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam'
Test-Assert ($global:MockInstallCalls.Count -eq 1) 'Without WhatIf it calls winget install once'
Test-Assert (($script:CapturedLogs -join "`n") -match "missing from 'winget list'") 'Post-check logs ERROR when missing from list'

# winget returning non-zero => ERROR
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @(); $global:MockInstallExit = 1
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam'
Test-Assert (($script:CapturedLogs -join "`n") -match 'returned code 1') 'Logs winget exit code on failure'

# Regex escaping: dotted AppIds must not partially match
$global:MockInstalledIds = @('BraveXBrave'); $global:MockInstallExit = 0
$r3 = Test-AppInstalled -AppId 'Brave.Brave'
Test-Assert ($r3 -eq $false) 'Test-AppInstalled has no partial match (BraveXBrave != Brave.Brave)'

Remove-Item function:\winget -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# BLOCK 4: Install-Category with captured Write-InstallLog + spied Install-WingetApp
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Block 4: Install-Category ---'
$global:SpyInstalled = @()
function Install-WingetApp {
    param([string]$AppId, [string]$AppName)
    $global:SpyInstalled += $AppId
}
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $AppsConfigPath
Test-Assert ($global:SpyInstalled.Count -eq 4) "Category Base installs 4 (actual=$($global:SpyInstalled.Count))"
Test-Assert ($global:SpyInstalled -contains 'Brave.Brave') 'Base contains Brave.Brave'

$global:SpyInstalled = @()
Invoke-InstallCategory -Category 'All' -AppsConfigPath $AppsConfigPath
Test-Assert ($global:SpyInstalled.Count -eq 14) "Category All expands to 14 (actual=$($global:SpyInstalled.Count))"

# Missing file => ERROR and clean return
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath (Join-Path $RepoRoot 'config/noexiste.json')
Test-Assert (($script:CapturedLogs -join "`n") -match 'not found') 'Category with missing file logs ERROR'

# Invalid JSON => ERROR
$badJson = Join-Path ([System.IO.Path]::GetTempPath()) 'bad-apps.json'
'{ invalid' | Set-Content $badJson -Encoding UTF8
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $badJson
Test-Assert (($script:CapturedLogs -join "`n") -match 'not valid JSON') 'Category with invalid JSON logs ERROR'
Remove-Item $badJson -Force -ErrorAction SilentlyContinue

# Empty category => WARNING
$emptyJson = Join-Path ([System.IO.Path]::GetTempPath()) 'empty-apps.json'
'{ "Base": [], "Dev": [], "Gaming": [] }' | Set-Content $emptyJson -Encoding UTF8
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $emptyJson
Test-Assert (($script:CapturedLogs -join "`n") -match 'has no applications') 'Empty category logs WARNING'
Remove-Item $emptyJson -Force -ErrorAction SilentlyContinue

# AppName extraction: last segment after the dot
Test-Assert (('Microsoft.VisualStudioCode'.Split('.')[-1]) -eq 'VisualStudioCode') 'AppName = last segment after dot'
# Restore real modules
. (Join-Path $ModulesDir 'Common.ps1')
. (Join-Path $ModulesDir 'Install-Category.ps1')
. (Join-Path $ModulesDir 'Config-Git.ps1')
. (Join-Path $ModulesDir 'Config-VSCode.ps1')
function Write-InstallLog {
    param([string]$Message, [string]$Level = 'INFO')
    $script:CapturedLogs += "[$Level] $Message"
    if ($Level -eq 'ERROR') { Write-Error $Message -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# BLOCK 5: mocked Config-Git
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Block 5: Config-Git ---'
$global:MockGitCalls = @(); $global:MockGitExit = 0
function git {
    param()
    $global:MockGitCalls += ($args -join ' ')
    $global:LASTEXITCODE = $global:MockGitExit
}
Reset-Capture
Invoke-GitConfig -UserName 'Test User' -UserEmail 'test@example.com'
Test-Assert ($global:MockGitCalls.Count -ge 4) "Git config applies >=4 calls (actual=$($global:MockGitCalls.Count))"
Test-Assert (($global:MockGitCalls -join "`n") -match 'user.name') 'Git config sets user.name'
Test-Assert (($global:MockGitCalls -join "`n") -match 'init.defaultBranch') 'Git config sets defaultBranch main'

Reset-Capture; $global:MockGitCalls = @()
Invoke-GitConfig -UserName 'Test' -UserEmail 'not-an-email'
Test-Assert ($global:MockGitCalls.Count -eq 0) 'Invalid email never runs git'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Invalid email format') 'Invalid email logs WARNING'

Reset-Capture; $global:MockGitCalls = @()
# With params it must not prompt: mock Read-Host first so it cannot block
function Read-Host { param($Prompt) return 'mocked' }
Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com' -WhatIf
Test-Assert ($global:MockGitCalls.Count -eq 0) 'WhatIf never runs real git'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Simulation') 'Git WhatIf logs simulation'
Remove-Item function:\Read-Host -ErrorAction SilentlyContinue

# WhatIf WITHOUT params must not block on Read-Host (no-interactive fix)
Reset-Capture; $global:MockGitCalls = @()
function Read-Host { param($Prompt) throw 'Read-Host must not be called in WhatIf without data' }
try {
    Invoke-GitConfig -WhatIf
    Test-Assert ($global:MockGitCalls.Count -eq 0) 'Git WhatIf without params never runs git'
    Test-Assert (($script:CapturedLogs -join "`n") -match 'no interactive input') 'Git WhatIf without params logs and never blocks'
} catch {
    Test-Assert $false 'Git WhatIf without params never blocks' "$_"
}
Remove-Item function:\Read-Host -ErrorAction SilentlyContinue

# Missing git on PATH => WARNING (mock Get-Command, never touch real git)
Reset-Capture
$global:MockGitCalls = @()
function Get-Command {
    param([Parameter(Position=0)]$Name, [Parameter(ValueFromRemainingArguments=$true)]$Rest)
    if ($Name -eq 'git') { return $null }
    Microsoft.PowerShell.Core\Get-Command -Name $Name @Rest -ErrorAction SilentlyContinue
}
Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com'
Test-Assert (($script:CapturedLogs -join "`n") -match 'not installed or not on this session') 'Missing git logs WARNING and skips'
Test-Assert ($global:MockGitCalls.Count -eq 0) 'Missing git never runs git'
Remove-Item function:\Get-Command -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# BLOCK 6: mocked Config-VSCode
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Block 6: Config-VSCode ---'
$global:MockCodeCalls = @(); $global:MockCodeList = @('ecmel.vscode-html-css'); $global:MockCodeExit = 0
function code {
    param()
    $a = ($args -join ' ')
    if ($a -match 'list-extensions') { $global:LASTEXITCODE = 0; foreach ($e in $global:MockCodeList) { Write-Output $e }; return }
    $global:MockCodeCalls += $a; $global:LASTEXITCODE = $global:MockCodeExit
}
Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath
Test-Assert ($global:MockCodeCalls.Count -ge 1) "VSCode installs missing ones (calls=$($global:MockCodeCalls.Count))"
Test-Assert (($script:CapturedLogs -join "`n") -match 'already installed') 'VSCode detects already installed (idempotent)'

# WhatIf installs nothing
$global:MockCodeCalls = @(); Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath -WhatIf
Test-Assert ($global:MockCodeCalls.Count -eq 0) 'VSCode WhatIf never runs code --install-extension'

# Missing file => ERROR
Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath (Join-Path $RepoRoot 'config/vscode/noexiste.json')
Test-Assert (($script:CapturedLogs -join "`n") -match 'not found') 'VSCode missing file logs ERROR'

# Missing code on PATH (mock Get-Command, never touch real code)
$global:MockCodeCalls = @()
Reset-Capture
function Get-Command {
    param([Parameter(Position=0)]$Name, [Parameter(ValueFromRemainingArguments=$true)]$Rest)
    if ($Name -eq 'code') { return $null }
    Microsoft.PowerShell.Core\Get-Command -Name $Name @Rest -ErrorAction SilentlyContinue
}
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath
Test-Assert (($script:CapturedLogs -join "`n") -match 'not available on this session') 'Missing code logs WARNING and skips'
Test-Assert ($global:MockCodeCalls.Count -eq 0) 'Missing code never runs code'
Remove-Item function:\Get-Command -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# BLOCK 7: install.ps1 entry guards (static analysis + replicated logic, never runs the entry)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Block 7: Entry guards ---'
$entry = Get-Content (Join-Path $RepoRoot 'install.ps1') -Raw
Test-Assert ($entry -match 'IsInRole.*Administrator') 'install.ps1 checks Administrator'
Test-Assert ($entry -match 'BuildNumber|Build.*22000') 'install.ps1 checks Build >=22000'
Test-Assert ($entry -match 'Is64BitOperatingSystem') 'install.ps1 checks 64-bit OS'
Test-Assert ($entry -match "Get-Command.*winget") 'install.ps1 checks winget'
Test-Assert ($entry -match 'SupportsShouldProcess') 'install.ps1 supports -WhatIf'
Test-Assert ($entry -match "ValidateSet.*Base.*Dev.*Gaming.*All") 'install.ps1 ValidateSet Category'
Test-Assert ($entry -match 'Update-SessionPath') 'install.ps1 refreshes PATH after install'
Test-Assert ($entry -match "Category.*Dev.*or.*All") 'Git/VSCode only on Dev or All'
Test-Assert ($entry -match 'GitUserName' -and $entry -match 'GitUserEmail') 'install.ps1 accepts GitUserName/GitUserEmail'
Test-Assert ($entry -match 'Invoke-GitConfig -UserName') 'install.ps1 passes params to Invoke-GitConfig'
Test-Assert ($entry -match 'InstallHadErrors') 'install.ps1 propagates errors with exit code'

# Replicated Win11 logic with real values (read-only)
$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber; $arch = [string]$os.OSArchitecture; $is64 = [Environment]::Is64BitOperatingSystem
Test-Assert ($build -ge 22000) "Real Build $build >=22000 (Win11)"
Test-Assert (($arch -match '64') -and $is64) "Real architecture '$arch' is 64-bit"
$isAdminNow = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Test-Assert ($isAdminNow -eq $false) 'Current session is NOT Admin (real dry-run aborts by design)'
Test-Assert ($null -ne (Get-Command winget -ErrorAction SilentlyContinue)) 'winget available in this session'

# Update-SessionPath: real merge keeps process-only entries
$oldPath = $env:Path
try {
    $m = [Environment]::GetEnvironmentVariable('Path','Machine'); $u = [Environment]::GetEnvironmentVariable('Path','User')
    Test-Assert (($null -ne $m) -or ($null -ne $u)) 'Machine/User PATH readable for Update-SessionPath'
    $sentinel = 'C:\TestUnicoPATH12345'
    $env:Path = "$sentinel;$oldPath"
    $fnText = Get-Content (Join-Path $RepoRoot 'install.ps1') -Raw
    if ($fnText -match '(?s)function Update-SessionPath\s*\{(.*?)\n\}') {
        $fnBody = $Matches[1]
        $sb = [scriptblock]::Create("try { $fnBody } catch { Write-Warning `$_ }")
        & $sb
        Test-Assert ($env:Path -match 'TestUnicoPATH12345') 'Update-SessionPath keeps process entries'
        $parts = $env:Path -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $uniqueCount = ($parts | Sort-Object -Unique -CaseSensitive:$false).Count
        Test-Assert ($parts.Count -eq $uniqueCount) 'Update-SessionPath has no duplicates'
    } else {
        Test-Assert $false 'Update-SessionPath extractable from install.ps1' ''
    }
} catch {
    Test-Assert $false 'Update-SessionPath merge' "$_"
} finally {
    $env:Path = $oldPath
}

# No personal data in source code (test fixtures are neutral)
$srcFiles = @((Join-Path $RepoRoot 'install.ps1')) + (Get-ChildItem (Join-Path $RepoRoot 'modules') -Filter '*.ps1' | Select-Object -ExpandProperty FullName) + (Get-ChildItem (Join-Path $RepoRoot 'config') -Recurse -File | Select-Object -ExpandProperty FullName)
$srcText = ($srcFiles | ForEach-Object { Get-Content $_ -Raw -ErrorAction SilentlyContinue }) -join "`n"
Test-Assert ($srcText -notmatch 'alexp11mon|alexponmon|a@b\.com') 'Source code has no personal data'
Test-Assert ($srcText -notmatch 'Invoke-GitConfig -UserName "\.\.\."') 'No literal placeholders in Git call'

# ---------------------------------------------------------------------------
# BLOCK 8: bootstrap.ps1 online installer (static analysis + mocked WhatIf, no network)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Block 8: bootstrap.ps1 ---'
$bootPath = Join-Path $RepoRoot 'bootstrap.ps1'
Test-Assert (Test-Path $bootPath) 'bootstrap.ps1 exists'
$bootErrs = $null; $bootToks = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($bootPath, [ref]$bootToks, [ref]$bootErrs)
Test-Assert ($bootErrs.Count -eq 0) 'bootstrap.ps1 syntax OK'
$boot = Get-Content $bootPath -Raw
Test-Assert ($boot -match 'Major -lt 7') 'bootstrap.ps1 requires PowerShell 7'
Test-Assert ($boot -match 'archive/refs/heads/' -and $boot -match '\$Branch') 'bootstrap.ps1 builds ZIP URL from Branch'
Test-Assert ($boot -match 'Verb RunAs') 'bootstrap.ps1 auto-elevates with UAC'
Test-Assert ($boot -match "ValidateSet.*Base.*Dev.*Gaming.*All") 'bootstrap.ps1 validates Category'
Test-Assert ($boot -match '-GitUserName' -and $boot -match '-GitUserEmail') 'bootstrap.ps1 passes Git params'
Test-Assert ($boot -match 'KeepDownload') 'bootstrap.ps1 supports KeepDownload'
$whatIfPos = $boot.IndexOf('$WhatIfPreference')
$netPos = $boot.IndexOf('Invoke-WebRequest -Uri')
Test-Assert ($whatIfPos -ge 0 -and $netPos -gt $whatIfPos) 'bootstrap.ps1 WhatIf exits before any download'

Write-Output ''
Write-Output '=== SUMMARY ==='
Write-Output "Total: $script:Total Passed: $script:Passed Failed: $script:Failed"
if ($script:Failed -gt 0) {
    Write-Output 'Failures:'
    $script:Failures | ForEach-Object { Write-Output " - $_" }
    exit 1
} else {
    exit 0
}
