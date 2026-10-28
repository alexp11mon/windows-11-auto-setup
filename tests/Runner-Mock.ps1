# Runner-Mock.ps1 - Harness de test general SIN dependencias (no requiere Pester 5).
# Todo mockeado: no instala nada, no modifica git/vscode/winget reales.
# Uso: pwsh -NoProfile -File tests/Runner-Mock.ps1
# Genera solo logs temporales en $env:TEMP, no toca logs/ reales salvo 1 prueba controlada.

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

# Importar modulos reales (dot-source)
. (Join-Path $ModulesDir 'Common.ps1')
. (Join-Path $ModulesDir 'Install-Category.ps1')
. (Join-Path $ModulesDir 'Config-Git.ps1')
. (Join-Path $ModulesDir 'Config-VSCode.ps1')
. (Join-Path $ModulesDir 'Config-OpenCode.ps1')
. (Join-Path $ModulesDir 'Config-Brave.ps1')

Write-Output '=== TEST GENERAL MOCKEADO - Instalador ==='
Write-Output "Repo: $RepoRoot"
Write-Output "pwsh: $($PSVersionTable.PSVersion) PSEdition=$($PSVersionTable.PSEdition)"
Write-Output ''

# ---------------------------------------------------------------------------
# BLOQUE 1: Sintaxis + JSON (checks estaticos re-ejecutados en harness)
# ---------------------------------------------------------------------------
Write-Output '--- Bloque 1: Estatico ---'
foreach ($f in @('install.ps1','modules/Common.ps1','modules/Install-Category.ps1','modules/Config-Git.ps1','modules/Config-VSCode.ps1','modules/Config-OpenCode.ps1','modules/Config-Brave.ps1')) {
    $full = Join-Path $RepoRoot $f
    $errs = $null; $toks = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$toks, [ref]$errs)
    Test-Assert ($errs.Count -eq 0) "Sintaxis OK: $f" "Errores: $($errs.Count)"
}
try {
    $apps = Get-Content $AppsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Test-Assert ($null -ne $apps.Base -and $null -ne $apps.Dev -and $null -ne $apps.Gaming) 'apps.json tiene Base/Dev/Gaming'
    $all = @($apps.Base) + @($apps.Dev) + @($apps.Gaming)
    Test-Assert ($all.Count -eq 16) "apps.json total=16 (real=$($all.Count))"
    Test-Assert ((($all | Sort-Object -Unique).Count) -eq $all.Count) 'apps.json sin duplicados'
} catch {
    Test-Assert $false 'apps.json valido' "$_"
}
try {
    $ext = Get-Content $ExtConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Test-Assert ($ext.extensions.Count -eq 10) "extensions.json total=10 (real=$($ext.extensions.Count))"
    Test-Assert ((($ext.extensions | Sort-Object -Unique).Count) -eq $ext.extensions.Count) 'extensions.json sin duplicadas'
    Test-Assert ($ext.extensions -contains 'ms-python.vscode-python-envs') 'extensions.json usa ID nuevo vscode-python-envs'
    Test-Assert (-not ($ext.extensions -contains 'ms-python.python-envs')) 'extensions.json sin ID obsoleto python-envs'
} catch {
    Test-Assert $false 'extensions.json valido' "$_"
}

# ---------------------------------------------------------------------------
# BLOQUE 2: Common.ps1 - Write-InstallLog escribe al mismo archivo (prueba real controlada en TEMP)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 2: Common.ps1 ---'
# Redirigir log a TEMP mockeando Initialize-InstallLog solo para este bloque
$origInit = Get-Command Initialize-InstallLog -CommandType Function
$tempLog = Join-Path ([System.IO.Path]::GetTempPath()) ("instalador-test-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
function Initialize-InstallLog { return $script:tempLogPath }
$script:tempLogPath = $tempLog
Write-InstallLog -Message 'linea-test-1' -Level 'INFO'
Write-InstallLog -Message 'linea-test-2' -Level 'WARNING' 3>$null
$logContent = Get-Content $tempLog -Raw -ErrorAction SilentlyContinue
Test-Assert ($logContent -match 'linea-test-1' -and $logContent -match 'linea-test-2') 'Write-InstallLog escribe 2 lineas al mismo archivo'
Remove-Item $tempLog -Force -ErrorAction SilentlyContinue

# En -WhatIf el log se escribe igual (plan 001: en simulacion solo loguea); si se escribe, no hay aviso "What if"
& {
    $WhatIfPreference = $true
    Write-InstallLog -Message 'linea-whatif' -Level 'INFO'
}
$whatIfLog = Get-Content $tempLog -Raw -ErrorAction SilentlyContinue
Test-Assert ($whatIfLog -match 'linea-whatif') 'Write-InstallLog escribe el log tambien en -WhatIf'
Remove-Item $tempLog -Force -ErrorAction SilentlyContinue
# Restaurar funcion original re-importando
. (Join-Path $ModulesDir 'Common.ps1')
. (Join-Path $ModulesDir 'Install-Category.ps1')
. (Join-Path $ModulesDir 'Config-Git.ps1')
. (Join-Path $ModulesDir 'Config-VSCode.ps1')
. (Join-Path $ModulesDir 'Config-OpenCode.ps1')
. (Join-Path $ModulesDir 'Config-Brave.ps1')

# Flag de errores: ERROR marca InstallHadErrors, INFO no (log real en logs/, se limpia)
$global:InstallHadErrors = $false
Write-InstallLog -Message 'test-flag-error' -Level 'ERROR' 2>$null
Test-Assert ($global:InstallHadErrors -eq $true) 'Write-InstallLog ERROR marca InstallHadErrors'
$global:InstallHadErrors = $false
Write-InstallLog -Message 'test-flag-info' -Level 'INFO' -Verbose 4>$null
Test-Assert ($global:InstallHadErrors -eq $false) 'Write-InstallLog INFO no marca errores'
Get-ChildItem (Join-Path $RepoRoot 'logs') -Filter 'install-*.log' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$global:InstallHadErrors = $false

# ---------------------------------------------------------------------------
# BLOQUE 3: Test-AppInstalled + Install-WingetApp con winget mockeado
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 3: winget mockeado ---'
# Mock winget: controla $MockInstalledIds y $MockInstallExit
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
        if ($global:MockInstallAddsId) { $global:MockInstalledIds += $global:MockInstallAddsId }
        $global:LASTEXITCODE = $global:MockInstallExit
        return
    }
    $global:LASTEXITCODE = 0
}
# Capturar logs en memoria para no tocar disco: override Write-InstallLog
function Write-InstallLog {
    param([string]$Message, [string]$Level = 'INFO')
    $script:CapturedLogs += "[$Level] $Message"
    if ($Level -eq 'ERROR') { Write-Error $Message -ErrorAction SilentlyContinue }
}

Reset-Capture
$r1 = Test-AppInstalled -AppId 'Brave.Brave'
Test-Assert ($r1 -eq $true) 'Test-AppInstalled true si winget list lo contiene'
$r2 = Test-AppInstalled -AppId 'No.Existe'
Test-Assert ($r2 -eq $false) 'Test-AppInstalled false si no esta'

# Idempotencia: ya instalado => no llama a install
Reset-Capture; $global:MockInstallCalls = @()
Install-WingetApp -AppId 'Brave.Brave' -AppName 'Brave'
Test-Assert ($global:MockInstallCalls.Count -eq 0) 'Install-WingetApp omite si ya instalado'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Skipping') 'Log dice Omitiendo cuando ya instalado'

# No instalado + WhatIf => no llama a install real, solo log simulacion
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @()
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam' -WhatIf
Test-Assert ($global:MockInstallCalls.Count -eq 0) 'WhatIf no ejecuta winget install'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Simulation') 'WhatIf loguea simulacion'

# No instalado, sin WhatIf, exit 0 pero sigue sin aparecer => ERROR post-verificacion
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @(); $global:MockInstallExit = 0
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam'
Test-Assert ($global:MockInstallCalls.Count -eq 1) 'Sin WhatIf llama 1 vez a winget install'
Test-Assert (($script:CapturedLogs -join "`n") -match 'not listed') 'Post-verificacion ERROR si no aparece en list'

# winget devuelve codigo !=0 => ERROR
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @(); $global:MockInstallExit = 1
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam'
Test-Assert (($script:CapturedLogs -join "`n") -match 'exit code 1') 'Loguea codigo de salida winget !=0'
Test-Assert (($script:CapturedLogs -join "`n") -match '\[ERROR\]') 'winget !=0 y app ausente => ERROR (RF-36)'

# winget !=0 pero la app queda instalada => WARNING, no ERROR (RF-36)
Reset-Capture; $global:MockInstalledIds = @(); $global:MockInstallExit = -1978335189
$global:MockInstallAddsId = 'Valve.Steam'
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam'
$rf36Logs = $script:CapturedLogs -join "`n"
Test-Assert ($rf36Logs -match '\[WARNING\].*but the app is installed') 'winget !=0 con app instalada => WARNING (RF-36)'
Test-Assert ($rf36Logs -notmatch '\[ERROR\]') 'winget !=0 con app instalada no loguea ERROR (RF-36)'
$global:MockInstallAddsId = $null; $global:MockInstallExit = 0

# Regex escape: AppId con puntos no debe hacer match parcial
$global:MockInstalledIds = @('BraveXBrave'); $global:MockInstallExit = 0
$r3 = Test-AppInstalled -AppId 'Brave.Brave'
Test-Assert ($r3 -eq $false) 'Test-AppInstalled no hace match parcial sin escapar puntos (BraveXBrave != Brave.Brave)'

Remove-Item function:\winget -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# BLOQUE 4: Install-Category con Write-InstallLog capturado + Install-WingetApp espiado
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 4: Install-Category ---'
$global:SpyInstalled = @()
function Install-WingetApp {
    param([string]$AppId, [string]$AppName)
    $global:SpyInstalled += $AppId
}
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $AppsConfigPath
Test-Assert ($global:SpyInstalled.Count -eq 6) "Category Base instala 6 (real=$($global:SpyInstalled.Count))"
Test-Assert ($global:SpyInstalled -contains 'Brave.Brave') 'Base contiene Brave.Brave'
Test-Assert ($global:SpyInstalled -contains 'Obsidian.Obsidian') 'Base contiene Obsidian.Obsidian'
Test-Assert ($global:SpyInstalled -contains 'Spotify.Spotify') 'Base contiene Spotify.Spotify'

$global:SpyInstalled = @()
Invoke-InstallCategory -Category 'Gaming' -AppsConfigPath $AppsConfigPath
Test-Assert ($global:SpyInstalled.Count -eq 4) "Category Gaming instala 4 (real=$($global:SpyInstalled.Count))"
Test-Assert ($global:SpyInstalled -contains 'Discord.Discord') 'Gaming contiene Discord.Discord'

$global:SpyInstalled = @()
Invoke-InstallCategory -Category 'All' -AppsConfigPath $AppsConfigPath
Test-Assert ($global:SpyInstalled.Count -eq 16) "Category All expande a 16 (real=$($global:SpyInstalled.Count))"

# Fichero inexistente => ERROR y return sin excepcion
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath (Join-Path $RepoRoot 'config/noexiste.json')
Test-Assert (($script:CapturedLogs -join "`n") -match 'not found') 'Categoria con fichero inexistente loguea ERROR'

# JSON invalido => ERROR
$badJson = Join-Path ([System.IO.Path]::GetTempPath()) 'bad-apps.json'
'{ invalido' | Set-Content $badJson -Encoding UTF8
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $badJson
Test-Assert (($script:CapturedLogs -join "`n") -match 'valid JSON') 'Categoria con JSON invalido loguea ERROR'
Remove-Item $badJson -Force -ErrorAction SilentlyContinue

# Categoria vacia => WARNING
$emptyJson = Join-Path ([System.IO.Path]::GetTempPath()) 'empty-apps.json'
'{ "Base": [], "Dev": [], "Gaming": [] }' | Set-Content $emptyJson -Encoding UTF8
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $emptyJson
Test-Assert (($script:CapturedLogs -join "`n") -match 'no applications') 'Categoria vacia loguea WARNING'
Remove-Item $emptyJson -Force -ErrorAction SilentlyContinue

# AppName extraccion: ultimo segmento tras punto
Test-Assert (('Microsoft.VisualStudioCode'.Split('.')[-1]) -eq 'VisualStudioCode') 'AppName = ultimo segmento tras punto'
# Restaurar modulos reales
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
# BLOQUE 5: Config-Git mockeado
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 5: Config-Git ---'
$global:MockGitCalls = @(); $global:MockGitExit = 0
function git {
    param()
    $global:MockGitCalls += ($args -join ' ')
    $global:LASTEXITCODE = $global:MockGitExit
}
Reset-Capture
Invoke-GitConfig -UserName 'Test User' -UserEmail 'test@example.com'
Test-Assert ($global:MockGitCalls.Count -ge 4) "Git config aplica >=4 llamadas (real=$($global:MockGitCalls.Count))"
Test-Assert (($global:MockGitCalls -join "`n") -match 'user.name') 'Git config user.name'
Test-Assert (($global:MockGitCalls -join "`n") -match 'init.defaultBranch') 'Git config defaultBranch main'

# Fallo solo en init.defaultBranch => ERROR que lo nombra y no sigue (RF-39)
Reset-Capture; $global:MockGitCalls = @()
function git {
    param()
    $global:MockGitCalls += ($args -join ' ')
    $global:LASTEXITCODE = if (($args -join ' ') -match 'init\.defaultBranch') { 5 } else { 0 }
}
Invoke-GitConfig -UserName 'Test User' -UserEmail 'test@example.com'
Test-Assert (($script:CapturedLogs -join "`n") -match '\[ERROR\].*init\.defaultBranch') 'Fallo en defaultBranch loguea ERROR con su nombre (RF-39)'
Test-Assert (($global:MockGitCalls -join "`n") -notmatch 'alias\.tree') 'Tras fallo en defaultBranch no aplica alias (RF-39)'
function git {
    param()
    $global:MockGitCalls += ($args -join ' ')
    $global:LASTEXITCODE = $global:MockGitExit
}

Reset-Capture; $global:MockGitCalls = @()
Invoke-GitConfig -UserName 'Test' -UserEmail 'no-es-email'
Test-Assert ($global:MockGitCalls.Count -eq 0) 'Email invalido no ejecuta git'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Invalid email') 'Email invalido loguea WARNING'

Reset-Capture; $global:MockGitCalls = @()
# En WhatIf con params no debe llamar a git real
function Read-Host { param($Prompt) return 'mocked' }
Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com' -WhatIf
Test-Assert ($global:MockGitCalls.Count -eq 0) 'WhatIf no ejecuta git real'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Simulation') 'Git WhatIf loguea simulacion'
Remove-Item function:\Read-Host -ErrorAction SilentlyContinue

# Git WhatIf SIN params no debe bloquear pidiendo Read-Host (fix del bloqueo)
Reset-Capture; $global:MockGitCalls = @()
function Read-Host { param($Prompt) throw 'Read-Host no debe llamarse en WhatIf sin datos' }
try {
    Invoke-GitConfig -WhatIf
    Test-Assert ($global:MockGitCalls.Count -eq 0) 'Git WhatIf sin params no ejecuta git'
    Test-Assert (($script:CapturedLogs -join "`n") -match 'no interactive input') 'Git WhatIf sin params loguea sin datos y no bloquea'
} catch {
    Test-Assert $false 'Git WhatIf sin params no bloquea' "$_"
}
Remove-Item function:\Read-Host -ErrorAction SilentlyContinue

# Sin git en PATH => WARNING (simular mockeando Get-Command, SIN tocar git real)
Reset-Capture
$global:MockGitCalls = @()
function Get-Command {
    param([Parameter(Position=0)]$Name, [Parameter(ValueFromRemainingArguments=$true)]$Rest)
    if ($Name -eq 'git') { return $null }
    Microsoft.PowerShell.Core\Get-Command -Name $Name @Rest -ErrorAction SilentlyContinue
}
Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com'
Test-Assert (($script:CapturedLogs -join "`n") -match 'not installed|not on this session') 'Sin git loguea WARNING y omite'
Test-Assert ($global:MockGitCalls.Count -eq 0) 'Sin git no ejecuta git'
Remove-Item function:\Get-Command -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# BLOQUE 6: Config-VSCode mockeado
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 6: Config-VSCode ---'
$global:MockCodeCalls = @(); $global:MockCodeList = @('ecmel.vscode-html-css'); $global:MockCodeExit = 0
function code {
    param()
    $a = ($args -join ' ')
    if ($a -match 'list-extensions') { $global:LASTEXITCODE = 0; foreach ($e in $global:MockCodeList) { Write-Output $e }; return }
    $global:MockCodeCalls += $a; $global:LASTEXITCODE = $global:MockCodeExit
}
Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath
Test-Assert ($global:MockCodeCalls.Count -ge 1) "VSCode instala faltantes (llamadas=$($global:MockCodeCalls.Count))"
Test-Assert (($script:CapturedLogs -join "`n") -match 'already installed') 'VSCode detecta ya instalada (idempotente)'

# WhatIf no instala
$global:MockCodeCalls = @(); Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath -WhatIf
Test-Assert ($global:MockCodeCalls.Count -eq 0) 'VSCode WhatIf no ejecuta code --install-extension'

# Fichero inexistente => ERROR
Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath (Join-Path $RepoRoot 'config/vscode/noexiste.json')
Test-Assert (($script:CapturedLogs -join "`n") -match 'not found') 'VSCode fichero inexistente loguea ERROR'

# Sin code en PATH (mockear Get-Command, SIN tocar code real)
$global:MockCodeCalls = @()
Reset-Capture
function Get-Command {
    param([Parameter(Position=0)]$Name, [Parameter(ValueFromRemainingArguments=$true)]$Rest)
    if ($Name -eq 'code') { return $null }
    Microsoft.PowerShell.Core\Get-Command -Name $Name @Rest -ErrorAction SilentlyContinue
}
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath
Test-Assert (($script:CapturedLogs -join "`n") -match 'not available') 'Sin code loguea WARNING y omite'
Test-Assert ($global:MockCodeCalls.Count -eq 0) 'Sin code no ejecuta code'
Remove-Item function:\Get-Command -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# BLOQUE 7: install.ps1 entry guards (analisis estatico + logica replicada, sin ejecutar entry real)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 7: Entry guards ---'
$entry = Get-Content (Join-Path $RepoRoot 'install.ps1') -Raw
Test-Assert ($entry -match 'IsInRole.*Administrator') 'install.ps1 chequea Administrador'
Test-Assert ($entry -match 'BuildNumber|Build.*22000') 'install.ps1 chequea Build >=22000'
Test-Assert ($entry -match 'Is64BitOperatingSystem') 'install.ps1 chequea 64-bit OS'
Test-Assert ($entry -match "Get-Command.*winget") 'install.ps1 chequea winget'
Test-Assert ($entry -match 'SupportsShouldProcess') 'install.ps1 soporta -WhatIf'
Test-Assert ($entry -match "ValidateSet.*Base.*Dev.*Gaming.*All") 'install.ps1 ValidateSet Category'
Test-Assert ($entry -match 'Update-SessionPath') 'install.ps1 refresca PATH tras instalar'
Test-Assert ($entry -match "Category.*Dev.*or.*All") 'Git/VSCode solo con Dev o All'
Test-Assert ($entry -match 'GitUserName' -and $entry -match 'GitUserEmail') 'install.ps1 acepta GitUserName/GitUserEmail'
Test-Assert ($entry -match 'Invoke-GitConfig -UserName') 'install.ps1 pasa params a Invoke-GitConfig'
Test-Assert ($entry -match '\[switch\]\$SkipGit' -and $entry -match '\[switch\]\$SkipVSCode') 'install.ps1 acepta switches SkipGit/SkipVSCode'
Test-Assert ($entry -match 'skipped via -SkipGit') 'install.ps1 omite Git con SkipGit sin preguntar'
Test-Assert ($entry -match 'skipped via -SkipVSCode') 'install.ps1 omite VSCode con SkipVSCode'
Test-Assert ($entry -match '\[switch\]\$SkipOpenCode' -and $entry -match '\[switch\]\$SkipBrave') 'install.ps1 acepta switches SkipOpenCode/SkipBrave'
Test-Assert ($entry -match 'skipped via -SkipOpenCode') 'install.ps1 omite OpenCode con SkipOpenCode'
Test-Assert ($entry -match 'skipped via -SkipBrave') 'install.ps1 omite Brave con SkipBrave'
Test-Assert ($entry -match 'Invoke-OpenCodeConfig -ConfigSourcePath') 'install.ps1 invoca OpenCode con snapshot'
Test-Assert ($entry -match 'Invoke-BraveConfig -ExtensionsConfigPath') 'install.ps1 invoca Brave con catalogo'
Test-Assert ($entry -match '\$Category -eq ''Base''') 'Brave solo con Base o All'
Test-Assert ($entry -match 'InstallHadErrors') 'install.ps1 propaga errores con exit code'
# Modulo Config-* ausente => ERROR (RF-38). Estatico: el entry real aborta sin Admin antes de llegar ahi.
$missingModuleLines = @([regex]::Matches($entry, 'configuration module not found at:[^\r\n]*') | ForEach-Object { $_.Value })
Test-Assert ($missingModuleLines.Count -eq 4) "install.ps1 tiene 4 avisos de modulo Config-* ausente (real=$($missingModuleLines.Count))"
Test-Assert (@($missingModuleLines | Where-Object { $_ -notmatch '-Level "ERROR"' }).Count -eq 0) 'Modulo Config-* ausente loguea ERROR, no WARNING (RF-38)'

# Logica Win11 replicada con valores reales (solo lectura)
$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber; $arch = [string]$os.OSArchitecture; $is64 = [Environment]::Is64BitOperatingSystem
Test-Assert ($build -ge 22000) "Build real $build >=22000 (Win11)"
Test-Assert (($arch -match '64') -and $is64) "Arquitectura real '$arch' es 64-bit"
$isAdminNow = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Test-Assert ($isAdminNow -eq $false) 'Sesion actual NO es Admin (dry-run real abortaria como esta disenado)'
Test-Assert ($null -ne (Get-Command winget -ErrorAction SilentlyContinue)) 'winget disponible en esta sesion'

# Update-SessionPath: merge real sin perder entradas solo-proceso (fix del fallo 3)
$oldPath = $env:Path
try {
    $m = [Environment]::GetEnvironmentVariable('Path','Machine'); $u = [Environment]::GetEnvironmentVariable('Path','User')
    Test-Assert (($null -ne $m) -or ($null -ne $u)) 'Machine/User PATH legibles para Update-SessionPath'
    $sentinel = 'C:\TestUnicoPATH12345'
    $env:Path = "$sentinel;$oldPath"
    $fnText = Get-Content (Join-Path $RepoRoot 'install.ps1') -Raw
    if ($fnText -match '(?s)function Update-SessionPath\s*\{(.*?)\n\}') {
        $fnBody = $Matches[1]
        $sb = [scriptblock]::Create("try { $fnBody } catch { Write-Warning `$_ }")
        & $sb
        Test-Assert ($env:Path -match 'TestUnicoPATH12345') 'Update-SessionPath conserva entradas del proceso'
        $parts = $env:Path -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $uniqueCount = ($parts | Sort-Object -Unique -CaseSensitive:$false).Count
        Test-Assert ($parts.Count -eq $uniqueCount) 'Update-SessionPath sin duplicados'
        # Duplicados con distinta capitalizacion se quedan una vez y en su orden original (RF-41)
        $env:Path = "C:\RF41First;c:\rf41first;C:\RF41Second;$oldPath"
        & $sb
        $rf41 = @($env:Path -split ';' | Where-Object { $_ -match 'RF41' })
        Test-Assert (($rf41.Count -eq 2) -and ($rf41[0] -eq 'C:\RF41First') -and ($rf41[1] -eq 'C:\RF41Second')) "Update-SessionPath deduplica sin mayusculas y conserva orden (RF-41, real=$($rf41 -join ','))"
        Test-Assert ($fnBody -match 'HashSet') 'Update-SessionPath usa HashSet (RF-41)'
    } else {
        Test-Assert $false 'Update-SessionPath extraible de install.ps1' ''
    }
} catch {
    Test-Assert $false 'Update-SessionPath merge' "$_"
} finally {
    $env:Path = $oldPath
}

# Sin datos personales en codigo fuente (solo tests con fixtures neutros)
$srcFiles = @((Join-Path $RepoRoot 'install.ps1')) + (Get-ChildItem (Join-Path $RepoRoot 'modules') -Filter '*.ps1' | Select-Object -ExpandProperty FullName) + (Get-ChildItem (Join-Path $RepoRoot 'config') -Recurse -File | Select-Object -ExpandProperty FullName)
$srcText = ($srcFiles | ForEach-Object { Get-Content $_ -Raw -ErrorAction SilentlyContinue }) -join "`n"
Test-Assert ($srcText -notmatch 'alexp11mon|alexponmon|a@b\.com') 'Codigo fuente sin datos personales'
Test-Assert ($srcText -notmatch 'Invoke-GitConfig -UserName "\.\.\."') 'Sin placeholders literales en llamada Git'

# ---------------------------------------------------------------------------
# BLOQUE 8: bootstrap.ps1 instalador en linea (estatico + menu funcional mockeado, sin red)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 8: bootstrap.ps1 ---'
$bootPath = Join-Path $RepoRoot 'bootstrap.ps1'
Test-Assert (Test-Path $bootPath) 'bootstrap.ps1 existe'
$bootErrs = $null; $bootToks = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($bootPath, [ref]$bootToks, [ref]$bootErrs)
Test-Assert ($bootErrs.Count -eq 0) 'bootstrap.ps1 sintaxis OK'
$boot = Get-Content $bootPath -Raw
Test-Assert ($boot -match 'Major -lt 7') 'bootstrap.ps1 exige PowerShell 7'
Test-Assert ($boot -match 'github\.com/\$Repo/archive/\$Branch\.zip') 'bootstrap.ps1 construye URL ZIP desde Branch o tag (archive/<ref>.zip)'
Test-Assert ($boot -match 'Verb RunAs') 'bootstrap.ps1 auto-eleva con UAC'
Test-Assert ($boot -match "ValidateSet.*Base.*Dev.*Gaming.*All") 'bootstrap.ps1 valida Category'
Test-Assert ($boot -match '-GitUserName' -and $boot -match '-GitUserEmail') 'bootstrap.ps1 pasa params Git'
Test-Assert ($boot -match 'KeepDownload') 'bootstrap.ps1 soporta KeepDownload'
$ps7Pos = $boot.IndexOf('Require PowerShell 7')
$menuPos = $boot.IndexOf('$interactive')
Test-Assert ($ps7Pos -ge 0 -and $menuPos -gt $ps7Pos) 'bootstrap.ps1 chequea PS7 antes del menu'
$zipPos = $boot.IndexOf('$ZipUrl = "https://github.com')
Test-Assert ($zipPos -ge 0 -and $zipPos -lt $menuPos) 'bootstrap.ps1 define ZipUrl antes del menu'
Test-Assert ($boot.IndexOf('$WhatIfPreference') -lt $boot.IndexOf('Invoke-WebRequest -Uri')) 'bootstrap.ps1 WhatIf sale antes de descargar'
Test-Assert ($boot -match 'function Show-Menu' -and $boot -match 'ReadKey') 'bootstrap.ps1 menu con flechas existe'
Test-Assert ($boot -match 'function Show-NumberedMenu' -and $boot -match 'KeyAvailable') 'bootstrap.ps1 fallback numerado existe'
Test-Assert ($boot -match 'PSBoundParameters') 'bootstrap.ps1 detecta modo interactivo sin params'
Test-Assert ($boot -notmatch 'bootstrap-iex\.ps1' -and $boot -notmatch 'MyCommand\.ScriptBlock') 'bootstrap.ps1 no guarda su codigo en TEMP bajo iex (RF-30)'
Test-Assert ($boot -match 'raw\.githubusercontent\.com/\$Repo/\$Branch/bootstrap\.ps1' -and $boot -match 'EncodedCommand') 'bootstrap.ps1 eleva con EncodedCommand y URL raw bajo iex (RF-30)'
Test-Assert ($boot -match 'Could not download the app list') 'bootstrap.ps1 lista de apps con try/catch'
Test-Assert ($boot -match '\[string\[\]\]\$Apps' -and $boot -match 'Where-Object \{ \$Apps -contains') 'bootstrap.ps1 filtra -Apps en el ZIP (RF-29)'
Test-Assert ($boot -match '\$elevParams\.Apps = \$Apps') 'bootstrap.ps1 pasa -Apps al hijo elevado (RF-29)'
Test-Assert ($boot -notmatch 'customApps') 'bootstrap.ps1 sin variable customApps residual'
Test-Assert ($boot -match '\$isIex = \[string\]::IsNullOrWhiteSpace\(\$PSCommandPath\)') 'bootstrap.ps1 detecta modo iex'
$bareExits = ([regex]::Matches($boot, '(?m)^\s*exit\b')).Count
Test-Assert ($bareExits -eq 0) "bootstrap.ps1 sin exit pelados (todos con if isIex, encontrados=$bareExits)"
Test-Assert (([regex]::Matches($boot, 'if \(\$isIex\) \{ return \} else \{ exit')).Count -ge 10) 'bootstrap.ps1 patron return-iex en todas las salidas'
Test-Assert ($boot -match '\[switch\]\$SkipGit' -and $boot -match '\[switch\]\$SkipVSCode') 'bootstrap.ps1 acepta switches SkipGit/SkipVSCode'
Test-Assert ($boot -match "Skip VSCode configuration") 'bootstrap.ps1 menu pregunta por VSCode'
Test-Assert (($boot -match "\`$elevSwitches \+= 'SkipGit'") -and ($boot -match "\`$installArgs \+= '-SkipGit'")) 'bootstrap.ps1 propaga SkipGit al elevar y al instalar'
Test-Assert ($boot -match 'Elevated installer exited with code') 'bootstrap.ps1 elevacion muestra exit code'
Test-Assert ($boot -notmatch 'RedirectStandard') 'bootstrap.ps1 sin -Redirect* (incompatible con -Verb RunAs, RF-28)'
Test-Assert ($boot -match '& pwsh @installArgs' -and $boot -notmatch 'Start-Process -FilePath "pwsh" -ArgumentList \$installArgs') 'bootstrap.ps1 invoca install.ps1 directo (valores con espacios intactos)'
Test-Assert (($boot -match "\`$elevSwitches \+= 'SkipVSCode'") -and ($boot -match "\`$installArgs \+= '-SkipVSCode'")) 'bootstrap.ps1 propaga SkipVSCode al elevar y al instalar'
Test-Assert ($boot -match '\[switch\]\$SkipOpenCode' -and $boot -match '\[switch\]\$SkipBrave') 'bootstrap.ps1 acepta switches SkipOpenCode/SkipBrave'
Test-Assert (($boot -match "\`$elevSwitches \+= 'SkipOpenCode'") -and ($boot -match "\`$installArgs \+= '-SkipBrave'")) 'bootstrap.ps1 propaga SkipOpenCode/SkipBrave al elevar y al instalar'
Test-Assert ($boot -match 'machine policy') 'bootstrap.ps1 avisa que Brave se fuerza por politica (RF-42)'

# Bajo iex (one-liner real, sin parametros): el param() se evalua como codigo y no debe fallar.
# Sin consola, el menu numerado lee fin de entrada y cancela con 0, sin red ni cambios.
$iexOut = (& pwsh -NoProfile -NonInteractive -Command "Get-Content -Raw '$bootPath' | Invoke-Expression; exit `$LASTEXITCODE" 2>&1 | Out-String)
$iexExit = $LASTEXITCODE
Test-Assert ($iexOut -notmatch 'Invoke-Expression:') "bootstrap bajo iex arranca sin errores del bloque param (salida: $($iexOut.Trim()))"
Test-Assert ($iexExit -eq 0) "bootstrap bajo iex cancelado sale con 0 (real=$iexExit)"

# -Apps "a,b" desde pwsh -File se separa en IDs (simulacion real, sin red)
$appsWhatIf = (& pwsh -NoProfile -File $bootPath -Category Base -Apps 'Valve.Steam,Brave.Brave' -WhatIf) -join "`n"
Test-Assert ($appsWhatIf -match 'Would keep only these apps: Valve\.Steam, Brave\.Brave') "bootstrap -WhatIf separa -Apps con comas (RF-29)"
Test-Assert ($LASTEXITCODE -eq 0) 'bootstrap -WhatIf con -Apps sale con 0'

# SHA256 (RF-32): parametro validado, verificacion antes de extraer
$bootCmd = Get-Command $bootPath
$shaPattern = ($bootCmd.Parameters['Sha256'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }).RegexPattern
$hexLower = 'a' * 64; $hexUpper = 'A' * 64
Test-Assert (($hexLower -match $shaPattern) -and ($hexUpper -match $shaPattern) -and (('a' * 63) -notmatch $shaPattern) -and ('' -match $shaPattern)) 'bootstrap -Sha256 acepta 64 hex en mayus/minus , rechaza 63 y admite vacio para iex (RF-32)'
$hashPos = $boot.IndexOf('Get-FileHash -Path $zipPath')
Test-Assert ($hashPos -gt 0 -and $hashPos -lt $boot.IndexOf('Expand-Archive')) 'bootstrap verifica SHA256 antes de extraer (RF-32)'
Test-Assert ($boot -match 'SHA256 mismatch') 'bootstrap aborta con ERROR si el hash no coincide (RF-32)'
Test-Assert ($hexLower -eq $hexUpper) 'Comparacion -eq/-ne de hash insensible a mayusculas (RF-32)'

# Logs del modo en linea (RF-31): se copian antes de borrar el temporal
$savePos = $boot.IndexOf('Save-RunLogs -SourceDir')
$cleanupPos = $boot.LastIndexOf('Remove-Item -Path $workDir')
Test-Assert ($savePos -gt 0 -and $savePos -lt $cleanupPos) 'bootstrap copia logs antes de la limpieza final (RF-31)'
Test-Assert ($boot -match "LOCALAPPDATA -ChildPath ""win11-setup\\logs""") 'bootstrap guarda logs en %LOCALAPPDATA%\win11-setup\logs (RF-31)'

# AST (RF-37): ningun Start-Process del repo combina -Verb con -Redirect*
$psFiles = Get-ChildItem $RepoRoot -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '[\\/]tests[\\/]' }
$badStartProcess = @()
foreach ($psFile in $psFiles) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($psFile.FullName, [ref]$null, [ref]$null)
    $calls = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Start-Process' }, $true)
    foreach ($call in $calls) {
        $names = @($call.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } | ForEach-Object { $_.ParameterName })
        if (($names -contains 'Verb') -and (@($names | Where-Object { $_ -like 'Redirect*' }).Count -gt 0)) {
            $badStartProcess += "$($psFile.Name):$($call.Extent.StartLineNumber)"
        }
    }
}
Test-Assert ($badStartProcess.Count -eq 0) "Ningun Start-Process mezcla -Verb y -Redirect* (RF-37, encontrados: $($badStartProcess -join ', '))"
$spSets = (Get-Command Start-Process).ParameterSets
Test-Assert (@($spSets | Where-Object { ($_.Parameters.Name -contains 'Verb') -and ($_.Parameters.Name -contains 'RedirectStandardOutput') }).Count -eq 0) 'Start-Process real: -Verb y -RedirectStandardOutput en sets distintos (RF-37)'

# Funciones de bootstrap extraidas por AST y probadas de verdad
$bootAst = [System.Management.Automation.Language.Parser]::ParseFile($bootPath, [ref]$null, [ref]$null)
foreach ($fn in @('ConvertTo-PSLiteral', 'Get-ElevatedCommand', 'Save-RunLogs')) {
    $fnAst = $bootAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true)
    if ($fnAst) { . ([scriptblock]::Create($fnAst.Extent.Text)) }
    Test-Assert ($null -ne $fnAst) "bootstrap define $fn"
}
$elevTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("elev-test-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $elevTemp -Force | Out-Null
try {
    # Hijo falso: vuelca sus parametros y sale con 7 para comprobar ida y vuelta real via -EncodedCommand.
    $fakeChild = Join-Path $elevTemp "fake child.ps1"
    $fakeOut = Join-Path $elevTemp 'out.json'
    @"
param([string]`$Category, [string]`$Repo, [string]`$Branch, [string]`$GitUserName, [string]`$GitUserEmail, [string[]]`$Apps, [switch]`$SkipBrave, [switch]`$KeepDownload)
[pscustomobject]@{ Category = `$Category; GitUserName = `$GitUserName; Apps = `$Apps; SkipBrave = [bool]`$SkipBrave; KeepDownload = [bool]`$KeepDownload } | ConvertTo-Json | Set-Content -Path '$fakeOut' -Encoding UTF8
exit 7
"@ | Set-Content -Path $fakeChild -Encoding UTF8
    $p = [ordered]@{ Category = 'All'; Repo = 'o/r'; Branch = 'master'; GitUserName = "Ana O'Brien Lopez"; Apps = @('Valve.Steam', 'Discord.Discord') }
    $cmdText = Get-ElevatedCommand -ScriptPath $fakeChild -RawUrl 'https://example.invalid/x.ps1' -Params $p -Switches @('SkipBrave')
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmdText))
    & pwsh -NoProfile -EncodedCommand $enc
    $childExit = $LASTEXITCODE
    $got = Get-Content $fakeOut -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    Test-Assert ($childExit -eq 7) "Comando elevado propaga exit code del hijo (RF-28, real=$childExit)"
    Test-Assert ($got.GitUserName -eq "Ana O'Brien Lopez") "Comando elevado conserva espacios y comillas (real=$($got.GitUserName))"
    Test-Assert ((@($got.Apps) -join ',') -eq 'Valve.Steam,Discord.Discord') "Comando elevado pasa -Apps al hijo (RF-29, real=$(@($got.Apps) -join ','))"
    Test-Assert ($got.SkipBrave -eq $true -and $got.KeepDownload -eq $false) 'Comando elevado pasa solo los switches pedidos'
    $iexCmd = Get-ElevatedCommand -ScriptPath '' -RawUrl 'https://raw.githubusercontent.com/o/r/master/bootstrap.ps1' -Params ([ordered]@{ Category = 'Base' })
    Test-Assert ($iexCmd -match "Invoke-RestMethod -Uri 'https://raw\.githubusercontent\.com/o/r/master/bootstrap\.ps1'" -and $iexCmd -match 'scriptblock\]::Create' -and $iexCmd -notmatch 'Set-Content|TEMP') 'Bajo iex el hijo descarga el script en memoria, sin fichero (RF-30)'
    Test-Assert ($iexCmd -match 'catch \{ Write-Error \$_; exit 1 \}') 'Bajo iex un fallo de descarga sale con 1 (RF-30)'

    # Save-RunLogs copia logs a destino estable (RF-31) y no falla sin logs
    $srcLogs = Join-Path $elevTemp 'repo\logs'
    $dstLogs = Join-Path $elevTemp 'archive\logs'
    New-Item -ItemType Directory -Path $srcLogs -Force | Out-Null
    'linea' | Set-Content -Path (Join-Path $srcLogs 'install-20260101-000000.log')
    Save-RunLogs -SourceDir $srcLogs -Destination $dstLogs 6>$null
    Remove-Item (Join-Path $elevTemp 'repo') -Recurse -Force
    Test-Assert (Test-Path (Join-Path $dstLogs 'install-20260101-000000.log')) 'Save-RunLogs conserva el log tras borrar el temporal (RF-31)'
    $noLogsOk = $true
    try { Save-RunLogs -SourceDir (Join-Path $elevTemp 'noexiste') -Destination (Join-Path $elevTemp 'archive2') 6>$null } catch { $noLogsOk = $false }
    Test-Assert ($noLogsOk -and -not (Test-Path (Join-Path $elevTemp 'archive2'))) 'Save-RunLogs sin logs no falla ni crea destino'
} finally {
    Remove-Item $elevTemp -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($fn in @('ConvertTo-PSLiteral', 'Get-ElevatedCommand', 'Save-RunLogs')) { Remove-Item "function:\$fn" -ErrorAction SilentlyContinue }
}
Test-Assert ($boot -match 'OpenCode configuration\?') 'bootstrap.ps1 menu pregunta por OpenCode'
Test-Assert ($boot -notmatch 'Brave configuration\?') 'bootstrap.ps1 no pregunta por Brave (automatico en Base/All)'
Test-Assert ($boot -match 'braveApplies') 'bootstrap.ps1 deriva Brave del alcance en confirmacion'

# Test funcional de Show-NumberedMenu extrayendo la funcion (Read-Host mockeado, sin consola)
if ($boot -match '(?s)(function Show-NumberedMenu \{.*?\n\})\s*\$ZipUrl') {
    $menuSb = [scriptblock]::Create($Matches[1])
    . $menuSb
    function Read-Host { param($Prompt) return '2' }
    try {
        $pick = Show-NumberedMenu -Title 'T' -Options @('A', 'B', 'C')
        Test-Assert ($pick -eq 1) 'Menu numerado elige opcion 2 -> indice 1'
    } catch {
        Test-Assert $false 'Menu numerado seleccion simple' "$_"
    }
    function Read-Host { param($Prompt) return '1,3' }
    try {
        $picks = Show-NumberedMenu -Title 'T' -Options @('A', 'B', 'C') -Multi
        Test-Assert (($picks.Count -eq 2) -and ($picks -contains 'A') -and ($picks -contains 'C')) 'Menu numerado multi marca 1,3 -> A,C'
    } catch {
        Test-Assert $false 'Menu numerado multi-seleccion' "$_"
    }
    Remove-Item function:\Read-Host -ErrorAction SilentlyContinue
    Remove-Item function:\Show-NumberedMenu -ErrorAction SilentlyContinue
} else {
    Test-Assert $false 'Show-NumberedMenu extraible de bootstrap.ps1' ''
}

# ---------------------------------------------------------------------------
# BLOQUE 9: Config-OpenCode mockeado (sin red, sin HOME real, todo en TEMP)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 9: Config-OpenCode ---'
$OpenCodeSnapshot = Join-Path $RepoRoot 'config/opencode'
$MockTempBase = Join-Path ([System.IO.Path]::GetTempPath()) 'oc-mock'
$global:MockOpencodeExit = 0
$global:MockDownloadCalls = 0
$global:MockDownloadFailCount = 0
$global:MockInstallerExit = 0
$global:MockInstallerRan = $false
function opencode {
    param()
    $global:LASTEXITCODE = $global:MockOpencodeExit
}
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    $global:MockDownloadCalls++
    if ($global:MockDownloadCalls -le $global:MockDownloadFailCount) { throw 'mock network failure' }
    ('$global:MockInstallerRan = $true; exit ' + $global:MockInstallerExit) | Set-Content -Path $OutFile -Encoding UTF8
}
# Script-scope override (a helper function would scope it locally and lose it on return).
$global:MockOpencodePresent = $true
function Get-Command {
    param([Parameter(Position = 0)]$Name, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    if ($Name -eq 'opencode') {
        if ($global:MockOpencodePresent) { return @{ Name = 'opencode' } } else { return $null }
    }
    Microsoft.PowerShell.Core\Get-Command -Name $Name @Rest -ErrorAction SilentlyContinue
}

# Presente: no descarga, aplica config en TEMP
$global:MockOpencodePresent = $true
Reset-Capture; $global:MockDownloadCalls = 0; $global:MockOpencodeExit = 0
$destPresent = Join-Path $MockTempBase 'present'
Remove-Item $destPresent -Recurse -Force -ErrorAction SilentlyContinue
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot $destPresent
Test-Assert ($global:MockDownloadCalls -eq 0) 'OpenCode presente no descarga instalador'
Test-Assert (($script:CapturedLogs -join "`n") -match 'already installed') 'OpenCode presente loguea omitido'
Test-Assert (Test-Path (Join-Path $destPresent 'opencode.jsonc')) 'OpenCode presente aplica config en destino'

# Ausente: 1 descarga, stub ejecuta, succeeded
$global:MockOpencodePresent = $false
Reset-Capture; $global:MockDownloadCalls = 0; $global:MockDownloadFailCount = 0; $global:MockInstallerExit = 0; $global:MockInstallerRan = $false
$destAbsent = Join-Path $MockTempBase 'absent'
Remove-Item $destAbsent -Recurse -Force -ErrorAction SilentlyContinue
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot $destAbsent
Test-Assert ($global:MockDownloadCalls -eq 1) 'OpenCode ausente descarga 1 vez'
Test-Assert ($global:MockInstallerRan -eq $true) 'OpenCode ausente ejecuta instalador descargado'
Test-Assert (($script:CapturedLogs -join "`n") -match 'succeeded') 'OpenCode ausente verifica version y loguea exito'

# Version rota (exit 1) se trata como ausente
$global:MockOpencodePresent = $true
Reset-Capture; $global:MockDownloadCalls = 0; $global:MockOpencodeExit = 1
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot (Join-Path $MockTempBase 'broken')
Test-Assert ($global:MockDownloadCalls -eq 1) 'Version rota descarga como si ausente'
$global:MockOpencodeExit = 0

# Doble fallo de descarga => ERROR y continua
$global:MockOpencodePresent = $false
Reset-Capture; $global:MockDownloadCalls = 0; $global:MockDownloadFailCount = 2
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot (Join-Path $MockTempBase 'dlerror')
Test-Assert ($global:MockDownloadCalls -eq 2) 'Descarga reintenta 1 vez (2 intentos)'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Could not download') 'Doble fallo loguea ERROR y continua'

# Fallo simple + exito => 2 llamadas y succeeded
Reset-Capture; $global:MockDownloadCalls = 0; $global:MockDownloadFailCount = 1; $global:MockInstallerExit = 0; $global:MockInstallerRan = $false
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot (Join-Path $MockTempBase 'retry')
Test-Assert ($global:MockDownloadCalls -eq 2) 'Reintento descarga tras fallo simple'
Test-Assert (($script:CapturedLogs -join "`n") -match 'succeeded') 'Reintento con exito loguea succeeded'

# Instalador con exit !=0 => ERROR
Reset-Capture; $global:MockDownloadCalls = 0; $global:MockDownloadFailCount = 0; $global:MockInstallerExit = 3
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot (Join-Path $MockTempBase 'badexit')
Test-Assert (($script:CapturedLogs -join "`n") -match 'exit code 3') 'Instalador con exit 3 loguea ERROR'
$global:MockInstallerExit = 0

# Fusion: identico se omite, distinto se conserva con aviso
Reset-Capture
$destMerge = Join-Path $MockTempBase 'merge'
$mergeAgents = Join-Path $destMerge 'agents'
New-Item -ItemType Directory -Path $mergeAgents -Force | Out-Null
Copy-Item -Path (Join-Path $OpenCodeSnapshot 'agents/sdd-orchestrator.md') -Destination (Join-Path $mergeAgents 'sdd-orchestrator.md') -Force
Set-Content -Path (Join-Path $destMerge 'opencode.jsonc') -Value '{"custom":true}' -Encoding UTF8
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot $destMerge
Test-Assert (($script:CapturedLogs -join "`n") -match 'already applied') 'Fusion omite fichero identico'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Keeping existing') 'Fusion conserva distinto con aviso'
Test-Assert ((Get-Content (Join-Path $destMerge 'opencode.jsonc') -Raw) -match 'custom') 'Fusion no sobrescribe el fichero del usuario'

# Secreto en origen se omite con aviso, resto se aplica
Reset-Capture
$srcSecret = Join-Path $MockTempBase 'src-secret'
$destSecret = Join-Path $MockTempBase 'dest-secret'
New-Item -ItemType Directory -Path $srcSecret -Force | Out-Null
Set-Content -Path (Join-Path $srcSecret 'evil.md') -Value 'api_key = 12345' -Encoding UTF8
Set-Content -Path (Join-Path $srcSecret 'good.md') -Value 'hello' -Encoding UTF8
Invoke-OpenCodeConfig -ConfigSourcePath $srcSecret -DestinationRoot $destSecret
Test-Assert (-not (Test-Path (Join-Path $destSecret 'evil.md'))) 'Fichero con secreto no se copia'
Test-Assert (Test-Path (Join-Path $destSecret 'good.md')) 'Resto se aplica aunque haya secreto'
Test-Assert (($script:CapturedLogs -join "`n") -match 'possible secret') 'Secreto loguea WARNING y continua'

# Barrido por asignacion (RF-34): texto libre con "token" se aplica; asignacion o nombre se omiten
Reset-Capture
$srcProse = Join-Path $MockTempBase 'src-prose'
$destProse = Join-Path $MockTempBase 'dest-prose'
New-Item -ItemType Directory -Path $srcProse -Force | Out-Null
Set-Content -Path (Join-Path $srcProse 'prose.md') -Value 'The agent uses a token to log in. Never store a password.' -Encoding UTF8
Set-Content -Path (Join-Path $srcProse 'assign.md') -Value 'token: abc12345' -Encoding UTF8
Set-Content -Path (Join-Path $srcProse 'json.jsonc') -Value '{ "apiKey": "sk-123456" }' -Encoding UTF8
Set-Content -Path (Join-Path $srcProse 'my-secret.md') -Value 'hello' -Encoding UTF8
Invoke-OpenCodeConfig -ConfigSourcePath $srcProse -DestinationRoot $destProse
Test-Assert (Test-Path (Join-Path $destProse 'prose.md')) 'Texto libre que menciona token/password se aplica (RF-34)'
Test-Assert (-not (Test-Path (Join-Path $destProse 'assign.md'))) 'Asignacion token: valor se omite (RF-34)'
Test-Assert (-not (Test-Path (Join-Path $destProse 'json.jsonc'))) 'Asignacion JSON "apiKey": "valor" se omite (RF-34)'
Test-Assert (-not (Test-Path (Join-Path $destProse 'my-secret.md'))) 'Nombre de fichero con secret se omite (RF-34)'

# opencode.jsonc con comentarios se valida y aplica (RF-35)
Reset-Capture
$srcJsonc = Join-Path $MockTempBase 'src-jsonc'
$destJsonc = Join-Path $MockTempBase 'dest-jsonc'
New-Item -ItemType Directory -Path $srcJsonc -Force | Out-Null
Set-Content -Path (Join-Path $srcJsonc 'opencode.jsonc') -Value "{`n  // line comment`n  ""model"": ""x"" /* block */`n}" -Encoding UTF8
Invoke-OpenCodeConfig -ConfigSourcePath $srcJsonc -DestinationRoot $destJsonc
Test-Assert (Test-Path (Join-Path $destJsonc 'opencode.jsonc')) 'opencode.jsonc con comentarios // y /* */ se aplica (RF-35)'
Test-Assert (($script:CapturedLogs -join "`n") -notmatch 'invalid JSON') 'opencode.jsonc con comentarios no da invalid JSON (RF-35)'

# Origen inexistente => ERROR
Reset-Capture
Invoke-OpenCodeConfig -ConfigSourcePath (Join-Path $RepoRoot 'config/noexiste') -DestinationRoot (Join-Path $MockTempBase 'nosrc')
Test-Assert (($script:CapturedLogs -join "`n") -match 'not found') 'Origen inexistente loguea ERROR'

# WhatIf: 0 descargas, destino intacto, simulacion
$global:MockOpencodePresent = $false
Reset-Capture; $global:MockDownloadCalls = 0
$destWhatIf = Join-Path $MockTempBase 'whatif'
Remove-Item $destWhatIf -Recurse -Force -ErrorAction SilentlyContinue
Invoke-OpenCodeConfig -ConfigSourcePath $OpenCodeSnapshot -DestinationRoot $destWhatIf -WhatIf
Test-Assert ($global:MockDownloadCalls -eq 0) 'WhatIf no descarga instalador'
Test-Assert (-not (Test-Path $destWhatIf)) 'WhatIf no crea destino ni copia'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Simulation') 'WhatIf loguea simulacion'

# Snapshot del repo valido: jsonc parseable, 11 ficheros, sin secretos ni rutas personales
$ocFiles = @(Get-ChildItem $OpenCodeSnapshot -Recurse -File)
Test-Assert ($ocFiles.Count -eq 11) "Snapshot tiene 11 ficheros (real=$($ocFiles.Count))"
Test-Assert (-not (Test-Path (Join-Path $OpenCodeSnapshot 'plugins/gk-hooks.js'))) 'Snapshot sin gk-hooks.js (RF-33)'
$ocJsoncOk = $true
try { $null = Get-Content (Join-Path $OpenCodeSnapshot 'opencode.jsonc') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $ocJsoncOk = $false }
Test-Assert $ocJsoncOk 'opencode.jsonc del snapshot es JSON valido'
$ocText = ($ocFiles | ForEach-Object { Get-Content $_ -Raw -ErrorAction SilentlyContinue }) -join "`n"
Test-Assert ($ocText -notmatch 'token|password|secret|api[_-]?key') 'Snapshot sin secretos ni tokens'
Test-Assert ($ocText -notmatch 'gemini') 'Snapshot sin referencias a Gemini'
Test-Assert ($ocText -notmatch '(?i)[a-z]:[\\/]+Users[\\/]') 'Snapshot sin rutas absolutas de usuario (RF-33)'

Remove-Item function:\opencode -ErrorAction SilentlyContinue
Remove-Item function:\Invoke-WebRequest -ErrorAction SilentlyContinue
Remove-Item function:\Get-Command -ErrorAction SilentlyContinue
Remove-Item $MockTempBase -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# BLOQUE 10: Config-Brave mockeado (registro real solo en clave HKCU temporal)
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '--- Bloque 10: Config-Brave ---'
$BraveExtConfig = Join-Path $RepoRoot 'config/brave/extensions.json'
$MockPolicyBase = 'HKCU:\Software\Win11InstallerTest'
Remove-Item $MockPolicyBase -Recurse -Force -ErrorAction SilentlyContinue
$global:MockBraveInstalled = $true
$global:MockBraveInstallCalls = @()
function Test-AppInstalled {
    param([string]$AppId)
    return $global:MockBraveInstalled
}
function Install-WingetApp {
    param([string]$AppId, [string]$AppName)
    $global:MockBraveInstallCalls += $AppId
    $global:MockBraveInstalled = $true
}
function Get-PolicyValues {
    param([string]$Root)
    return @((Get-ItemProperty -Path $Root -ErrorAction SilentlyContinue).PSObject.Properties |
        Where-Object { $_.Name -match '^\d+$' } |
        Select-Object -ExpandProperty Value)
}

# Presente + 1 preexistente: aplica 4, omite 1
Reset-Capture; $global:MockBraveInstalled = $true; $global:MockBraveInstallCalls = @()
$rootEnforce = Join-Path $MockPolicyBase 'enforce'
New-Item -Path $rootEnforce -Force | Out-Null
New-ItemProperty -Path $rootEnforce -Name '1' -Value 'nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx' -Force | Out-Null
Invoke-BraveConfig -ExtensionsConfigPath $BraveExtConfig -PolicyRoot $rootEnforce
Test-Assert ((Get-PolicyValues $rootEnforce).Count -eq 5) 'Brave aplica ausentes hasta 5 valores'
Test-Assert (($script:CapturedLogs -join "`n") -match 'already enforced') 'Brave omite preexistente (idempotente)'
Test-Assert ($global:MockBraveInstallCalls.Count -eq 0) 'Brave presente no reinstala Brave'
Test-Assert (($script:CapturedLogs -join "`n") -match 'machine policy') 'Brave avisa que las extensiones se fuerzan por politica (RF-42)'

# Una sola lectura de politicas por ejecucion y slots sin colision (RF-40)
$global:GetItemPropertyCalls = 0
function Get-ItemProperty {
    $global:GetItemPropertyCalls++
    Microsoft.PowerShell.Management\Get-ItemProperty @args
}
Reset-Capture
$rootOnce = Join-Path $MockPolicyBase 'read-once'
New-Item -Path $rootOnce -Force | Out-Null
New-ItemProperty -Path $rootOnce -Name '2' -Value 'otherextensionaaaaaaaaaaaaaaaaaa;https://example.invalid' -Force | Out-Null
Invoke-BraveConfig -ExtensionsConfigPath $BraveExtConfig -PolicyRoot $rootOnce
Test-Assert ($global:GetItemPropertyCalls -eq 1) "Brave lee politicas una vez (RF-40, real=$global:GetItemPropertyCalls)"
Remove-Item function:\Get-ItemProperty -ErrorAction SilentlyContinue
$onceNames = @((Get-ItemProperty -Path $rootOnce).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' } | Select-Object -ExpandProperty Name)
Test-Assert (($onceNames.Count -eq 6) -and ((@($onceNames | Sort-Object -Unique)).Count -eq 6)) "Brave usa 6 slots unicos con hueco previo ocupado (RF-40, real=$($onceNames -join ','))"

# Ausente: instala Brave primero y luego aplica
Reset-Capture; $global:MockBraveInstalled = $false; $global:MockBraveInstallCalls = @()
$rootFirst = Join-Path $MockPolicyBase 'install-first'
Invoke-BraveConfig -ExtensionsConfigPath $BraveExtConfig -PolicyRoot $rootFirst
Test-Assert ($global:MockBraveInstallCalls -contains 'Brave.Brave') 'Brave ausente lo instala primero'
Test-Assert ((Get-PolicyValues $rootFirst).Count -eq 5) 'Tras instalar Brave aplica las 5'

# Ausente y sin instalar: WARNING y no escribe
Reset-Capture; $global:MockBraveInstallCalls = @()
function Install-WingetApp {
    param([string]$AppId, [string]$AppName)
    $global:MockBraveInstallCalls += $AppId
}
$global:MockBraveInstalled = $false
$rootNoBrave = Join-Path $MockPolicyBase 'no-brave'
Invoke-BraveConfig -ExtensionsConfigPath $BraveExtConfig -PolicyRoot $rootNoBrave
Test-Assert (($script:CapturedLogs -join "`n") -match 'Skipping') 'Sin Brave omite con aviso'
Test-Assert (-not (Test-Path $rootNoBrave)) 'Sin Brave no escribe en registro'
$global:MockBraveInstalled = $true

# ID invalido se omite, resto se aplica
Reset-Capture
$srcBadId = Join-Path ([System.IO.Path]::GetTempPath()) 'brave-badid.json'
'{"extensions": [{"id": "zzz", "name": "Bad"}, {"id": "ddkjiahejlhfcafbddmgiahcphecmpfh", "name": "uBlock Origin Lite"}]}' | Set-Content -Path $srcBadId -Encoding UTF8
$rootBadId = Join-Path $MockPolicyBase 'bad-id'
Invoke-BraveConfig -ExtensionsConfigPath $srcBadId -PolicyRoot $rootBadId
Test-Assert (($script:CapturedLogs -join "`n") -match 'invalid') 'ID invalido loguea WARNING'
Test-Assert ((Get-PolicyValues $rootBadId).Count -eq 1) 'ID invalido no bloquea al resto'
Remove-Item $srcBadId -Force -ErrorAction SilentlyContinue

# Fichero inexistente y JSON invalido => ERROR
Reset-Capture
Invoke-BraveConfig -ExtensionsConfigPath (Join-Path $RepoRoot 'config/noexiste.json') -PolicyRoot (Join-Path $MockPolicyBase 'no-file')
Test-Assert (($script:CapturedLogs -join "`n") -match 'not found') 'Fichero inexistente loguea ERROR'
$srcBadJson = Join-Path ([System.IO.Path]::GetTempPath()) 'brave-badjson.json'
'{no json' | Set-Content -Path $srcBadJson -Encoding UTF8
Reset-Capture
Invoke-BraveConfig -ExtensionsConfigPath $srcBadJson -PolicyRoot (Join-Path $MockPolicyBase 'bad-json')
Test-Assert (($script:CapturedLogs -join "`n") -match 'not valid JSON') 'JSON invalido loguea ERROR'
Remove-Item $srcBadJson -Force -ErrorAction SilentlyContinue

# WhatIf no escribe
Reset-Capture
$rootWhatIf = Join-Path $MockPolicyBase 'whatif'
Invoke-BraveConfig -ExtensionsConfigPath $BraveExtConfig -PolicyRoot $rootWhatIf -WhatIf
Test-Assert (-not (Test-Path $rootWhatIf)) 'WhatIf no escribe en registro'
Test-Assert (($script:CapturedLogs -join "`n") -match 'Simulation') 'WhatIf loguea simulacion'

# Catalogo del repo valido: 5 entradas, IDs de 32 chars, sin duplicados
$braveData = Get-Content $BraveExtConfig -Raw -Encoding UTF8 | ConvertFrom-Json
Test-Assert ($braveData.extensions.Count -eq 5) "Catalogo Brave tiene 5 (real=$($braveData.extensions.Count))"
Test-Assert ((($braveData.extensions.id | Sort-Object -Unique).Count) -eq 5) 'Catalogo Brave sin duplicados'
Test-Assert (($braveData.extensions.id | Where-Object { $_ -notmatch '^[a-z]{32}$' }).Count -eq 0) 'Catalogo Brave con IDs validos'

Remove-Item function:\Test-AppInstalled -ErrorAction SilentlyContinue
Remove-Item function:\Install-WingetApp -ErrorAction SilentlyContinue
Remove-Item function:\Get-PolicyValues -ErrorAction SilentlyContinue
. (Join-Path $ModulesDir 'Common.ps1')
Remove-Item $MockPolicyBase -Recurse -Force -ErrorAction SilentlyContinue

Write-Output ''
Write-Output '=== RESUMEN ==='
Write-Output "Total: $script:Total Pasados: $script:Passed Fallidos: $script:Failed"
if ($script:Failed -gt 0) {
    Write-Output 'Fallos:'
    $script:Failures | ForEach-Object { Write-Output " - $_" }
    exit 1
} else {
    exit 0
}
