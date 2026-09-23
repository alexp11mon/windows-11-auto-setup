# 1. Crear archivo de log
function Write-InstallLog {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Date] [$Level] $Message"
    
    $LogPath = ".\logs\install.log"
    Add-Content -Path $LogPath -Value $LogLine
}

# 2. Verificar si una aplicación está instalada
function Test-AppInstalled {
    param (
        [string]$AppId
    )
    
    $Output = winget list --id $AppId --exact --accept-source-agreements
    
    if ($Output -match $AppId) {
        return $true
    } else {
        return $false
    }
}

function Install-WingetApp {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$AppId,
        
        [Parameter(Mandatory=$true)]
        [string]$AppName
    )
    
    # 3. Comprobar idempotencia
    if (Test-AppInstalled -AppId $AppId) {
        Write-InstallLog -Message "El programa $AppName ($AppId) ya esta instalado. Omitiendo." -Level "INFO"
        return
    }
    
    # 4. Soporte WhatIf e Instalacion
    if ($PSCmdlet.ShouldProcess($AppName, "Instalar mediante winget")) {
        Write-InstallLog -Message "Iniciando instalacion de $AppName ($AppId)..." -Level "INFO"
        
        winget install --exact --id $AppId --accept-source-agreements --accept-package-agreements --silent
        
        # 5. Verificacion final
        if (Test-AppInstalled -AppId $AppId) {
            Write-InstallLog -Message "Instalacion exitosa: $AppName" -Level "INFO"
        } else {
            Write-InstallLog -Message "Error al instalar: $AppName. Revisa la consola." -Level "ERROR"
        }
    } else {
        Write-InstallLog -Message "Modo simulacion activado. Se instalaria: $AppName ($AppId)" -Level "INFO"
    }
}