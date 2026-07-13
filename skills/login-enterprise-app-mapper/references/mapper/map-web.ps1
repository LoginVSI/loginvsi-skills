<#
.SYNOPSIS
  Map a web page's interactive elements into an app-map.json file.

.DESCRIPTION
  Pipeline:
    1. Run a standalone Playwright probe (probe.py) to capture the accessibility
       tree and DOM elements — this runs outside the LE engine because WebScriptBase
       has no DOM dump capability.
    2. Parse the probe output into control descriptors.
    3. Assemble and write app-map.json (kind: "web").
  Requires Python 3 + playwright (pip install playwright && playwright install chromium).

.PARAMETER Url          URL to probe (required).
.PARAMETER AppName      Friendly name (default: derived from URL hostname).
.PARAMETER Browser      Playwright browser: chromium, firefox, webkit (default: chromium).
.PARAMETER OutputPath   Where to write app-map.json (default: <AppName>.app-map.json in CWD).
.PARAMETER WaitSeconds  Seconds to wait after page load (default: 2).
.PARAMETER Headless     Run browser headless (default: true).
.PARAMETER Catalog      Also save to the global catalog (~/.login-enterprise/app-maps/).
.PARAMETER AppVersion   Version string for catalog naming (default: unknown).
.PARAMETER CatalogDir   Override catalog directory.

.EXAMPLE
  .\map-web.ps1 -Url "https://example.com"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Url,
    [string]$AppName,
    [string]$Browser = 'chromium',
    [string]$OutputPath,
    [int]$WaitSeconds = 2,
    [bool]$Headless = $true,
    [switch]$Catalog,
    [string]$AppVersion = 'unknown',
    [string]$CatalogDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mapper-lib.ps1')

function Fail([string]$msg, [int]$code = 3) {
    Write-Host "FATAL: $msg" -ForegroundColor Red
    exit $code
}

# --- resolve inputs -------------------------------------------------------------------------
if (-not $AppName) {
    try {
        $uri = [System.Uri]::new($Url)
        $AppName = $uri.Host -replace '^www\.', '' -replace '\..*$', ''
    } catch {
        $AppName = 'web-app'
    }
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Get-Location) "$AppName.app-map.json"
}

# --- check prerequisites -------------------------------------------------------------------
$pythonExe = $null
foreach ($cand in @('python', 'python3', 'py')) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if ($cmd) { $pythonExe = $cmd.Source; break }
}
if (-not $pythonExe) {
    Fail "Python 3 not found on PATH.`nInstall from: https://python.org (check 'Add to PATH' during setup)."
}

# Verify Python 3 (not 2)
$pyVer = & $pythonExe -c "import sys; print(sys.version_info.major)" 2>&1
if ($LASTEXITCODE -ne 0 -or "$pyVer" -ne '3') {
    Fail "Python 3 is required but '$pythonExe' appears to be Python $pyVer.`nInstall Python 3 from: https://python.org"
}

# Check playwright is importable
$checkResult = & $pythonExe -c "import playwright" 2>&1
if ($LASTEXITCODE -ne 0) {
    Fail "playwright is not installed.`nRun: pip install playwright && playwright install chromium"
}

# Check browser binary is installed
$browserCheck = & $pythonExe -c "from playwright.sync_api import sync_playwright; p = sync_playwright().start(); getattr(p, '$Browser'); p.stop()" 2>&1
if ($LASTEXITCODE -ne 0) {
    Fail "Playwright browser '$Browser' may not be installed.`nRun: playwright install $Browser"
}

$probeScript = Join-Path $PSScriptRoot '..\web-probe\probe.py'
if (-not (Test-Path $probeScript)) {
    Fail "probe.py not found at: $probeScript"
}
$probeScript = (Resolve-Path $probeScript).Path

$dumpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("le-web-mapper-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $dumpDir | Out-Null
$dumpFile = Join-Path $dumpDir 'web-dump.json'

# --- 1. run the Playwright probe ------------------------------------------------------------
Write-Host " Running web probe for $Url..."
$probeArgs = @($probeScript, $Url, '--out', $dumpFile, '--browser', $Browser, '--wait', $WaitSeconds)
if (-not $Headless) { $probeArgs += '--no-headless' }

& $pythonExe @probeArgs
if ($LASTEXITCODE -ne 0) {
    Fail "probe.py failed (exit $LASTEXITCODE)."
}

if (-not (Test-Path $dumpFile)) {
    Fail "Probe output not found at $dumpFile."
}
Write-Host " Probe completed." -ForegroundColor Green

# --- 2. parse the dump ----------------------------------------------------------------------
Write-Host " Parsing web dump..."
$controls = @(ConvertFrom-WebDump -DumpPath $dumpFile)
Write-Host " Found $($controls.Count) elements."

# Read title from dump
$dumpData = Get-Content -Path $dumpFile -Raw | ConvertFrom-Json
$title = if ($dumpData.title) { $dumpData.title } else { '' }

# --- 3. assemble + write app-map.json -------------------------------------------------------
$map = New-WebAppMap -AppName $AppName -Url $Url -Controls $controls -Title $title

$json = ConvertTo-AppMapJson -AppMap $map
Set-Content -Path $OutputPath -Value $json -Encoding UTF8
Write-Host " App map written to: $OutputPath" -ForegroundColor Green

# --- 4. optionally save to catalog ----------------------------------------------------------
if ($Catalog) {
    $catDir = Get-CatalogDir -Path $CatalogDir
    $catPath = Add-MapToCatalog -AppMap $map -CatalogDir $catDir -AppVersion $AppVersion
    Write-Host " Catalog entry: $catPath" -ForegroundColor Green
}

# Emit JSON to stdout for piping
$json

exit 0
