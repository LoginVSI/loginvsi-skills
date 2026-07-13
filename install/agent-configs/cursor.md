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
ln -s "$(pwd)/skills/login-enterprise-script-writer" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-script-runner" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-app-mapper" .cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .cursor/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".cursor\skills" -Force
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-script-runner" -Target "$PWD\skills\login-enterprise-script-runner"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-app-mapper" -Target "$PWD\skills\login-enterprise-app-mapper"
New-Item -ItemType SymbolicLink -Path ".cursor\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Cursor and ask: "What Login Enterprise skills are available?"
