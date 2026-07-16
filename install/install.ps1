#Requires -Version 5.1
<#
.SYNOPSIS
    Install Login Enterprise skills for supported AI coding agents.
.DESCRIPTION
    Copies skill directories into agent-specific locations. All agents that scan
    .agents/skills/ get skills there; agents that don't (Claude, Junie, Trae, Kilo)
    also get a copy in their native path. No symlinks are used.

    Run without parameters for an interactive checkbox UI, or use -Agent for
    non-interactive installation.
.PARAMETER Agent
    Which agent to install for: Claude, Codex, Gemini, Cursor, Copilot, Windsurf,
    Roo, Junie, Goose, Antigravity, OpenCode, Kilo, Trae, or All.
.PARAMETER Project
    Install skills at project level (current directory or specified path).
.PARAMETER Global
    Install skills globally (user home directory).
.EXAMPLE
    .\install.ps1
    .\install.ps1 -Agent Claude -Global
    .\install.ps1 -Agent All -Project
    .\install.ps1 -Agent Codex -Project
#>
param(
    [ValidateSet('Claude', 'Codex', 'Gemini', 'Cursor', 'Copilot', 'Windsurf', 'Roo', 'Junie', 'Goose', 'Antigravity', 'OpenCode', 'Kilo', 'Trae', 'All')]
    [string]$Agent,
    [switch]$Project,
    [switch]$Global
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$SkillsDir = Join-Path $RepoDir 'skills'

# ── Agent definitions ──────────────────────────────────────────────────────────
# ScansAgentsSkills: whether the agent reads .agents/skills/ automatically
# NativeDir: relative subfolder for agents that DON'T scan .agents/skills/

$AgentDefs = [ordered]@{
    'Claude'      = @{ Label = 'Claude Code';    ScansAgentsSkills = $false; NativeDir = '.claude/skills' }
    'Codex'       = @{ Label = 'OpenAI Codex';   ScansAgentsSkills = $true;  NativeDir = $null }
    'Gemini'      = @{ Label = 'Gemini CLI';     ScansAgentsSkills = $true;  NativeDir = $null }
    'Cursor'      = @{ Label = 'Cursor';         ScansAgentsSkills = $true;  NativeDir = $null }
    'Copilot'     = @{ Label = 'GitHub Copilot'; ScansAgentsSkills = $true;  NativeDir = $null }
    'Windsurf'    = @{ Label = 'Windsurf';       ScansAgentsSkills = $true;  NativeDir = $null }
    'Roo'         = @{ Label = 'Roo Code';       ScansAgentsSkills = $true;  NativeDir = $null }
    'Junie'       = @{ Label = 'Junie';          ScansAgentsSkills = $false; NativeDir = '.junie/skills' }
    'Goose'       = @{ Label = 'Goose';          ScansAgentsSkills = $true;  NativeDir = $null }
    'OpenCode'    = @{ Label = 'OpenCode';       ScansAgentsSkills = $true;  NativeDir = $null }
    'Trae'        = @{ Label = 'Trae';           ScansAgentsSkills = $false; NativeDir = '.trae/skills' }
    'Kilo'        = @{ Label = 'Kilo Code';      ScansAgentsSkills = $false; NativeDir = '.kilo/skills' }
    'Antigravity' = @{ Label = 'Antigravity';    ScansAgentsSkills = $true;  NativeDir = $null }
}
$AgentKeys = @($AgentDefs.Keys)

# ── Skills discovery ───────────────────────────────────────────────────────────

Write-Host "Login Enterprise Skills Installer" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

$skills = Get-ChildItem -Path $SkillsDir -Directory -Filter 'login-enterprise-*' |
    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
    Select-Object -ExpandProperty Name

if ($skills.Count -eq 0) {
    Write-Host "Error: No skills found in $SkillsDir" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($skills.Count) skill(s): $($skills -join ', ')"
Write-Host ""

# ── Install helper ─────────────────────────────────────────────────────────────

$installed = 0

function Install-SkillsTo {
    param([string]$Label, [string]$TargetDir)
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    Write-Host ""
    Write-Host "Copying skills to $Label -> $TargetDir"
    foreach ($skill in $skills) {
        $target = Join-Path $TargetDir $skill
        $source = Join-Path $SkillsDir $skill
        if (Test-Path $target) {
            Remove-Item $target -Recurse -Force
            Copy-Item -Path $source -Destination $target -Recurse -Force
            Write-Host "  ~ $skill (updated)" -ForegroundColor Yellow
        } else {
            Copy-Item -Path $source -Destination $target -Recurse -Force
            Write-Host "  + $skill" -ForegroundColor Green
        }
        $script:installed++
    }
}

# ── Scope prompt helper ───────────────────────────────────────────────────────

function Get-AgentScope {
    param([string]$AgentLabel)

    Write-Host ""
    Write-Host "$AgentLabel supports installing skills globally or at a project level."
    Write-Host "  Global  - available in all your projects"
    Write-Host "  Project - available in one project folder only"
    $scopeChoice = Read-Host "Install globally or at project level? [g/p]"

    if ($scopeChoice -match '^[pP]') {
        $cwd = (Get-Location).Path
        Write-Host ""
        Write-Host "Install to this folder? ($cwd)"
        Write-Host "  1) Yes, use this folder"
        Write-Host "  2) Different folder"
        $folderChoice = Read-Host "Choice [1-2]"
        if ($folderChoice -eq '2') {
            $customPath = Read-Host "Enter project folder path"
            if (-not (Test-Path $customPath -PathType Container)) {
                Write-Host "Warning: '$customPath' does not exist. It will be created." -ForegroundColor Yellow
            }
            return @{ Scope = 'project'; ProjectPath = $customPath }
        } else {
            return @{ Scope = 'project'; ProjectPath = $cwd }
        }
    } else {
        return @{ Scope = 'global'; ProjectPath = $null }
    }
}

# ── Compute target directories for an agent + scope ───────────────────────────

function Get-TargetDirs {
    param(
        [string]$Key,
        [hashtable]$ScopeInfo
    )
    $def = $AgentDefs[$Key]
    $targets = @()

    if ($ScopeInfo.Scope -eq 'global') {
        $base = $HOME
        $scopeLabel = 'global'
    } else {
        $base = $ScopeInfo.ProjectPath
        $scopeLabel = 'project'
    }

    # Every agent gets .agents/skills/
    $agentsPath = Join-Path $base '.agents/skills'
    $targets += @{ Label = "$($def.Label) ($scopeLabel, .agents/skills)"; Path = $agentsPath }

    # Agents that don't scan .agents/skills/ also get their native path
    if (-not $def.ScansAgentsSkills -and $def.NativeDir) {
        $nativePath = Join-Path $base $def.NativeDir
        $targets += @{ Label = "$($def.Label) ($scopeLabel, native)"; Path = $nativePath }
    }

    return $targets
}

# ── Interactive checkbox UI ────────────────────────────────────────────────────

function Show-CheckboxUI {
    $selected = @{}
    foreach ($k in $AgentKeys) { $selected[$k] = $false }

    function Draw-List {
        for ($i = 0; $i -lt $AgentKeys.Count; $i++) {
            $key = $AgentKeys[$i]
            $def = $AgentDefs[$key]
            $mark = if ($selected[$key]) { '[x]' } else { '[ ]' }
            $num = ($i + 1).ToString().PadLeft(2)
            Write-Host "  $mark $num) $($def.Label)"
        }
    }

    Write-Host "Select agents to install for (enter numbers to toggle, Enter to confirm):"
    Write-Host ""

    $startY = [Console]::CursorTop
    Draw-List

    while ($true) {
        Write-Host ""
        $userInput = Read-Host "Select [ex. 1,2,13 or 1-13, a=all, Enter=continue]"

        if ([string]::IsNullOrWhiteSpace($userInput)) {
            break
        }

        if ($userInput.Trim().ToLower() -eq 'a') {
            foreach ($k in $AgentKeys) { $selected[$k] = $true }
        } else {
            foreach ($part in ($userInput -split ',')) {
                $part = $part.Trim()
                if ($part -match '^\d+-\d+$') {
                    $bounds = $part -split '-'
                    $lo = [int]$bounds[0]
                    $hi = [int]$bounds[1]
                    for ($n = $lo; $n -le $hi; $n++) {
                        if ($n -ge 1 -and $n -le $AgentKeys.Count) {
                            $key = $AgentKeys[$n - 1]
                            $selected[$key] = -not $selected[$key]
                        }
                    }
                } elseif ($part -match '^\d+$') {
                    $n = [int]$part
                    if ($n -ge 1 -and $n -le $AgentKeys.Count) {
                        $key = $AgentKeys[$n - 1]
                        $selected[$key] = -not $selected[$key]
                    }
                }
            }
        }

        [Console]::SetCursorPosition(0, $startY)
        Draw-List
    }

    return $AgentKeys | Where-Object { $selected[$_] }
}

# ── Main logic ─────────────────────────────────────────────────────────────────

if ($Agent) {
    # Non-interactive mode
    if ($Agent -eq 'All') {
        $selectedAgents = $AgentKeys
    } else {
        $selectedAgents = @($Agent)
    }

    if ($Project -and $Global) {
        Write-Host "Error: Specify either -Project or -Global, not both." -ForegroundColor Red
        exit 1
    }

    $allTargets = @()

    foreach ($key in $selectedAgents) {
        $def = $AgentDefs[$key]

        if ($Project) {
            $scopeInfo = @{ Scope = 'project'; ProjectPath = (Get-Location).Path }
        } elseif ($Global) {
            $scopeInfo = @{ Scope = 'global'; ProjectPath = $null }
        } else {
            $scopeInfo = Get-AgentScope $def.Label
        }

        $allTargets += Get-TargetDirs -Key $key -ScopeInfo $scopeInfo
    }

    $uniqueTargets = @{}
    foreach ($t in $allTargets) {
        $norm = $t.Path.TrimEnd('\', '/')
        if (-not $uniqueTargets.ContainsKey($norm)) {
            $uniqueTargets[$norm] = $t.Label
        }
    }

    foreach ($path in $uniqueTargets.Keys) {
        Install-SkillsTo $uniqueTargets[$path] $path
    }

} else {
    # Interactive mode
    $selectedAgents = Show-CheckboxUI

    if (-not $selectedAgents -or $selectedAgents.Count -eq 0) {
        Write-Host ""
        Write-Host "No agents selected. Nothing to install." -ForegroundColor Yellow
        exit 0
    }

    Write-Host ""
    Write-Host "Selected: $( ($selectedAgents | ForEach-Object { $AgentDefs[$_].Label }) -join ', ' )"

    $allTargets = @()

    foreach ($key in $selectedAgents) {
        $def = $AgentDefs[$key]
        $scopeInfo = Get-AgentScope $def.Label
        $allTargets += Get-TargetDirs -Key $key -ScopeInfo $scopeInfo
    }

    $uniqueTargets = @{}
    foreach ($t in $allTargets) {
        $norm = $t.Path.TrimEnd('\', '/')
        if (-not $uniqueTargets.ContainsKey($norm)) {
            $uniqueTargets[$norm] = $t.Label
        }
    }

    foreach ($path in $uniqueTargets.Keys) {
        Install-SkillsTo $uniqueTargets[$path] $path
    }
}

Write-Host ""
Write-Host "Done. $installed skill(s) installed." -ForegroundColor Green
Write-Host ""
Write-Host 'Verify by opening your agent and asking:'
Write-Host '  "What Login Enterprise skills are available?"'
