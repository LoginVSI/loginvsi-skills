<#
.SYNOPSIS
  Run a Login Enterprise .cs script on the standalone engine, validating it first by default.

.DESCRIPTION
  Pipeline (design option A — the wrapper owns the validation gate):
    1. Validate (unless -SkipValidation) by invoking the sibling validator's le-validate.dll.
       Aborts before launching the engine unless compiles:true with zero error-severity findings.
    2. Pre-flight the required header comment (// TARGET: or // BROWSER:).
    3. Run LoginEnterprise.Engine.Standalone.exe with a results= folder so timers are captured.
    4. Normalize the ScriptResult exit code (1 = success) and emit a JSON summary.
  Windows only (the engine is a .NET Framework 4.8 executable).

.PARAMETER Script        Path to the .cs script to run (required).
.PARAMETER EngineDir     Folder containing LoginEnterprise.Engine.Standalone.exe (required).
.PARAMETER EditorDir     Deployed ScriptEditor root, passed to the validator. Required unless -SkipValidation.
.PARAMETER ValidatorDll  Override path to le-validate.dll. Default: the sibling validator skill's build output.
.PARAMETER SkipValidation Bypass the default validate-first gate.
.PARAMETER Results       Results output folder. Default: a fresh temp folder.
.PARAMETER Parameters    Path to a .prm parameters file.
.PARAMETER User          Username, exposed to the script as __user__.
.PARAMETER Password      Password, exposed as __password__.
.PARAMETER Repeats       Number of repetitions (default 1).
.PARAMETER LeaveRunning  Leave the app running after execution.
.PARAMETER DebugMode     Application debug mode (engine debug=true). Named DebugMode, not Debug,
                         to avoid colliding with CmdletBinding's automatic -Debug common parameter.

.EXAMPLE
  .\run.ps1 -Script C:\s\Login.cs -EngineDir "C:\ScriptEditor\engine" -EditorDir "C:\ScriptEditor"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Script,
    [Parameter(Mandatory)][string]$EngineDir,
    [string]$EditorDir,
    [string]$ValidatorDll,
    [switch]$SkipValidation,
    [string]$Results,
    [string]$Parameters,
    [string]$User,
    [string]$Password,
    [int]$Repeats = 1,
    [switch]$LeaveRunning,
    [switch]$DebugMode
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'runner-lib.ps1')

function Fail([string]$msg, [int]$code = 3) {
    Write-Host "FATAL: $msg" -ForegroundColor Red
    exit $code
}

# --- platform + prerequisite checks ---------------------------------------------------------
if ($env:OS -ne 'Windows_NT') {
    Fail "The standalone engine requires Windows. This script cannot run on $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)."
}

if (-not $SkipValidation) {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCmd) {
        Fail "dotnet not found on PATH. The validator requires the .NET 8 SDK.`nInstall from: https://dotnet.microsoft.com/download/dotnet/8.0"
    }
}

# --- resolve inputs -------------------------------------------------------------------------
if (-not (Test-Path $Script)) { Fail "Script not found: $Script" }
$Script = (Resolve-Path $Script).Path

$exe = Join-Path $EngineDir 'LoginEnterprise.Engine.Standalone.exe'
if (-not (Test-Path $exe)) { Fail "Engine not found: $exe (is -EngineDir the folder with the standalone exe?)" }

if (-not $ValidatorDll) {
    $ValidatorDll = Join-Path $PSScriptRoot '..\..\..\login-enterprise-script-validator\references\validator\bin\Release\net8.0\le-validate.dll'
}

# --- 1. validate (default gate) -------------------------------------------------------------
if (-not $SkipValidation) {
    if (-not (Test-Path $ValidatorDll)) {
        Fail ("Validator not built: $ValidatorDll`n" +
              "Build it once via the login-enterprise-script-validator skill's install.ps1, " +
              "or pass -ValidatorDll, or re-run with -SkipValidation.")
    }
    if (-not $EditorDir) { Fail "Validation requires -EditorDir (the deployed ScriptEditor root). Or use -SkipValidation." }

    Write-Host " Validating $Script ..."
    $vOut  = & dotnet $ValidatorDll --script $Script --editor-dir $EditorDir 2>&1
    $vJson = $null
    try { $vJson = ($vOut | Out-String | ConvertFrom-Json) } catch { }
    if (-not $vJson) { Fail "Validator produced no parseable JSON. Output:`n$($vOut | Out-String)" }

    $errFindings = @($vJson.findings | Where-Object { $_.severity -eq 'Error' })
    if (-not $vJson.compiles -or $errFindings.Count -gt 0) {
        Write-Host " Validation FAILED — not running the engine:" -ForegroundColor Red
        Write-Host ("  compiles: {0}" -f $vJson.compiles)
        foreach ($f in @($vJson.findings)) {
            Write-Host ("  [{0}] {1} (line {2}): {3}" -f $f.severity, $f.id, $f.line, $f.message)
        }
        exit 1
    }
    Write-Host " Validation passed." -ForegroundColor Green
} else {
    Write-Host " -SkipValidation set — running WITHOUT validating." -ForegroundColor Yellow
}

# --- 2. header pre-flight -------------------------------------------------------------------
$header = Test-ScriptHeader -ScriptText (Get-Content -Path $Script -Raw)
if (-not $header.ok) { Fail $header.message }

# --- 3. run the engine ----------------------------------------------------------------------
if (-not $Results) {
    $Results = Join-Path ([System.IO.Path]::GetTempPath()) ("le-runner-" + [System.IO.Path]::GetRandomFileName())
}
New-Item -ItemType Directory -Force -Path $Results | Out-Null
$Results = (Resolve-Path $Results).Path

$settings = @{ Script = $Script; Results = $Results; Repeats = $Repeats }
if ($Parameters) { $settings.Parameters = $Parameters }
if ($User)       { $settings.User       = $User }
if ($Password)   { $settings.Password   = $Password }
if ($PSBoundParameters.ContainsKey('LeaveRunning')) { $settings.LeaveRunning = [bool]$LeaveRunning }
if ($PSBoundParameters.ContainsKey('DebugMode'))    { $settings.Debug        = [bool]$DebugMode }
$engineArgs = Build-EngineArgs -Settings $settings

Write-Host " Running: $exe $($engineArgs -join ' ')"
# Stream the engine's output live AND capture it: success is determined from stdout markers, not
# the exit code (the deployed engine exits 0 on success — see Get-ScriptOutcome).
$engineOut = & $exe @engineArgs 2>&1 | ForEach-Object { $line = $_.ToString(); Write-Host $line; $line }
$engineExit = $LASTEXITCODE

# --- 4. normalize + report ------------------------------------------------------------------
$verdict = Get-ScriptOutcome -StdoutText ($engineOut -join [Environment]::NewLine) -ExitCode $engineExit

$csv = Get-ChildItem -Path $Results -Filter 'results *.csv' -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
$timers = if ($csv) { ConvertFrom-ResultsCsv -CsvPath $csv.FullName } else { @() }

$logDir = Join-Path ([System.IO.Path]::GetTempPath()) 'LoginPI\Logs'
$log = Get-ChildItem -Path $logDir -Filter 'Engine *.txt' -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1

$summary = [ordered]@{
    success    = $verdict.success
    result     = $verdict.result
    exitCode   = $engineExit
    timers     = @($timers)
    resultsCsv = if ($csv) { $csv.FullName } else { $null }
    logPath    = if ($log) { $log.FullName } else { $null }
}
$summary | ConvertTo-Json -Depth 5

if ($verdict.success) { exit 0 } else { exit 1 }
