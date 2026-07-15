# OpenCode Setup

## Automatic Installation

```bash
# Unix/macOS — project-level (default)
./install/install.sh --opencode

# Unix/macOS — global
./install/install.sh --opencode-global

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent OpenCode

# Windows — global
.\install\install.ps1 -Agent OpenCode -Global
```

## Manual Installation

Skills are symlinked to `.opencode/skills/` (project) or `~/.config/opencode/skills/` (global).

### Unix/macOS

```bash
# Project-level
mkdir -p .opencode/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .opencode/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .opencode/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .opencode/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .opencode/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .opencode/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".opencode\skills" -Force
New-Item -ItemType SymbolicLink -Path ".opencode\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".opencode\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".opencode\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".opencode\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".opencode\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open OpenCode and ask: "What Login Enterprise skills are available?"
