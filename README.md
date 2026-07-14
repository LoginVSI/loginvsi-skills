# loginvsi-skills

[![Validate Skills](https://github.com/LoginVSI/loginvsi-skills/actions/workflows/validate-skills.yml/badge.svg)](https://github.com/LoginVSI/loginvsi-skills/actions/workflows/validate-skills.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-agentskills.io-purple.svg)](https://agentskills.io/specification)

AI coding agent skills for [Login Enterprise](https://www.loginvsi.com/) — generate automation scripts, validate them, run them on the engine, map application UIs, and document workflows.

Built on the [Agent Skills specification](https://agentskills.io/specification). Works with any compatible AI coding agent.

## Supported Agents

| Agent | Status |
|-------|--------|
| [Claude Code](https://claude.ai/code) | Supported |
| [OpenAI Codex](https://developers.openai.com/codex) | Supported |
| [Gemini CLI](https://geminicli.com) | Supported |
| [Cursor](https://cursor.com/) | Supported |
| [GitHub Copilot](https://github.com/features/copilot) | Planned |
| [Windsurf](https://codeium.com/windsurf) | Planned |
| [Roo Code](https://roocode.com) | Planned |
| [Junie (JetBrains)](https://junie.jetbrains.com/) | Planned |

Any agent implementing the [agentskills.io specification](https://agentskills.io/clients) will discover and use these skills automatically.

## Skills

| Skill | Purpose | Status |
|-------|---------|--------|
| `login-enterprise-write-script` | Generate a `.cs` automation script from natural-language instructions | Available |
| `login-enterprise-validate-script` | Validate scripts against Login Enterprise's 8 Roslyn analyzer rules | Available |
| `login-enterprise-run-script` | Execute a script on the standalone engine and report results | Available |
| `login-enterprise-map-application` | Map a desktop app's UI tree or web page DOM into `app-map.json` | Available |
| `login-enterprise-transcribe-video` | Convert screen recordings into step-by-step documentation | Available |

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/LoginVSI/loginvsi-skills.git
cd loginvsi-skills
```

### 2. Install skills for your agent

**Automatic (recommended):**

```bash
# Unix/macOS — install for Claude Code
./install/install.sh --claude

# Unix/macOS — install for OpenAI Codex
./install/install.sh --codex

# Unix/macOS — install for Gemini CLI
./install/install.sh --gemini

# Unix/macOS — install for Cursor
./install/install.sh --cursor

# Unix/macOS — install for all supported agents
./install/install.sh --all
```

```powershell
# Windows (PowerShell) — install for Claude Code
.\install\install.ps1 -Agent Claude

# Windows (PowerShell) — install for OpenAI Codex
.\install\install.ps1 -Agent Codex

# Windows (PowerShell) — install for Gemini CLI
.\install\install.ps1 -Agent Gemini

# Windows (PowerShell) — install for Cursor
.\install\install.ps1 -Agent Cursor

# Windows (PowerShell) — install for all supported agents
.\install\install.ps1 -Agent All
```

Run without arguments for interactive selection.

**Manual installation:**

<details>
<summary>Claude Code</summary>

```bash
# User-wide (all projects)
ln -s "$(pwd)/skills/login-enterprise-write-script" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" ~/.claude/skills/
```

```powershell
# Windows (run as Administrator for symlinks)
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

</details>

<details>
<summary>OpenAI Codex</summary>

```bash
# Project-level
mkdir -p .agent-skills
ln -s "$(pwd)/skills/login-enterprise-write-script" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" .agent-skills/
```

</details>

<details>
<summary>Cursor</summary>

```bash
# User-wide (all projects)
ln -s "$(pwd)/skills/login-enterprise-write-script" ~/.cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" ~/.cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" ~/.cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" ~/.cursor/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" ~/.cursor/skills/
```

```powershell
# Windows (run as Administrator for symlinks)
New-Item -ItemType SymbolicLink -Path "$HOME\.cursor\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.cursor\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.cursor\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.cursor\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path "$HOME\.cursor\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

See [install/agent-configs/cursor.md](install/agent-configs/cursor.md) for additional setup details.

</details>

<details>
<summary>Gemini CLI</summary>

```bash
# User-wide (all projects)
ln -s "$(pwd)/skills/login-enterprise-write-script" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-validate-script" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-run-script" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-map-application" ~/.gemini/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" ~/.gemini/skills/
```

```powershell
# Windows (run as Administrator for symlinks)
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-write-script" -Target "$PWD\skills\login-enterprise-write-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-validate-script" -Target "$PWD\skills\login-enterprise-validate-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-run-script" -Target "$PWD\skills\login-enterprise-run-script"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-map-application" -Target "$PWD\skills\login-enterprise-map-application"
New-Item -ItemType SymbolicLink -Path "$HOME\.gemini\skills\login-enterprise-transcribe-video" -Target "$PWD\skills\login-enterprise-transcribe-video"
```

</details>

### 3. Verify installation

Open your AI coding agent and ask:

> "What Login Enterprise skills are available?"

The agent should list the installed skills and their capabilities.

### 4. Run the environment check

```powershell
.\install\check-setup.ps1
```

This detects ScriptEditor, the standalone engine, .NET 8 SDK, Python 3, Playwright, and ffmpeg, then reports which skills are ready to use. Pass `-Json` for machine-readable output.

> **New to Windows setup?** See the [Getting Started on Windows](docs/getting-started-windows.md) guide for a step-by-step walkthrough.

## Prerequisites

`login-enterprise-write-script` has no prerequisites — it works on any platform with no additional tools required.

`login-enterprise-transcribe-video` requires Python 3 and ffmpeg (both must be on your `PATH`). It works on any platform.

> **Windows Python note:** If `python` opens the Microsoft Store instead of Python,
> use the Windows Python launcher: `py -m pip install playwright` and
> `py -m playwright install chromium`. Alternatively, disable the Microsoft Store
> Python alias in Settings > Apps > Advanced app settings > App execution aliases.

`login-enterprise-validate-script` requires a Windows environment with the Login Enterprise toolchain installed:

| Requirement | Skills that need it |
|-------------|-------------------|
| Windows | script-validator, script-runner, app-mapper (desktop) |
| .NET 8 SDK | script-validator, script-runner |
| Login Enterprise ScriptEditor at `C:\Program Files\Login VSI\ScriptEditor\` | script-validator, script-runner |
| Login Enterprise Engine (standalone) installed and running | script-runner, app-mapper (desktop) |
| `le-validate.dll` built (run `script-validator`'s `install.ps1` first) | script-runner |
| script-runner skill installed | app-mapper (desktop) |
| Python 3 | app-mapper (web), transcribe-video |
| Playwright (`pip install playwright`) | app-mapper (web) |
| ffmpeg | transcribe-video |

## How Skills Work Together

> `script-writer`, `script-validator`, `script-runner`, `app-mapper`, and `transcribe-video` are now available. The map → write → validate → run flow is fully functional. `transcribe-video` works independently as a utility skill.

```
 MAP    app-mapper        --> app-map.json  (real UI identifiers from the live app)  ← available now
              │
 WRITE  script-writer     --> Script.cs     (uses app-map if available)              ← available now
              │
 VALIDATE script-validator --> compiles? timers ok?                                  ← available now
              │
 RUN    script-runner     --> did it actually drive the app?                         ← available now
```

Any AI agent with these skills installed can orchestrate the full flow naturally. Each skill also works independently.

## Examples

**Generate a script:**
> "Write a Login Enterprise script that opens Outlook, composes a new email, types a subject and body, and sends it"

**Generate a desktop automation script:**
> "Write a Login Enterprise UIAutomation script for Calculator that adds two numbers"

**Generate a web automation script:**
> "Write a Login Enterprise Playwright script that logs into our HR portal and navigates to the leave request form"

**Validate a script:**
> "Validate my Login Enterprise script at C:\Scripts\OutlookTest.cs against all Roslyn analyzer rules"

**Write and validate in one flow:**
> "Write a Login Enterprise script for Notepad that types text and saves the file, then validate it"

**Map an application:**
> "Map the UI elements in Calculator so I can write a test script"

**Run a test:**
> "Run my Script.cs on the Login Enterprise engine"

**Transcribe a screen recording:**
> "Transcribe my recording at C:\Recordings\session.mp4 into step-by-step documentation"

## Updating

```bash
cd loginvsi-skills
git pull
```

Skills are loaded fresh each session — pulling the latest changes is all you need.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new skills, submit improvements, and validate your changes.

## License

[Apache-2.0](LICENSE)
