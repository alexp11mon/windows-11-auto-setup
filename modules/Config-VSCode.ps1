function Invoke-VSCodeConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    # 1. Comprobar si VSCode esta instalado en el sistema
    if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "VSCode (comando 'code') no se encuentra disponible. Se omite la configuracion." -Level "WARNING"
        return
    }

    # 2. Localizar el archivo de configuracion
    $ExtensionsConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config\vscode\extensions.json"
    
    if (-not (Test-Path $ExtensionsConfigPath)) {
        Write-InstallLog -Message "No se encontro el archivo de extensiones: $ExtensionsConfigPath" -Level "ERROR"
        return
    }

    # 3. Cargar listas para garantizar idempotencia
    $ExtensionsData = Get-Content -Path $ExtensionsConfigPath | ConvertFrom-Json
    $DesiredExtensions = $ExtensionsData.extensions
    
    Write-InstallLog -Message "Obteniendo lista de extensiones actuales de VSCode..." -Level "INFO"
    $InstalledExtensions = code --list-extensions

    # 4. Procesar cada extension con soporte WhatIf
    foreach ($Ext in $DesiredExtensions) {
        $isInstalled = $false
        
        # Comprobar si la extension actual esta en la lista de las ya instaladas
        if ($InstalledExtensions -contains $Ext) {
            $isInstalled = $true
        }

        if ($isInstalled) {
            Write-InstallLog -Message "La extension '$Ext' ya esta instalada. Omitiendo." -Level "INFO"
            continue
        }

        if ($PSCmdlet.ShouldProcess($Ext, "Instalar extension de VSCode")) {
            Write-InstallLog -Message "Instalando extension de VSCode: $Ext..." -Level "INFO"
            
            # Comando nativo de instalacion
            code --install-extension $Ext --force
            
            Write-InstallLog -Message "Instalacion solicitada para: $Ext" -Level "INFO"
        } else {
            Write-InstallLog -Message "Modo simulacion activado. Se instalaria la extension: $Ext" -Level "INFO"
        }
    }
}