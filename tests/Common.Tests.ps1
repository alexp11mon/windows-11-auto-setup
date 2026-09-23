# Common.Tests.ps1 - Pester 5. Requiere: Install-Module Pester -MinimumVersion 5.0
# Ejecucion futura: Invoke-Pester -Path ./tests -Output Detailed
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
}
Describe 'Common.ps1' {
    Context 'Initialize-InstallLog' {
        It 'Crea un archivo fechado y reutiliza el mismo en la sesion' {
            $p1 = Initialize-InstallLog
            $p2 = Initialize-InstallLog
            $p1 | Should -Be $p2
            $p1 | Should -Match 'install-\d{8}-\d{6}\.log$'
        }
    }
    Context 'Test-AppInstalled' {
        BeforeEach { Mock winget { } }
        It 'Devuelve true si winget list contiene el Id exacto' {
            Mock winget { Write-Output 'Brave.Brave  1.77  winget'; $global:LASTEXITCODE = 0 } -ParameterFilter { ($args -join ' ') -match '^\s*list\b' }
            Test-AppInstalled -AppId 'Brave.Brave' | Should -Be $true
        }
        It 'No hace match parcial (BraveXBrave != Brave.Brave)' {
            Mock winget { Write-Output 'BraveXBrave  1.0'; $global:LASTEXITCODE = 0 } -ParameterFilter { ($args -join ' ') -match '^\s*list\b' }
            Test-AppInstalled -AppId 'Brave.Brave' | Should -Be $false
        }
        It 'Devuelve false si winget falla' {
            Mock winget { $global:LASTEXITCODE = 1 } -ParameterFilter { ($args -join ' ') -match '^\s*list\b' }
            Test-AppInstalled -AppId 'Brave.Brave' | Should -Be $false
        }
    }
    Context 'Install-WingetApp' {
        It 'Omite si ya instalado (idempotente)' {
            Mock Test-AppInstalled { $true }
            Mock winget { throw 'no deberia llamarse' }
            { Install-WingetApp -AppId 'Brave.Brave' -AppName 'Brave' } | Should -Not -Throw
        }
        It 'En -WhatIf no llama a winget install' {
            Mock Test-AppInstalled { $false }
            Mock winget { throw 'no deberia llamarse en WhatIf' } -ParameterFilter { ($args -join ' ') -match 'install' }
            Install-WingetApp -AppId 'Valve.Steam' -AppName 'Steam' -WhatIf
        }
    }
}
