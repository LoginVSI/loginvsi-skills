# loginvsi-skills

AI coding agent skills for [Login Enterprise](https://www.loginvsi.com/) — generate automation scripts, validate them, run them on the engine, map application UIs, and document workflows.

Built on the [Agent Skills specification](https://agentskills.io/specification). Works with any compatible AI coding agent.

## Supported Agents

| Agent | Status |
|-------|--------|
| [Claude Code](https://claude.ai/code) | Supported |
| [OpenAI Codex](https://developers.openai.com/codex) | Supported |
| [GitHub Copilot](https://github.com/features/copilot) | Supported |
| [Cursor](https://cursor.com/) | Supported |
| [Windsurf](https://codeium.com/windsurf) | Supported |
| [Gemini CLI](https://geminicli.com) | Supported |
| [Roo Code](https://roocode.com) | Supported |
| [Junie (JetBrains)](https://junie.jetbrains.com/) | Supported |

Any agent implementing the [agentskills.io specification](https://agentskills.io/clients) will discover and use these skills automatically.

## Skills

| Skill | Purpose |
|-------|---------|
| `login-enterprise-create-test` | Orchestrate the full test lifecycle: check environment, map app, write script, validate, run |
| `login-enterprise-script-writer` | Generate a `.cs` automation script from natural-language instructions |
| `login-enterprise-script-validator` | Validate scripts against Login Enterprise's 8 Roslyn analyzer rules |
| `login-enterprise-script-runner` | Execute a script on the standalone engine and report results |
| `login-enterprise-app-mapper` | Map a desktop app's UI tree or web page DOM into `app-map.json` |
| `login-enterprise-transcribe-video` | Convert screen recordings into step-by-step documentation |

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/loginvsi/loginvsi-skills.git
cd loginvsi-skills
```

### 2. Install skills for your agent

**Automatic (recommended):**

```bash
# Unix/macOS
./install/install.sh

# Windows (PowerShell)
.\install\install.ps1
```

The install script detects which AI coding agents are installed and symlinks skills to the correct locations.

**Manual installation:**

<details>
<summary>Claude Code</summary>

```bash
# User-wide (all projects)
ln -s "$(pwd)/skills/login-enterprise-script-writer" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-script-validator" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-script-runner" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-app-mapper" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-create-test" ~/.claude/skills/
ln -s "$(pwd)/skills/login-enterprise-transcribe-video" ~/.claude/skills/

# Or per-project
ln -s "$(pwd)/skills/login-enterprise-script-writer" .claude/skills/
```

```powershell
# Windows (run as Administrator for symlinks)
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\login-enterprise-script-writer" -Target "$PWD\skills\login-enterprise-script-writer"
# Repeat for each skill, or use install.ps1
```

</details>

<details>
<summary>OpenAI Codex</summary>

```bash
# Project-level
mkdir -p .agent-skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" .agent-skills/
# Repeat for each skill
```

See [install/agent-configs/codex.md](install/agent-configs/codex.md) for details.

</details>

<details>
<summary>Cursor</summary>

```bash
mkdir -p .cursor/skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" .cursor/skills/
# Repeat for each skill
```

See [install/agent-configs/cursor.md](install/agent-configs/cursor.md) for details.

</details>

<details>
<summary>Windsurf</summary>

```bash
mkdir -p .windsurf/skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" .windsurf/skills/
# Repeat for each skill
```

See [install/agent-configs/windsurf.md](install/agent-configs/windsurf.md) for details.

</details>

<details>
<summary>GitHub Copilot</summary>

```bash
mkdir -p .github/skills
cp -r skills/login-enterprise-script-writer .github/skills/
# Repeat for each skill
```

See [install/agent-configs/copilot.md](install/agent-configs/copilot.md) for details.

</details>

<details>
<summary>Gemini CLI</summary>

```bash
mkdir -p ~/.gemini/skills
ln -s "$(pwd)/skills/login-enterprise-script-writer" ~/.gemini/skills/
# Repeat for each skill
```

See [install/agent-configs/gemini-cli.md](install/agent-configs/gemini-cli.md) for details.

</details>

### 3. Verify installation

Open your AI coding agent and ask:

> "What Login Enterprise skills are available?"

The agent should list the installed skills and their capabilities.

## Prerequisites

Skills that execute scripts or interact with Login Enterprise require:

| Requirement | Skills that need it |
|-------------|-------------------|
| Windows | script-validator, script-runner, app-mapper (desktop) |
| Login Enterprise ScriptEditor installed | script-validator, script-runner |
| .NET 8 SDK | script-validator, script-runner |
| Login Enterprise Engine (standalone) | script-runner, app-mapper (desktop) |
| Python 3 | app-mapper (web), transcribe-video |
| Playwright (`pip install playwright`) | app-mapper (web) |
| ffmpeg | transcribe-video |

> `script-writer` and `create-test` have no prerequisites — they work on any platform.

Run the environment check to see what's ready:

```powershell
# Windows
.\skills\login-enterprise-create-test\references\check-setup.ps1
```

## How Skills Work Together

```
 MAP    app-mapper        --> app-map.json  (real UI identifiers from the live app)
              │
 WRITE  script-writer     --> Script.cs     (uses app-map if available)
              │
 VALIDATE script-validator --> compiles? timers ok?
              │
 RUN    script-runner     --> did it actually drive the app?
```

The `create-test` skill orchestrates this entire flow. Each skill also works independently.

## Examples

**Generate a script:**
> "Write a Login Enterprise script that opens Outlook, composes a new email, types a subject and body, and sends it"

**Validate a script:**
> "Validate Script.cs against Login Enterprise rules"

**Map an application:**
> "Map the UI elements in Calculator so I can write a test script"

**Run a test:**
> "Run my Script.cs on the Login Enterprise engine"

**Full workflow:**
> "Create a test for Microsoft Teams that joins a meeting, enables camera, and leaves after 30 seconds"

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
