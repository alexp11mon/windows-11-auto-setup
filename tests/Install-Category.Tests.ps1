# Install-Category.Tests.ps1 - Pester 5
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $RepoRoot 'modules/Common.ps1')
    . (Join-Path $RepoRoot 'modules/Install-Category.ps1')
    $script:Apps = Join-Path $RepoRoot 'config/apps.json'
}
Describe 'Install-Category' {
    It 'All expands to 14 apps (4+7+3)' {
        Mock Install-WingetApp { }
        Invoke-InstallCategory -Category 'All' -AppsConfigPath $script:Apps
        Should -Invoke Install-WingetApp -Times 14 -Exactly
    }
    It 'Base installs 4' {
        Mock Install-WingetApp { }
        Invoke-InstallCategory -Category 'Base' -AppsConfigPath $script:Apps
        Should -Invoke Install-WingetApp -Times 4 -Exactly
    }
    It 'Missing file logs ERROR without throwing' {
        Mock Write-InstallLog { }
        { Invoke-InstallCategory -Category 'Base' -AppsConfigPath 'noexiste.json' } | Should -Not -Throw
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'ERROR' }
    }
    It 'Invalid JSON logs ERROR' {
        $bad = Join-Path ([System.IO.Path]::GetTempPath()) 'bad-apps.json'
        '{ invalid' | Set-Content $bad -Encoding UTF8
        Mock Write-InstallLog { }
        Invoke-InstallCategory -Category 'Base' -AppsConfigPath $bad
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'ERROR' }
        Remove-Item $bad -Force -ErrorAction SilentlyContinue
    }
    It 'Empty category logs WARNING' {
        $empty = Join-Path ([System.IO.Path]::GetTempPath()) 'empty-apps.json'
        '{ "Base": [] }' | Set-Content $empty -Encoding UTF8
        Mock Write-InstallLog { }
        Mock Install-WingetApp { }
        Invoke-InstallCategory -Category 'Base' -AppsConfigPath $empty
        Should -Invoke Write-InstallLog -ParameterFilter { $Level -eq 'WARNING' }
        Remove-Item $empty -Force -ErrorAction SilentlyContinue
    }
}
