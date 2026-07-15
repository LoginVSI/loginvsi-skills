# Roo Code Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --roo

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Roo
```

## Manual Installation

Skills are symlinked to `.roo/skills/` in your project directory.

### Unix/macOS

```bash
mkdir -p .roo/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .roo/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .roo/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .roo/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .roo/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .roo/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".roo\skills" -Force
New-Item -ItemType SymbolicLink -Path ".roo\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".roo\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".roo\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".roo\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".roo\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Roo Code and ask: "What Login Enterprise skills are available?"
