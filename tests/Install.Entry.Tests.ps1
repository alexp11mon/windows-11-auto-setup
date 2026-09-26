# Install.Entry.Tests.ps1 - Pester 5. Guards de install.ps1 sin ejecutarlo (requiere Admin).
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:Entry = Get-Content (Join-Path $RepoRoot 'install.ps1') -Raw
}
Describe 'install.ps1 entry guards' {
    It 'Chequea Administrador y sale 1' {
        $script:Entry | Should -Match 'IsInRole.*Administrator'
        $script:Entry | Should -Match 'exit 1'
    }
    It 'Chequea Win11 Build>=22000 y 64-bit' {
        $script:Entry | Should -Match '22000'
        $script:Entry | Should -Match 'Is64BitOperatingSystem'
    }
    It 'Chequea winget disponible' {
        $script:Entry | Should -Match 'Get-Command.*winget'
    }
    It 'Soporta -WhatIf y -Category Base/Dev/Gaming/All' {
        $script:Entry | Should -Match 'SupportsShouldProcess'
        $script:Entry | Should -Match "ValidateSet.*Base.*Dev.*Gaming.*All"
    }
    It 'Git/VSCode solo con Dev o All y refresca PATH' {
        $script:Entry | Should -Match 'Update-SessionPath'
        $script:Entry | Should -Match "Category.*Dev"
    }
    It 'Acepta GitUserName/GitUserEmail y los pasa a Invoke-GitConfig' {
        $script:Entry | Should -Match 'GitUserName'
        $script:Entry | Should -Match 'GitUserEmail'
        $script:Entry | Should -Match 'Invoke-GitConfig -UserName'
    }
    It 'Omite Git/VSCode con switches sin preguntar' {
        $script:Entry | Should -Match '\[switch\]\$SkipGit'
        $script:Entry | Should -Match '\[switch\]\$SkipVSCode'
        $script:Entry | Should -Match 'skipped via -SkipGit'
        $script:Entry | Should -Match 'skipped via -SkipVSCode'
    }
    It 'Propaga errores con InstallHadErrors y exit 1' {
        $script:Entry | Should -Match 'InstallHadErrors'
    }
}
