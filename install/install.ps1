#Requires -Version 5.1
<#
.SYNOPSIS
    Install Login Enterprise skills for supported AI coding agents.
.PARAMETER Agent
    Which agent to install for: Claude, Codex, Gemini, Cursor, Copilot, Windsurf, Roo, Junie, Goose, Antigravity, OpenCode, Kilo, Trae, or All.
.PARAMETER Project
    Install skills to project-level instead of global (applies to Claude, Codex).
.PARAMETER Global
    Install skills to global instead of project-level (applies to Gemini, Goose, Antigravity, OpenCode, Kilo, Trae).
.EXAMPLE
    .\install.ps1 -Agent Claude
    .\install.ps1 -Agent Claude -Project
    .\install.ps1 -Agent Gemini
    .\install.ps1 -Agent Gemini -Global
    .\install.ps1 -Agent All
#>
param(
    [ValidateSet('Claude', 'Codex', 'Gemini', 'Cursor', 'Copilot', 'Windsurf', 'Roo', 'Junie', 'Goose', 'Antigravity', 'OpenCode', 'Kilo', 'Trae', 'All')]
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
    Write-Host "  5) GitHub Copilot  (project: .github/skills/)"
    Write-Host "  6) Windsurf        (project: .windsurf/skills/)"
    Write-Host "  7) Roo Code        (project: .roo/skills/)"
    Write-Host "  8) Junie           (project: .junie/skills/)"
    Write-Host "  9) Goose           (project: .goose/skills/)"
    Write-Host " 10) Antigravity     (project: .agents/skills/)"
    Write-Host " 11) OpenCode        (project: .opencode/skills/)"
    Write-Host " 12) Kilo Code       (project: .kilo/skills/)"
    Write-Host " 13) Trae            (project: .trae/skills/)"
    Write-Host " 14) All"
    Write-Host ""
    $choice = Read-Host "Choice [1-14]"
    switch ($choice) {
        '1'  { $Agent = 'Claude' }
        '2'  { $Agent = 'Codex' }
        '3'  { $Agent = 'Gemini' }
        '4'  { $Agent = 'Cursor' }
        '5'  { $Agent = 'Copilot' }
        '6'  { $Agent = 'Windsurf' }
        '7'  { $Agent = 'Roo' }
        '8'  { $Agent = 'Junie' }
        '9'  { $Agent = 'Goose' }
        '10' { $Agent = 'Antigravity' }
        '11' { $Agent = 'OpenCode' }
        '12' { $Agent = 'Kilo' }
        '13' { $Agent = 'Trae' }
        '14' { $Agent = 'All' }
        default { Write-Host "Invalid choice" -ForegroundColor Red; exit 1 }
    }
}

$installClaude  = $Agent -in @('Claude', 'All')
$installCodex   = $Agent -in @('Codex', 'All')
$installGemini  = $Agent -in @('Gemini', 'All')
$installCursor  = $Agent -in @('Cursor', 'All')
$installCopilot  = $Agent -in @('Copilot', 'All')
$installWindsurf = $Agent -in @('Windsurf', 'All')
$installRoo      = $Agent -in @('Roo', 'All')
$installJunie       = $Agent -in @('Junie', 'All')
$installGoose       = $Agent -in @('Goose', 'All')
$installAntigravity = $Agent -in @('Antigravity', 'All')
$installOpenCode    = $Agent -in @('OpenCode', 'All')
$installKilo        = $Agent -in @('Kilo', 'All')
$installTrae        = $Agent -in @('Trae', 'All')
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

# GitHub Copilot (project: .github/skills/)
if ($installCopilot) {
    Install-SkillsTo "GitHub Copilot" (Join-Path (Join-Path (Get-Location) '.github') 'skills')
}

# Windsurf (project: .windsurf/skills/)
if ($installWindsurf) {
    Install-SkillsTo "Windsurf" (Join-Path (Join-Path (Get-Location) '.windsurf') 'skills')
}

# Roo Code (project: .roo/skills/)
if ($installRoo) {
    Install-SkillsTo "Roo Code" (Join-Path (Join-Path (Get-Location) '.roo') 'skills')
}

# Junie (project: .junie/skills/)
if ($installJunie) {
    Install-SkillsTo "Junie" (Join-Path (Join-Path (Get-Location) '.junie') 'skills')
}

# Goose (default: project .goose/skills/, -Global for ~/.agents/skills/)
if ($installGoose) {
    if ($Global) {
        Install-SkillsTo "Goose (global)" (Join-Path (Join-Path $HOME '.agents') 'skills')
    } else {
        Install-SkillsTo "Goose" (Join-Path (Join-Path (Get-Location) '.goose') 'skills')
    }
}

# Antigravity (default: project .agents/skills/, -Global for ~/.gemini/config/skills/)
if ($installAntigravity) {
    if ($Global) {
        Install-SkillsTo "Antigravity (global)" (Join-Path (Join-Path (Join-Path $HOME '.gemini') 'config') 'skills')
    } else {
        Install-SkillsTo "Antigravity" (Join-Path (Join-Path (Get-Location) '.agents') 'skills')
    }
}

# OpenCode (default: project .opencode/skills/, -Global for ~/.config/opencode/skills/)
if ($installOpenCode) {
    if ($Global) {
        Install-SkillsTo "OpenCode (global)" (Join-Path (Join-Path (Join-Path $HOME '.config') 'opencode') 'skills')
    } else {
        Install-SkillsTo "OpenCode" (Join-Path (Join-Path (Get-Location) '.opencode') 'skills')
    }
}

# Kilo Code (default: project .kilo/skills/, -Global for ~/.kilo/skills/)
if ($installKilo) {
    if ($Global) {
        Install-SkillsTo "Kilo Code (global)" (Join-Path (Join-Path $HOME '.kilo') 'skills')
    } else {
        Install-SkillsTo "Kilo Code" (Join-Path (Join-Path (Get-Location) '.kilo') 'skills')
    }
}

# Trae (default: project .trae/skills/, -Global for ~/.trae/skills/)
if ($installTrae) {
    if ($Global) {
        Install-SkillsTo "Trae (global)" (Join-Path (Join-Path $HOME '.trae') 'skills')
    } else {
        Install-SkillsTo "Trae" (Join-Path (Join-Path (Get-Location) '.trae') 'skills')
    }
}

Write-Host ""
Write-Host "Done. $installed skill(s) installed." -ForegroundColor Green
Write-Host ""
Write-Host 'Verify by opening your agent and asking:'
Write-Host '  "What Login Enterprise skills are available?"'
