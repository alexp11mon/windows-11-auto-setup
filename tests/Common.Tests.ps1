# Common.Tests.ps1 - Pester 5. Requires: Install-Module Pester -MinimumVersion 5.0
# Run: Invoke-Pester -Path ./tests -Output Detailed
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
}
Describe 'Common.ps1' {
    Context 'Initialize-InstallLog' {
        It 'Creates a dated file and reuses it within the session' {
            $p1 = Initialize-InstallLog
            $p2 = Initialize-InstallLog
            $p1 | Should -Be $p2
            $p1 | Should -Match 'install-\d{8}-\d{6}\.log$'
        }
    }
    Context 'Test-AppInstalled' {
        BeforeEach { Mock winget { } }
        It 'Returns true when winget list contains the exact Id' {
            Mock winget { Write-Output 'Brave.Brave  1.77  winget'; $global:LASTEXITCODE = 0 } -ParameterFilter { ($args -join ' ') -match '^\s*list\b' }
            Test-AppInstalled -AppId 'Brave.Brave' | Should -Be $true
        }
        It 'Has no partial match (BraveXBrave != Brave.Brave)' {
            Mock winget { Write-Output 'BraveXBrave  1.0'; $global:LASTEXITCODE = 0 } -ParameterFilter { ($args -join ' ') -match '^\s*list\b' }
            Test-AppInstalled -AppId 'Brave.Brave' | Should -Be $false
        }
        It 'Returns false when winget fails' {
            Mock winget { $global:LASTEXITCODE = 1 } -ParameterFilter { ($args -join ' ') -match '^\s*list\b' }
            Test-AppInstalled -AppId 'Brave.Brave' | Should -Be $false
        }
    }
    Context 'Install-WingetApp' {
        It 'Skips when already installed (idempotent)' {
            Mock Test-AppInstalled { $true }
            Mock winget { throw 'must not be called' }
            { Install-WingetApp -AppId 'Brave.Brave' -AppName 'Brave' } | Should -Not -Throw
        }
        It 'Never calls winget install under -WhatIf' {
            Mock Test-AppInstalled { $false }
            Mock winget { throw 'must not be called under WhatIf' } -ParameterFilter { ($args -join ' ') -match 'install' }
            Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam' -WhatIf
        }
    }
    Context 'Write-InstallLog error flag' {
        It 'ERROR sets InstallHadErrors' {
            $global:InstallHadErrors = $false
            Mock Initialize-InstallLog { return (Join-Path ([System.IO.Path]::GetTempPath()) 'pester-flag-test.log') }
            Mock Add-Content { }
            Mock Write-Error { }
            Write-InstallLog -Message 'boom' -Level 'ERROR'
            $global:InstallHadErrors | Should -Be $true
        }
    }
}
