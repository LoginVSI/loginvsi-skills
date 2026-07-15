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
.PARAMETER Save        Save the resolved EditorRoot and EngineDir to ~/.login-enterprise/config.json for future use.

.EXAMPLE
  .\install\check-setup.ps1
  .\install\check-setup.ps1 -Json
  .\install\check-setup.ps1 -EditorRoot "C:\ScriptEditor" -EngineDir "C:\ScriptEditor\engine" -Save
#>
[CmdletBinding()]
param(
    [switch]$Json,
    [string]$SkillsRoot,
    [string]$EditorRoot,
    [string]$EngineDir,
    [switch]$Save
)

$ErrorActionPreference = 'Stop'

# --- resolve skills root -------------------------------------------------------------------
if (-not $SkillsRoot) {
    # Script is at install/check-setup.ps1
    # Skills root is one level up
    $SkillsRoot = (Resolve-Path (Join-Path $PSScriptRoot '..') -ErrorAction SilentlyContinue).Path
    if (-not $SkillsRoot) { $SkillsRoot = Join-Path $PSScriptRoot '..' }
}

# --- config file helpers ------------------------------------------------------------------
# Persistent config at ~/.login-enterprise/config.json stores user-provided paths
# so they only need to be specified once.

function Get-LeConfigPath {
    return Join-Path $HOME '.login-enterprise/config.json'
}

function Get-LeConfig {
    $path = Get-LeConfigPath
    if (Test-Path $path) {
        try { return (Get-Content $path -Raw | ConvertFrom-Json) }
        catch { return $null }
    }
    return $null
}

function Save-LeConfig {
    param([hashtable]$Config)
    $dir = Join-Path $HOME '.login-enterprise'
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Config | ConvertTo-Json | Set-Content (Get-LeConfigPath) -Encoding UTF8
}

# --- detection helpers ---------------------------------------------------------------------

function Find-EditorRoot {
    # 1. Check config file
    $config = Get-LeConfig
    if ($config -and $config.editorRoot -and (Test-Path (Join-Path $config.editorRoot 'bin\ScriptAnalyzer.dll'))) {
        return $config.editorRoot
    }
    # 2. Check standard install path
    $standardPath = 'C:\Program Files\Login VSI\ScriptEditor'
    if (Test-Path (Join-Path $standardPath 'bin\ScriptAnalyzer.dll')) {
        return $standardPath
    }
    return $null
}

function Find-EngineDir {
    # 1. Check config file
    $config = Get-LeConfig
    if ($config -and $config.engineDir -and (Test-Path (Join-Path $config.engineDir 'LoginEnterprise.Engine.Standalone.exe'))) {
        return $config.engineDir
    }
    # 2. Check standard path
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
    $path = Join-Path $SkillsRoot 'skills\login-enterprise-validate-script\references\validator\bin\Release\net8.0\le-validate.dll'
    if (Test-Path $path) { return (Resolve-Path $path).Path }
    return $null
}

function Find-RunnerScript {
    $path = Join-Path $SkillsRoot 'skills\login-enterprise-run-script\references\runner\run.ps1'
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

# Save paths to config if -Save was specified and paths were found
if ($Save -and ($editorRoot -or $engineDir)) {
    $config = Get-LeConfig
    $configHash = @{}
    if ($config) {
        if ($config.editorRoot) { $configHash['editorRoot'] = $config.editorRoot }
        if ($config.engineDir)  { $configHash['engineDir']  = $config.engineDir }
    }
    if ($editorRoot) { $configHash['editorRoot'] = $editorRoot }
    if ($engineDir)  { $configHash['engineDir']  = $engineDir }
    Save-LeConfig -Config $configHash
    Write-Host "Saved paths to $(Get-LeConfigPath)" -ForegroundColor Green
}

# Engine version -- extract from the exe's FileVersionInfo if available
$engineVersion = $null
if ($engineDir) {
    $engineExe = Join-Path $engineDir 'LoginEnterprise.Engine.Standalone.exe'
    if (Test-Path $engineExe) {
        try {
            $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($engineExe)
            if ($vi.ProductVersion) { $engineVersion = $vi.ProductVersion }
            elseif ($vi.FileVersion) { $engineVersion = $vi.FileVersion }
        } catch { }
    }
}

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
if (-not $runnerScript)  { $mapDNeeds.Add('login-enterprise-run-script skill') }
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

# --- detect installed agents ---------------------------------------------------------------

# Each agent: name, project path, global path (or $null if N/A)
$agentDefs = @(
    @{ name = 'Claude Code';      project = '.claude/skills';      global = (Join-Path $HOME '.claude/skills') }
    @{ name = 'OpenAI Codex';     project = '.agent-skills';       global = $null }
    @{ name = 'Gemini CLI';       project = '.gemini/skills';      global = (Join-Path $HOME '.gemini/skills') }
    @{ name = 'Cursor';           project = '.cursor/skills';      global = $null }
    @{ name = 'GitHub Copilot';   project = '.github/skills';      global = $null }
    @{ name = 'Windsurf';         project = '.windsurf/skills';    global = $null }
    @{ name = 'Roo Code';         project = '.roo/skills';         global = $null }
    @{ name = 'Junie';            project = '.junie/skills';       global = $null }
    @{ name = 'Goose';            project = '.goose/skills';       global = (Join-Path $HOME '.agents/skills') }
    @{ name = 'Antigravity';      project = '.agents/skills';      global = (Join-Path (Join-Path $HOME '.gemini') 'config/skills') }
    @{ name = 'OpenCode';         project = '.opencode/skills';    global = (Join-Path (Join-Path $HOME '.config') 'opencode/skills') }
    @{ name = 'Kilo Code';        project = '.kilo/skills';        global = (Join-Path $HOME '.kilo/skills') }
    @{ name = 'Trae';             project = '.trae/skills';        global = (Join-Path $HOME '.trae/skills') }
)

# Check for at least one login-enterprise-* skill directory in a path
function Test-SkillsInstalled {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $found = Get-ChildItem -Path $Path -Directory -Filter 'login-enterprise-*' -ErrorAction SilentlyContinue
    return ($found.Count -gt 0)
}

$agentResults = [ordered]@{}
foreach ($agent in $agentDefs) {
    $projectPath = Join-Path (Get-Location) $agent.project
    $projectInstalled = Test-SkillsInstalled $projectPath
    $globalInstalled = if ($agent.global) { Test-SkillsInstalled $agent.global } else { $false }
    $agentResults[$agent.name] = [ordered]@{
        projectPath      = $agent.project
        projectInstalled = $projectInstalled
        globalPath       = $agent.global
        globalInstalled  = $globalInstalled
        installed        = ($projectInstalled -or $globalInstalled)
    }
}

$installedAgentCount = ($agentResults.Values | Where-Object { $_.installed }).Count

# --- JSON output ---------------------------------------------------------------------------

$jsonSummary = [ordered]@{
    platform    = if ($onWindows) { 'Windows' } else { [System.Runtime.InteropServices.RuntimeInformation]::OSDescription }
    editorRoot  = $editorRoot
    engineDir   = $engineDir
    engineVersion = $engineVersion
    dotnetSdk   = $dotnetVersion
    validatorDll = $validatorDll
    python      = if ($python) { $python.version } else { $null }
    playwright  = $playwrightVersion
    playwrightBrowser = $playwrightBrowser
    ffmpeg      = $ffmpegVersion
    readyCount  = $readyCount
    totalCount  = $totalCount
    installedAgents = $installedAgentCount
    totalAgents = $agentDefs.Count
    agents      = $agentResults
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
$dEngine      = if ($engineDir -and $engineVersion) { "$engineDir ($engineVersion)" }
                elseif ($engineDir) { $engineDir }
                else { '(not found)' }
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
Write-Host " Agent installations:"

foreach ($agentName in $agentResults.Keys) {
    $a = $agentResults[$agentName]
    if ($a.installed) {
        $locations = @()
        if ($a.projectInstalled) { $locations += "project" }
        if ($a.globalInstalled)  { $locations += "global" }
        $locStr = $locations -join ' + '
        Write-Host ("   [{0}]   {1,-20} ({2})" -f 'installed', $agentName, $locStr) -ForegroundColor Green
    } else {
        Write-Host ("   [{0}]   {1}" -f '        ', $agentName) -ForegroundColor DarkGray
    }
}

Write-Host ""
if ($readyCount -eq $totalCount) {
    Write-Host " All $totalCount skills operational." -ForegroundColor Green
} else {
    Write-Host " $readyCount of $totalCount skills ready." -ForegroundColor Yellow
}
if ($installedAgentCount -gt 0) {
    Write-Host " $installedAgentCount of $($agentDefs.Count) agents have skills installed." -ForegroundColor Cyan
} else {
    Write-Host " No agents have skills installed yet. Run install.ps1 to get started." -ForegroundColor Yellow
}
Write-Host "==================================================================="
Write-Host ""

# Also emit JSON for agents to parse
Write-Host "--- JSON ---"
$jsonSummary | ConvertTo-Json -Depth 5
