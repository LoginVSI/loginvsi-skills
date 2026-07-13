<#
.SYNOPSIS
  Check the environment and report which Login Enterprise AI skills are operational.

.DESCRIPTION
  Repo-level utility that detects: platform, ScriptEditor deployment, standalone engine,
  .NET 8 SDK, validator DLL, Python 3, Playwright, ffmpeg. Reports skill readiness as
  both human-readable text and a JSON summary (when -Json is set).

  Run this after cloning the repository to verify your environment meets the prerequisites
  for each skill.

.PARAMETER Json   Emit only the JSON summary (for programmatic consumption).
.PARAMETER SkillsRoot  Override the skills root directory (default: auto-detect from script location).
.PARAMETER EditorRoot  Explicit path to the ScriptEditor root (skips auto-detection).
.PARAMETER EngineDir   Explicit path to the engine directory containing LoginEnterprise.Engine.Standalone.exe (skips auto-detection).

.EXAMPLE
  .\install\check-setup.ps1
  .\install\check-setup.ps1 -Json
  .\install\check-setup.ps1 -EditorRoot "C:\ScriptEditor" -EngineDir "C:\ScriptEditor\engine"
#>
[CmdletBinding()]
param(
    [switch]$Json,
    [string]$SkillsRoot,
    [string]$EditorRoot,
    [string]$EngineDir
)

$ErrorActionPreference = 'Stop'

# --- resolve skills root -------------------------------------------------------------------
if (-not $SkillsRoot) {
    # Script is at install/check-setup.ps1
    # Skills root is one level up
    $SkillsRoot = (Resolve-Path (Join-Path $PSScriptRoot '..') -ErrorAction SilentlyContinue).Path
    if (-not $SkillsRoot) { $SkillsRoot = Join-Path $PSScriptRoot '..' }
}

# --- detection helpers ---------------------------------------------------------------------

function Find-EditorRoot {
    # Only check the standard install path -- no recursive scanning.
    # If ScriptEditor is elsewhere, the user must specify -EditorRoot.
    $standardPath = 'C:\Program Files\Login VSI\ScriptEditor'
    if (Test-Path (Join-Path $standardPath 'bin\ScriptAnalyzer.dll')) {
        return $standardPath
    }
    return $null
}

function Find-EngineDir {
    # Engine lives inside the ScriptEditor directory.
    # Only check the standard path -- no recursive scanning.
    $standardPath = 'C:\Program Files\Login VSI\ScriptEditor\engine'
    if (Test-Path (Join-Path $standardPath 'LoginEnterprise.Engine.Standalone.exe')) {
        return $standardPath
    }
    return $null
}

# Run `python -c <code>` capturing stdout, never throwing. Under -ErrorActionPreference Stop,
# Windows PowerShell 5.1 escalates a native command's stderr to a TERMINATING error even with
# 2>$null, so probes must run with the preference relaxed.
function Invoke-PyProbe($exe, $code) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { return (& $exe -c $code 2>$null) } catch { return $null }
    finally { $ErrorActionPreference = $old }
}

function Find-Python {
    foreach ($cand in @('python', 'python3', 'py')) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if ($cmd) {
            $ver = Invoke-PyProbe $cmd.Source "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"
            if ($LASTEXITCODE -eq 0 -and $ver -match '^3\.') {
                return @{ path = $cmd.Source; version = "$ver".Trim() }
            }
        }
    }
    return $null
}

function Find-ValidatorDll {
    $path = Join-Path $SkillsRoot 'skills\login-enterprise-script-validator\references\validator\bin\Release\net8.0\le-validate.dll'
    if (Test-Path $path) { return (Resolve-Path $path).Path }
    return $null
}

function Find-RunnerScript {
    $path = Join-Path $SkillsRoot 'skills\login-enterprise-script-runner\references\runner\run.ps1'
    if (Test-Path $path) { return (Resolve-Path $path).Path }
    return $null
}

# --- detect everything ---------------------------------------------------------------------

$onWindows = $env:OS -eq 'Windows_NT'

$editorRoot = if ($EditorRoot)  { $EditorRoot }
              elseif ($onWindows) { Find-EditorRoot }
              else { $null }

$engineDir  = if ($EngineDir)   { $EngineDir }
              elseif ($onWindows) { Find-EngineDir }
              else { $null }

$dotnetVersion = $null
$dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnetCmd) {
    try { $dotnetVersion = (& dotnet --version 2>$null) } catch { }
}

$validatorDll = Find-ValidatorDll
$runnerScript = Find-RunnerScript

$python = Find-Python

$playwrightVersion = $null
$playwrightBrowser = $null
if ($python) {
    # playwright exposes no module __version__; read it from package metadata instead.
    $pwVer = Invoke-PyProbe $python.path "import importlib.metadata as m; print(m.version('playwright'))"
    if ($LASTEXITCODE -eq 0 -and $pwVer) { $playwrightVersion = ("$pwVer" -split "`n" | Select-Object -Last 1).Trim() }
    if ($playwrightVersion) {
        # Readiness = chromium is INSTALLED (files present), NOT launchable. Launching needs a
        # runtime session that the image-bake VM (Session 0) lacks; a real runner launches fine.
        # Filesystem check only -- never starts the playwright driver, so it can't fail to launch.
        $pwBrowsers = if ($env:PLAYWRIGHT_BROWSERS_PATH -and $env:PLAYWRIGHT_BROWSERS_PATH -ne '0') { $env:PLAYWRIGHT_BROWSERS_PATH } else { Join-Path $env:LOCALAPPDATA 'ms-playwright' }
        if ((Test-Path $pwBrowsers) -and @(Get-ChildItem -Path $pwBrowsers -Directory -Filter 'chromium*' -ErrorAction SilentlyContinue).Count -gt 0) { $playwrightBrowser = 'chromium' }
    }
}

$ffmpegVersion = $null
$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegCmd) {
    $ffOut = & ffmpeg -version 2>$null | Select-Object -First 1
    if ($ffOut -match 'version\s+([\d.]+)') { $ffmpegVersion = $Matches[1] }
    elseif ($ffOut) { $ffmpegVersion = 'installed' }
}

$ffprobeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue

# --- determine skill readiness -------------------------------------------------------------

$skills = [ordered]@{}

# script-writer -- no prerequisites
$skills['script-writer'] = @{
    ready = $true; needs = @(); prereqs = 'no prerequisites'
}

# script-validator -- Windows + .NET 8 + ScriptEditor + built validator
$valNeeds = [System.Collections.Generic.List[string]]::new()
if (-not $onWindows)     { $valNeeds.Add('Windows') }
if (-not $dotnetVersion) { $valNeeds.Add('.NET 8 SDK (https://dotnet.microsoft.com/download/dotnet/8.0)') }
if (-not $editorRoot)    { $valNeeds.Add('ScriptEditor deployment') }
if (-not $validatorDll)  { $valNeeds.Add('run install.ps1 to build le-validate.dll') }
$skills['script-validator'] = @{
    ready = ($valNeeds.Count -eq 0); needs = $valNeeds; prereqs = '.NET 8 + ScriptEditor + validator built'
}

# script-runner -- everything validator needs + engine
$runNeeds = [System.Collections.Generic.List[string]]::new()
if (-not $onWindows)     { $runNeeds.Add('Windows') }
if (-not $dotnetVersion) { $runNeeds.Add('.NET 8 SDK') }
if (-not $editorRoot)    { $runNeeds.Add('ScriptEditor deployment') }
if (-not $validatorDll)  { $runNeeds.Add('run install.ps1 to build le-validate.dll') }
if (-not $engineDir)     { $runNeeds.Add('standalone engine (EngineDir)') }
$skills['script-runner'] = @{
    ready = ($runNeeds.Count -eq 0); needs = $runNeeds; prereqs = '.NET 8 + ScriptEditor + engine'
}

# app-mapper (desktop) -- Windows + engine + runner
$mapDNeeds = [System.Collections.Generic.List[string]]::new()
if (-not $onWindows)     { $mapDNeeds.Add('Windows') }
if (-not $engineDir)     { $mapDNeeds.Add('standalone engine (EngineDir)') }
if (-not $runnerScript)  { $mapDNeeds.Add('login-enterprise-script-runner skill') }
$skills['app-mapper-desktop'] = @{
    ready = ($mapDNeeds.Count -eq 0); needs = $mapDNeeds; prereqs = 'Windows + engine + runner'
}

# app-mapper (web) -- Python 3 + playwright
$mapWNeeds = [System.Collections.Generic.List[string]]::new()
if (-not $python)              { $mapWNeeds.Add('Python 3 (https://python.org)') }
if (-not $playwrightVersion)   { $mapWNeeds.Add('pip install playwright') }
if (-not $playwrightBrowser)   { $mapWNeeds.Add('playwright install chromium') }
$skills['app-mapper-web'] = @{
    ready = ($mapWNeeds.Count -eq 0); needs = $mapWNeeds; prereqs = 'Python 3 + playwright'
}

# transcribe-video -- ffmpeg + Python 3
$tvNeeds = [System.Collections.Generic.List[string]]::new()
if (-not $ffmpegCmd)   { $tvNeeds.Add('ffmpeg (winget install Gyan.FFmpeg)') }
if (-not $ffprobeCmd)  { $tvNeeds.Add('ffprobe (included with ffmpeg)') }
if (-not $python)      { $tvNeeds.Add('Python 3') }
$skills['transcribe-video'] = @{
    ready = ($tvNeeds.Count -eq 0); needs = $tvNeeds; prereqs = 'ffmpeg + Python 3'
}

$readyCount = ($skills.Values | Where-Object { $_.ready }).Count
$totalCount = $skills.Count

# --- JSON output ---------------------------------------------------------------------------

$jsonSummary = [ordered]@{
    platform    = if ($onWindows) { 'Windows' } else { [System.Runtime.InteropServices.RuntimeInformation]::OSDescription }
    editorRoot  = $editorRoot
    engineDir   = $engineDir
    dotnetSdk   = $dotnetVersion
    validatorDll = $validatorDll
    python      = if ($python) { $python.version } else { $null }
    playwright  = $playwrightVersion
    playwrightBrowser = $playwrightBrowser
    ffmpeg      = $ffmpegVersion
    readyCount  = $readyCount
    totalCount  = $totalCount
    skills      = [ordered]@{}
}
foreach ($name in $skills.Keys) {
    $s = $skills[$name]
    $jsonSummary.skills[$name] = [ordered]@{
        ready = $s.ready
        needs = @($s.needs)
    }
}

if ($Json) {
    $jsonSummary | ConvertTo-Json -Depth 5
    exit 0
}

# --- human-readable output -----------------------------------------------------------------

Write-Host ""
Write-Host "==================================================================="
Write-Host " Login Enterprise Skills -- Environment Check"
Write-Host "==================================================================="
Write-Host ""

$pad = 18
$dPlatform    = if ($onWindows) { 'Windows' } else { [System.Runtime.InteropServices.RuntimeInformation]::OSDescription }
$dEditor      = if ($editorRoot) { $editorRoot } else { '(not found)' }
$dEngine      = if ($engineDir) { $engineDir } else { '(not found)' }
$dDotnet      = if ($dotnetVersion) { $dotnetVersion } else { '(not found)' }
$dValidator   = if ($validatorDll) { 'built' } else { '(not built -- run install.ps1 in the script-validator skill)' }
$dPython      = if ($python) { $python.version } else { '(not found)' }
$dPlaywright  = if ($playwrightVersion) { "$playwrightVersion ($playwrightBrowser)" } else { '(not installed)' }
$dFfmpeg      = if ($ffmpegVersion) { $ffmpegVersion } else { '(not found)' }

Write-Host (" {0,-$pad} {1}" -f 'Platform:', $dPlatform)
Write-Host (" {0,-$pad} {1}" -f 'ScriptEditor:', $dEditor)
Write-Host (" {0,-$pad} {1}" -f 'Engine:', $dEngine)
Write-Host (" {0,-$pad} {1}" -f '.NET 8 SDK:', $dDotnet)
Write-Host (" {0,-$pad} {1}" -f 'Validator:', $dValidator)
Write-Host (" {0,-$pad} {1}" -f 'Python 3:', $dPython)
Write-Host (" {0,-$pad} {1}" -f 'Playwright:', $dPlaywright)
Write-Host (" {0,-$pad} {1}" -f 'ffmpeg:', $dFfmpeg)
Write-Host ""
Write-Host " Skill readiness:"

foreach ($name in $skills.Keys) {
    $s = $skills[$name]
    if ($s.ready) {
        Write-Host ("   [{0}]   {1,-24} {2}" -f 'ready', $name, $s.prereqs) -ForegroundColor Green
    } else {
        $missing = $s.needs -join ', '
        Write-Host ("   [{0}]   {1,-24} needs: {2}" -f 'SETUP', $name, $missing) -ForegroundColor Yellow
    }
}

Write-Host ""
if ($readyCount -eq $totalCount) {
    Write-Host " All $totalCount skills operational." -ForegroundColor Green
} else {
    Write-Host " $readyCount of $totalCount skills ready." -ForegroundColor Yellow
}
Write-Host "==================================================================="
Write-Host ""

# Also emit JSON for agents to parse
Write-Host "--- JSON ---"
$jsonSummary | ConvertTo-Json -Depth 5
