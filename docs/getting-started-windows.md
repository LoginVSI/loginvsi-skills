# Getting Started on Windows

Step-by-step guide to set up Login Enterprise AI skills on a Windows machine. After completing these steps, all 5 skills will be operational and you can generate, validate, and run automation scripts with your AI coding agent.

## What you need

| Component | Required for | How to get it |
|-----------|-------------|---------------|
| Git | Cloning this repo | [git-scm.com](https://git-scm.com/) or `winget install Git.Git` |
| An AI coding agent | Using the skills | Claude Code, OpenAI Codex, or Gemini CLI |
| .NET 8 SDK | script-validator, script-runner | [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/8.0) or `winget install Microsoft.DotNet.SDK.8` |
| Login Enterprise ScriptEditor | script-validator, script-runner, app-mapper (desktop) | Download from your Login Enterprise appliance |
| Python 3 | app-mapper (web), transcribe-video | [python.org](https://python.org) or `winget install Python.Python.3.12` |
| Playwright | app-mapper (web) | `pip install playwright && playwright install chromium` |
| ffmpeg | transcribe-video | `winget install Gyan.FFmpeg` |

> **script-writer works immediately** with no prerequisites beyond the AI agent. You can start generating scripts right away and set up the other components as needed.

## Step 1: Clone and install skills

```powershell
git clone https://github.com/LoginVSI/loginvsi-skills.git
cd loginvsi-skills

# Install for your agent (requires Developer Mode or Administrator for symlinks)
.\install\install.ps1 -Agent Claude    # or Codex, Gemini, All
```

If you get a symlink error, enable Developer Mode:
**Settings > System > For developers > Developer Mode > On**

Verify by opening your agent and asking: *"What Login Enterprise skills are available?"*

At this point, **script-writer** is ready to use.

## Step 2: Install .NET 8 SDK

Required for: script-validator, script-runner, app-mapper (desktop)

```powershell
# Check if already installed
dotnet --version
# Should show 8.x.x

# If not installed:
winget install Microsoft.DotNet.SDK.8
# Restart your terminal after installing
```

## Step 3: Set up ScriptEditor

Required for: script-validator, script-runner, app-mapper (desktop)

ScriptEditor is downloaded from your licensed Login Enterprise appliance — it is not available as a public download.

1. Log in to your Login Enterprise appliance web interface
2. Navigate to the **Downloads** or **Tools** section
3. Download the **ScriptEditor** package (.zip)
4. Extract the zip to: `C:\Program Files\Login VSI\ScriptEditor`
5. Verify the expected files exist:

```powershell
# These files must be present:
Test-Path "C:\Program Files\Login VSI\ScriptEditor\bin\ScriptAnalyzer.dll"
Test-Path "C:\Program Files\Login VSI\ScriptEditor\engine\LoginEnterprise.Engine.Standalone.exe"
```

> **Non-standard path?** If you extract ScriptEditor elsewhere, save the path so all skills find it automatically:
> ```powershell
> .\install\check-setup.ps1 -EditorRoot "D:\Tools\ScriptEditor" -EngineDir "D:\Tools\ScriptEditor\engine" -Save
> ```
> This saves to `~/.login-enterprise/config.json` and is read by all skills going forward.

## Step 4: Build the validator

Required for: script-validator, script-runner

The validator is a thin wrapper around the ScriptEditor's Roslyn analyzers. It must be built once per machine.

```powershell
cd skills\login-enterprise-validate-script\references\validator
.\install.ps1
```

This will:
- Auto-detect ScriptEditor at `C:\Program Files\Login VSI\ScriptEditor`
- Build `le-validate.dll`
- Run self-tests to confirm the analyzer works

If ScriptEditor is in a non-standard location:

```powershell
.\install.ps1 -EditorRoot "D:\path\to\ScriptEditor"
```

Expected output: `INSTALLED & VERIFIED` with both self-tests passing.

## Step 5: Install Python 3 (optional)

Required for: app-mapper (web), transcribe-video

```powershell
# Check if already installed
python --version
# Should show Python 3.x.x
```

> **Windows Python issue:** If `python` opens the Microsoft Store instead of running Python, use the Windows Python launcher instead: `py --version`. Alternatively, disable the Microsoft Store alias: **Settings > Apps > Advanced app settings > App execution aliases** — turn off "python.exe" and "python3.exe".

If not installed:

```powershell
winget install Python.Python.3.12
# Restart your terminal after installing
```

## Step 6: Install Playwright (optional)

Required for: app-mapper (web)

```powershell
pip install playwright
playwright install chromium
```

If `pip` is not recognized, use the Python launcher:

```powershell
py -m pip install playwright
py -m playwright install chromium
```

## Step 7: Install ffmpeg (optional)

Required for: transcribe-video

```powershell
winget install Gyan.FFmpeg
# Restart your terminal after installing — PATH update requires a new session
```

Verify:

```powershell
ffmpeg -version
ffprobe -version
```

> **Agent can't find ffmpeg?** Some AI agents run commands in a subprocess that doesn't see recent PATH changes. Restart your agent after installing ffmpeg. If it still can't find it, use the explicit path override: `--ffmpeg "C:\path\to\ffmpeg.exe" --ffprobe "C:\path\to\ffprobe.exe"`

## Step 8: Verify everything

Run the environment check from the repo root:

```powershell
.\install\check-setup.ps1
```

Expected output when everything is set up:

```
===================================================================
 Login Enterprise Skills -- Environment Check
===================================================================

 Platform:          Windows
 ScriptEditor:      C:\Program Files\Login VSI\ScriptEditor
 Engine:            C:\Program Files\Login VSI\ScriptEditor\engine (6.x.x+...)
 .NET 8 SDK:        8.0.xxx
 Validator:         built
 Python 3:          3.x.x
 Playwright:        1.x.x (chromium)
 ffmpeg:            x.x.x

 Skill readiness:
   [ready]   script-writer            no prerequisites
   [ready]   script-validator         .NET 8 + ScriptEditor + validator built
   [ready]   script-runner            .NET 8 + ScriptEditor + engine
   [ready]   app-mapper-desktop       Windows + engine + runner
   [ready]   app-mapper-web           Python 3 + playwright
   [ready]   transcribe-video         ffmpeg + Python 3

 All 6 skills operational.
===================================================================
```

If ScriptEditor is in a non-standard location:

```powershell
.\install\check-setup.ps1 -EditorRoot "D:\path\to\ScriptEditor" -EngineDir "D:\path\to\ScriptEditor\engine"
```

## What to do first

Once setup is complete, try these prompts with your AI agent:

**Generate a script (works immediately — no prerequisites):**
> "Write a Login Enterprise script that opens Notepad, types hello world, and saves the file"

**Validate a script:**
> "Validate Script.cs against Login Enterprise rules"

**Run a script:**
> "Run my Script.cs on the Login Enterprise engine"

**Map an application:**
> "Map the UI elements in Calculator so I can write a test script"

**Full workflow:**
> "Map Notepad, write a script to type and save a file, validate it, and run it"

## Troubleshooting

### Symlink creation fails
Enable Developer Mode: **Settings > System > For developers > Developer Mode > On**. Or run PowerShell as Administrator.

### `python` opens Microsoft Store
Use `py` instead of `python`, or disable the Store alias in **Settings > Apps > Advanced app settings > App execution aliases**.

### check-setup shows "(not found)" for ScriptEditor
Verify the zip was extracted to `C:\Program Files\Login VSI\ScriptEditor` and that `bin\ScriptAnalyzer.dll` exists inside it. If using a different path, pass `-EditorRoot`.

### Validator shows "(not built)"
Run `install.ps1` in the validator skill directory (see Step 4).

### ffmpeg works in PowerShell but not in my agent
Restart the agent — it may have been started before ffmpeg was added to PATH. Or use `--ffmpeg` / `--ffprobe` explicit path overrides.

### Agent can't find the skills
Re-run `.\install\install.ps1 -Agent <your-agent>`. Verify symlinks exist in the agent's skills directory (e.g., `~/.claude/skills/` for Claude Code).
