# le-validate — Login Enterprise script validator

A thin host (`Program.cs` → `le-validate.dll`) that validates a Login Enterprise `.cs` script
against the **same Roslyn analyzer the ScriptEditor uses**. It does not reimplement anything — it
loads the editor's own `ScriptAnalyzer.dll`, Roslyn, and `LoginPI.Engine.ScriptBase` reference
assemblies from a deployed ScriptEditor.

## Requirements

- **Windows** with a **deployed ScriptEditor** — the unzipped folder (`EditorRoot`) containing
  `bin\`, `ReferenceAssemblies\` and `ScriptEditor.Config` (e.g. `C:\Program Files\Login VSI\ScriptEditor`).
- **.NET 8 SDK** (the validator targets `net8.0`; the deployed Roslyn is `4.7.0`). No NuGet —
  it references the Roslyn inside the deployment, so it builds offline.

## Install (one-time)

```powershell
.\install.ps1 -EditorRoot "C:\Program Files\Login VSI\ScriptEditor"   # or just .\install.ps1 to auto-detect
```

This builds `le-validate.dll` against your editor's Roslyn and runs the self-tests to prove the
analyzer is actually wired up. On success it prints the validate command.

> **Why build instead of ship a prebuilt binary?** The wrapper is compiled against your editor's
> *exact* Roslyn version. `le-validate.dll`, the deployed `ScriptAnalyzer.dll`, and Roslyn must all
> agree on a single `Microsoft.CodeAnalysis` identity, or the analyzer silently returns nothing —
> which looks identical to "clean." Building locally guarantees the match.

## Validate a script

```powershell
dotnet bin\Release\net8.0\le-validate.dll --script path\to\Script.cs --editor-dir "C:\Program Files\Login VSI\ScriptEditor"
```

Output is JSON: `{ "compiles": bool, "findings": [ {id, severity, line, category, message} ] }`.
Exit code: `0` = no error-severity diagnostics, `1` = errors present, `2` = tool/usage failure.

Useful flags: `--wrap` (wrap a bare method body in a class), `--class <name>`, `--base
<ScriptBase|WebScriptBase>`. Full procedure and rule set: the skill's `SKILL.md` and
`../validation-rules.md`.

## When to rebuild

**Day-to-day validation never rebuilds** — just run `le-validate.dll`. Re-run `install.ps1`
**only when you upgrade or replace the ScriptEditor deployment**, since a new deployment can ship
a different Roslyn version the wrapper must be rebuilt against.

## Files

| File | Purpose |
|------|---------|
| `install.ps1` | One-time build + verify; prints the validate command and when to rebuild. |
| `run-selftests.ps1` | Build + run both self-tests, writing `selftest-results.txt` to hand back. |
| `Program.cs` | The validator host. |
| `Validator.csproj` | References the deployed Roslyn via `-p:EditorRoot` (no NuGet). |
| `global.json` | Pins .NET 8 SDK (roll-forward to latest patch within major). |
