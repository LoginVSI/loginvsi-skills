BeforeAll {
    . (Join-Path $PSScriptRoot 'runner-lib.ps1')
}

Describe 'Get-ScriptOutcome' {
    BeforeAll {
        # Real successful transcript (engine 6.5.10): ends with "The script ended", exits 0.
        $script:successOut = @'
Script Log [Information] 'Starting script'
The script reported a measurement: 'app_start_time' = 2213
Script Log [Information] 'Application.Stop() of application mspaint'
The script ended
'@
        # Real compile-error transcript: prints the CSxxxx error then the construct-failure line.
        $script:compileOut = @'
ID: CS1002, Message: ; expected,Location: (4,42)-(4,42), Severity: Error
We could not construct the script to be executed, exiting
'@
    }

    It 'treats "The script ended" with no failure markers as success (even on exit code 0)' {
        $r = Get-ScriptOutcome -StdoutText $script:successOut -ExitCode 0
        $r.result  | Should -Be 'Ended'
        $r.success | Should -BeTrue
    }
    It 'classifies the construct-failure marker as CompilationError (even on exit code 0)' {
        $r = Get-ScriptOutcome -StdoutText $script:compileOut -ExitCode 0
        $r.result  | Should -Be 'CompilationError'
        $r.success | Should -BeFalse
    }
    It 'treats a failed iteration as failure even though "The script ended" is also printed' {
        $out = "The script did not complete successfully (result: EndedWithErrors)`nThe script ended"
        $r = Get-ScriptOutcome -StdoutText $out
        $r.result  | Should -Be 'EndedWithErrors'
        $r.success | Should -BeFalse
    }
    It 'classifies the unhandled-exception marker as failure' {
        $r = Get-ScriptOutcome -StdoutText "The script encountered an error:`nboom"
        $r.success | Should -BeFalse
    }
    It 'returns Undefined/failure when no marker is present' {
        $r = Get-ScriptOutcome -StdoutText 'some unrelated output'
        $r.result  | Should -Be 'Undefined'
        $r.success | Should -BeFalse
    }
}

Describe 'ConvertFrom-ResultsCsv' {
    BeforeAll {
        $script:csv = Join-Path $TestDrive 'results.csv'
        @(
            '2026-06-06T10:00:00.0000000+00:00,6.6.0,PC1,alice,SmokeNotepad,Type_Body,123'
            '2026-06-06T10:00:01.0000000+00:00,6.6.0,PC1,alice,SmokeNotepad,Save_Latency,1200'
        ) | Set-Content -Path $script:csv -Encoding UTF8
    }
    It 'parses one object per timer line' {
        $t = @(ConvertFrom-ResultsCsv -CsvPath $script:csv)
        $t.Count | Should -Be 2
    }
    It 'maps MeasurementId->name, Result->value, col0->timestamp' {
        $t = @(ConvertFrom-ResultsCsv -CsvPath $script:csv)
        $t[0].name      | Should -Be 'Type_Body'
        $t[0].value     | Should -Be 123
        $t[0].timestamp | Should -Be '2026-06-06T10:00:00.0000000+00:00'
        $t[1].name      | Should -Be 'Save_Latency'
        $t[1].value     | Should -Be 1200
    }
    It 'returns an empty array when the file is missing' {
        (@(ConvertFrom-ResultsCsv -CsvPath (Join-Path $TestDrive 'nope.csv'))).Count | Should -Be 0
    }
    It 'skips blank lines' {
        $p = Join-Path $TestDrive 'withblank.csv'
        @('2026-06-06T10:00:00.0000000+00:00,6.6.0,PC1,alice,App,A,1','') | Set-Content $p -Encoding UTF8
        (@(ConvertFrom-ResultsCsv -CsvPath $p)).Count | Should -Be 1
    }
    It 'parses decimal values with invariant culture' {
        $p = Join-Path $TestDrive 'decimal.csv'
        '2026-06-06T10:00:00.0000000+00:00,6.6.0,PC1,alice,App,Latency,1200.5' | Set-Content $p -Encoding UTF8
        (@(ConvertFrom-ResultsCsv -CsvPath $p))[0].value | Should -Be 1200.5
    }
}

Describe 'Test-ScriptHeader' {
    It 'accepts a // TARGET: header as windows' {
        $r = Test-ScriptHeader -ScriptText "// TARGET:C:\Windows\System32\notepad.exe`npublic class X {}"
        $r.ok   | Should -BeTrue
        $r.kind | Should -Be 'windows'
    }
    It 'accepts a // BROWSER: header as web' {
        $r = Test-ScriptHeader -ScriptText "// BROWSER:EdgeChromium`npublic class X {}"
        $r.ok   | Should -BeTrue
        $r.kind | Should -Be 'web'
    }
    It 'accepts leading whitespace and spacing variations' {
        (Test-ScriptHeader -ScriptText "   //   TARGET: notepad.exe").ok | Should -BeTrue
    }
    It 'rejects a script with no recognized header and explains why' {
        $r = Test-ScriptHeader -ScriptText "using System;`npublic class X {}"
        $r.ok      | Should -BeFalse
        $r.kind    | Should -BeNullOrEmpty
        $r.message | Should -Match 'TARGET'
        $r.message | Should -Match 'BROWSER'
    }
}

Describe 'Build-EngineArgs' {
    It 'always emits script and results' {
        $a = Build-EngineArgs -Settings @{ Script = 'C:\s.cs'; Results = 'C:\out' }
        $a | Should -Contain 'script=C:\s.cs'
        $a | Should -Contain 'results=C:\out'
    }
    It 'includes only the optional keys that were provided' {
        $a = Build-EngineArgs -Settings @{ Script='s.cs'; Results='o'; User='alice'; Repeats=3 }
        $a | Should -Contain 'user=alice'
        $a | Should -Contain 'repeats=3'
        ($a -join ' ') | Should -Not -Match 'password='
        ($a -join ' ') | Should -Not -Match 'parameters='
    }
    It 'serializes booleans lowercase for leaverunning and debug' {
        $a = Build-EngineArgs -Settings @{ Script='s.cs'; Results='o'; LeaveRunning=$true; Debug=$false }
        $a | Should -Contain 'leaverunning=true'
        $a | Should -Contain 'debug=false'
    }
    It 'throws when a required setting is missing' {
        { Build-EngineArgs -Settings @{ Script = 's.cs' } } | Should -Throw '*Results*'
    }
}
