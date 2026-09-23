function Invoke-InstallCategory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
        [string]$Category
    )

    $AppsConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config\apps.json"
    
    if (-not (Test-Path $AppsConfigPath)) {
        Write-InstallLog -Message "No se encontro el archivo de configuracion: $AppsConfigPath" -Level "ERROR"
        return
    }

    $AppsData = Get-Content -Path $AppsConfigPath | ConvertFrom-Json
    $CategoriesToInstall = @()

    if ($Category -eq 'All') {
        $CategoriesToInstall = @('Base', 'Dev', 'Gaming')
    } else {
        $CategoriesToInstall = @($Category)
    }

    foreach ($Cat in $CategoriesToInstall) {
        Write-InstallLog -Message "Iniciando instalacion de la categoria: $Cat" -Level "INFO"
        
        $AppList = $AppsData.$Cat
        
        foreach ($AppId in $AppList) {
            $AppName = $AppId.Split('.')[-1]
            
            if ($PSCmdlet.ShouldProcess($AppName, "Llamar a Install-WingetApp")) {
                Install-WingetApp -AppId $AppId -AppName $AppName
            }
        }
    }
}