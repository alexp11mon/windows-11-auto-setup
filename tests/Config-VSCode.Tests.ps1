# Config-VSCode.Tests.ps1 - Pester 5
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
    . (Join-Path $RepoRoot 'modules/Config-VSCode.ps1')
    $script:ExtPath = Join-Path $RepoRoot 'config/vscode/extensions.json'
}
Describe 'Config-VSCode' {
    It 'Skips with WARNING when code is missing from PATH' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'code' }
        Mock Write-InstallLog { }
        Invoke-VSCodeConfig -ExtensionsConfigPath $script:ExtPath
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' }
    }
    It 'Installs only missing ones (idempotent)' {
        Mock Get-Command { @{ Name = 'code' } } -ParameterFilter { $Name -eq 'code' }
        Mock code { Write-Output 'ecmel.vscode-html-css'; $global:LASTEXITCODE = 0 } -ParameterFilter { ($args -join ' ') -match 'list-extensions' }
        Mock code { $global:LASTEXITCODE = 0 } -ParameterFilter { ($args -join ' ') -match 'install-extension' }
        Mock Write-InstallLog { }
        Invoke-VSCodeConfig -ExtensionsConfigPath $script:ExtPath
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'already installed' }
    }
    It '-WhatIf installs nothing' {
        Mock Get-Command { @{ Name = 'code' } } -ParameterFilter { $Name -eq 'code' }
        Mock code { Write-Output ''; $global:LASTEXITCODE = 0 } -ParameterFilter { ($args -join ' ') -match 'list-extensions' }
        Mock code { throw 'must not install under WhatIf' } -ParameterFilter { ($args -join ' ') -match 'install-extension' }
        Invoke-VSCodeConfig -ExtensionsConfigPath $script:ExtPath -WhatIf
    }
    It 'Missing file logs ERROR' {
        Mock Get-Command { @{ Name = 'code' } } -ParameterFilter { $Name -eq 'code' }
        Mock Write-InstallLog { }
        Invoke-VSCodeConfig -ExtensionsConfigPath 'noexiste.json'
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'ERROR' }
    }
    It 'extensions.json uses the new Python Envs ID' {
        $data = Get-Content $script:ExtPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $data.extensions | Should -Contain 'ms-python.vscode-python-envs'
        $data.extensions | Should -Not -Contain 'ms-python.python-envs'
    }
}
