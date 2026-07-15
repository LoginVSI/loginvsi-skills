# Trae Setup

## Automatic Installation

```bash
# Unix/macOS — project-level (default)
./install/install.sh --trae

# Unix/macOS — global
./install/install.sh --trae-global

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Trae

# Windows — global
.\install\install.ps1 -Agent Trae -Global
```

## Manual Installation

Skills are symlinked to `.trae/skills/` (project) or `~/.trae/skills/` (global).

### Unix/macOS

```bash
# Project-level
mkdir -p .trae/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .trae/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .trae/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .trae/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .trae/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .trae/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".trae\skills" -Force
New-Item -ItemType SymbolicLink -Path ".trae\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".trae\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".trae\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".trae\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".trae\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Trae and ask: "What Login Enterprise skills are available?"
