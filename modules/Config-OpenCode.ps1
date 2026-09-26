function Invoke-OpenCodeConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        # Versioned snapshot to restore (agents, skills, plugins, settings).
        [Parameter(Mandatory = $true)]
        [string]$ConfigSourcePath,

        # Global user configuration destination. Overridable for tests.
        [string]$DestinationRoot = (Join-Path $HOME ".config/opencode")
    )

    $InstallerUrl = "https://opencode.ai/install.ps1"

    # Detect an existing install: command present and version check passing.
    # A broken install (version check fails) counts as absent.
    $opencodePresent = $false
    try {
        if (Get-Command "opencode" -ErrorAction SilentlyContinue) {
            opencode --version 2>&1 | Out-Null
            $opencodePresent = ($LASTEXITCODE -eq 0)
        }
    } catch {
        $opencodePresent = $false
    }

    if ($opencodePresent) {
        Write-InstallLog -Message "OpenCode is already installed. Skipping installation." -Level "INFO"
    } elseif ($PSCmdlet.ShouldProcess("OpenCode", "Install via official installer")) {
        $downloaded = $false
        $installerPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("opencode-install-{0}.ps1" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            try {
                Write-InstallLog -Message "Downloading OpenCode installer ($attempt/2): $InstallerUrl" -Level "INFO"
                Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerPath -UseBasicParsing
                $downloaded = $true
                break
            } catch {
                Write-InstallLog -Message "Download attempt $attempt failed: $_" -Level "WARNING"
            }
        }
        if (-not $downloaded) {
            Write-InstallLog -Message "Could not download the OpenCode installer from: $InstallerUrl" -Level "ERROR"
        } else {
            try {
                & $installerPath
                $installerExit = $(if ($?) { $LASTEXITCODE } elseif ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 })
            } catch {
                $installerExit = 1
            } finally {
                Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
            }
            if ($installerExit -ne 0) {
                Write-InstallLog -Message "OpenCode installer returned exit code $installerExit." -Level "ERROR"
            } else {
                # Same-session PATH may not include opencode yet: warn instead of failing.
                $versionOk = $false
                try {
                    opencode --version 2>&1 | Out-Null
                    $versionOk = ($LASTEXITCODE -eq 0)
                } catch {
                    $versionOk = $false
                }
                if ($versionOk) {
                    Write-InstallLog -Message "OpenCode installation succeeded." -Level "INFO"
                } else {
                    Write-InstallLog -Message "OpenCode installer finished but 'opencode' is not on this session's PATH yet. Re-run in a new terminal if configuration is skipped." -Level "WARNING"
                }
            }
        }
    } else {
        Write-InstallLog -Message "Simulation mode. Would install OpenCode via official installer." -Level "INFO"
    }

    # Restore the versioned global configuration (merge, never delete user files).
    # Resolve to an absolute path so relative prefixes compute correctly.
    $resolvedSource = Resolve-Path -Path $ConfigSourcePath -ErrorAction SilentlyContinue
    if ($null -eq $resolvedSource) {
        Write-InstallLog -Message "OpenCode snapshot not found: $ConfigSourcePath" -Level "ERROR"
        return
    }
    $ConfigSourcePath = $resolvedSource.Path
    $sourceFiles = @(Get-ChildItem -Path $ConfigSourcePath -Recurse -File -ErrorAction SilentlyContinue)
    if ($PSCmdlet.ShouldProcess($DestinationRoot, "Restore OpenCode global configuration ($($sourceFiles.Count) files)")) {
        if (-not (Test-Path $DestinationRoot)) {
            New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
        }
        foreach ($file in $sourceFiles) {
            $relative = $file.FullName.Substring($ConfigSourcePath.Length).TrimStart('\', '/')
            if ([string]::IsNullOrWhiteSpace($relative)) { continue }
            $destPath = Join-Path -Path $DestinationRoot -ChildPath $relative

            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            if (($relative -match 'token|password|secret|api[_-]?key') -or ($content -match 'token|password|secret|api[_-]?key')) {
                Write-InstallLog -Message "Skipping '$relative': possible secret detected." -Level "WARNING"
                continue
            }
            if ($file.Name -eq 'opencode.jsonc') {
                try {
                    $null = $content | ConvertFrom-Json
                } catch {
                    Write-InstallLog -Message "Skipping '$relative': invalid JSON ($ConfigSourcePath): $_" -Level "ERROR"
                    continue
                }
            }

            if (-not (Test-Path $destPath)) {
                $destDir = Split-Path -Parent $destPath
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                Write-InstallLog -Message "Restored OpenCode file: $relative" -Level "INFO"
            } elseif ((Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash -eq (Get-FileHash -Path $destPath -Algorithm SHA256).Hash) {
                Write-InstallLog -Message "OpenCode file '$relative' is already applied. Skipping." -Level "INFO"
            } else {
                Write-InstallLog -Message "OpenCode file '$relative' differs. Keeping existing user file." -Level "WARNING"
            }
        }
    } else {
        Write-InstallLog -Message "Simulation mode. Would restore $($sourceFiles.Count) OpenCode files to: $DestinationRoot" -Level "INFO"
    }
}
