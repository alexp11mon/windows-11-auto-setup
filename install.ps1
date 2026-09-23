# 1. Definir categorías de instalación
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    # 
    [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
    [string]$Category = 'All'
)

# 2. Comprobacion de permisos de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "Este script requiere permisos de Administrador. Por favor, abre PowerShell como Administrador y vuelve a intentarlo."
    exit
}

# 3. Comprobacion de Windows 11 de 64 bits
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor

$isWin11 = $os.BuildNumber -ge 22000
$is64Bit = $cpu.AddressWidth -eq 64

if (-not ($isWin11 -and $is64Bit)) {
    Write-Error "Este script esta disenado exclusivamente para Windows 11 de 64 bits. Ejecucion abortada."
    exit
}

# 4. Comprobacion de disponibilidad de winget
if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    Write-Error "La herramienta winget no esta disponible en este sistema. Por favor, instalala para continuar."
    exit
}

# 5. Importar modulos comunes
$CommonModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\Common.ps1"

if (Test-Path $CommonModulePath) {
    . $CommonModulePath
} else {
    Write-Error "No se encontro el modulo basico en la ruta: $CommonModulePath. Ejecucion abortada."
    exit
}

# 6. Iniciar registro de actividad
Write-InstallLog -Message "Iniciando instalador automatico. Categoria seleccionada: $Category" -Level "INFO"

# 7. Importar modulo de categorias
$CategoryModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\Install-Category.ps1"

if (Test-Path $CategoryModulePath) {
    . $CategoryModulePath
} else {
    Write-Error "No se encontro el modulo de categorias en la ruta: $CategoryModulePath."
    Write-InstallLog -Message "Fallo critico: Modulo Install-Category no encontrado." -Level "ERROR"
    exit
}

# 8. Ejecutar instalacion de winget
Invoke-InstallCategory -Category $Category

# 9.1. Importar y ejecutar configuracion de Git
$GitModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\Config-Git.ps1"

if (Test-Path $GitModulePath) {
    . $GitModulePath
    
    # Solo configuramos Git si la categoria incluye 'Dev' o es 'All'
    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        Invoke-GitConfig
    }
} else {
    Write-InstallLog -Message "Modulo de configuracion de Git no encontrado en: $GitModulePath" -Level "WARNING"
}

# 9.2. Importar y ejecutar configuracion de VSCode
$VSCodeModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules\Config-VSCode.ps1"

if (Test-Path $VSCodeModulePath) {
    . $VSCodeModulePath
    
    # Solo instalamos extensiones si la categoria incluye 'Dev' o es 'All'
    if ($Category -eq 'Dev' -or $Category -eq 'All') {
        Invoke-VSCodeConfig
    }
} else {
    Write-InstallLog -Message "Modulo de configuracion de VSCode no encontrado en: $VSCodeModulePath" -Level "WARNING"
}

# 10. Cierre
Write-InstallLog -Message "Ejecucion del instalador finalizada." -Level "INFO"
Write-Host "Proceso completado. Revisa la carpeta logs/ para mas detalles." -ForegroundColor Green