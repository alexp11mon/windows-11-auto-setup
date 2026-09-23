# Common.ps1 - Funciones compartidas del instalador.
# Requiere PowerShell 7+. No ejecuta nada al importarse salvo inicializar la ruta de log.

# Ruta del log de la ejecución actual. Se fija una sola vez por proceso
# para que todas las llamadas a Write-InstallLog escriban al mismo archivo fechado.
$script:InstallLogPath = $null

function Initialize-InstallLog {
    [CmdletBinding()]
    param()

    if ($script:InstallLogPath -and (Test-Path (Split-Path -Parent $script:InstallLogPath))) {
        return $script:InstallLogPath
    }

    # $PSScriptRoot aquí (ámbito de script) es la carpeta modules/.
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $logsDir = Join-Path -Path $repoRoot -ChildPath "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:InstallLogPath = Join-Path -Path $logsDir -ChildPath "install-$timestamp.log"
    return $script:InstallLogPath
}

function Write-InstallLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $logPath = Initialize-InstallLog
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$date] [$Level] $Message"

    Add-Content -Path $logPath -Value $logLine -Encoding UTF8

    # Reflejar errores y avisos también en consola para visibilidad inmediata.
    # Marcar flag global para que install.ps1 pueda salir con codigo 1 si hubo errores.
    if ($Level -eq "ERROR") {
        $global:InstallHadErrors = $true
        Write-Error $Message
    } elseif ($Level -eq "WARNING") {
        Write-Warning $Message
    } else {
        Write-Verbose $Message
    }
}

function Test-AppInstalled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    $output = winget list --id $AppId --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    # $AppId contiene puntos (p. ej. Brave.Brave): escapar para no tratarlos como regex.
    $pattern = [regex]::Escape($AppId)
    if ($output | Select-String -Pattern $pattern -Quiet) {
        return $true
    }
    return $false
}

function Install-WingetApp {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    # Idempotencia: omitir si ya está instalado.
    if (Test-AppInstalled -AppId $AppId) {
        Write-InstallLog -Message "El programa $AppName ($AppId) ya esta instalado. Omitiendo." -Level "INFO"
        return
    }

    if ($PSCmdlet.ShouldProcess($AppName, "Instalar mediante winget")) {
        Write-InstallLog -Message "Iniciando instalacion de $AppName ($AppId)..." -Level "INFO"

        winget install --exact --id $AppId --accept-source-agreements --accept-package-agreements --silent
        $wingetExit = $LASTEXITCODE

        if ($wingetExit -ne 0) {
            Write-InstallLog -Message "winget devolvio codigo $wingetExit al instalar: $AppName ($AppId). Revisa la consola." -Level "ERROR"
            return
        }

        # Verificación final (puede tardar en reflejarse en PATH/registro).
        if (Test-AppInstalled -AppId $AppId) {
            Write-InstallLog -Message "Instalacion exitosa: $AppName" -Level "INFO"
        } else {
            Write-InstallLog -Message "Error al instalar: $AppName ($AppId). winget termino sin error pero la app no aparece en 'winget list'." -Level "ERROR"
        }
    } else {
        Write-InstallLog -Message "Modo simulacion activado. Se instalaria: $AppName ($AppId)" -Level "INFO"
    }
}
