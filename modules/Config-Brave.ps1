function Invoke-BraveConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        # Catalog of extensions ({id, name} entries) to enforce.
        [Parameter(Mandatory = $true)]
        [string]$ExtensionsConfigPath,

        # Policy list root. Overridable for tests; production uses HKLM.
        [string]$PolicyRoot = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist'
    )

    $UpdateUrl = 'https://clients2.google.com/service/update2/crx'

    if (-not (Test-Path $ExtensionsConfigPath)) {
        Write-InstallLog -Message "Brave extensions file not found: $ExtensionsConfigPath" -Level "ERROR"
        return
    }
    try {
        $ExtensionsData = Get-Content -Path $ExtensionsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-InstallLog -Message "Brave extensions file is not valid JSON ($ExtensionsConfigPath): $_" -Level "ERROR"
        return
    }
    $DesiredExtensions = @($ExtensionsData.extensions)
    if ($DesiredExtensions.Count -eq 0) {
        Write-InstallLog -Message "No extensions defined in $ExtensionsConfigPath." -Level "WARNING"
        return
    }

    # Ensure Brave exists first (Install-WingetApp handles -WhatIf internally).
    if (-not (Test-AppInstalled -AppId 'Brave.Brave')) {
        Write-InstallLog -Message "Brave is not installed. Installing it first..." -Level "INFO"
        Install-WingetApp -AppId 'Brave.Brave' -AppName 'Brave'
        if (-not (Test-AppInstalled -AppId 'Brave.Brave')) {
            Write-InstallLog -Message "Brave is not installed. Skipping Brave extensions." -Level "WARNING"
            return
        }
    }

    if ($PSCmdlet.ShouldProcess($PolicyRoot, "Enforce $($DesiredExtensions.Count) Brave extensions")) {
        if (-not (Test-Path $PolicyRoot)) {
            New-Item -Path $PolicyRoot -Force | Out-Null
        }
        $enforcedValues = @(
            (Get-ItemProperty -Path $PolicyRoot -ErrorAction SilentlyContinue).PSObject.Properties |
                Where-Object { $_.Name -match '^\d+$' } |
                Select-Object -ExpandProperty Value
        )
        foreach ($ext in $DesiredExtensions) {
            $id = $ext.id
            $name = if ($ext.name) { $ext.name } else { $id }
            if ([string]::IsNullOrWhiteSpace($id)) {
                Write-InstallLog -Message "Skipping extension with empty ID." -Level "WARNING"
                continue
            }
            if ($id -notmatch '^[a-z]{32}$') {
                Write-InstallLog -Message "Skipping extension '$name': invalid ID format ('$id')." -Level "WARNING"
                continue
            }
            $idPattern = '^' + [regex]::Escape($id) + ';'
            if ($enforcedValues -match $idPattern) {
                Write-InstallLog -Message "Brave extension '$name' is already enforced. Skipping." -Level "INFO"
                continue
            }
            Write-InstallLog -Message "Enforcing Brave extension: $name..." -Level "INFO"
            $takenNames = @(
                (Get-ItemProperty -Path $PolicyRoot -ErrorAction SilentlyContinue).PSObject.Properties |
                    Where-Object { $_.Name -match '^\d+$' } |
                    Select-Object -ExpandProperty Name
            )
            $slot = 1
            while ($takenNames -contains "$slot") { $slot++ }
            New-ItemProperty -Path $PolicyRoot -Name "$slot" -Value "$id;$UpdateUrl" -Force | Out-Null
            $enforcedValues += "$id;$UpdateUrl"
        }
        Write-InstallLog -Message "Brave extensions enforced. Restart Brave to apply them." -Level "WARNING"
    } else {
        Write-InstallLog -Message "Simulation mode. Would enforce $($DesiredExtensions.Count) Brave extensions under: $PolicyRoot" -Level "INFO"
    }
}
