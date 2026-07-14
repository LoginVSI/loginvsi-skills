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
ln -s "$(pwd)/skills/login-enterprise-write-script" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .agent-skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".agent-skills" -Force
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Codex and ask: "What Login Enterprise skills are available?"
