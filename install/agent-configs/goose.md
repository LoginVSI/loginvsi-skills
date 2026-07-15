# Goose Setup

## Automatic Installation

```bash
# Unix/macOS — project-level (default)
./install/install.sh --goose

# Unix/macOS — global
./install/install.sh --goose-global

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Goose

# Windows — global
.\install\install.ps1 -Agent Goose -Global
```

## Manual Installation

Skills are symlinked to `.goose/skills/` (project) or `~/.agents/skills/` (global).

### Unix/macOS

```bash
# Project-level
mkdir -p .goose/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .goose/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .goose/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .goose/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .goose/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .goose/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".goose\skills" -Force
New-Item -ItemType SymbolicLink -Path ".goose\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".goose\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".goose\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".goose\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".goose\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Goose and ask: "What Login Enterprise skills are available?"
