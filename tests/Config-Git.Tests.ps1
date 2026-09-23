# Config-Git.Tests.ps1 - Pester 5
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
    . (Join-Path $RepoRoot 'modules/Config-Git.ps1')
}
Describe 'Config-Git' {
    It 'Omite con WARNING si git no esta en PATH' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
        Mock Write-InstallLog { }
        { Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com' } | Should -Not -Throw
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' }
    }
    It 'Rechaza email invalido sin ejecutar git' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git { throw 'no debe ejecutarse' }
        Mock Write-InstallLog { }
        Invoke-GitConfig -UserName 'Test' -UserEmail 'no-es-email'
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' }
    }
    It 'Aplica user.name, user.email, defaultBranch y alias tree' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git { $global:LASTEXITCODE = 0 }
        Invoke-GitConfig -UserName 'Test User' -UserEmail 'test@example.com'
        Should -Invoke git -Times 4 -Exactly
    }
    It '-WhatIf no ejecuta git' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git { throw 'no debe ejecutarse en WhatIf' }
        Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com' -WhatIf
    }
    It '-WhatIf sin params no pide Read-Host ni bloquea' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock Read-Host { throw 'no debe preguntar en WhatIf' }
        Mock git { throw 'no debe ejecutarse' }
        Mock Write-InstallLog { }
        { Invoke-GitConfig -WhatIf } | Should -Not -Throw
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'sin datos interactivos' }
    }
}
