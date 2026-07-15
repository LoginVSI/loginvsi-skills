# Kilo Code Setup

## Automatic Installation

```bash
# Unix/macOS — project-level (default)
./install/install.sh --kilo

# Unix/macOS — global
./install/install.sh --kilo-global

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Kilo

# Windows — global
.\install\install.ps1 -Agent Kilo -Global
```

## Manual Installation

Skills are symlinked to `.kilo/skills/` (project) or `~/.kilo/skills/` (global).

### Unix/macOS

```bash
# Project-level
mkdir -p .kilo/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .kilo/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .kilo/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .kilo/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .kilo/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .kilo/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".kilo\skills" -Force
New-Item -ItemType SymbolicLink -Path ".kilo\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".kilo\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".kilo\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".kilo\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".kilo\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Kilo Code and ask: "What Login Enterprise skills are available?"
