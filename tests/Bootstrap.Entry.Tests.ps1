# Bootstrap.Entry.Tests.ps1 - Pester 5. Online installer guards without network access.
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:Boot = Get-Content (Join-Path $RepoRoot 'bootstrap.ps1') -Raw
}
Describe 'bootstrap.ps1 online installer' {
    It 'Requires PowerShell 7' {
        $script:Boot | Should -Match 'Major -lt 7'
    }
    It 'Builds the ZIP URL from Repo/Branch' {
        $script:Boot | Should -Match 'archive/refs/heads/'
        $script:Boot | Should -Match '\$Branch'
    }
    It 'Auto-elevates with UAC and validates Category' {
        $script:Boot | Should -Match 'Verb RunAs'
        $script:Boot | Should -Match "ValidateSet.*Base.*Dev.*Gaming.*All"
    }
    It 'Passes Git params and supports KeepDownload' {
        $script:Boot | Should -Match '-GitUserName'
        $script:Boot | Should -Match 'KeepDownload'
    }
    It 'WhatIf exits before any download' {
        $script:Boot.IndexOf('$WhatIfPreference') | Should -BeGreaterThan -1
        $script:Boot.IndexOf('$WhatIfPreference') | Should -BeLessThan $script:Boot.IndexOf('Invoke-WebRequest -Uri')
    }
    It 'Has arrow-key menu with numbered fallback' {
        $script:Boot | Should -Match 'function Show-Menu'
        $script:Boot | Should -Match 'ReadKey'
        $script:Boot | Should -Match 'function Show-NumberedMenu'
        $script:Boot | Should -Match 'KeyAvailable'
    }
    It 'Detects interactive mode and supports iex elevation' {
        $script:Boot | Should -Match 'PSBoundParameters'
        $script:Boot | Should -Match 'selfPath'
        $script:Boot | Should -Match 'bootstrap-iex\.ps1'
    }
    It 'Filters custom apps into the extracted archive' {
        $script:Boot | Should -Match '\$customApps'
        $script:Boot | Should -Match 'Where-Object \{ \$customApps'
    }
    It 'Never closes an iex console (return instead of exit)' {
        $script:Boot | Should -Match '\$isIex = \[string\]::IsNullOrWhiteSpace\(\$PSCommandPath\)'
        $script:Boot | Should -Match 'if \(\$isIex\) \{ return \} else \{ exit'
    }
    It 'Supports SkipGit/SkipVSCode end to end' {
        $script:Boot | Should -Match '\[switch\]\$SkipGit'
        $script:Boot | Should -Match '\[switch\]\$SkipVSCode'
        $script:Boot | Should -Match 'Skip VSCode configuration'
        $script:Boot | Should -Match "\$elevArgs \+= '-SkipGit'"
        $script:Boot | Should -Match "\$installArgs \+= '-SkipVSCode'"
    }
    It 'Elevation is visible (log + exit code, no literal quotes)' {
        $script:Boot | Should -Match 'RedirectStandardOutput'
        $script:Boot | Should -Match 'Elevated installer exited with code'
        $script:Boot | Should -Not -Match '''"\$selfPath"'''
    }
}
