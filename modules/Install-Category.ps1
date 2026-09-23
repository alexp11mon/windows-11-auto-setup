function Invoke-InstallCategory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
        [string]$Category,

        # Ruta resuelta por install.ps1 para evitar depender de $PSScriptRoot
        # dentro de una función dot-sourced (frágil según el llamador).
        [Parameter(Mandatory = $true)]
        [string]$AppsConfigPath
    )

    if (-not (Test-Path $AppsConfigPath)) {
        Write-InstallLog -Message "No se encontro el archivo de configuracion: $AppsConfigPath" -Level "ERROR"
        return
    }

    try {
        $AppsData = Get-Content -Path $AppsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-InstallLog -Message "El archivo de configuracion no es JSON valido ($AppsConfigPath): $_" -Level "ERROR"
        return
    }

    $CategoriesToInstall = @()
    if ($Category -eq 'All') {
        $CategoriesToInstall = @('Base', 'Dev', 'Gaming')
    } else {
        $CategoriesToInstall = @($Category)
    }

    foreach ($Cat in $CategoriesToInstall) {
        Write-InstallLog -Message "Iniciando instalacion de la categoria: $Cat" -Level "INFO"

        $AppList = $AppsData.$Cat
        if ($null -eq $AppList -or $AppList.Count -eq 0) {
            Write-InstallLog -Message "La categoria '$Cat' no tiene aplicaciones definidas en $AppsConfigPath. Omitiendo." -Level "WARNING"
            continue
        }

        foreach ($AppId in $AppList) {
            if ([string]::IsNullOrWhiteSpace($AppId)) { continue }
            $AppName = $AppId.Split('.')[-1]

            # Sin ShouldProcess aquí: Install-WingetApp ya lo implementa.
            # Así se evita el doble prompt/log en modo -WhatIf.
            Install-WingetApp -AppId $AppId -AppName $AppName
        }
    }
}
