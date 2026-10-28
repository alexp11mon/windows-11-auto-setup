# Bootstrap.Entry.Tests.ps1 - Pester 5. Online installer guards without network access.
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:BootPath = Join-Path $RepoRoot 'bootstrap.ps1'
    $script:Boot = Get-Content $script:BootPath -Raw
    $bootAst = [System.Management.Automation.Language.Parser]::ParseFile($script:BootPath, [ref]$null, [ref]$null)
    foreach ($fn in @('ConvertTo-PSLiteral', 'Get-ElevatedCommand', 'Save-RunLogs')) {
        $fnAst = $bootAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true)
        . ([scriptblock]::Create($fnAst.Extent.Text))
    }
}
Describe 'bootstrap.ps1 online installer' {
    It 'Requires PowerShell 7' {
        $script:Boot | Should -Match 'Major -lt 7'
    }
    It 'Builds the ZIP URL from a branch or release tag' {
        $script:Boot | Should -Match 'github\.com/\$Repo/archive/\$Branch\.zip'
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
    It 'Detects interactive mode' {
        $script:Boot | Should -Match 'PSBoundParameters'
    }
    It 'Filters -Apps into the extracted archive' {
        $script:Boot | Should -Match '\[string\[\]\]\$Apps'
        $script:Boot | Should -Match 'Where-Object \{ \$Apps -contains'
    }
    It 'Never closes an iex console (return instead of exit)' {
        $script:Boot | Should -Match '\$isIex = \[string\]::IsNullOrWhiteSpace\(\$PSCommandPath\)'
        $script:Boot | Should -Match 'if \(\$isIex\) \{ return \} else \{ exit'
    }
    It 'Supports SkipGit/SkipVSCode end to end' {
        $script:Boot | Should -Match '\[switch\]\$SkipGit'
        $script:Boot | Should -Match '\[switch\]\$SkipVSCode'
        $script:Boot | Should -Match 'Skip VSCode configuration'
        $script:Boot | Should -Match "\`$elevSwitches \+= 'SkipGit'"
        $script:Boot | Should -Match "\`$installArgs \+= '-SkipVSCode'"
    }
    It 'Supports SkipOpenCode/SkipBrave end to end' {
        $script:Boot | Should -Match '\[switch\]\$SkipOpenCode'
        $script:Boot | Should -Match '\[switch\]\$SkipBrave'
        $script:Boot | Should -Match "\`$elevSwitches \+= 'SkipOpenCode'"
        $script:Boot | Should -Match "\`$installArgs \+= '-SkipBrave'"
    }
    It 'Menu asks for OpenCode; Brave applies automatically and says it is forced by policy' {
        $script:Boot | Should -Match 'OpenCode configuration\?'
        $script:Boot | Should -Not -Match 'Brave configuration\?'
        $script:Boot | Should -Match 'braveApplies'
        $script:Boot | Should -Match 'machine policy'
    }
    It 'Elevation never mixes -Verb with -Redirect* (RF-28)' {
        $script:Boot | Should -Not -Match 'RedirectStandard'
        $script:Boot | Should -Match 'Elevated installer exited with code'
    }
    It 'Starts under iex without param-block errors (real one-liner path)' {
        $out = & pwsh -NoProfile -NonInteractive -Command "Get-Content -Raw '$($script:BootPath)' | Invoke-Expression" 2>&1 | Out-String
        $out | Should -Not -Match 'Invoke-Expression:'
        $out | Should -Match 'Cancelled'
    }
    It 'Never writes its own code to TEMP under iex (RF-30)' {
        $script:Boot | Should -Not -Match 'bootstrap-iex\.ps1'
        $script:Boot | Should -Not -Match 'MyCommand\.ScriptBlock'
        $cmd = Get-ElevatedCommand -ScriptPath '' -RawUrl 'https://raw.githubusercontent.com/o/r/master/bootstrap.ps1' -Params ([ordered]@{ Category = 'Base' })
        $cmd | Should -Match "Invoke-RestMethod -Uri 'https://raw\.githubusercontent\.com/o/r/master/bootstrap\.ps1'"
        $cmd | Should -Match 'scriptblock\]::Create'
        $cmd | Should -Not -Match 'Set-Content'
    }
    It 'Elevated command round-trips spaces, quotes, -Apps and the exit code (RF-28, RF-29)' {
        $child = Join-Path $TestDrive 'fake child.ps1'
        $out = Join-Path $TestDrive 'out.json'
        @"
param([string]`$Category, [string]`$Repo, [string]`$Branch, [string]`$GitUserName, [string[]]`$Apps, [switch]`$SkipBrave)
[pscustomobject]@{ GitUserName = `$GitUserName; Apps = `$Apps; SkipBrave = [bool]`$SkipBrave } | ConvertTo-Json | Set-Content -Path '$out' -Encoding UTF8
exit 7
"@ | Set-Content -Path $child -Encoding UTF8
        $params = [ordered]@{ Category = 'All'; Repo = 'o/r'; Branch = 'master'; GitUserName = "Ana O'Brien"; Apps = @('Valve.Steam', 'Discord.Discord') }
        $cmd = Get-ElevatedCommand -ScriptPath $child -RawUrl 'https://example.invalid' -Params $params -Switches @('SkipBrave')
        & pwsh -NoProfile -EncodedCommand ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd)))
        $LASTEXITCODE | Should -Be 7
        $got = Get-Content $out -Raw | ConvertFrom-Json
        $got.GitUserName | Should -Be "Ana O'Brien"
        @($got.Apps) | Should -Be @('Valve.Steam', 'Discord.Discord')
        $got.SkipBrave | Should -BeTrue
    }
    It 'Keeps logs outside the deleted work folder (RF-31)' {
        $src = Join-Path $TestDrive 'repo/logs'
        $dst = Join-Path $TestDrive 'archive/logs'
        New-Item -ItemType Directory -Path $src -Force | Out-Null
        'line' | Set-Content -Path (Join-Path $src 'install-1.log')
        Save-RunLogs -SourceDir $src -Destination $dst 6>$null
        Remove-Item (Join-Path $TestDrive 'repo') -Recurse -Force
        Test-Path (Join-Path $dst 'install-1.log') | Should -BeTrue
        $script:Boot.IndexOf('Save-RunLogs -SourceDir') | Should -BeLessThan $script:Boot.LastIndexOf('Remove-Item -Path $workDir')
    }
    It 'Verifies -Sha256 before extracting (RF-32)' {
        $pattern = ((Get-Command $script:BootPath).Parameters['Sha256'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }).RegexPattern
        ('a' * 64) | Should -Match $pattern
        ('A' * 64) | Should -Match $pattern
        ('a' * 63) | Should -Not -Match $pattern
        '' | Should -Match $pattern  # under iex the empty default is validated too
        $script:Boot.IndexOf('Get-FileHash -Path $zipPath') | Should -BeLessThan $script:Boot.IndexOf('Expand-Archive')
        $script:Boot | Should -Match 'SHA256 mismatch'
    }
}
