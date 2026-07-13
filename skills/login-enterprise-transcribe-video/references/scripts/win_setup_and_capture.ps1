<#
.SYNOPSIS
  One-shot Windows tester for the video-to-steps skill:
  installs ffmpeg if needed, records your screen to an .mp4, then (optionally)
  runs the frame-extraction script so you can see the whole pipeline end to end.

.DESCRIPTION
  Capture uses ffmpeg's built-in 'gdigrab' screen grabber, so no extra recording
  software is required. ffmpeg is sourced in this order:
    1. an ffmpeg already on PATH,
    2. winget (Gyan.FFmpeg),
    3. a portable static build downloaded to %LOCALAPPDATA%\ffmpeg (no admin needed).

  This script is ASCII-only on purpose so Windows PowerShell 5.1 reads it the same
  way regardless of code page. Every external call has its exit code checked, so it
  fails loudly at the real point of failure instead of printing a misleading success.

.PARAMETER Duration   Seconds to record. Default 20.
.PARAMETER Output     Path to the .mp4 to write. Default: .\capture_<timestamp>.mp4 next to this script.
.PARAMETER Fps        Capture frame rate. Default 15.
.PARAMETER Region     Optional crop "WIDTHxHEIGHT+X+Y", e.g. "1280x720+0+0". Omit for full desktop.
.PARAMETER Countdown  Seconds before recording starts. Default 3.
.PARAMETER SkipInstall  Do not try to install ffmpeg; fail if it isn't available.
.PARAMETER ExtractAfter Run extract_frames.py on the recording (needs Python 3 on PATH).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\win_setup_and_capture.ps1 -Duration 30 -ExtractAfter
#>

[CmdletBinding()]
param(
    [int]    $Duration     = 20,
    [string] $Output       = "",
    [int]    $Fps          = 15,
    [string] $Region       = "",
    [int]    $Countdown    = 3,
    [switch] $SkipInstall,
    [switch] $ExtractAfter
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg"   -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    $msg"   -ForegroundColor Yellow }
function Write-Err2($msg) { Write-Host "    $msg"   -ForegroundColor Red }

# --- Resolve ffmpeg ---------------------------------------------------------
function Get-Ffmpeg {
    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    if ($SkipInstall) { throw "ffmpeg not found and -SkipInstall was set. Install ffmpeg and retry." }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Step "Installing ffmpeg via winget (Gyan.FFmpeg)..."
        try {
            winget install --id Gyan.FFmpeg -e --source winget `
                --accept-package-agreements --accept-source-agreements | Out-Host
            $links = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"
            if (Test-Path (Join-Path $links "ffmpeg.exe")) { $env:Path = "$links;$env:Path" }
            $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            Write-Warn2 "winget finished but ffmpeg isn't on PATH yet; falling back to portable build."
        } catch {
            Write-Warn2 "winget install failed ($($_.Exception.Message)); falling back to portable build."
        }
    }

    $toolsDir = Join-Path $env:LOCALAPPDATA "ffmpeg"
    $existing = Get-ChildItem -Path $toolsDir -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
    if ($existing) { $env:Path = "$($existing.DirectoryName);$env:Path"; return $existing.FullName }

    Write-Step "Downloading portable ffmpeg (static build)..."
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    $zip = Join-Path $env:TEMP "ffmpeg-release-essentials.zip"
    $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Write-Step "Extracting ffmpeg..."
    Expand-Archive -Path $zip -DestinationPath $toolsDir -Force
    Remove-Item $zip -ErrorAction SilentlyContinue
    $bin = Get-ChildItem -Path $toolsDir -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if (-not $bin) { throw "Could not locate ffmpeg.exe after extraction." }
    $env:Path = "$($bin.DirectoryName);$env:Path"
    return $bin.FullName
}

# --- Resolve ffmpeg ---------------------------------------------------------
Write-Step "Checking for ffmpeg..."
$ffmpeg = Get-Ffmpeg
Write-Ok "Using ffmpeg: $ffmpeg"
& $ffmpeg -version | Select-Object -First 1 | ForEach-Object { Write-Ok $_ }

# --- Decide output path -----------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Output)) {
    $stamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $Output = Join-Path $ScriptDir "capture_$stamp.mp4"
}
# Make sure the parent folder exists so ffmpeg can write there.
$outParent = Split-Path -Parent $Output
if ($outParent -and -not (Test-Path -LiteralPath $outParent)) {
    New-Item -ItemType Directory -Force -Path $outParent | Out-Null
}

# --- Build gdigrab input args (optional crop region) ------------------------
$inputArgs = @("-f", "gdigrab", "-framerate", "$Fps", "-rtbufsize", "256M")
if (-not [string]::IsNullOrWhiteSpace($Region)) {
    if ($Region -match '^(\d+)x(\d+)\+(\d+)\+(\d+)$') {
        $inputArgs += @("-video_size", "$($Matches[1])x$($Matches[2])",
                        "-offset_x", "$($Matches[3])", "-offset_y", "$($Matches[4])")
    } else {
        throw "Invalid -Region '$Region'. Use WIDTHxHEIGHT+X+Y, e.g. 1280x720+0+0."
    }
}
$inputArgs += @("-i", "desktop")

# --- Countdown --------------------------------------------------------------
if ($Countdown -gt 0) {
    Write-Step "Recording starts in $Countdown s -- switch to the app you want to capture."
    for ($i = $Countdown; $i -ge 1; $i--) { Write-Host "   $i..."; Start-Sleep 1 }
}

# --- Record -----------------------------------------------------------------
Write-Step "Recording $Duration s of the screen at $Fps fps -> $Output"
# H.264 requires even width/height; some desktops report odd sizes (e.g. 1300x689),
# so round both dimensions down to the nearest even number before encoding.
$evenScale = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
$ffArgs = @("-y") + $inputArgs + @("-t", "$Duration", "-vf", $evenScale, "-pix_fmt", "yuv420p", "$Output")
$global:LASTEXITCODE = 0
& $ffmpeg @ffArgs
if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg exited with code $LASTEXITCODE. gdigrab capture failed. " +
          "If you're on an RDP/remote or locked session there may be no desktop to grab; " +
          "try running locally, or pass -Region to capture a specific area."
}

# Verify a real, non-empty file actually exists (don't trust a bare Test-Path).
$item = Get-Item -LiteralPath $Output -ErrorAction SilentlyContinue
if (-not $item -or $item.Length -le 0) {
    throw "No usable recording was produced at:`n  $Output`nffmpeg reported success but the file is missing or empty."
}
$Output = $item.FullName    # canonical absolute path
$sizeKB = [math]::Round($item.Length / 1KB, 1)
Write-Ok "Saved recording: $Output  ($sizeKB KB)"

# --- Optional: run frame extraction ----------------------------------------
if ($ExtractAfter) {
    Write-Step "Running frame extraction..."

    # Prefer a real python; the bare 'python' on Windows is sometimes the Store stub.
    $pyExe = $null
    foreach ($cand in @("python", "py")) {
        $c = Get-Command $cand -ErrorAction SilentlyContinue
        if ($c) { $pyExe = $c.Source; break }
    }
    if (-not $pyExe) {
        Write-Warn2 "Python 3 not found on PATH; skipping extraction."
        Write-Warn2 "Install it from python.org (check 'Add to PATH'), then run:"
        Write-Warn2 "  python `"$ScriptDir\extract_frames.py`" `"$Output`" --out `"<folder>`""
    } else {
        $extract = Join-Path $ScriptDir "extract_frames.py"
        if (-not (Test-Path -LiteralPath $extract)) {
            throw "extract_frames.py not found next to this script:`n  $extract"
        }

        # Sanity-check the file is visible right before we hand it off.
        if (-not (Test-Path -LiteralPath $Output)) {
            Write-Err2 "The recording isn't visible at extraction time. Folder contents:"
            Get-ChildItem -LiteralPath $ScriptDir -Filter *.mp4 | ForEach-Object { Write-Err2 "  $($_.Name)" }
            throw "Recording vanished before extraction: $Output"
        }

        $outDir = Join-Path $ScriptDir ("steps_" + [IO.Path]::GetFileNameWithoutExtension($Output))

        # Pass args as an array (splat). This avoids PowerShell 5.1 native-arg
        # quoting quirks that can mangle the path Python receives.
        $pyArgs = @($extract, $Output, "--out", $outDir)
        $global:LASTEXITCODE = 0
        & $pyExe @pyArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Frame extraction failed (python exit code $LASTEXITCODE). See the error above."
        }
        Write-Ok "Frames + manifest written to: $outDir"
        Write-Host "`nNext: open that folder in your AI coding agent and ask it to 'turn this recording into step-by-step docs'." -ForegroundColor Magenta
    }
} else {
    Write-Host "`nNext: point the video-to-steps skill at your recording:" -ForegroundColor Magenta
    Write-Host "  $Output" -ForegroundColor Magenta
}

Write-Step "Done."
