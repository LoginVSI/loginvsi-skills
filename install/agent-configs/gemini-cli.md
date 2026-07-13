# Gemini CLI Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --gemini

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Gemini
```

## Manual Installation

Skills are symlinked to `~/.gemini/skills/` for user-wide access.

### Unix/macOS

```bash
mkdir -p ~/.gemini/skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-script-runner" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-app-mapper" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" ~/.gemini/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path "$HOME\.gemini\skills" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-script-runner" -Target "$PWD\skills\login-enterprise-script-runner"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-app-mapper" -Target "$PWD\skills\login-enterprise-app-mapper"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Gemini CLI and ask: "What Login Enterprise skills are available?"
