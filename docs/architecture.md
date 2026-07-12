# Architecture

## How Skills Relate

```
WRITE  script-writer     --> Script.cs     (generate from natural language)
         │
VALIDATE script-validator --> pass/fail    (check against 8 Roslyn rules)
```

Each skill works independently. The `script-writer` generates `.cs` files that can
then be validated by `script-validator`.

Future skills (`script-runner`, `app-mapper`, `create-test`, `transcribe-video`)
will extend this pipeline. See [PRD.md](PRD.md) for the full planned flow.

## Skill Format

Skills follow the [agentskills.io specification](https://agentskills.io/specification).
See [../CONTRIBUTING.md](../CONTRIBUTING.md) for detailed format requirements.
