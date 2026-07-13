# Architecture

## How Skills Relate

```
WRITE  script-writer     --> Script.cs     (generate from natural language)  ← available
         │
VALIDATE script-validator --> pass/fail    (check against 8 Roslyn rules)    ← available
         │
RUN    script-runner     --> results       (execute on standalone engine)     ← available
```

`script-writer`, `script-validator`, and `script-runner` are all available. The full
writer → validator → runner pipeline is functional. Each skill also works independently.

**script-writer**: Generate a `.cs` automation script from natural-language instructions.
Works on any platform with no additional tools required.

**script-validator**: Validate a script against Login Enterprise's 8 Roslyn analyzer rules.
Requires Windows, .NET 8 SDK, and ScriptEditor installed at
`C:\Program Files\Login VSI\ScriptEditor\`. Uses a C# project under
`skills/login-enterprise-script-validator/references/validator/` with its own `install.ps1`
to build the validation tooling (`le-validate.dll`) on first use.

**script-runner**: Execute a validated `.cs` script on the Login Enterprise standalone engine
and report results. Requires Windows, Login Enterprise Engine (standalone) installed and
running, and `le-validate.dll` already built (run `script-validator`'s `install.ps1` first).

Future skills (`app-mapper`, `create-test`, `transcribe-video`)
will extend this pipeline. See [PRD.md](PRD.md) for the full planned flow.

## Skill Format

Skills follow the [agentskills.io specification](https://agentskills.io/specification).
See [../CONTRIBUTING.md](../CONTRIBUTING.md) for detailed format requirements.
