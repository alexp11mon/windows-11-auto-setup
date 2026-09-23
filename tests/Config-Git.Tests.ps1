# Config-Git.Tests.ps1 - Pester 5
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
    . (Join-Path $RepoRoot 'modules/Config-Git.ps1')
}
Describe 'Config-Git' {
    It 'Skips with WARNING when git is missing from PATH' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
        Mock Write-InstallLog { }
        { Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com' } | Should -Not -Throw
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' }
    }
    It 'Rejects invalid email without running git' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git { throw 'must not run' }
        Mock Write-InstallLog { }
        Invoke-GitConfig -UserName 'Test' -UserEmail 'not-an-email'
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' }
    }
    It 'Applies user.name, user.email, defaultBranch and tree alias' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git { $global:LASTEXITCODE = 0 }
        Invoke-GitConfig -UserName 'Test User' -UserEmail 'test@example.com'
        Should -Invoke git -Times 4 -Exactly
    }
    It '-WhatIf never runs git' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock git { throw 'must not run under WhatIf' }
        Invoke-GitConfig -UserName 'Test' -UserEmail 'test@example.com' -WhatIf
    }
    It '-WhatIf without params never prompts for Read-Host' {
        Mock Get-Command { @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
        Mock Read-Host { throw 'must not prompt under WhatIf' }
        Mock git { throw 'must not run' }
        Mock Write-InstallLog { }
        { Invoke-GitConfig -WhatIf } | Should -Not -Throw
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'no interactive input' }
    }
}
