<#
.SYNOPSIS
  One-time install for the Login Enterprise script validator: build the le-validate wrapper
  against your deployed ScriptEditor, then verify it with the bundled self-tests.

.DESCRIPTION
  The validator is a thin wrapper (Program.cs) that loads the ScriptEditor's OWN Roslyn and
  ScriptAnalyzer.dll. It is compiled against your editor's exact Roslyn version, so it cannot be
  shipped prebuilt — it must be built once per machine, per ScriptEditor version. Run this on
  Windows after pulling the repo, with a deployed ScriptEditor available (the unzipped folder
  containing bin\, ReferenceAssemblies\ and ScriptEditor.Config).

  It:
    1. Resolves EditorRoot (param or auto-detect under Program Files / LOCALAPPDATA).
    2. Builds + self-tests via run-selftests.ps1 (no NuGet — uses the deployed Roslyn).
    3. On success, prints the path to le-validate.dll, the exact command to validate a script,
       and the one case where you need to re-run this installer.

  Re-run this installer ONLY when you upgrade/replace the ScriptEditor (a new deployment can
  ship a different Roslyn version, and the wrapper is bound to a specific one at build time).
  Day-to-day validation never rebuilds — you just run le-validate.dll.

.PARAMETER EditorRoot
  Deployed ScriptEditor folder (contains bin\, ReferenceAssemblies\, ScriptEditor.Config).
  If omitted, the installer searches Program Files / Program Files (x86) / LOCALAPPDATA.

.PARAMETER Configuration
  Build configuration. Default: Release.

.PARAMETER SkipSelfTest
  Build only; skip the self-tests. Not recommended — the self-tests are what prove the analyzer
  actually wired up (a missing reference looks identical to "clean").

.EXAMPLE
  .\install.ps1 -EditorRoot "C:\Program Files\Login VSI\ScriptEditor"

.EXAMPLE
  .\install.ps1   # auto-detect the deployed ScriptEditor
#>
[CmdletBinding()]
param(
    [string]$EditorRoot,
    [string]$Configuration = 'Release',
    [switch]$SkipSelfTest
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

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

Write-Host "==================================================================="
Write-Host " Login Enterprise validator — install"
Write-Host "==================================================================="

# --- platform -------------------------------------------------------------------------------
if ($env:OS -ne 'Windows_NT') {
    Write-Host "FATAL: The validator requires Windows (it loads the ScriptEditor's Roslyn and ScriptAnalyzer.dll)." -ForegroundColor Red
    exit 3
}

# --- dotnet ---------------------------------------------------------------------------------
try { $dotnetVersion = (& dotnet --version) 2>$null } catch { $dotnetVersion = $null }
if (-not $dotnetVersion) {
    Write-Host "FATAL: 'dotnet' not found on PATH. Install the .NET 8 SDK and retry." -ForegroundColor Red
    Write-Host "       https://dotnet.microsoft.com/download/dotnet/8.0"
    exit 3
}
Write-Host " dotnet SDK: $dotnetVersion"

# --- resolve EditorRoot ---------------------------------------------------------------------
if (-not $EditorRoot) {
    Write-Host " EditorRoot: (auto-detecting...)"
    $EditorRoot = Find-EditorRoot
}
if (-not $EditorRoot -or -not (Test-Path $EditorRoot)) {
    Write-Host "FATAL: Could not resolve a deployed ScriptEditor." -ForegroundColor Red
    Write-Host "       Pass -EditorRoot ""C:\Path\To\ScriptEditor"" (the folder with bin\, ReferenceAssemblies\, ScriptEditor.Config)."
    exit 3
}
$EditorRoot = (Resolve-Path $EditorRoot).Path
Write-Host " EditorRoot: $EditorRoot"

# --- build (+ self-test) --------------------------------------------------------------------
$dll = Join-Path $root "bin\$Configuration\net8.0\le-validate.dll"

if ($SkipSelfTest) {
    Write-Host ""
    Write-Host " Building validator (no NuGet; deployed Roslyn via -p:EditorRoot)..."
    Push-Location $root
    try {
        & dotnet build -c $Configuration -p:EditorRoot="$EditorRoot" --nologo
        $buildExit = $LASTEXITCODE
    } finally { Pop-Location }
    if ($buildExit -ne 0 -or -not (Test-Path $dll)) {
        Write-Host "FATAL: build failed (exit $buildExit)." -ForegroundColor Red
        exit 3
    }
    Write-Host " Build OK -> $dll" -ForegroundColor Green
    Write-Host " WARNING: self-tests skipped — analyzer wiring is NOT verified." -ForegroundColor Yellow
} else {
    # Delegate build + verification to the self-test runner (the source of truth for "wired up").
    & (Join-Path $root 'run-selftests.ps1') -EditorRoot $EditorRoot -Configuration $Configuration
    $verifyExit = $LASTEXITCODE
    if ($verifyExit -ne 0) {
        Write-Host ""
        Write-Host "==================================================================="
        Write-Host " INSTALL FAILED — see output above and selftest-results.txt." -ForegroundColor Red
        Write-Host "==================================================================="
        exit 1
    }
}

# --- success guidance -----------------------------------------------------------------------
Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host " INSTALLED & VERIFIED" -ForegroundColor Green
Write-Host "==================================================================="
Write-Host " Validator: $dll"
Write-Host ""
Write-Host " Validate a script with:"
Write-Host "   dotnet `"$dll`" --script path\to\Script.cs --editor-dir `"$EditorRoot`""
Write-Host ""
Write-Host " You do NOT rebuild for day-to-day validation — just run the command above."
Write-Host " Re-run this installer ONLY when you upgrade/replace the ScriptEditor deployment"
Write-Host " (a new deployment may ship a different Roslyn version the wrapper must match)."
exit 0
