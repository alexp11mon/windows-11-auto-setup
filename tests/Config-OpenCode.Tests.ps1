# Config-OpenCode.Tests.ps1 - Pester 5+
# NOTE: 'opencode' resolves to an external opencode.ps1 shim, which Pester
# cannot Mock (mock registration is dropped). Use plain function overrides
# with call counters instead, as in tests/Runner-Mock.ps1.
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
    . (Join-Path $RepoRoot 'modules/Config-OpenCode.ps1')
    $script:SnapshotPath = Join-Path $RepoRoot 'config/opencode'
}
Describe 'Config-OpenCode' {
    AfterEach {
        Remove-Item function:\opencode -ErrorAction SilentlyContinue
        $global:MockOpencodeCalls = @()
    }
    It 'Omite install si opencode ya esta presente pero aplica config' {
        Mock Get-Command { @{ Name = 'opencode' } } -ParameterFilter { $Name -eq 'opencode' }
        function opencode { $global:MockOpencodeCalls += ($args -join ' '); $global:LASTEXITCODE = 0 }
        Mock Invoke-WebRequest { throw 'no debe descargar si ya instalado' }
        Mock Write-InstallLog { }
        Invoke-OpenCodeConfig -ConfigSourcePath $script:SnapshotPath -DestinationRoot (Join-Path $TestDrive 'opencode-present')
        Should -Invoke Invoke-WebRequest -Times 0
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'already installed' }
    }
    It 'Instala si opencode ausente y verifica version' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'opencode' }
        function opencode { $global:MockOpencodeCalls += ($args -join ' '); $global:LASTEXITCODE = 0 }
        Mock Invoke-WebRequest { Set-Content -Path $OutFile -Value 'exit 0' -Encoding UTF8 } -ParameterFilter { $OutFile }
        Mock Write-InstallLog { }
        Invoke-OpenCodeConfig -ConfigSourcePath $script:SnapshotPath -DestinationRoot (Join-Path $TestDrive 'opencode-absent')
        Should -Invoke Invoke-WebRequest -Times 1
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'succeeded' }
    }
    It 'Version rota se trata como ausente' {
        Mock Get-Command { @{ Name = 'opencode' } } -ParameterFilter { $Name -eq 'opencode' }
        function opencode { $global:MockOpencodeCalls += ($args -join ' '); $global:LASTEXITCODE = 1 }
        Mock Invoke-WebRequest { Set-Content -Path $OutFile -Value 'exit 0' -Encoding UTF8 } -ParameterFilter { $OutFile }
        Mock Write-InstallLog { }
        Invoke-OpenCodeConfig -ConfigSourcePath $script:SnapshotPath -DestinationRoot (Join-Path $TestDrive 'opencode-broken')
        Should -Invoke Invoke-WebRequest -Times 1
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' -and $Message -match 'PATH' }
    }
    It 'Fallo doble de descarga loguea ERROR y continua' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'opencode' }
        Mock Invoke-WebRequest { throw 'mock network failure' }
        Mock Write-InstallLog { }
        Invoke-OpenCodeConfig -ConfigSourcePath $script:SnapshotPath -DestinationRoot (Join-Path $TestDrive 'opencode-dlerror')
        Should -Invoke Invoke-WebRequest -Times 2
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'ERROR' }
    }
    It 'Fusion conserva el fichero del usuario con aviso' {
        Mock Get-Command { @{ Name = 'opencode' } } -ParameterFilter { $Name -eq 'opencode' }
        function opencode { $global:MockOpencodeCalls += ($args -join ' '); $global:LASTEXITCODE = 0 }
        Mock Write-InstallLog { }
        $dest = Join-Path $TestDrive 'opencode-keep'
        $destAgents = Join-Path $dest 'agents'
        New-Item -ItemType Directory -Path $destAgents -Force | Out-Null
        Set-Content -Path (Join-Path $destAgents 'sdd-orchestrator.md') -Value 'user content' -Encoding UTF8
        Invoke-OpenCodeConfig -ConfigSourcePath $script:SnapshotPath -DestinationRoot $dest
        Get-Content -Path (Join-Path $destAgents 'sdd-orchestrator.md') -Raw | Should -Match 'user content'
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' -and $Message -match 'keep' }
    }
    It 'Omite ficheros con secretos con aviso' {
        Mock Get-Command { @{ Name = 'opencode' } } -ParameterFilter { $Name -eq 'opencode' }
        function opencode { $global:MockOpencodeCalls += ($args -join ' '); $global:LASTEXITCODE = 0 }
        Mock Write-InstallLog { }
        $src = Join-Path $TestDrive 'src-secret'
        New-Item -ItemType Directory -Path $src -Force | Out-Null
        Set-Content -Path (Join-Path $src 'evil.md') -Value 'api_key = 12345' -Encoding UTF8
        Set-Content -Path (Join-Path $src 'good.md') -Value 'hello' -Encoding UTF8
        $dest = Join-Path $TestDrive 'opencode-secret'
        Invoke-OpenCodeConfig -ConfigSourcePath $src -DestinationRoot $dest
        Test-Path (Join-Path $dest 'evil.md') | Should -Be $false
        Test-Path (Join-Path $dest 'good.md') | Should -Be $true
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' -and $Message -match 'secret' }
    }
    It '-WhatIf no descarga ni copia' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'opencode' }
        Mock Invoke-WebRequest { throw 'no debe descargar en WhatIf' }
        Mock Write-InstallLog { }
        $dest = Join-Path $TestDrive 'opencode-whatif'
        Invoke-OpenCodeConfig -ConfigSourcePath $script:SnapshotPath -DestinationRoot $dest -WhatIf
        Test-Path $dest | Should -Be $false
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'Simulation' }
    }
    It 'Origen inexistente loguea ERROR' {
        Mock Get-Command { @{ Name = 'opencode' } } -ParameterFilter { $Name -eq 'opencode' }
        function opencode { $global:MockOpencodeCalls += ($args -join ' '); $global:LASTEXITCODE = 0 }
        Mock Write-InstallLog { }
        Invoke-OpenCodeConfig -ConfigSourcePath 'noexiste' -DestinationRoot (Join-Path $TestDrive 'opencode-nosrc')
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'ERROR' }
    }
}
