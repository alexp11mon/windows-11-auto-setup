function Invoke-GitConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$UserName = "",
        [string]$UserEmail = ""
    )

    # 1. Check whether Git is installed.
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "Git is not installed or not on this session's PATH. Skipping Git configuration (restart the terminal if it was installed during this run)." -Level "WARNING"
        return
    }

    # 2. In simulation mode without data, do not prompt.
    if ($WhatIfPreference -and ([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($UserEmail))) {
        Write-InstallLog -Message "Simulation mode enabled. Would configure Git (no interactive input)." -Level "INFO"
        return
    }

    # 3. Ask for personal data with basic validation.
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        $UserName = Read-Host "Enter your user name for Git"
    }
    if ([string]::IsNullOrWhiteSpace($UserEmail)) {
        $UserEmail = Read-Host "Enter your email address for Git"
    }

    if ([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($UserEmail)) {
        Write-InstallLog -Message "Empty name or email. Skipping Git configuration." -Level "WARNING"
        return
    }
    if ($UserEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-InstallLog -Message "Invalid email format ('$UserEmail'). Skipping Git configuration." -Level "WARNING"
        return
    }

    # 4. Apply configuration with WhatIf support.
    if ($PSCmdlet.ShouldProcess("Global Git configuration", "Apply aliases and credentials for $UserName")) {
        Write-InstallLog -Message "Applying base Git configuration for $UserName..." -Level "INFO"

        # Quote names with spaces. Native commands do not throw: check $LASTEXITCODE.
        git config --global user.name "$UserName"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Failed to set user.name in Git (code $LASTEXITCODE)." -Level "ERROR"
            return
        }
        git config --global user.email "$UserEmail"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Failed to set user.email in Git (code $LASTEXITCODE)." -Level "ERROR"
            return
        }
        git config --global init.defaultBranch "main"
        git config --global alias.tree "log --graph --decorate --all --oneline"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Failed to set Git defaults/aliases (code $LASTEXITCODE)." -Level "ERROR"
            return
        }

        Write-InstallLog -Message "Git configuration applied successfully. Alias 'tree' created." -Level "INFO"
    } else {
        Write-InstallLog -Message "Simulation mode enabled. Would configure Git for user: $UserName ($UserEmail)." -Level "INFO"
    }
}
