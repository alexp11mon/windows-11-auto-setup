# Install.Entry.Tests.ps1 - Pester 5. Entry guards of install.ps1 without running it (requires Admin).
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:Entry = Get-Content (Join-Path $RepoRoot 'install.ps1') -Raw
}
Describe 'install.ps1 entry guards' {
    It 'Checks Administrator and exits 1' {
        $script:Entry | Should -Match 'IsInRole.*Administrator'
        $script:Entry | Should -Match 'exit 1'
    }
    It 'Checks Win11 Build>=22000 and 64-bit' {
        $script:Entry | Should -Match '22000'
        $script:Entry | Should -Match 'Is64BitOperatingSystem'
    }
    It 'Checks winget availability' {
        $script:Entry | Should -Match 'Get-Command.*winget'
    }
    It 'Supports -WhatIf and -Category Base/Dev/Gaming/All' {
        $script:Entry | Should -Match 'SupportsShouldProcess'
        $script:Entry | Should -Match "ValidateSet.*Base.*Dev.*Gaming.*All"
    }
    It 'Git/VSCode only on Dev or All and refreshes PATH' {
        $script:Entry | Should -Match 'Update-SessionPath'
        $script:Entry | Should -Match "Category.*Dev"
    }
    It 'Accepts GitUserName/GitUserEmail and passes them to Invoke-GitConfig' {
        $script:Entry | Should -Match 'GitUserName'
        $script:Entry | Should -Match 'GitUserEmail'
        $script:Entry | Should -Match 'Invoke-GitConfig -UserName'
    }
    It 'Propagates errors with InstallHadErrors and exit 1' {
        $script:Entry | Should -Match 'InstallHadErrors'
    }
}
