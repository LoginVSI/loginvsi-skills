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
ln -s "$(pwd)/skills/login-enterprise-script-runner" .agent-skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".agent-skills" -Force
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
New-Item -ItemType SymbolicLink -Path ".agent-skills\login-enterprise-script-runner" -Target "$PWD\skills\login-enterprise-script-runner"
```

## Verification

Open Codex and ask: "What Login Enterprise skills are available?"
