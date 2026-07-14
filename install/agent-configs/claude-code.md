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
ln -s "$(pwd)/skills/login-enterprise-write-script" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" ~/.claude/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path "$HOME\.claude\skills" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Claude Code and ask: "What Login Enterprise skills are available?"
