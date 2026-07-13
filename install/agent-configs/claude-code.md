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
ln -s "$(pwd)/skills/login-enterprise-script-runner" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-app-mapper" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" ~/.claude/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path "$HOME\.claude\skills" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-runner" -Target "$PWD\skills\login-enterprise-script-runner"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-app-mapper" -Target "$PWD\skills\login-enterprise-app-mapper"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Claude Code and ask: "What Login Enterprise skills are available?"
