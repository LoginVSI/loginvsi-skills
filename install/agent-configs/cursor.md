# Cursor Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --cursor

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Cursor
```

## Manual Installation

Skills are symlinked to `.cursor/skills/` in your project directory.

### Unix/macOS

```bash
mkdir -p .cursor/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .cursor/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".cursor\skills" -Force
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Cursor and ask: "What Login Enterprise skills are available?"
