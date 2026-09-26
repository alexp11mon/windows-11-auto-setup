function Invoke-VSCodeConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        # Resolved by install.ps1 to avoid relying on $PSScriptRoot
        # inside a dot-sourced function.
        [Parameter(Mandatory = $true)]
        [string]$ExtensionsConfigPath
    )

    if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "VSCode ('code' command) is not available on this session's PATH. Skipping (open a new terminal if it was installed during this run)." -Level "WARNING"
        return
    }

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

    # Read the installed list once so present extensions are skipped.
    Write-InstallLog -Message "Reading current VSCode extensions..." -Level "INFO"
    $InstalledExtensions = code --list-extensions 2>&1
    if ($LASTEXITCODE -ne 0 -or $null -eq $InstalledExtensions) {
        Write-InstallLog -Message "Could not list installed extensions (exit code $LASTEXITCODE). Attempting installation anyway." -Level "WARNING"
        $InstalledExtensions = @()
    }

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
                Write-InstallLog -Message "Failed to install extension '$Ext' (exit code $LASTEXITCODE)." -Level "ERROR"
            } else {
                Write-InstallLog -Message "Extension installed successfully: $Ext" -Level "INFO"
            }
        } else {
            Write-InstallLog -Message "Simulation mode. Would install extension: $Ext" -Level "INFO"
        }
    }
}
