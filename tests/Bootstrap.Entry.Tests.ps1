# Bootstrap.Entry.Tests.ps1 - Pester 5. Online installer guards without network access.
BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:BootPath = Join-Path $RepoRoot 'bootstrap.ps1'
    $script:Boot = Get-Content $script:BootPath -Raw
    $bootAst = [System.Management.Automation.Language.Parser]::ParseFile($script:BootPath, [ref]$null, [ref]$null)
    $script:AppsData = Get-Content (Join-Path $RepoRoot 'config/apps.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:AppsPath = Join-Path $RepoRoot 'config/apps.json'
    $script:MenuBack = '<back>'
    foreach ($fn in @('ConvertTo-PSLiteral', 'Get-ElevatedCommand', 'Save-RunLogs', 'Show-Menu', 'Get-ConfigScope', 'Read-MenuKey', 'Format-InstallSummary', 'Invoke-InteractiveSetup', 'Invoke-InstallRound')) {
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
        $script:Boot | Should -Match 'machine policy'
    }
    It 'Elevation never mixes -Verb with -Redirect* (RF-28)' {
        $script:Boot | Should -Not -Match 'RedirectStandard'
        $script:Boot | Should -Match 'Installer exited with code'
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
    Context 'Menu keys (spec 004)' {
        BeforeEach {
            function Clear-Host { }
            function Invoke-Keys {
                param([string[]]$Keys, [string[]]$Options, [switch]$Multi, [string[]]$Checked = @(), [int]$Start = 0)
                $script:Keys = [System.Collections.Generic.Queue[string]]::new([string[]]$Keys)
                Show-Menu -Title 'T' -Options $Options -Multi:$Multi -Checked $Checked -Start $Start 6>$null
            }
            Mock Read-MenuKey { [pscustomobject]@{ Key = $script:Keys.Dequeue() } }
        }
        It 'Enter with nothing marked picks the highlighted item (RF-43)' {
            $picked = Invoke-Keys -Keys 'DownArrow', 'Enter' -Options 'A', 'B', 'C' -Multi
            $picked.Count | Should -Be 1
            $picked | Should -Be 'B'
        }
        It 'Fully checked list confirms everything with Enter (RF-44)' {
            $picked = Invoke-Keys -Keys 'Enter' -Options 'A', 'B' -Multi -Checked 'A', 'B'
            $picked.Count | Should -Be 2
            $picked | Should -Be @('A', 'B')
        }
        It 'Unmarking everything and pressing Enter cancels (RF-46)' {
            Invoke-Keys -Keys 'Spacebar', 'DownArrow', 'Spacebar', 'Enter' -Options 'A', 'B' -Multi -Checked 'A', 'B' | Should -BeNullOrEmpty
        }
        It 'Esc goes back instead of cancelling (RF-50)' {
            Invoke-Keys -Keys 'Escape' -Options 'A', 'B' -Multi | Should -Be $script:MenuBack
            Invoke-Keys -Keys 'Escape' -Options 'A', 'B' | Should -Be $script:MenuBack
        }
        It 'Remembers marks and the highlighted option (RF-51)' {
            $picked = Invoke-Keys -Keys 'Enter' -Options 'A', 'B', 'C' -Multi -Checked 'B'
            $picked | Should -Be 'B'
            Invoke-Keys -Keys 'Enter' -Options 'A', 'B', 'C' -Start 2 | Should -Be 2
        }
    }
    Context 'Back, summary and install rounds (spec 005)' {
        BeforeEach {
            $script:Replies = [System.Collections.Generic.Queue[object]]::new()
            $script:Calls = [System.Collections.Generic.List[object]]::new()
            function Invoke-Menu {
                param($Title, $Options, [switch]$Multi, $Checked, $Start)
                $script:Calls.Add([pscustomobject]@{ Title = $Title; Options = $Options; Checked = $Checked; Start = $Start })
                $x = $script:Replies.Dequeue()
                if ($x -is [array]) { , $x } else { $x }
            }
            function Invoke-Setup { param([object[]]$Replies) foreach ($r in $Replies) { $script:Replies.Enqueue($r) }; Invoke-InteractiveSetup -AppsData $script:AppsData 6>$null }
        }
        It 'Summary groups apps by category and lists the config (RF-53)' {
            $sum = Format-InstallSummary -Choices @{ Category = 'All'; Apps = @('Brave.Brave', 'Valve.Steam'); SkipGit = $true; SkipVSCode = $true; SkipOpenCode = $true } -AppsData $script:AppsData
            $sum | Should -Match '(?s)Base:\s+- Brave\.Brave\s+Gaming:\s+- Valve\.Steam'
            $sum | Should -Not -Match 'Dev:'
            $sum | Should -Match 'Git: skipped'
            $sum | Should -Match 'machine policy'
        }
        It 'Back from the summary keeps the marked apps; Install returns the choices (RF-50, RF-51, RF-54)' {
            $got = Invoke-Setup -Replies @(3, @('Valve.Steam'), 1, @('Valve.Steam'), 0)
            $apps = @($script:Calls | Where-Object { $_.Title -match 'Apps to install' })
            @($apps[1].Checked) | Should -Be @('Valve.Steam')
            ($script:Calls[2].Title) | Should -Match 'Are you sure you want to install these programs\?'
            ($script:Calls[2].Options -join ',') | Should -Be 'Install,Back,Cancel'
            $got.Category | Should -Be 'Gaming'
            @($got.Apps) | Should -Be @('Valve.Steam')
            $got.SkipGit | Should -BeTrue
        }
        It 'Exit, Esc on the first menu and Cancel on the summary return nothing (RF-52, RF-54)' {
            Invoke-Setup -Replies @(4) | Should -BeNullOrEmpty
            Invoke-Setup -Replies @($script:MenuBack) | Should -BeNullOrEmpty
            Invoke-Setup -Replies @(3, @('Valve.Steam'), 2) | Should -BeNullOrEmpty
        }
        It 'Each round runs in a child process: UAC only without admin; a refused UAC returns 1 (RF-55)' {
            Mock Start-Process { [pscustomobject]@{ ExitCode = 3 } }
            $p = [ordered]@{ Category = 'Base'; Repo = 'o/r'; Branch = 'master' }
            Invoke-InstallRound -Params $p -IsAdmin $false -ScriptPath '' -RawUrl 'https://x' -LogDir $TestDrive 6>$null | Should -Be 3
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $Verb -eq 'RunAs' }
            Invoke-InstallRound -Params $p -IsAdmin $true -ScriptPath '' -RawUrl 'https://x' -LogDir $TestDrive 6>$null | Should -Be 3
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $NoNewWindow }
            Mock Start-Process { throw 'cancelled' }
            Invoke-InstallRound -Params $p -IsAdmin $false -ScriptPath '' -RawUrl 'https://x' -LogDir $TestDrive 3>$null 6>$null | Should -Be 1
        }
    }
    It 'Get-ConfigScope follows the selected apps (RF-47, RF-48)' {
        $s = Get-ConfigScope -Category 'All' -Apps 'Valve.Steam' -AppsData $script:AppsData
        @($s.Git, $s.VSCode, $s.OpenCode, $s.Brave) | Should -Be @($false, $false, $false, $false)
        $s = Get-ConfigScope -Category 'All' -Apps 'Microsoft.VisualStudioCode', 'Brave.Brave' -AppsData $script:AppsData
        @($s.Git, $s.VSCode, $s.OpenCode, $s.Brave) | Should -Be @($false, $true, $true, $true)
        $s = Get-ConfigScope -Category 'Gaming' -AppsData $script:AppsData
        @($s.Git, $s.VSCode, $s.OpenCode, $s.Brave) | Should -Be @($false, $false, $false, $false)
    }
    It 'Gaming menu lists its apps, asks nothing about Git/VSCode/OpenCode and loops until Exit (RF-44, RF-47, RF-55, RF-56)' {
        $childCmd = @"
`$global:MenuAnswers = [System.Collections.Generic.Queue[string]]::new([string[]]@('4', '1,2,4', '1', '1', '2', '2,3', '1', '2'))
function Read-Host { param(`$Prompt) if (`$global:MenuAnswers.Count) { `$global:MenuAnswers.Dequeue() } else { '' } }
function Invoke-RestMethod { param(`$Uri) Get-Content -Raw '$($script:AppsPath)' -Encoding UTF8 | ConvertFrom-Json }
function Start-Process { param(`$FilePath, `$ArgumentList, `$Verb, [switch]`$Wait, [switch]`$PassThru, [switch]`$NoNewWindow) Write-Host ('FAKE-INSTALL ' + [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String(`$ArgumentList[-1]))); [pscustomobject]@{ ExitCode = 0 } }
Get-Content -Raw '$($script:BootPath)' | Invoke-Expression
exit `$LASTEXITCODE
"@
        $out = '' | & pwsh -NoProfile -OutputFormat Text -EncodedCommand ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childCmd))) *>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Not -Match 'Custom per-app'
        $out | Should -Match 'Apps to install \(Gaming\)'
        $out | Should -Not -Match 'Git configuration\?'
        $out | Should -Match 'Are you sure you want to install these programs\?'
        $out | Should -Match "FAKE-INSTALL .*-Category 'Gaming'.*-Apps 'Valve\.Steam','EpicGames\.EpicGamesLauncher','Discord\.Discord' -SkipGit -SkipVSCode -SkipOpenCode -SkipBrave"
        ([regex]::Matches($out, 'FAKE-INSTALL')).Count | Should -Be 2
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
