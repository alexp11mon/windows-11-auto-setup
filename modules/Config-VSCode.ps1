function Invoke-VSCodeConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        # Ruta resuelta por install.ps1 para evitar depender de $PSScriptRoot
        # dentro de una función dot-sourced.
        [Parameter(Mandatory = $true)]
        [string]$ExtensionsConfigPath
    )

    # 1. Comprobar si VSCode está instalado en el sistema.
    if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "VSCode (comando 'code') no se encuentra disponible en el PATH de esta sesion. Se omite la configuracion (reinicia la terminal si se instalo en esta misma ejecucion)." -Level "WARNING"
        return
    }

    # 2. Localizar y validar el archivo de configuración.
    if (-not (Test-Path $ExtensionsConfigPath)) {
        Write-InstallLog -Message "No se encontro el archivo de extensiones: $ExtensionsConfigPath" -Level "ERROR"
        return
    }
    try {
        $ExtensionsData = Get-Content -Path $ExtensionsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-InstallLog -Message "El archivo de extensiones no es JSON valido ($ExtensionsConfigPath): $_" -Level "ERROR"
        return
    }
    $DesiredExtensions = $ExtensionsData.extensions
    if ($null -eq $DesiredExtensions -or $DesiredExtensions.Count -eq 0) {
        Write-InstallLog -Message "No hay extensiones definidas en $ExtensionsConfigPath." -Level "WARNING"
        return
    }

    # 3. Cargar lista instalada una sola vez para garantizar idempotencia.
    Write-InstallLog -Message "Obteniendo lista de extensiones actuales de VSCode..." -Level "INFO"
    $InstalledExtensions = code --list-extensions 2>&1
    if ($LASTEXITCODE -ne 0 -or $null -eq $InstalledExtensions) {
        Write-InstallLog -Message "No se pudo obtener la lista de extensiones instaladas (codigo $LASTEXITCODE). Se intentara instalar de todos modos." -Level "WARNING"
        $InstalledExtensions = @()
    }

    # 4. Procesar cada extensión con soporte WhatIf y verificación real.
    foreach ($Ext in $DesiredExtensions) {
        if ([string]::IsNullOrWhiteSpace($Ext)) { continue }

        if ($InstalledExtensions -contains $Ext) {
            Write-InstallLog -Message "La extension '$Ext' ya esta instalada. Omitiendo." -Level "INFO"
            continue
        }

        if ($PSCmdlet.ShouldProcess($Ext, "Instalar extension de VSCode")) {
            Write-InstallLog -Message "Instalando extension de VSCode: $Ext..." -Level "INFO"

            code --install-extension $Ext --force
            if ($LASTEXITCODE -ne 0) {
                Write-InstallLog -Message "Fallo al instalar la extension '$Ext' (codigo $LASTEXITCODE)." -Level "ERROR"
            } else {
                Write-InstallLog -Message "Extension instalada correctamente: $Ext" -Level "INFO"
            }
        } else {
            Write-InstallLog -Message "Modo simulacion activado. Se instalaria la extension: $Ext" -Level "INFO"
        }
    }
}
