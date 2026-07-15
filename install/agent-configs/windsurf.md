# Windsurf Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --windsurf

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Windsurf
```

## Manual Installation

Skills are symlinked to `.windsurf/skills/` in your project directory.

### Unix/macOS

```bash
mkdir -p .windsurf/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .windsurf/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .windsurf/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .windsurf/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .windsurf/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .windsurf/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".windsurf\skills" -Force
New-Item -ItemType SymbolicLink -Path ".windsurf\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".windsurf\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".windsurf\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".windsurf\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".windsurf\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Windsurf and ask: "What Login Enterprise skills are available?"
