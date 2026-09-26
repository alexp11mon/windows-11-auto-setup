function Invoke-InstallCategory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Base', 'Dev', 'Gaming', 'All')]
        [string]$Category,

        # Resolved by install.ps1: $PSScriptRoot inside a dot-sourced
        # function is unreliable depending on the caller.
        [Parameter(Mandatory = $true)]
        [string]$AppsConfigPath
    )

    if (-not (Test-Path $AppsConfigPath)) {
        Write-InstallLog -Message "Configuration file not found: $AppsConfigPath" -Level "ERROR"
        return
    }

    try {
        $AppsData = Get-Content -Path $AppsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-InstallLog -Message "Configuration file is not valid JSON ($AppsConfigPath): $_" -Level "ERROR"
        return
    }

    $CategoriesToInstall = @()
    if ($Category -eq 'All') {
        $CategoriesToInstall = @('Base', 'Dev', 'Gaming')
    } else {
        $CategoriesToInstall = @($Category)
    }

    foreach ($Cat in $CategoriesToInstall) {
        Write-InstallLog -Message "Starting installation of category: $Cat" -Level "INFO"

        $AppList = $AppsData.$Cat
        if ($null -eq $AppList -or $AppList.Count -eq 0) {
            Write-InstallLog -Message "Category '$Cat' has no applications defined in $AppsConfigPath. Skipping." -Level "WARNING"
            continue
        }

        foreach ($AppId in $AppList) {
            if ([string]::IsNullOrWhiteSpace($AppId)) { continue }
            $AppName = $AppId.Split('.')[-1]

            # No ShouldProcess here: Install-WingetApp already implements it.
            Install-WingetApp -AppId $AppId -AppName $AppName
        }
    }
}
