function Invoke-GitConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$UserName = "",
        [string]$UserEmail = ""
    )

    # 1. Comprobar si Git está instalado en el sistema.
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "Git no se encuentra instalado o no esta en el PATH de esta sesion. Se omite la configuracion de Git (reinicia la terminal si se instalo en esta misma ejecucion)." -Level "WARNING"
        return
    }

    # 2. En modo simulacion sin datos, no preguntar (evita bloqueo en -WhatIf/automatizacion).
    if ($WhatIfPreference -and ([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($UserEmail))) {
        Write-InstallLog -Message "Modo simulacion activado. Se configuraria Git (sin datos interactivos)." -Level "INFO"
        return
    }

    # 3. Solicitar datos personales interactivos con validación básica.
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        $UserName = Read-Host "Por favor, introduce tu nombre de usuario para Git"
    }
    if ([string]::IsNullOrWhiteSpace($UserEmail)) {
        $UserEmail = Read-Host "Por favor, introduce tu correo electronico para Git"
    }

    if ([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($UserEmail)) {
        Write-InstallLog -Message "Nombre o email vacios. Se omite la configuracion de Git." -Level "WARNING"
        return
    }
    if ($UserEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-InstallLog -Message "Email con formato invalido ('$UserEmail'). Se omite la configuracion de Git." -Level "WARNING"
        return
    }

    # 4. Soporte WhatIf y aplicación de configuración.
    if ($PSCmdlet.ShouldProcess("Configuracion global de Git", "Aplicar alias y credenciales para $UserName")) {
        Write-InstallLog -Message "Aplicando configuracion base de Git para $UserName..." -Level "INFO"

        # Nota: entrecomillar para soportar nombres con espacios. Los comandos
        # nativos no lanzan excepciones: hay que comprobar $LASTEXITCODE.
        git config --global user.name "$UserName"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Fallo al configurar user.name en Git (codigo $LASTEXITCODE)." -Level "ERROR"
            return
        }
        git config --global user.email "$UserEmail"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Fallo al configurar user.email en Git (codigo $LASTEXITCODE)." -Level "ERROR"
            return
        }
        git config --global init.defaultBranch "main"
        git config --global alias.tree "log --graph --decorate --all --oneline"
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog -Message "Fallo al configurar valores por defecto/alias en Git (codigo $LASTEXITCODE)." -Level "ERROR"
            return
        }

        Write-InstallLog -Message "Configuracion de Git aplicada con exito. Alias 'tree' creado." -Level "INFO"
    } else {
        Write-InstallLog -Message "Modo simulacion activado. Se configuraria Git para el usuario: $UserName ($UserEmail)." -Level "INFO"
    }
}
