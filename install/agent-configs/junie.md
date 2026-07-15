# Junie Setup

## Automatic Installation

```bash
# Unix/macOS
./install/install.sh --junie

# Windows (PowerShell, run as Administrator for symlinks)
.\install\install.ps1 -Agent Junie
```

## Manual Installation

Skills are symlinked to `.junie/skills/` in your project directory.

### Unix/macOS

```bash
mkdir -p .junie/skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .junie/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .junie/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .junie/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .junie/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .junie/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".junie\skills" -Force
New-Item -ItemType SymbolicLink -Path ".junie\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path ".junie\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path ".junie\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path ".junie\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path ".junie\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Junie and ask: "What Login Enterprise skills are available?"
