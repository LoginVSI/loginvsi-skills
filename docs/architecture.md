# Architecture

## How Skills Relate

```
MAP    app-mapper        --> app-map.json  (real UI identifiers from the live app)  ← available
         │
WRITE  script-writer     --> Script.cs     (generate from natural language)         ← available
         │
VALIDATE script-validator --> pass/fail    (check against 8 Roslyn rules)           ← available
         │
RUN    script-runner     --> results       (execute on standalone engine)            ← available
```

`app-mapper`, `script-writer`, `script-validator`, `script-runner`, and `transcribe-video` are all available.
The full map → write → validate → run pipeline is functional. Each skill also works independently.

**transcribe-video**: An independent utility skill. Convert screen recordings (`.mp4`, `.mov`,
etc.) into step-by-step documentation. Requires Python 3 and ffmpeg on `PATH`. Works on any
platform with no Login Enterprise installation required.

**app-mapper**: Map a desktop application's UI control tree or a web page's DOM into
`app-map.json`, producing real automation identifiers (AutomationId, Name, ClassName, XPath)
before script writing begins. Desktop mapping requires Windows, Login Enterprise Engine
(standalone), and the script-runner skill. Web mapping requires Python 3 and Playwright
(`pip install playwright`).

**script-writer**: Generate a `.cs` automation script from natural-language instructions.
Works on any platform with no additional tools required. Accepts an `app-map.json` produced
by app-mapper to use accurate control identifiers.

**script-validator**: Validate a script against Login Enterprise's 8 Roslyn analyzer rules.
Requires Windows, .NET 8 SDK, and ScriptEditor installed at
`C:\Program Files\Login VSI\ScriptEditor\`. Uses a C# project under
`skills/login-enterprise-script-validator/references/validator/` with its own `install.ps1`
to build the validation tooling (`le-validate.dll`) on first use.

**script-runner**: Execute a validated `.cs` script on the Login Enterprise standalone engine
and report results. Requires Windows, Login Enterprise Engine (standalone) installed and
running, and `le-validate.dll` already built (run `script-validator`'s `install.ps1` first).

Any AI agent with these skills installed can orchestrate the full pipeline naturally by
chaining the skills in sequence. See [PRD.md](PRD.md) for background.

## Skill Format

Skills follow the [agentskills.io specification](https://agentskills.io/specification).
See [../CONTRIBUTING.md](../CONTRIBUTING.md) for detailed format requirements.
