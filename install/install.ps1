#Requires -Version 5.1
<#
.SYNOPSIS
    Install Login Enterprise skills for supported AI coding agents.
.PARAMETER Agent
    Which agent to install for: Claude, Codex, or All.
.EXAMPLE
    .\install.ps1 -Agent Claude
    .\install.ps1 -Agent All
#>
param(
    [ValidateSet('Claude', 'Codex', 'Gemini', 'All')]
    [string]$Agent
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$SkillsDir = Join-Path $RepoDir 'skills'

Write-Host "Login Enterprise Skills Installer" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Collect available skills
$skills = Get-ChildItem -Path $SkillsDir -Directory -Filter 'login-enterprise-*' |
    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
    Select-Object -ExpandProperty Name

if ($skills.Count -eq 0) {
    Write-Host "Error: No skills found in $SkillsDir" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($skills.Count) skill(s): $($skills -join ', ')"
Write-Host ""

# Agent selection
if (-not $Agent) {
    Write-Host "Select agents to install for:"
    Write-Host ""
    Write-Host "  1) Claude Code (~/.claude/skills/)"
    Write-Host "  2) OpenAI Codex (.agent-skills/ in current project)"
    Write-Host "  3) Gemini CLI (~/.gemini/skills/)"
    Write-Host "  4) All"
    Write-Host ""
    $choice = Read-Host "Choice [1/2/3/4]"
    switch ($choice) {
        '1' { $Agent = 'Claude' }
        '2' { $Agent = 'Codex' }
        '3' { $Agent = 'Gemini' }
        '4' { $Agent = 'All' }
        default { Write-Host "Invalid choice" -ForegroundColor Red; exit 1 }
    }
}

$installClaude = $Agent -in @('Claude', 'All')
$installCodex  = $Agent -in @('Codex', 'All')
$installGemini = $Agent -in @('Gemini', 'All')
$installed = 0

# Claude Code
if ($installClaude) {
    $claudeSkillsDir = Join-Path (Join-Path $HOME '.claude') 'skills'
    if (-not (Test-Path $claudeSkillsDir)) {
        New-Item -ItemType Directory -Path $claudeSkillsDir -Force | Out-Null
    }
    Write-Host ""
    Write-Host "Installing for Claude Code -> $claudeSkillsDir"
    foreach ($skill in $skills) {
        $target = Join-Path $claudeSkillsDir $skill
        $source = Join-Path $SkillsDir $skill
        if (Test-Path $target) {
            Write-Host "  Skipping $skill (already exists)" -ForegroundColor Yellow
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
            Write-Host "  + $skill" -ForegroundColor Green
            $installed++
        }
    }
}

# Codex
if ($installCodex) {
    $codexSkillsDir = Join-Path (Get-Location) '.agent-skills'
    if (-not (Test-Path $codexSkillsDir)) {
        New-Item -ItemType Directory -Path $codexSkillsDir -Force | Out-Null
    }
    Write-Host ""
    Write-Host "Installing for OpenAI Codex -> $codexSkillsDir"
    foreach ($skill in $skills) {
        $target = Join-Path $codexSkillsDir $skill
        $source = Join-Path $SkillsDir $skill
        if (Test-Path $target) {
            Write-Host "  Skipping $skill (already exists)" -ForegroundColor Yellow
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
            Write-Host "  + $skill" -ForegroundColor Green
            $installed++
        }
    }
}

# Gemini CLI
if ($installGemini) {
    $geminiSkillsDir = Join-Path (Join-Path $HOME '.gemini') 'skills'
    if (-not (Test-Path $geminiSkillsDir)) {
        New-Item -ItemType Directory -Path $geminiSkillsDir -Force | Out-Null
    }
    Write-Host ""
    Write-Host "Installing for Gemini CLI -> $geminiSkillsDir"
    foreach ($skill in $skills) {
        $target = Join-Path $geminiSkillsDir $skill
        $source = Join-Path $SkillsDir $skill
        if (Test-Path $target) {
            Write-Host "  Skipping $skill (already exists)" -ForegroundColor Yellow
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
            Write-Host "  + $skill" -ForegroundColor Green
            $installed++
        }
    }
}

Write-Host ""
Write-Host "Done. $installed skill(s) installed." -ForegroundColor Green
Write-Host ""
Write-Host 'Verify by opening your agent and asking:'
Write-Host '  "What Login Enterprise skills are available?"'
