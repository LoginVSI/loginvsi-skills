# GitHub Copilot Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --copilot

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Copilot
```

## Manual Installation

Skills are symlinked to `.github/skills/` in your project directory.

### Unix/macOS

```bash
mkdir -p .github/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .github/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .github/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .github/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .github/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .github/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".github\skills" -Force
New-Item -ItemType SymbolicLink -Path ".github\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".github\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".github\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".github\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".github\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open GitHub Copilot and ask: "What Login Enterprise skills are available?"
