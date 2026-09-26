function Invoke-GitConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$UserName = "",
        [string]$UserEmail = ""
    )

    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "Git is not installed or not on this session's PATH. Skipping Git configuration (open a new terminal if it was installed during this run)." -Level "WARNING"
        return
    }

    # Never prompt in simulation without data (avoids hanging under -WhatIf/automation).
    if ($WhatIfPreference -and ([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($UserEmail))) {
        Write-InstallLog -Message "Simulation mode. Git would be configured (no interactive input)." -Level "INFO"
        return
    }

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

    if ($PSCmdlet.ShouldProcess("Global Git configuration", "Apply identity and alias for $UserName")) {
        Write-InstallLog -Message "Applying base Git configuration for $UserName..." -Level "INFO"

        # Quote the name (it may contain spaces). Native commands do not
        # throw: check $LASTEXITCODE after each one.
        git config --global user.name "$UserName"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Failed to set Git user.name (exit code $LASTEXITCODE)." -Level "ERROR"
            return
        }
        git config --global user.email "$UserEmail"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Failed to set Git user.email (exit code $LASTEXITCODE)." -Level "ERROR"
            return
        }
        git config --global init.defaultBranch "main"
        git config --global alias.tree "log --graph --decorate --all --oneline"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Failed to set Git defaults/alias (exit code $LASTEXITCODE)." -Level "ERROR"
            return
        }

        Write-InstallLog -Message "Git configuration applied successfully. Alias 'tree' created." -Level "INFO"
    } else {
        Write-InstallLog -Message "Simulation mode. Git would be configured for user: $UserName ($UserEmail)." -Level "INFO"
    }
}
