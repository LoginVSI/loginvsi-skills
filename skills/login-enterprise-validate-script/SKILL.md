---
name: login-enterprise-validate-script
description: >-
  Validate a Login Enterprise .cs automation script against the 8 Roslyn analyzer
  rules. Checks for correct timer usage, prohibited API calls, proper ScriptBase
  inheritance, and other compliance requirements. Use when the user asks to validate,
  check, or lint a Login Enterprise script.
license: Apache-2.0
compatibility: >-
  Requires Windows, .NET 8 SDK, and Login Enterprise ScriptEditor installed
  at C:\Program Files\Login VSI\ScriptEditor\.
metadata:
  author: loginvsi
  version: "1.0"
---

# Login Enterprise Script Validator

Validate Login Enterprise `.cs` scripts against the **same Roslyn analyzer the ScriptEditor
uses**, so a script is provably clean before it runs on the Engine.

This skill **only validates** — it does not generate scripts. For script generation, use
`login-enterprise-write-script`.

## When to activate

Use this skill when the user says things like:
- "validate this script"
- "check my Login Enterprise script"
- "lint the .cs file"
- "does this script pass the analyzer?"
- "are there any timer errors in this script?"

Do NOT activate this skill for script generation — use `login-enterprise-write-script` for that.

## Absolute rules

1. **Never claim a script is validated without running the validator.** If you cannot run the
   validator (no installed ScriptEditor, not on Windows), say so explicitly.
2. **Always validate a full compilation unit** (`using …; public class X : ScriptBase { … }`),
   never a loose method body — the analyzer resolves calls by fully-qualified symbol, so an
   unwrapped body produces *zero* diagnostics that look exactly like "clean."
3. **A compiler error means timer analysis did not run.** Fix compilation first, then re-validate.

## Platform requirements

The validator **requires Windows** with a deployed Login Enterprise ScriptEditor. It is not
possible to run the Roslyn analyzer on macOS or Linux because it loads `ScriptAnalyzer.dll` and
reference assemblies from your local ScriptEditor installation.

**If you are not on Windows or do not have ScriptEditor installed**, you must say so instead of
claiming the script is valid. You can still:
- Apply the lexical rules textually (whitespace, length, null/empty, negative values) as fast
  pre-checks, but clearly label these as "pre-checks only — not a full validation."
- Advise the user to run the validator on a Windows machine that has ScriptEditor deployed.

## The 8 analyzer rules

Authoritative list, severities, and the lexical-vs-structural split:
`references/validation-rules.md`.

| ID | Severity | What it checks |
|---|---|---|
| `SpacelessNameDiagnostic` | Error | Timer/screenshot name contains whitespace |
| `NameMaxLengthDiagnostic` | Error | Timer name exceeds 64 characters |
| `EmptyExceptionDiagnostic` | Error | Timer name is `""` |
| `NullExceptionDiagnostic` | Error | Timer name is `null` |
| `NegativeNumbersDiagnostic` | Error | `SetTimer` value is negative |
| `StartTimerDiagnostic` | Error | `StartTimer(x)` with no later matching `StopTimer(x)` |
| `StopTimerDiagnostic` | Error | `StopTimer(x)` with no earlier matching `StartTimer(x)` |
| `DuplicateDiagnostic` | Warning | Timer name reused on same path without `CancelTimer` |

See `references/validation-rules.md` for full details, including reserved timer names, analyzer
limitations, and the generation checklist.

## Install the validator (one-time per machine)

The validator is a C# project under `references/validator/`. It compiles against your locally
deployed ScriptEditor's Roslyn, so it cannot be shipped prebuilt.

```powershell
cd references\validator
.\install.ps1 -EditorRoot "C:\Program Files\Login VSI\ScriptEditor"
# Or let it auto-detect: .\install.ps1
```

This builds `le-validate.dll` and runs the two bundled self-tests to confirm the analyzer is
wired up. On success it prints the exact command to run for day-to-day validation.

**Re-run `install.ps1` only when you upgrade or replace your ScriptEditor deployment.** Day-to-day
validation never rebuilds — just run `le-validate.dll`.

## Validate a script

```powershell
dotnet references\validator\bin\Release\net8.0\le-validate.dll `
    --script path\to\Script.cs `
    --editor-dir "C:\Program Files\Login VSI\ScriptEditor"
```

Useful flags:
- `--wrap` — auto-wrap a bare method body in a class before validating
- `--class <name>` — class name to use with `--wrap` (default: `GeneratedTest`)
- `--base <ScriptBase|WebScriptBase>` — base class to use with `--wrap`

## Output format

The validator writes JSON to stdout:

```json
{
  "compiles": true,
  "findings": [
    {
      "id": "StartTimerDiagnostic",
      "severity": "Error",
      "line": 14,
      "category": "rule",
      "message": "StartTimer(\"Open Document\") has no matching StopTimer."
    }
  ]
}
```

Exit codes:
- `0` — no error-severity diagnostics (clean)
- `1` — one or more error-severity diagnostics
- `2` — tool/usage failure (bad args, missing files, build failure)

`category` values: `"compiler"` (CSxxxx), `"rule"` (one of the 8 analyzer rules),
`"analyzer-error"` (AD0001 — usually a downstream effect of a compile error), `"other"`.

## Procedure

1. **Run the validator** — requires Windows + a deployed ScriptEditor. Install once per machine
   (see above), then validate as many scripts as you like without rebuilding:

   ```powershell
   dotnet references\validator\bin\Release\net8.0\le-validate.dll --script path\to\Script.cs --editor-dir "C:\Program Files\Login VSI\ScriptEditor"
   ```

2. **Read the JSON output:**
   - `"compiles": false` → the script has compiler errors (`category: "compiler"`, `CSxxxx`). Fix
     those FIRST: a non-compiling script makes the analyzer throw (`AD0001`), so timer results are
     unreliable until it compiles. (The validator drops the `AD0001` noise when `compiles` is false.)
   - `category: "rule"` → one of the 8 analyzer rules. Fix the script and re-validate.

3. **Only report success after a clean run** (`"compiles": true`, empty `findings`, exit 0).

4. **If a generated script fails validation**, fix the violations and re-validate. Common fixes:
   - Add a missing `StopTimer` to match every `StartTimer`.
   - Remove whitespace from timer/screenshot names.
   - Ensure timer names are ≤64 chars, not `""`, not `null`.

## Confirm the validator is actually wired up

Before trusting a "clean" result, prove the analyzer is really being applied — a missing
`ScriptBase` reference produces *zero* findings that look identical to success. Run the two
bundled self-tests once per machine/editor:

- `references/examples/_selftest-bad.cs` → MUST exit 1 with `compiles: true` and exactly
  `SpacelessNameDiagnostic`, `StartTimerDiagnostic`, and `StopTimerDiagnostic`. If it comes back
  clean, the analyzer is not running (usually the reference assemblies did not load) — fix that
  before trusting any result.
- `references/examples/measured-notepad.cs` → MUST exit 0 with `compiles: true` and empty `findings`.

Both are verified working against ScriptEditor 6.6 (Roslyn 4.7.0).

## Error handling: ScriptEditor not found

The validator checks for ScriptEditor in this order:
1. Explicit `-EditorRoot` parameter (if provided)
2. Saved config at `~/.login-enterprise/config.json`
3. Standard path `C:\Program Files\Login VSI\ScriptEditor`

If ScriptEditor is not found, **ask the user** where it is installed. Do not silently fail.

Prompt the user with something like:
> "ScriptEditor was not found at the default location. Where is your ScriptEditor installed?
> Please provide the path (e.g., `D:\Tools\ScriptEditor`)."

Once the user provides the path, use it with `-EditorRoot` and **save it** so they don't
have to provide it again:
```
.\install\check-setup.ps1 -EditorRoot "D:\Tools\ScriptEditor" -Save
.\install.ps1 -EditorRoot "D:\Tools\ScriptEditor"
```

The saved config at `~/.login-enterprise/config.json` is read automatically by all skills.

If ScriptEditor is not installed at all, guide the user:
1. Log in to your Login Enterprise appliance web interface.
2. Navigate to the Downloads or Tools section.
3. Download the ScriptEditor package (`.zip`).
4. Extract to a folder (e.g. `C:\Program Files\Login VSI\ScriptEditor`).
5. Ensure the extracted folder contains `bin\`, `ReferenceAssemblies\`, and `ScriptEditor.Config`.

Contact your Login Enterprise administrator if you do not have access to the appliance.

## Why validate with Roslyn, not text matching

The structural rules (Start/Stop pairing, duplicate detection with `CancelTimer` handling)
depend on Roslyn's semantic model and cross-statement analysis. A regex reimplementation
silently drifts and gives false confidence. The lexical rules (whitespace, length, null/empty,
negative value) are safe to pre-check textually for fast feedback, but the validator is the
only authoritative answer. See `references/validation-rules.md`.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Handing the validator a bare method body | Won't compile → `compiles: false`, `CSxxxx` errors, no timer analysis |
| `StartTimer` with no later `StopTimer` (or vice versa) | `StartTimerDiagnostic` / `StopTimerDiagnostic` (Error) |
| Reusing a timer name without an intervening `CancelTimer` | `DuplicateDiagnostic` (Warning) |
| Whitespace in a timer/screenshot name | `SpacelessNameDiagnostic` (Error) |
| Treating `compiles: false` as "no timer problems" | Timer analysis did not run; fix the compiler errors first |
| Claiming validated without running the tool on Windows | Dishonest result — state the limitation instead |
| AD0001 warning on a compiling script | Known ScriptAnalyzer limitation — timer analysis may be incomplete for scripts with helper methods, while loops, or try/catch. The script is likely valid; the analyzer crashed, not the script. |
