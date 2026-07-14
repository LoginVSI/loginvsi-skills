# Gemini CLI Setup

## Automatic Installation

Skills are installed to the **project directory** by default (`.gemini/skills/`) so Gemini CLI's workspace sandbox can read them.

```bash
# Unix/macOS (project-level — recommended)
./install/install.sh --gemini

# Unix/macOS (global — ~/.gemini/skills/)
./install/install.sh --gemini-global

# Windows (project-level — recommended)
.\install\install.ps1 -Agent Gemini

# Windows (global)
.\install\install.ps1 -Agent Gemini -Global
```

> **Why project-level?** Gemini CLI restricts file reads to the workspace directory. Skills installed globally (`~/.gemini/skills/`) may not be readable due to sandbox restrictions. Project-level installation ensures Gemini can read the SKILL.md files.

## Manual Installation (project-level)

Skills are symlinked to `.gemini/skills/` in your project directory.

### Unix/macOS

```bash
mkdir -p .gemini/skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" .gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" .gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-script-runner" .gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-app-mapper" .gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .gemini/skills/
```

### Windows (PowerShell as Administrator)

```powershell
New-Item -ItemType Directory -Path ".gemini\skills" -Force
New-Item -ItemType SymbolicLink -Path ".gemini\skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path ".gemini\skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
New-Item -ItemType SymbolicLink -Path ".gemini\skills\login-enterprise-script-runner" -Target "$PWD\skills\login-enterprise-script-runner"
New-Item -ItemType SymbolicLink -Path ".gemini\skills\login-enterprise-app-mapper" -Target "$PWD\skills\login-enterprise-app-mapper"
New-Item -ItemType SymbolicLink -Path ".gemini\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

## Verification

Open Gemini CLI in the project directory and ask: "What Login Enterprise skills are available?"
