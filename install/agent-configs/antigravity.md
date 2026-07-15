# Antigravity Setup

## Automatic Installation

```bash
# Unix/macOS — project-level (default)
./install/install.sh --antigravity

# Unix/macOS — global
./install/install.sh --antigravity-global

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Antigravity

# Windows — global
.\install\install.ps1 -Agent Antigravity -Global
```

## Manual Installation

Skills are symlinked to `.agents/skills/` (project) or `~/.gemini/config/skills/` (global).

### Unix/macOS

```bash
# Project-level
mkdir -p .agents/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .agents/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .agents/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .agents/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .agents/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .agents/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".agents\skills" -Force
New-Item -ItemType SymbolicLink -Path ".agents\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".agents\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".agents\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".agents\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".agents\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Antigravity and ask: "What Login Enterprise skills are available?"
