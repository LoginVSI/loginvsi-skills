# Architecture

## How Skills Relate

```
WRITE  script-writer     --> Script.cs     (generate from natural language)  ← available
         │
VALIDATE script-validator --> pass/fail    (check against 8 Roslyn rules)    ← available
         │
RUN    script-runner     --> results       (execute on standalone engine)     (coming soon)
```

Both `script-writer` and `script-validator` are available in Phase 1. Each skill works
independently. The typical flow is: generate a `.cs` file with `script-writer`, then
validate it with `script-validator` (requires Windows, .NET 8 SDK, and ScriptEditor
installed at `C:\Program Files\Login VSI\ScriptEditor\`).

The validator uses a C# project under `skills/login-enterprise-script-validator/references/validator/`
with its own `install.ps1` to build the validation tooling on first use.

Future skills (`script-runner`, `app-mapper`, `create-test`, `transcribe-video`)
will extend this pipeline. See [PRD.md](PRD.md) for the full planned flow.

## Skill Format

Skills follow the [agentskills.io specification](https://agentskills.io/specification).
See [../CONTRIBUTING.md](../CONTRIBUTING.md) for detailed format requirements.
