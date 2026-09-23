# Instalador automático Windows 11 64-bit.
# Uso: .\install.ps1 [-Category Base|Dev|Gaming|All] [-WhatIf]
# Requiere: Windows 11 64-bit, PowerShell 7, winget, ejecución como Administrador.
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
    [string]$Category = 'All'
)

$RepoRoot = $PSScriptRoot
$AppsConfigPath = Join-Path -Path $RepoRoot -ChildPath "config/apps.json"
$ExtensionsConfigPath = Join-Path -Path $RepoRoot -ChildPath "config/vscode/extensions.json"

function Update-SessionPath {
    # Tras instalar apps con winget en la misma sesión, el PATH del proceso
    # no incluye las nuevas rutas (git, code). Refrescar desde Machine + User.
    try {
        $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $user = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($machine -or $user) {
            $env:Path = "$machine;$user"
        }
    } catch {
        Write-Warning "No se pudo refrescar el PATH de la sesion: $_"
    }
}

# 1. Comprobación de permisos de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Este script requiere permisos de Administrador. Abre PowerShell como Administrador y vuelve a intentarlo."
    exit 1
}

# 2. Comprobación de Windows 11 de 64 bits (SO, no solo CPU)
$os = Get-CimInstance Win32_OperatingSystem
$isWin11 = [int]$os.BuildNumber -ge 22000
$is64BitOS = [Environment]::Is64BitOperatingSystem -and ($os.OSArchitecture -eq "64-bit")

if (-not ($isWin11 -and $is64BitOS)) {
    Write-Error "Este script esta disenado exclusivamente para Windows 11 de 64 bits (Build >= 22000, SO 64-bit). Ejecucion abortada."
    exit 1
}

# 3. Comprobación de disponibilidad de winget
if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    Write-Error "La herramienta winget no esta disponible en este sistema. Instalala (App Installer desde Microsoft Store) para continuar."
    exit 1
}

# 4. Importar módulos (rutas resueltas con Join-Path anidado)
$CommonModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Common.ps1")
if (Test-Path $CommonModulePath) {
    . $CommonModulePath
} else {
    Write-Error "No se encontro el modulo basico en la ruta: $CommonModulePath. Ejecucion abortada."
    exit 1
}

# 5. Iniciar registro de actividad (archivo fechado en logs/)
Initialize-InstallLog | Out-Null
Write-InstallLog -Message "Iniciando instalador automatico. Categoria seleccionada: $Category" -Level "INFO"

# 6. Importar módulo de categorías
$CategoryModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Install-Category.ps1")
if (Test-Path $CategoryModulePath) {
    . $CategoryModulePath
} else {
    Write-InstallLog -Message "Fallo critico: Modulo Install-Category no encontrado en: $CategoryModulePath." -Level "ERROR"
    exit 1
}

# 7. Ejecutar instalación de winget (-WhatIf se propaga por $WhatIfPreference)
Invoke-InstallCategory -Category $Category -AppsConfigPath $AppsConfigPath

# Refrescar PATH para que git/code recién instalados sean detectables sin reiniciar.
Update-SessionPath

# 8. Configuración de Git (solo Dev o All)
$GitModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Config-Git.ps1")
if (Test-Path $GitModulePath) {
    . $GitModulePath

    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        Invoke-GitConfig
    }
} else {
    Write-InstallLog -Message "Modulo de configuracion de Git no encontrado en: $GitModulePath" -Level "WARNING"
}

# 9. Configuración de VSCode (solo Dev o All)
$VSCodeModulePath = Join-Path -Path $RepoRoot -ChildPath (Join-Path "modules" "Config-VSCode.ps1")
if (Test-Path $VSCodeModulePath) {
    . $VSCodeModulePath

    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        Invoke-VSCodeConfig -ExtensionsConfigPath $ExtensionsConfigPath
    }
} else {
    Write-InstallLog -Message "Modulo de configuracion de VSCode no encontrado en: $VSCodeModulePath" -Level "WARNING"
}

# 10. Cierre
Write-InstallLog -Message "Ejecucion del instalador finalizada." -Level "INFO"
Write-Host "Proceso completado. Revisa la carpeta logs/ para mas detalles." -ForegroundColor Green
