#Requires -Version 5.1
<#
.SYNOPSIS
    Install Login Enterprise skills for supported AI coding agents.
.PARAMETER Agent
    Which agent to install for: Claude, Codex, Gemini, Cursor, or All.
.PARAMETER Project
    Install Claude Code skills to project-level (.claude/skills/) instead of global.
.PARAMETER Global
    Install Gemini CLI skills to global (~/.gemini/skills/) instead of project-level.
.EXAMPLE
    .\install.ps1 -Agent Claude
    .\install.ps1 -Agent Claude -Project
    .\install.ps1 -Agent Gemini
    .\install.ps1 -Agent Gemini -Global
    .\install.ps1 -Agent All
#>
param(
    [ValidateSet('Claude', 'Codex', 'Gemini', 'Cursor', 'All')]
    [string]$Agent,
    [switch]$Project,
    [switch]$Global
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check symlink capability — requires Developer Mode or Administrator on Windows
try {
    $testLink = Join-Path $env:TEMP 'le-skills-symlink-test'
    $testTarget = $ScriptDir
    New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop | Out-Null
    Remove-Item $testLink -Force
} catch {
    Write-Host "Error: Cannot create symbolic links." -ForegroundColor Red
    Write-Host "Enable Developer Mode in Windows Settings, or run as Administrator." -ForegroundColor Yellow
    exit 1
}
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
    Write-Host "  1) Claude Code     (global: ~/.claude/skills/)"
    Write-Host "  2) OpenAI Codex    (project: .agent-skills/)"
    Write-Host "  3) Gemini CLI      (project: .gemini/skills/)"
    Write-Host "  4) Cursor          (project: .cursor/skills/)"
    Write-Host "  5) All"
    Write-Host ""
    $choice = Read-Host "Choice [1/2/3/4/5]"
    switch ($choice) {
        '1' { $Agent = 'Claude' }
        '2' { $Agent = 'Codex' }
        '3' { $Agent = 'Gemini' }
        '4' { $Agent = 'Cursor' }
        '5' { $Agent = 'All' }
        default { Write-Host "Invalid choice" -ForegroundColor Red; exit 1 }
    }
}

$installClaude = $Agent -in @('Claude', 'All')
$installCodex  = $Agent -in @('Codex', 'All')
$installGemini = $Agent -in @('Gemini', 'All')
$installCursor = $Agent -in @('Cursor', 'All')
$installed = 0

# Helper: install skills to a target directory
function Install-SkillsTo {
    param([string]$AgentName, [string]$TargetDir)
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    Write-Host ""
    Write-Host "Installing for $AgentName -> $TargetDir"
    foreach ($skill in $skills) {
        $target = Join-Path $TargetDir $skill
        $source = Join-Path $SkillsDir $skill
        $existing = Get-Item $target -Force -ErrorAction SilentlyContinue
        if ($existing -and $existing.LinkType -eq 'SymbolicLink') {
            Remove-Item $target -Force
            Write-Host "  Replacing broken symlink: $skill" -ForegroundColor Yellow
        }
        if (Test-Path $target) {
            Write-Host "  Skipping $skill (already exists)" -ForegroundColor Yellow
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
            Write-Host "  + $skill" -ForegroundColor Green
            $script:installed++
        }
    }
}

# Claude Code (default: global ~/.claude/skills/, -Project for .claude/skills/)
if ($installClaude) {
    if ($Project) {
        Install-SkillsTo "Claude Code (project)" (Join-Path (Get-Location) '.claude/skills')
    } else {
        Install-SkillsTo "Claude Code" (Join-Path (Join-Path $HOME '.claude') 'skills')
    }
}

# OpenAI Codex (project: .agent-skills/)
if ($installCodex) {
    Install-SkillsTo "OpenAI Codex" (Join-Path (Get-Location) '.agent-skills')
}

# Gemini CLI (default: project .gemini/skills/, -Global for ~/.gemini/skills/)
if ($installGemini) {
    if ($Global) {
        Install-SkillsTo "Gemini CLI (global)" (Join-Path (Join-Path $HOME '.gemini') 'skills')
    } else {
        Install-SkillsTo "Gemini CLI" (Join-Path (Get-Location) '.gemini/skills')
    }
}

# Cursor (project: .cursor/skills/)
if ($installCursor) {
    Install-SkillsTo "Cursor" (Join-Path (Join-Path (Get-Location) '.cursor') 'skills')
}

Write-Host ""
Write-Host "Done. $installed skill(s) installed." -ForegroundColor Green
Write-Host ""
Write-Host 'Verify by opening your agent and asking:'
Write-Host '  "What Login Enterprise skills are available?"'
