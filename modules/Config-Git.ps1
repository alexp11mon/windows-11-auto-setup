function Invoke-GitConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$UserName = "",
        [string]$UserEmail = ""
    )

    # 1. Comprobar si Git esta instalado en el sistema
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-InstallLog -Message "Git no se encuentra instalado. Se omite la configuracion de Git." -Level "WARNING"
        return
    }

    # 2. Solicitar datos personales interactivos
    if ($UserName -eq "") {
        $UserName = Read-Host "Por favor, introduce tu nombre de usuario para Git"
    }
    
    if ($UserEmail -eq "") {
        $UserEmail = Read-Host "Por favor, introduce tu correo electronico para Git"
    }

    # 3. Soporte WhatIf y aplicacion de configuracion
    if ($PSCmdlet.ShouldProcess("Configuracion global de Git", "Aplicar alias y credenciales para $UserName")) {
        Write-InstallLog -Message "Aplicando configuracion base de Git para $UserName..." -Level "INFO"

        try {
            git config --global user.name $UserName
            git config --global user.email $UserEmail
            
            git config --global init.defaultBranch "main"
            git config --global alias.tree "log --graph --decorate --all --oneline"

            Write-InstallLog -Message "Configuracion de Git aplicada con exito. Alias 'tree' creado." -Level "INFO"
        }
        catch {
            Write-InstallLog -Message "Ocurrio un error al configurar Git: $_" -Level "ERROR"
        }
    } else {
        Write-InstallLog -Message "Modo simulacion activado. Se configuraria Git para el usuario: $UserName ($UserEmail)." -Level "INFO"
    }
}