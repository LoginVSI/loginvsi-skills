# Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver two fully functional agentskills.io-compliant skills (`script-writer` and `script-validator`) with install scripts, CI, and docs — ready for external user testing with Claude Code and OpenAI Codex.

**Architecture:** Vertical slices — each skill ships end-to-end (skill content + install + CI + docs) before starting the next. Content is ported from an existing internal repo that the implementer has access to.

**Tech Stack:** Markdown (SKILL.md per agentskills.io spec), PowerShell (.ps1), Bash (.sh), GitHub Actions YAML, Node.js (npx skills-ref validate)

## Global Constraints

- All skill instructions must be agent-agnostic — no Claude-specific or Codex-specific syntax
- No internal/proprietary references (ProGet feeds, TFS, internal URLs)
- No bundled binaries — users supply their own Login Enterprise installation
- Skill names: `login-enterprise-<name>`, lowercase + hyphens, 1-64 chars, must match directory name
- SKILL.md body must be under 500 lines; description under 1024 chars
- All skills must pass `npx skills-ref validate`
- ScriptEditor expected at `C:\Program Files\Login VSI\ScriptEditor\`
- Target agents for Phase 1: Claude Code and OpenAI Codex only
- License: Apache-2.0

---

### Task 1: Repository Rename and Scaffold

**Files:**
- Create: `LICENSE`
- Create: `skills/` (empty directory structure)
- Create: `install/` (empty directory structure)
- Create: `docs/` (directory)
- Move: `PRD.md` → `docs/PRD.md`
- Modify: `.git/config` (remote URL)

**Interfaces:**
- Consumes: nothing
- Produces: clean repo structure that all subsequent tasks build on

- [ ] **Step 1: Rename the GitHub repo**

Go to https://github.com/loginvsi/loginvsi-skills-prd/settings and rename the repository to `loginvsi-skills`.

- [ ] **Step 2: Update local remote and rename directory**

```bash
git remote set-url origin https://github.com/loginvsi/loginvsi-skills.git
cd ..
mv loginvsi-skills-prd loginvsi-skills
cd loginvsi-skills
```

- [ ] **Step 3: Create directory scaffold**

```bash
mkdir -p skills/login-enterprise-script-writer/{references/examples,assets}
mkdir -p skills/login-enterprise-script-validator/{scripts,references}
mkdir -p install/agent-configs
mkdir -p docs
mkdir -p .github/workflows
```

- [ ] **Step 4: Move PRD.md to docs/**

```bash
git mv PRD.md docs/PRD.md
```

- [ ] **Step 5: Add LICENSE file**

Create `LICENSE` with the full Apache-2.0 license text. Use the standard Apache-2.0 text with:
- Copyright line: `Copyright 2026 Login VSI`

- [ ] **Step 6: Commit scaffold**

```bash
git add LICENSE docs/PRD.md skills/ install/ .github/
git commit -m "chore: scaffold repo structure and move PRD to docs"
```

---

### Task 2: Port script-writer Skill Content

**Files:**
- Create: `skills/login-enterprise-script-writer/SKILL.md`
- Create: `skills/login-enterprise-script-writer/references/api-reference.md`
- Create: `skills/login-enterprise-script-writer/references/patterns-desktop.md`
- Create: `skills/login-enterprise-script-writer/references/patterns-web.md`
- Create: `skills/login-enterprise-script-writer/references/examples/notepad-basic.cs`
- Create: `skills/login-enterprise-script-writer/references/examples/web-login.cs`
- Create: `skills/login-enterprise-script-writer/assets/script-template.cs`

**Interfaces:**
- Consumes: internal repo's script-writer skill content
- Produces: a complete agentskills.io-compliant `script-writer` skill directory

- [ ] **Step 1: Create SKILL.md with frontmatter**

Create `skills/login-enterprise-script-writer/SKILL.md` with this frontmatter:

```yaml
---
name: login-enterprise-script-writer
description: >-
  Generate a complete Login Enterprise .cs automation script from natural-language
  instructions. Supports Desktop (UIAutomation), Playwright web, and legacy CSS/Selenium
  patterns. Use when the user asks to write, create, or generate a Login Enterprise
  script, test script, or automation script.
license: Apache-2.0
compatibility: No specific requirements. Works on any platform.
metadata:
  author: loginvsi
  version: "1.0"
---
```

Port the Markdown body from the internal repo. The body must include:
- A "When to activate" section listing trigger keywords/intents
- Instructions for determining script type (Desktop, Playwright, Legacy)
- References to `references/patterns-desktop.md` and `references/patterns-web.md` using relative paths
- Output format requirements (inherit `ScriptBase`, override `Execute()`, timer pairs)
- Examples section referencing `references/examples/`

Verify the body is under 500 lines.

- [ ] **Step 2: Port reference files**

Port the following from the internal repo, adapting any internal references:

- `references/api-reference.md` — `ScriptBase` API, `FindControl()`, `StartTimer`/`StopTimer`, naming rules
- `references/patterns-desktop.md` — UIAutomation patterns with code examples
- `references/patterns-web.md` — Playwright patterns with code examples

Review each file for internal/proprietary references (ProGet feeds, TFS paths, internal URLs) and remove or replace them.

- [ ] **Step 3: Port example scripts**

Port from the internal repo:
- `references/examples/notepad-basic.cs` — simple desktop UIAutomation example
- `references/examples/web-login.cs` — Playwright web example

Each `.cs` file must:
- Inherit from `ScriptBase`
- Override `void Execute()`
- Use `StartTimer()`/`StopTimer()` around key operations
- Contain no internal references

- [ ] **Step 4: Port script template**

Port `assets/script-template.cs` from the internal repo — a minimal blank template inheriting `ScriptBase` with an empty `Execute()` method.

- [ ] **Step 5: Validate the skill**

```bash
npx skills-ref validate skills/login-enterprise-script-writer
```

Expected: validation passes with no errors. If it fails, fix the reported issues (name mismatch, missing fields, description too long, body over 500 lines).

- [ ] **Step 6: Commit**

```bash
git add skills/login-enterprise-script-writer/
git commit -m "feat: add login-enterprise-script-writer skill"
```

---

### Task 3: Install Scripts (Claude Code + Codex)

**Files:**
- Create: `install/install.sh`
- Create: `install/install.ps1`
- Create: `install/agent-configs/claude-code.md`
- Create: `install/agent-configs/codex.md`

**Interfaces:**
- Consumes: `skills/` directory (from Task 2)
- Produces: working install scripts that symlink skills for Claude Code and Codex

- [ ] **Step 1: Create install.sh**

Create `install/install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Login Enterprise Skills Installer"
echo "================================="
echo ""

# Collect available skills
SKILLS=()
for dir in "$SKILLS_DIR"/login-enterprise-*/; do
    if [ -f "$dir/SKILL.md" ]; then
        SKILLS+=("$(basename "$dir")")
    fi
done

if [ ${#SKILLS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No skills found in $SKILLS_DIR${NC}"
    exit 1
fi

echo "Found ${#SKILLS[@]} skill(s): ${SKILLS[*]}"
echo ""

# Agent selection
INSTALL_CLAUDE=false
INSTALL_CODEX=false

if [ $# -gt 0 ]; then
    for arg in "$@"; do
        case "$arg" in
            --claude) INSTALL_CLAUDE=true ;;
            --codex)  INSTALL_CODEX=true ;;
            --all)    INSTALL_CLAUDE=true; INSTALL_CODEX=true ;;
            --help)
                echo "Usage: install.sh [--claude] [--codex] [--all]"
                echo "  --claude  Install for Claude Code"
                echo "  --codex   Install for OpenAI Codex"
                echo "  --all     Install for all supported agents"
                echo "  (no args) Interactive selection"
                exit 0
                ;;
            *) echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        esac
    done
else
    echo "Select agents to install for:"
    echo ""
    echo "  1) Claude Code (~/.claude/skills/)"
    echo "  2) OpenAI Codex (.agent-skills/ in current project)"
    echo "  3) All"
    echo ""
    read -rp "Choice [1/2/3]: " choice
    case "$choice" in
        1) INSTALL_CLAUDE=true ;;
        2) INSTALL_CODEX=true ;;
        3) INSTALL_CLAUDE=true; INSTALL_CODEX=true ;;
        *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
    esac
fi

installed=0

# Claude Code
if [ "$INSTALL_CLAUDE" = true ]; then
    CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
    mkdir -p "$CLAUDE_SKILLS_DIR"
    echo ""
    echo "Installing for Claude Code → $CLAUDE_SKILLS_DIR"
    for skill in "${SKILLS[@]}"; do
        target="$CLAUDE_SKILLS_DIR/$skill"
        if [ -L "$target" ] || [ -d "$target" ]; then
            echo -e "  ${YELLOW}Skipping $skill (already exists)${NC}"
        else
            ln -s "$SKILLS_DIR/$skill" "$target"
            echo -e "  ${GREEN}✓ $skill${NC}"
            ((installed++))
        fi
    done
fi

# Codex
if [ "$INSTALL_CODEX" = true ]; then
    CODEX_SKILLS_DIR="$(pwd)/.agent-skills"
    mkdir -p "$CODEX_SKILLS_DIR"
    echo ""
    echo "Installing for OpenAI Codex → $CODEX_SKILLS_DIR"
    for skill in "${SKILLS[@]}"; do
        target="$CODEX_SKILLS_DIR/$skill"
        if [ -L "$target" ] || [ -d "$target" ]; then
            echo -e "  ${YELLOW}Skipping $skill (already exists)${NC}"
        else
            ln -s "$SKILLS_DIR/$skill" "$target"
            echo -e "  ${GREEN}✓ $skill${NC}"
            ((installed++))
        fi
    done
fi

echo ""
echo -e "${GREEN}Done. $installed skill(s) installed.${NC}"
echo ""
echo "Verify by opening your agent and asking:"
echo '  "What Login Enterprise skills are available?"'
```

- [ ] **Step 2: Make install.sh executable**

```bash
chmod +x install/install.sh
```

- [ ] **Step 3: Create install.ps1**

Create `install/install.ps1`:

```powershell
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
    [ValidateSet('Claude', 'Codex', 'All')]
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
    Write-Host "  3) All"
    Write-Host ""
    $choice = Read-Host "Choice [1/2/3]"
    switch ($choice) {
        '1' { $Agent = 'Claude' }
        '2' { $Agent = 'Codex' }
        '3' { $Agent = 'All' }
        default { Write-Host "Invalid choice" -ForegroundColor Red; exit 1 }
    }
}

$installClaude = $Agent -in @('Claude', 'All')
$installCodex  = $Agent -in @('Codex', 'All')
$installed = 0

# Claude Code
if ($installClaude) {
    $claudeSkillsDir = Join-Path $HOME '.claude' 'skills'
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

Write-Host ""
Write-Host "Done. $installed skill(s) installed." -ForegroundColor Green
Write-Host ""
Write-Host 'Verify by opening your agent and asking:'
Write-Host '  "What Login Enterprise skills are available?"'
```

- [ ] **Step 4: Create agent config docs**

Create `install/agent-configs/claude-code.md`:

```markdown
# Claude Code Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --claude

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Claude
```

## Manual Installation

Skills are symlinked to `~/.claude/skills/` for user-wide access, or `.claude/skills/` for per-project access.

### Unix/macOS

```bash
mkdir -p ~/.claude/skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" ~/.claude/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path "$HOME\.claude\skills" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
```

## Verification

Open Claude Code and ask: "What Login Enterprise skills are available?"
```

Create `install/agent-configs/codex.md`:

```markdown
# OpenAI Codex Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --codex

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Codex
```

## Manual Installation

Skills are symlinked to `.agent-skills/` in your project directory.

### Unix/macOS

```bash
mkdir -p .agent-skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" .agent-skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".agent-skills" -Force
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
```

## Verification

Open Codex and ask: "What Login Enterprise skills are available?"
```

- [ ] **Step 5: Test install.sh on Unix/macOS (or WSL)**

```bash
cd /tmp
git clone https://github.com/loginvsi/loginvsi-skills.git
cd loginvsi-skills
./install/install.sh --claude
ls -la ~/.claude/skills/
```

Expected: symlinks for `login-enterprise-script-writer` pointing to the repo's `skills/` directory.

```bash
# Cleanup
rm -rf ~/.claude/skills/login-enterprise-script-writer
```

- [ ] **Step 6: Test install.ps1 on Windows**

```powershell
cd C:\temp
git clone https://github.com/loginvsi/loginvsi-skills.git
cd loginvsi-skills
.\install\install.ps1 -Agent Claude
Get-ChildItem "$HOME\.claude\skills\"
```

Expected: symlink for `login-enterprise-script-writer` pointing to the repo's `skills/` directory.

```powershell
# Cleanup
Remove-Item "$HOME\.claude\skills\login-enterprise-script-writer" -Force
```

- [ ] **Step 7: Commit**

```bash
git add install/
git commit -m "feat: add install scripts for Claude Code and Codex"
```

---

### Task 4: CI Workflow

**Files:**
- Create: `.github/workflows/validate-skills.yml`

**Interfaces:**
- Consumes: `skills/` directories with `SKILL.md` files
- Produces: automated validation on push and PR

- [ ] **Step 1: Create validate-skills.yml**

Create `.github/workflows/validate-skills.yml`:

```yaml
name: Validate Skills

on:
  push:
    paths:
      - 'skills/**'
  pull_request:
    paths:
      - 'skills/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Validate all skills
        run: |
          exit_code=0
          for dir in skills/login-enterprise-*/; do
            echo "Validating $dir..."
            if npx skills-ref validate "$dir"; then
              echo "✓ $dir passed"
            else
              echo "✗ $dir failed"
              exit_code=1
            fi
            echo ""
          done
          exit $exit_code

      - name: Check SKILL.md body length
        run: |
          exit_code=0
          for skill_md in skills/*/SKILL.md; do
            # Count lines after second --- (end of frontmatter)
            body_lines=$(awk '/^---$/{n++; next} n>=2' "$skill_md" | wc -l)
            if [ "$body_lines" -gt 500 ]; then
              echo "✗ $skill_md body is $body_lines lines (max 500)"
              exit_code=1
            else
              echo "✓ $skill_md body is $body_lines lines"
            fi
          done
          exit $exit_code

      - name: Check directory name matches SKILL.md name
        run: |
          exit_code=0
          for dir in skills/login-enterprise-*/; do
            dir_name=$(basename "$dir")
            skill_name=$(awk '/^name:/{print $2; exit}' "$dir/SKILL.md")
            if [ "$dir_name" != "$skill_name" ]; then
              echo "✗ Directory '$dir_name' does not match SKILL.md name '$skill_name'"
              exit_code=1
            else
              echo "✓ $dir_name matches"
            fi
          done
          exit $exit_code
```

- [ ] **Step 2: Test the workflow locally**

```bash
# Simulate what CI does
for dir in skills/login-enterprise-*/; do
    echo "Validating $dir..."
    npx skills-ref validate "$dir"
done
```

Expected: `skills/login-enterprise-script-writer` passes validation.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/validate-skills.yml
git commit -m "ci: add skill validation workflow"
```

---

### Task 5: Slice 1 Docs Update (README, CONTRIBUTING, CLAUDE.md)

**Files:**
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `CLAUDE.md`
- Create: `docs/architecture.md`

**Interfaces:**
- Consumes: completed script-writer skill, install scripts, CI workflow
- Produces: accurate docs reflecting the current state of the repo

- [ ] **Step 1: Update README.md**

Rewrite `README.md` to reflect the current state. Key changes:
- Supported Agents table: Claude Code and Codex as "Supported", all others as "Planned"
- Skills table: only `script-writer` as available, other 5 skills listed as "Coming Soon"
- Quick Start: keep clone + install script instructions, remove manual instructions for agents not yet supported
- Prerequisites: only list requirements for `script-writer` (none — works on any platform)
- How Skills Work Together: keep the diagram but note that only `script-writer` is available now
- Remove references to skills that don't exist yet from examples (keep only script-writer examples)

- [ ] **Step 2: Update CONTRIBUTING.md**

Update `CONTRIBUTING.md`:
- "Test with at least two agents" → specify Claude Code and Codex
- PR template agents tested list: Claude Code and Codex checked, others as "Other: ___"
- All other content stays the same — it's already accurate for the agentskills.io format

- [ ] **Step 3: Update CLAUDE.md**

Rewrite `CLAUDE.md` to reflect this is now an implementation repo, not a PRD-only repo:
- Remove "The repo currently contains only planning documents" language
- Update Key Documents to list `skills/`, `install/`, `docs/PRD.md`
- Update Current Status to reflect Phase 1 Slice 1 is complete
- Keep all other sections (constraints, conventions) as they are

- [ ] **Step 4: Create docs/architecture.md**

Create `docs/architecture.md`:

```markdown
# Architecture

## How Skills Relate

```
WRITE  script-writer     --> Script.cs     (generate from natural language)
         │
VALIDATE script-validator --> pass/fail    (check against 8 Roslyn rules)
```

Each skill works independently. The `script-writer` generates `.cs` files that can
then be validated by `script-validator`.

Future skills (`script-runner`, `app-mapper`, `create-test`, `transcribe-video`)
will extend this pipeline. See [PRD.md](PRD.md) for the full planned flow.

## Skill Format

Skills follow the [agentskills.io specification](https://agentskills.io/specification).
See [../CONTRIBUTING.md](../CONTRIBUTING.md) for detailed format requirements.
```

- [ ] **Step 5: Commit**

```bash
git add README.md CONTRIBUTING.md CLAUDE.md docs/architecture.md
git commit -m "docs: update README, CONTRIBUTING, and CLAUDE.md for Phase 1 Slice 1"
```

---

### Task 6: Slice 1 End-to-End Verification

**Files:** none (testing only)

**Interfaces:**
- Consumes: everything from Tasks 1-5
- Produces: verified working Slice 1

- [ ] **Step 1: Run skill validation**

```bash
npx skills-ref validate skills/login-enterprise-script-writer
```

Expected: passes with no errors.

- [ ] **Step 2: Test install for Claude Code (Windows)**

```powershell
.\install\install.ps1 -Agent Claude
Get-ChildItem "$HOME\.claude\skills\" | Where-Object Name -like 'login-enterprise-*'
```

Expected: `login-enterprise-script-writer` symlink present.

- [ ] **Step 3: Test with Claude Code**

Open Claude Code in a project directory and ask:
> "What Login Enterprise skills are available?"

Expected: Claude Code lists `login-enterprise-script-writer` and describes its purpose.

Then ask:
> "Write a Login Enterprise script that opens Notepad, types hello world, and saves the file"

Expected: Claude Code activates the script-writer skill and produces a valid `.cs` file.

- [ ] **Step 4: Test install for Codex**

```bash
./install/install.sh --codex
ls -la .agent-skills/
```

Expected: `login-enterprise-script-writer` symlink present.

- [ ] **Step 5: Test with Codex**

Open Codex and ask it to write a Login Enterprise script. Verify the skill activates.

- [ ] **Step 6: Push and verify CI**

```bash
git push origin main
```

Go to https://github.com/loginvsi/loginvsi-skills/actions and verify the "Validate Skills" workflow passes.

- [ ] **Step 7: Commit any fixes**

If any verification steps failed, fix the issues and commit:

```bash
git add -A
git commit -m "fix: address Slice 1 verification issues"
```

---

### Task 7: Port script-validator Skill Content

**Files:**
- Create: `skills/login-enterprise-script-validator/SKILL.md`
- Create: `skills/login-enterprise-script-validator/scripts/validate.ps1`
- Create: `skills/login-enterprise-script-validator/references/analyzer-rules.md`

**Interfaces:**
- Consumes: internal repo's script-validator skill content
- Produces: a complete agentskills.io-compliant `script-validator` skill directory

- [ ] **Step 1: Create SKILL.md with frontmatter**

Create `skills/login-enterprise-script-validator/SKILL.md` with this frontmatter:

```yaml
---
name: login-enterprise-script-validator
description: >-
  Validate a Login Enterprise .cs automation script against the 8 Roslyn analyzer
  rules. Checks for correct timer usage, prohibited API calls, proper ScriptBase
  inheritance, and other compliance requirements. Use when the user asks to validate,
  check, or lint a Login Enterprise script.
license: Apache-2.0
compatibility: >-
  Requires Windows, .NET 8 SDK, and Login Enterprise ScriptEditor installed
  at C:\Program Files\Login VSI\ScriptEditor\.
metadata:
  author: loginvsi
  version: "1.0"
---
```

Port the Markdown body from the internal repo. The body must include:
- A "When to activate" section listing trigger keywords/intents
- A "Platform requirements" section stating Windows is required, with guidance for non-Windows users
- Instructions for running validation via `scripts/validate.ps1`
- Description of the 8 Roslyn analyzer rules (summary — details in `references/analyzer-rules.md`)
- Output format (pass/fail per rule, error messages, line numbers)
- Error handling: what to do when ScriptEditor is not found
- Reference to `references/analyzer-rules.md` for full rule details

Verify the body is under 500 lines.

- [ ] **Step 2: Create validate.ps1**

Create `skills/login-enterprise-script-validator/scripts/validate.ps1`:

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Validate a Login Enterprise .cs script against Roslyn analyzer rules.
.PARAMETER ScriptPath
    Path to the .cs file to validate.
.EXAMPLE
    .\validate.ps1 -ScriptPath "C:\scripts\MyScript.cs"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath
)

$ErrorActionPreference = 'Stop'

# Validate input file exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "Error: Script file not found: $ScriptPath" -ForegroundColor Red
    exit 1
}

if (-not $ScriptPath.EndsWith('.cs')) {
    Write-Host "Error: Expected a .cs file, got: $ScriptPath" -ForegroundColor Red
    exit 1
}

# Check for ScriptEditor
$scriptEditorPath = "C:\Program Files\Login VSI\ScriptEditor"
$scriptEditorExe = Join-Path $scriptEditorPath "LoginPI.Engine.ScriptEditor.exe"

if (-not (Test-Path $scriptEditorPath)) {
    Write-Host ""
    Write-Host "ScriptEditor not found at: $scriptEditorPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "To install ScriptEditor:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Log in to your Login Enterprise appliance web interface"
    Write-Host "  2. Navigate to the Downloads or Tools section"
    Write-Host "  3. Download the ScriptEditor package (.zip)"
    Write-Host "  4. Extract the zip to: $scriptEditorPath"
    Write-Host "  5. Ensure LoginPI.Engine.ScriptEditor.exe exists in that directory"
    Write-Host ""
    Write-Host "Note: ScriptEditor requires a licensed Login Enterprise installation."
    Write-Host "Contact your Login Enterprise administrator if you don't have access."
    Write-Host ""
    exit 1
}

if (-not (Test-Path $scriptEditorExe)) {
    Write-Host "Error: ScriptEditor directory exists but LoginPI.Engine.ScriptEditor.exe not found." -ForegroundColor Red
    Write-Host "Ensure ScriptEditor is properly extracted to: $scriptEditorPath" -ForegroundColor Yellow
    exit 1
}

# Check for .NET 8 SDK
$dotnetVersion = $null
try {
    $dotnetVersion = & dotnet --version 2>$null
} catch {
    # dotnet not found
}

if (-not $dotnetVersion -or -not $dotnetVersion.StartsWith('8')) {
    Write-Host "Warning: .NET 8 SDK not detected (found: $dotnetVersion)." -ForegroundColor Yellow
    Write-Host "ScriptEditor validation requires .NET 8 SDK." -ForegroundColor Yellow
    Write-Host "Download from: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
    Write-Host ""
}

# Run validation
Write-Host "Validating: $ScriptPath" -ForegroundColor Cyan
Write-Host "Using ScriptEditor at: $scriptEditorPath" -ForegroundColor Cyan
Write-Host ""

try {
    $result = & $scriptEditorExe validate "$ScriptPath" 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "Validation PASSED" -ForegroundColor Green
    } else {
        Write-Host "Validation FAILED" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host $result

    exit $exitCode
} catch {
    Write-Host "Error running ScriptEditor: $_" -ForegroundColor Red
    exit 1
}
```

Review the `validate.ps1` against your internal repo's version. The script above is a template — adapt the actual ScriptEditor invocation command and output parsing to match how your internal version works. The key requirements are:
1. Auto-detect ScriptEditor at `C:\Program Files\Login VSI\ScriptEditor\`
2. Provide clear download guidance if missing
3. Check for .NET 8 SDK
4. Run the Roslyn analyzers and return structured results

- [ ] **Step 3: Port analyzer-rules.md**

Port `references/analyzer-rules.md` from the internal repo. This file must document all 8 Roslyn analyzer rules with:
- Rule ID and name
- What it checks
- Example of passing code
- Example of failing code
- How to fix violations

Remove any internal/proprietary references.

- [ ] **Step 4: Validate the skill**

```bash
npx skills-ref validate skills/login-enterprise-script-validator
```

Expected: validation passes with no errors.

- [ ] **Step 5: Commit**

```bash
git add skills/login-enterprise-script-validator/
git commit -m "feat: add login-enterprise-script-validator skill"
```

---

### Task 8: Update Install Scripts and CI for Both Skills

**Files:**
- Modify: `install/agent-configs/claude-code.md` (already lists both skills)
- Modify: `install/agent-configs/codex.md` (already lists both skills)

**Interfaces:**
- Consumes: both skill directories
- Produces: install scripts and CI that handle both skills

- [ ] **Step 1: Test install scripts pick up both skills**

The install scripts already dynamically discover all `login-enterprise-*` directories, so no code changes are needed. Verify:

```powershell
.\install\install.ps1 -Agent Claude
Get-ChildItem "$HOME\.claude\skills\" | Where-Object Name -like 'login-enterprise-*'
```

Expected: both `login-enterprise-script-writer` and `login-enterprise-script-validator` symlinks present.

- [ ] **Step 2: Test CI validates both skills**

```bash
for dir in skills/login-enterprise-*/; do
    echo "Validating $dir..."
    npx skills-ref validate "$dir"
done
```

Expected: both skills pass validation.

- [ ] **Step 3: Commit any fixes**

If any changes were needed:

```bash
git add install/ .github/
git commit -m "fix: update install and CI for both skills"
```

---

### Task 9: Final Docs Polish

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `docs/architecture.md`

**Interfaces:**
- Consumes: completed Tasks 1-8
- Produces: accurate, final documentation for Phase 1

- [ ] **Step 1: Update README.md for both skills**

Update the README to reflect both skills are now available:
- Skills table: `script-writer` and `script-validator` as available; remaining 4 as "Coming Soon"
- Prerequisites table: add Windows, .NET 8 SDK, ScriptEditor for `script-validator`
- Examples section: add a "Validate a script" example
- How Skills Work Together: show the writer → validator flow

- [ ] **Step 2: Update CLAUDE.md**

Update Current Status to reflect Phase 1 is complete:
- Both skills available
- Install scripts for Claude Code and Codex
- CI pipeline active

- [ ] **Step 3: Update docs/architecture.md**

Ensure the architecture doc accurately describes the writer → validator flow with both skills now present.

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md docs/architecture.md
git commit -m "docs: finalize Phase 1 documentation"
```

---

### Task 10: External User End-to-End Test

**Files:** none (testing only)

**Interfaces:**
- Consumes: everything from Tasks 1-9
- Produces: verified working Phase 1 deliverable

- [ ] **Step 1: Fresh clone test (Windows)**

On a clean Windows machine (or clean directory):

```powershell
cd C:\temp
git clone https://github.com/loginvsi/loginvsi-skills.git
cd loginvsi-skills
```

- [ ] **Step 2: Run install for Claude Code**

```powershell
.\install\install.ps1 -Agent Claude
```

Expected: both skills symlinked to `~/.claude/skills/`.

- [ ] **Step 3: Verify Claude Code skill discovery**

Open Claude Code and ask:
> "What Login Enterprise skills are available?"

Expected: both `login-enterprise-script-writer` and `login-enterprise-script-validator` listed.

- [ ] **Step 4: Test script-writer with Claude Code**

Ask Claude Code:
> "Write a Login Enterprise script that opens Notepad, types hello world, and saves the file"

Expected: valid `.cs` file produced, inherits `ScriptBase`, has timer pairs.

- [ ] **Step 5: Test script-validator with Claude Code**

Ask Claude Code:
> "Validate the script you just wrote against Login Enterprise rules"

Expected: Claude Code activates script-validator, runs `validate.ps1`, reports results.

- [ ] **Step 6: Run install for Codex**

```bash
./install/install.sh --codex
ls -la .agent-skills/
```

Expected: both skills symlinked.

- [ ] **Step 7: Test with Codex**

Repeat the script-writer and script-validator tests with Codex.

- [ ] **Step 8: Push a PR and verify CI**

Create a test branch, push it, open a PR:

```bash
git checkout -b test/verify-ci
echo "# test" >> test-file.md
git add test-file.md
git commit -m "test: verify CI pipeline"
git push -u origin test/verify-ci
```

Go to GitHub and open a PR. Verify the "Validate Skills" workflow runs and passes. Then close the PR and delete the branch.

- [ ] **Step 9: Document any issues**

If any test steps failed, create GitHub issues for tracking. Fix critical issues before considering Phase 1 complete.
