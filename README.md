# loginvsi-skills

AI coding agent skills for [Login Enterprise](https://www.loginvsi.com/) — generate automation scripts, validate them, run them on the engine, map application UIs, and document workflows.

Built on the [Agent Skills specification](https://agentskills.io/specification). Works with any compatible AI coding agent.

## Supported Agents

| Agent | Status |
|-------|--------|
| [Claude Code](https://claude.ai/code) | Supported |
| [OpenAI Codex](https://developers.openai.com/codex) | Supported |
| [GitHub Copilot](https://github.com/features/copilot) | Planned |
| [Cursor](https://cursor.com/) | Planned |
| [Windsurf](https://codeium.com/windsurf) | Planned |
| [Gemini CLI](https://geminicli.com) | Planned |
| [Roo Code](https://roocode.com) | Planned |
| [Junie (JetBrains)](https://junie.jetbrains.com/) | Planned |

Any agent implementing the [agentskills.io specification](https://agentskills.io/clients) will discover and use these skills automatically.

## Skills

| Skill | Purpose | Status |
|-------|---------|--------|
| `login-enterprise-script-writer` | Generate a `.cs` automation script from natural-language instructions | Available |
| `login-enterprise-script-validator` | Validate scripts against Login Enterprise's 8 Roslyn analyzer rules | Available |
| `login-enterprise-script-runner` | Execute a script on the standalone engine and report results | Available |
| `login-enterprise-app-mapper` | Map a desktop app's UI tree or web page DOM into `app-map.json` | Available |
| `login-enterprise-create-test` | Orchestrate the full test lifecycle: check environment, map app, write script, validate, run | Coming Soon |
| `login-enterprise-transcribe-video` | Convert screen recordings into step-by-step documentation | Coming Soon |

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

# Unix/macOS — install for all supported agents
./install/install.sh --all
```

```powershell
# Windows (PowerShell) — install for Claude Code
.\install\install.ps1 -Agent Claude

# Windows (PowerShell) — install for OpenAI Codex
.\install\install.ps1 -Agent Codex

# Windows (PowerShell) — install for all supported agents
.\install\install.ps1 -Agent All
```

Run without arguments for interactive selection.

**Manual installation:**

<details>
<summary>Claude Code</summary>

```bash
# User-wide (all projects)
ln -s "$(pwd)/skills/login-enterprise-script-writer" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-script-runner" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-app-mapper" ~/.claude/skills/
```

```powershell
# Windows (run as Administrator for symlinks)
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-validator" -Target "$PWD\skills\login-enterprise-script-validator"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-runner" -Target "$PWD\skills\login-enterprise-script-runner"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-app-mapper" -Target "$PWD\skills\login-enterprise-app-mapper"
```

</details>

<details>
<summary>OpenAI Codex</summary>

```bash
# Project-level
mkdir -p .agent-skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-script-runner" .agent-skills/
ln -s "$(pwd)/skills/login-enterprise-app-mapper" .agent-skills/
```

</details>

### 3. Verify installation

Open your AI coding agent and ask:

> "What Login Enterprise skills are available?"

The agent should list the installed skills and their capabilities.

## Prerequisites

`login-enterprise-script-writer` has no prerequisites — it works on any platform with no additional tools required.

`login-enterprise-script-validator` requires a Windows environment with the Login Enterprise toolchain installed:

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

> `script-writer`, `script-validator`, `script-runner`, and `app-mapper` are now available. The map → write → validate → run flow is fully functional. Additional skills will be unlocked as they are released.

```
 MAP    app-mapper        --> app-map.json  (real UI identifiers from the live app)  ← available now
              │
 WRITE  script-writer     --> Script.cs     (uses app-map if available)              ← available now
              │
 VALIDATE script-validator --> compiles? timers ok?                                  ← available now
              │
 RUN    script-runner     --> did it actually drive the app?                         ← available now
```

The `create-test` skill will orchestrate this entire flow. Each skill also works independently.

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
