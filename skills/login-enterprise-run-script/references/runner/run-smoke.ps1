<#
.SYNOPSIS
  End-to-end smoke test for the Login Enterprise script runner. Runs smoke-notepad.cs through
  run.ps1 (validate -> run on the standalone engine) and verifies a successful, measured run.

.DESCRIPTION
  Run on Windows with: a deployed ScriptEditor (for both the engine and validation) and a built
  validator (le-validate.dll). Launches Notepad for real — it is an interactive run, not a sandbox.
  Writes smoke-results.txt next to this script; send that file back.

.PARAMETER EngineDir  Folder with LoginEnterprise.Engine.Standalone.exe. If omitted, auto-detected.
.PARAMETER EditorDir  Deployed ScriptEditor root (for validation). If omitted, auto-detected.

.EXAMPLE
  .\run-smoke.ps1 -EngineDir "C:\ScriptEditor\engine" -EditorDir "C:\ScriptEditor"
#>
[CmdletBinding()]
param(
    [string]$EngineDir,
    [string]$EditorDir
)

$ErrorActionPreference = 'Stop'
$root        = $PSScriptRoot
$script      = Join-Path $root '..\examples\smoke-notepad.cs'
$resultsFile = Join-Path $root 'smoke-results.txt'

$script:lines = New-Object System.Collections.Generic.List[string]
function Say([string]$m = '') { $script:lines.Add($m); Write-Host $m }
function Save-AndExit([int]$code) { $script:lines | Set-Content -Path $resultsFile -Encoding UTF8; exit $code }

function Find-EngineDir {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($r in $roots) {
        $exe = Get-ChildItem -Path $r -Recurse -Filter 'LoginEnterprise.Engine.Standalone.exe' -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($exe) { return (Split-Path $exe.FullName -Parent) }
    }
    return $null
}
function Find-EditorRoot {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($r in $roots) {
        $dll = Get-ChildItem -Path $r -Recurse -Filter 'ScriptAnalyzer.dll' -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($dll) { return (Split-Path (Split-Path $dll.FullName -Parent) -Parent) }
    }
    return $null
}

Say "==================================================================="
Say " Login Enterprise runner smoke test"
Say " UTC:     $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
Say " Machine: $env:COMPUTERNAME"
Say " OS:      $([System.Environment]::OSVersion.VersionString)"
Say "==================================================================="

if (-not $EngineDir) { Say " EngineDir: (auto-detecting...)"; $EngineDir = Find-EngineDir }
if (-not $EngineDir -or -not (Test-Path (Join-Path $EngineDir 'LoginEnterprise.Engine.Standalone.exe'))) {
    Say "FATAL: could not resolve EngineDir (folder with LoginEnterprise.Engine.Standalone.exe). Pass -EngineDir."
    Save-AndExit 3
}
if (-not $EditorDir) { Say " EditorDir: (auto-detecting...)"; $EditorDir = Find-EditorRoot }
if (-not $EditorDir -or -not (Test-Path $EditorDir)) {
    Say "FATAL: could not resolve EditorDir (deployed ScriptEditor root). Pass -EditorDir."
    Save-AndExit 3
}
Say " EngineDir: $EngineDir"
Say " EditorDir: $EditorDir"
Say " Script:    $script"
Say ""
Say " NOTE: this launches Notepad for real in the current interactive session."

# --- run the full pipeline ------------------------------------------------------------------
$out = & (Join-Path $root 'run.ps1') -Script $script -EngineDir $EngineDir -EditorDir $EditorDir 2>&1
$runExit = $LASTEXITCODE
Say ""
Say " run.ps1 exit code: $runExit"
Say " run.ps1 output:"
($out | Out-String).TrimEnd().Split("`n") | ForEach-Object { Say "   $_" }

# run.ps1's progress lines use Write-Host (information stream), which 2>&1 does NOT capture into
# $out — so $out holds only run.ps1's success-stream output, i.e. the ConvertTo-Json summary.
# (If those progress lines are ever switched to Write-Output, this parse would need to change.)
$json = $null
try { $json = ($out | Out-String | ConvertFrom-Json) } catch { }

$pass = $false
if ($json) {
    $hasTimer = @($json.timers | Where-Object { $_.name -eq 'Type_Body' }).Count -ge 1
    # Success is the marker-driven verdict, not a specific engine exit code (the engine exits 0 on
    # success on 6.5.10). run.ps1 itself exits 0 when it judges the run successful.
    $pass = ($runExit -eq 0) -and ($json.success -eq $true) -and ($json.result -eq 'Ended') -and $hasTimer
    Say ""
    Say (" success: {0}  result: {1}  engine exitCode: {2}  Type_Body timer present: {3}" -f $json.success, $json.result, $json.exitCode, $hasTimer)
}

Say ""
Say "==================================================================="
Say (" OVERALL: {0}" -f ($(if ($pass) {'PASS'} else {'FAILURE - see above'})))
Say "==================================================================="
Say " Results written to: $resultsFile"
Say " >>> Send that file back (or paste its contents). <<<"
Save-AndExit ($(if ($pass) { 0 } else { 1 }))
