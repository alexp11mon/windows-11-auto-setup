# Config-Brave.Tests.ps1 - Pester 5+
# Registry ops run against a scratch HKCU key (created + removed per test),
# never against the real HKLM policy path.
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
    . (Join-Path $RepoRoot 'modules/Config-Brave.ps1')
    $script:BraveExtPath = Join-Path $RepoRoot 'config/brave/extensions.json'
    $script:ScratchRoot = 'HKCU:\Software\Win11InstallerTest'
}
Describe 'Config-Brave' {
    BeforeEach {
        Remove-Item $script:ScratchRoot -Recurse -Force -ErrorAction SilentlyContinue
        Mock Test-AppInstalled { $true }
        Mock Install-WingetApp { }
        Mock Write-InstallLog { }
    }
    AfterEach {
        Remove-Item $script:ScratchRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    It 'Aplica ausentes y omite presentes (idempotente)' {
        $root = Join-Path $script:ScratchRoot 'enforce'
        New-Item -Path $root -Force | Out-Null
        New-ItemProperty -Path $root -Name '1' -Value 'nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx' -Force | Out-Null
        Invoke-BraveConfig -ExtensionsConfigPath $script:BraveExtPath -PolicyRoot $root
        $values = (Get-ItemProperty -Path $root).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' } | Select-Object -ExpandProperty Value
        $values.Count | Should -Be 5
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'already enforced' }
    }
    It 'Brave ausente lo instala primero y luego aplica' {
        $global:MockBraveInstalled = $false
        Mock Test-AppInstalled { $global:MockBraveInstalled }
        Mock Install-WingetApp { $global:MockBraveInstalled = $true }
        Invoke-BraveConfig -ExtensionsConfigPath $script:BraveExtPath -PolicyRoot (Join-Path $script:ScratchRoot 'install-first')
        Should -Invoke Install-WingetApp -ParameterFilter { $AppId -eq 'Brave.Brave' }
        Test-Path (Join-Path $script:ScratchRoot 'install-first') | Should -Be $true
    }
    It 'Brave ausente y sin instalar omite con aviso' {
        Mock Test-AppInstalled { $false }
        $root = Join-Path $script:ScratchRoot 'no-brave'
        Invoke-BraveConfig -ExtensionsConfigPath $script:BraveExtPath -PolicyRoot $root
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' -and $Message -match 'Skipping' }
        Test-Path $root | Should -Be $false
    }
    It 'ID invalido se omite con aviso y el resto se aplica' {
        $src = Join-Path $TestDrive 'brave.json'
        '{"extensions": [{"id": "zzz", "name": "Bad"}, {"id": "ddkjiahejlhfcafbddmgiahcphecmpfh", "name": "uBlock Origin Lite"}]}' | Set-Content -Path $src -Encoding UTF8
        $root = Join-Path $script:ScratchRoot 'bad-id'
        Invoke-BraveConfig -ExtensionsConfigPath $src -PolicyRoot $root
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' -and $Message -match 'invalid' }
        $values = (Get-ItemProperty -Path $root).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' } | Select-Object -ExpandProperty Value
        $values.Count | Should -Be 1
    }
    It 'Fichero inexistente loguea ERROR' {
        Invoke-BraveConfig -ExtensionsConfigPath 'noexiste.json' -PolicyRoot (Join-Path $script:ScratchRoot 'no-file')
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'ERROR' }
    }
    It '-WhatIf no escribe en registro' {
        $root = Join-Path $script:ScratchRoot 'whatif'
        Invoke-BraveConfig -ExtensionsConfigPath $script:BraveExtPath -PolicyRoot $root -WhatIf
        Test-Path $root | Should -Be $false
        Should -Invoke Write-InstallLog -ParameterFilter { $Message -match 'Simulation' }
    }
}
