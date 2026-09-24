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

Write-Output '=== TEST GENERAL MOCKEADO - Instalador ==='
Write-Output "Repo: $RepoRoot"
Write-Output "pwsh: $($PSVersionTable.PSVersion) PSEdition=$($PSVersionTable.PSEdition)"
Write-Output ''

# ---------------------------------------------------------------------------
# BLOQUE 1: Sintaxis + JSON (checks estaticos re-ejecutados en harness)
# ---------------------------------------------------------------------------
Write-Output '--- Bloque 1: Estatico ---'
foreach ($f in @('install.ps1','modules/Common.ps1','modules/Install-Category.ps1','modules/Config-Git.ps1','modules/Config-VSCode.ps1')) {
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
# Restaurar funcion original re-importando
. (Join-Path $ModulesDir 'Common.ps1')
. (Join-Path $ModulesDir 'Install-Category.ps1')
. (Join-Path $ModulesDir 'Config-Git.ps1')
. (Join-Path $ModulesDir 'Config-VSCode.ps1')

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
Test-Assert (($script:CapturedLogs -join "`n") -match 'Omitiendo') 'Log dice Omitiendo cuando ya instalado'

# No instalado + WhatIf => no llama a install real, solo log simulacion
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @()
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam' -WhatIf
Test-Assert ($global:MockInstallCalls.Count -eq 0) 'WhatIf no ejecuta winget install'
Test-Assert (($script:CapturedLogs -join "`n") -match 'simulacion') 'WhatIf loguea simulacion'

# No instalado, sin WhatIf, exit 0 pero sigue sin aparecer => ERROR post-verificacion
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @(); $global:MockInstallExit = 0
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam'
Test-Assert ($global:MockInstallCalls.Count -eq 1) 'Sin WhatIf llama 1 vez a winget install'
Test-Assert (($script:CapturedLogs -join "`n") -match 'no aparece') 'Post-verificacion ERROR si no aparece en list'

# winget devuelve codigo !=0 => ERROR
Reset-Capture; $global:MockInstallCalls = @(); $global:MockInstalledIds = @(); $global:MockInstallExit = 1
Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam'
Test-Assert (($script:CapturedLogs -join "`n") -match 'codigo 1') 'Loguea codigo de salida winget !=0'

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
Test-Assert (($script:CapturedLogs -join "`n") -match 'No se encontro') 'Categoria con fichero inexistente loguea ERROR'

# JSON invalido => ERROR
$badJson = Join-Path ([System.IO.Path]::GetTempPath()) 'bad-apps.json'
'{ invalido' | Set-Content $badJson -Encoding UTF8
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $badJson
Test-Assert (($script:CapturedLogs -join "`n") -match 'JSON valido') 'Categoria con JSON invalido loguea ERROR'
Remove-Item $badJson -Force -ErrorAction SilentlyContinue

# Categoria vacia => WARNING
$emptyJson = Join-Path ([System.IO.Path]::GetTempPath()) 'empty-apps.json'
'{ "Base": [], "Dev": [], "Gaming": [] }' | Set-Content $emptyJson -Encoding UTF8
Reset-Capture
Invoke-InstallCategory -Category 'Base' -AppsConfigPath $emptyJson
Test-Assert (($script:CapturedLogs -join "`n") -match 'no tiene aplicaciones') 'Categoria vacia loguea WARNING'
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

Reset-Capture; $global:MockGitCalls = @()
Invoke-GitConfig -UserName 'Test' -UserEmail 'no-es-email'
Test-Assert ($global:MockGitCalls.Count -eq 0) 'Email invalido no ejecuta git'
Test-Assert (($script:CapturedLogs -join "`n") -match 'formato invalido') 'Email invalido loguea WARNING'

Reset-Capture; $global:MockGitCalls = @()
# En WhatIf con params no debe llamar a git real
function Read-Host { param($Prompt) return 'mocked' }
Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com' -WhatIf
Test-Assert ($global:MockGitCalls.Count -eq 0) 'WhatIf no ejecuta git real'
Test-Assert (($script:CapturedLogs -join "`n") -match 'simulacion') 'Git WhatIf loguea simulacion'
Remove-Item function:\Read-Host -ErrorAction SilentlyContinue

# Git WhatIf SIN params no debe bloquear pidiendo Read-Host (fix del bloqueo)
Reset-Capture; $global:MockGitCalls = @()
function Read-Host { param($Prompt) throw 'Read-Host no debe llamarse en WhatIf sin datos' }
try {
    Invoke-GitConfig -WhatIf
    Test-Assert ($global:MockGitCalls.Count -eq 0) 'Git WhatIf sin params no ejecuta git'
    Test-Assert (($script:CapturedLogs -join "`n") -match 'sin datos interactivos') 'Git WhatIf sin params loguea sin datos y no bloquea'
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
Test-Assert (($script:CapturedLogs -join "`n") -match 'no se encuentra instalado|no esta en el PATH') 'Sin git loguea WARNING y omite'
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
Test-Assert (($script:CapturedLogs -join "`n") -match 'ya esta instalada') 'VSCode detecta ya instalada (idempotente)'

# WhatIf no instala
$global:MockCodeCalls = @(); Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath -WhatIf
Test-Assert ($global:MockCodeCalls.Count -eq 0) 'VSCode WhatIf no ejecuta code --install-extension'

# Fichero inexistente => ERROR
Reset-Capture
Invoke-VSCodeConfig -ExtensionsConfigPath (Join-Path $RepoRoot 'config/vscode/noexiste.json')
Test-Assert (($script:CapturedLogs -join "`n") -match 'No se encontro') 'VSCode fichero inexistente loguea ERROR'

# Sin code en PATH (mockear Get-Command, SIN tocar code real)
$global:MockCodeCalls = @()
Reset-Capture
function Get-Command {
    param([Parameter(Position=0)]$Name, [Parameter(ValueFromRemainingArguments=$true)]$Rest)
    if ($Name -eq 'code') { return $null }
    Microsoft.PowerShell.Core\Get-Command -Name $Name @Rest -ErrorAction SilentlyContinue
}
Invoke-VSCodeConfig -ExtensionsConfigPath $ExtConfigPath
Test-Assert (($script:CapturedLogs -join "`n") -match 'no se encuentra disponible') 'Sin code loguea WARNING y omite'
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
Test-Assert ($entry -match 'InstallHadErrors') 'install.ps1 propaga errores con exit code'

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
Test-Assert ($boot -match 'archive/refs/heads/' -and $boot -match '\$Branch') 'bootstrap.ps1 construye URL ZIP desde Branch'
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
Test-Assert ($boot -match 'selfPath' -and $boot -match 'bootstrap-iex\.ps1') 'bootstrap.ps1 elevacion funciona bajo iex'
Test-Assert ($boot -match 'Could not download the app list') 'bootstrap.ps1 lista de apps con try/catch'
Test-Assert ($boot -match '\$customApps' -and $boot -match 'Where-Object \{ \$customApps') 'bootstrap.ps1 filtra customApps en el ZIP'

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
