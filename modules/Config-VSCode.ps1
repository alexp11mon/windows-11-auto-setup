function Invoke-VSCodeConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        # Resolved by install.ps1 to avoid relying on $PSScriptRoot in a dot-sourced function.
        [Parameter(Mandatory = $true)]
        [string]$ExtensionsConfigPath
    )

    # 1. Check whether VSCode is installed.
    if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "VSCode ('code' command) is not available on this session's PATH. Skipping configuration (restart the terminal if it was installed during this run)." -Level "WARNING"
        return
    }

    # 2. Locate and validate the configuration file.
    if (-not (Test-Path $ExtensionsConfigPath)) {
        Write-InstallLog -Message "Extensions file not found: $ExtensionsConfigPath" -Level "ERROR"
        return
    }
    try {
        $ExtensionsData = Get-Content -Path $ExtensionsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-InstallLog -Message "Extensions file is not valid JSON ($ExtensionsConfigPath): $_" -Level "ERROR"
        return
    }
    $DesiredExtensions = $ExtensionsData.extensions
    if ($null -eq $DesiredExtensions -or $DesiredExtensions.Count -eq 0) {
        Write-InstallLog -Message "No extensions defined in $ExtensionsConfigPath." -Level "WARNING"
        return
    }

    # 3. Load installed list once for idempotency.
    Write-InstallLog -Message "Getting current VSCode extensions..." -Level "INFO"
    $InstalledExtensions = code --list-extensions 2>&1
    if ($LASTEXITCODE -ne 0 -or $null -eq $InstalledExtensions) {
        Write-InstallLog -Message "Could not get installed extensions (code $LASTEXITCODE). Trying to install anyway." -Level "WARNING"
        $InstalledExtensions = @()
    }

    # 4. Process each extension with WhatIf support and result check.
    foreach ($Ext in $DesiredExtensions) {
        if ([string]::IsNullOrWhiteSpace($Ext)) { continue }

        if ($InstalledExtensions -contains $Ext) {
            Write-InstallLog -Message "Extension '$Ext' is already installed. Skipping." -Level "INFO"
            continue
        }

        if ($PSCmdlet.ShouldProcess($Ext, "Install VSCode extension")) {
            Write-InstallLog -Message "Installing VSCode extension: $Ext..." -Level "INFO"

            code --install-extension $Ext --force
            if ($LASTEXITCODE -ne 0) {
                Write-InstallLog -Message "Failed to install extension '$Ext' (code $LASTEXITCODE)." -Level "ERROR"
            } else {
                Write-InstallLog -Message "Extension installed successfully: $Ext" -Level "INFO"
            }
        } else {
            Write-InstallLog -Message "Simulation mode enabled. Would install extension: $Ext" -Level "INFO"
        }
    }
}
