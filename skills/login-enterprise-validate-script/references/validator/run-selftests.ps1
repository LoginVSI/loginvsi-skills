<#
.SYNOPSIS
  Build the Login Enterprise script validator against a deployed ScriptEditor and run the two
  bundled self-tests, then write a results file to hand back.

.DESCRIPTION
  Run this on Windows after pulling the repo, with a deployed ScriptEditor available (the
  unzipped folder containing bin\, ReferenceAssemblies\ and ScriptEditor.Config).

  It:
    1. Resolves EditorRoot (param or auto-detect under Program Files / LOCALAPPDATA).
    2. Verifies the deployment has what the validator needs.
    3. Builds the validator with -p:EditorRoot (no NuGet — uses the deployed Roslyn).
    4. Runs _selftest-bad.cs (must FAIL: exit 1, compiles:true, 3 specific rule errors).
    5. Runs measured-notepad.cs (must PASS: exit 0, compiles:true, no findings).
    6. Writes selftest-results.txt next to this script and prints an overall verdict.

  Send back the generated selftest-results.txt (or paste its contents).

.PARAMETER EditorRoot
  Deployed ScriptEditor folder (contains bin\, ReferenceAssemblies\, ScriptEditor.Config).
  If omitted, the script searches Program Files / Program Files (x86) / LOCALAPPDATA.

.PARAMETER Configuration
  Build configuration. Default: Release.

.EXAMPLE
  .\run-selftests.ps1 -EditorRoot "C:\Program Files\Login VSI\ScriptEditor"
#>
[CmdletBinding()]
param(
    [string]$EditorRoot,
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$root      = $PSScriptRoot
$examples  = Join-Path $root '..\examples'
$badScript = Join-Path $examples '_selftest-bad.cs'
$goodScript= Join-Path $examples 'measured-notepad.cs'
$resultsFile = Join-Path $root 'selftest-results.txt'

# Collect every line into a transcript we both print and save.
$script:lines = New-Object System.Collections.Generic.List[string]
function Say([string]$msg = '') { $script:lines.Add($msg); Write-Host $msg }

function Get-GitHead {
    try { (& git -C $root rev-parse HEAD 2>$null).Trim() } catch { '(git not available)' }
}

# --- auto-detect EditorRoot ----------------------------------------------------------------
function Find-EditorRoot {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($r in $roots) {
        $dll = Get-ChildItem -Path $r -Recurse -Filter 'ScriptAnalyzer.dll' -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($dll) {
            # ScriptAnalyzer.dll lives in <root>\bin\ -> EditorRoot is two levels up.
            return (Split-Path (Split-Path $dll.FullName -Parent) -Parent)
        }
    }
    return $null
}

Say "==================================================================="
Say " Login Enterprise validator self-tests"
Say " UTC:        $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
Say " Machine:    $env:COMPUTERNAME"
Say " OS:         $([System.Environment]::OSVersion.VersionString)"
Say " Repo HEAD:  $(Get-GitHead)"
Say "==================================================================="

# --- dotnet ---------------------------------------------------------------------------------
try { $dotnetVersion = (& dotnet --version) 2>$null } catch { $dotnetVersion = $null }
if (-not $dotnetVersion) {
    Say "FATAL: 'dotnet' not found on PATH. Install the .NET 8 SDK and retry."
    $script:lines | Set-Content -Path $resultsFile -Encoding UTF8
    exit 3
}
Say " dotnet SDK: $dotnetVersion"

# --- resolve + validate EditorRoot ----------------------------------------------------------
if (-not $EditorRoot) {
    Say " EditorRoot: (auto-detecting...)"
    $EditorRoot = Find-EditorRoot
}
if (-not $EditorRoot -or -not (Test-Path $EditorRoot)) {
    Say "FATAL: Could not resolve a deployed ScriptEditor. Pass -EditorRoot ""C:\Path\To\ScriptEditor""."
    $script:lines | Set-Content -Path $resultsFile -Encoding UTF8
    exit 3
}
$EditorRoot = (Resolve-Path $EditorRoot).Path
Say " EditorRoot: $EditorRoot"

$checks = [ordered]@{
    'bin\Microsoft.CodeAnalysis.dll'                 = Join-Path $EditorRoot 'bin\Microsoft.CodeAnalysis.dll'
    'bin\Microsoft.CodeAnalysis.CSharp.dll'          = Join-Path $EditorRoot 'bin\Microsoft.CodeAnalysis.CSharp.dll'
    'bin\ScriptAnalyzer.dll'                         = Join-Path $EditorRoot 'bin\ScriptAnalyzer.dll'
    'ReferenceAssemblies\LoginPI.Engine.ScriptBase'  = Join-Path $EditorRoot 'ReferenceAssemblies\LoginPI.Engine.ScriptBase'
}
Say ""
Say " Deployment checks:"
$missingDeps = $false
foreach ($k in $checks.Keys) {
    $ok = Test-Path $checks[$k]
    if (-not $ok) { $missingDeps = $true }
    Say ("   [{0}] {1}" -f ($(if ($ok) {'OK'} else {'MISSING'}), $k))
}
if ($missingDeps) {
    Say ""
    Say "FATAL: deployment is missing required files (see MISSING above). Is -EditorRoot the"
    Say "       folder that contains bin\ and ReferenceAssemblies\ ?"
    $script:lines | Set-Content -Path $resultsFile -Encoding UTF8
    exit 3
}

# --- build ----------------------------------------------------------------------------------
Say ""
Say " Building validator (no NuGet; deployed Roslyn via -p:EditorRoot)..."
Push-Location $root
$buildLog = & dotnet build -c $Configuration -p:EditorRoot="$EditorRoot" --nologo 2>&1
$buildExit = $LASTEXITCODE
Pop-Location
if ($buildExit -ne 0) {
    Say "FATAL: build failed (exit $buildExit). Build output:"
    $buildLog | ForEach-Object { Say "   $_" }
    $script:lines | Set-Content -Path $resultsFile -Encoding UTF8
    exit 3
}
$dll = Join-Path $root "bin\$Configuration\net8.0\le-validate.dll"
if (-not (Test-Path $dll)) {
    Say "FATAL: build reported success but $dll is missing."
    $script:lines | Set-Content -Path $resultsFile -Encoding UTF8
    exit 3
}
Say " Build OK -> $dll"

# --- run one validation ---------------------------------------------------------------------
function Invoke-Validate([string]$scriptPath) {
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $out  = & dotnet $dll --script $scriptPath --editor-dir $EditorRoot 2>$errFile
        $code = $LASTEXITCODE
        $err  = Get-Content $errFile -Raw
    } finally {
        Remove-Item $errFile -ErrorAction SilentlyContinue
    }
    $text = ($out | Out-String)
    $json = $null
    try { $json = $text | ConvertFrom-Json } catch { }
    [pscustomobject]@{ Exit = $code; Text = $text; Stderr = $err; Json = $json }
}

# --- BAD self-test --------------------------------------------------------------------------
Say ""
Say "-------------------------------------------------------------------"
Say " SELF-TEST 1 (BAD): _selftest-bad.cs"
Say "   expect: exit 1, compiles=true, rules = SpacelessNameDiagnostic, StartTimerDiagnostic, StopTimerDiagnostic"
Say "-------------------------------------------------------------------"
$bad = Invoke-Validate $badScript
Say (" exit code: {0}" -f $bad.Exit)
if ($bad.Stderr) { Say " stderr: $($bad.Stderr.Trim())" }
Say " output:"
$bad.Text.TrimEnd().Split("`n") | ForEach-Object { Say "   $_" }

$expectedBad = @('SpacelessNameDiagnostic','StartTimerDiagnostic','StopTimerDiagnostic')
$badIds = @()
if ($bad.Json) { $badIds = @($bad.Json.findings.id) }
$badMissing = @($expectedBad | Where-Object { $_ -notin $badIds })
$badPass = ($bad.Exit -eq 1) -and ($bad.Json) -and ($bad.Json.compiles -eq $true) -and ($badMissing.Count -eq 0)
Say (" BAD verdict: {0}" -f ($(if ($badPass) {'PASS'} else {'FAIL'})))
if (-not $badPass -and $badMissing.Count -gt 0) { Say ("   missing expected rules: {0}" -f ($badMissing -join ', ')) }

# --- GOOD self-test -------------------------------------------------------------------------
Say ""
Say "-------------------------------------------------------------------"
Say " SELF-TEST 2 (GOOD): measured-notepad.cs"
Say "   expect: exit 0, compiles=true, no findings"
Say "-------------------------------------------------------------------"
$good = Invoke-Validate $goodScript
Say (" exit code: {0}" -f $good.Exit)
if ($good.Stderr) { Say " stderr: $($good.Stderr.Trim())" }
Say " output:"
$good.Text.TrimEnd().Split("`n") | ForEach-Object { Say "   $_" }

$goodFindings = if ($good.Json) { @($good.Json.findings).Count } else { -1 }
$goodPass = ($good.Exit -eq 0) -and ($good.Json) -and ($good.Json.compiles -eq $true) -and ($goodFindings -eq 0)
Say (" GOOD verdict: {0}" -f ($(if ($goodPass) {'PASS'} else {'FAIL'})))

# --- summary --------------------------------------------------------------------------------
$allPass = $badPass -and $goodPass
Say ""
Say "==================================================================="
Say (" OVERALL: {0}" -f ($(if ($allPass) {'ALL PASS'} else {'FAILURE - see above'})))
Say "==================================================================="
Say ""
Say " Results written to: $resultsFile"
Say " >>> Send that file back (or paste its contents). <<<"

$script:lines | Set-Content -Path $resultsFile -Encoding UTF8
if ($allPass) { exit 0 } else { exit 1 }
