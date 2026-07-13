---
name: login-enterprise-script-runner
description: Use when a user wants to run a Login Enterprise .cs script on the real standalone engine after validating it. Validates first by default (via login-enterprise-script-validator), then executes LoginEnterprise.Engine.Standalone.exe and reports the normalized result and timers. Windows only. Does not generate or fix scripts — use login-enterprise-script-writer / login-enterprise-script-validator for that.
license: Apache-2.0
compatibility: >-
  Requires Windows, Login Enterprise Engine (standalone), and the
  login-enterprise-script-validator skill's le-validate.dll built locally.
metadata:
  author: loginvsi
  version: "1.0"
---

# Login Enterprise Script Runner

Execute a Login Enterprise `.cs` script on the **real standalone engine**
(`LoginEnterprise.Engine.Standalone.exe`), gated by validation. This skill **runs** scripts; it
does not generate them (use `login-enterprise-script-writer`) and does not reimplement validation
(it calls `login-enterprise-script-validator`).

## Absolute rules

1. **Never claim a script "ran clean" without a real run on Windows.** If you are not on Windows,
   or the engine/validator is unavailable, say so explicitly — do not infer a result.
2. **The process exit code is NOT a reliable success signal.** The deployed engine (observed on
   6.5.10) exits `0` on success — and `0` isn't even a `ScriptResult` enum value. The exit code
   also varies by engine build. `run.ps1` therefore decides success from the engine's **stdout
   markers** — success is `The script ended` with no failure line; `We could not construct the
   script to be executed` is a compile error; `did not complete successfully` / `encountered an
   error` are failures. Trust `run.ps1`'s `success` field; the reported `exitCode` is informational.
3. **A run launches the real target application** in the current interactive Windows session. This
   is not a sandbox. Warn the user before running.
4. **Validation is the default gate.** A `compiles:false` result or any error-severity finding
   stops the run. `-SkipValidation` is an explicit, called-out opt-out — only use it when the user
   asks.

## Prerequisites

- **Windows** (the engine is a .NET Framework 4.8 executable).
- A ScriptEditor deployment containing `…\engine\LoginEnterprise.Engine.Standalone.exe` (`EngineDir`).
- For the default validation gate: a **built** `le-validate.dll` from the
  `login-enterprise-script-validator` skill (run its `install.ps1` once) and the deployed
  ScriptEditor root (`EditorDir`).

## Required script header

The engine needs a metadata header comment, or it throws:

- **Windows app:** `// TARGET:C:\Windows\System32\notepad.exe` (optionally `// START_IN:...`)
- **Web app:** `// BROWSER:EdgeChromium` (optionally `// URL:...`); valid browsers: `chrome`,
  `edge42`, `edge44`, `edgechromium`, `firefox`.

`run.ps1` pre-flights this and fails early with guidance if it is missing.

## Procedure

1. **Run the wrapper** (Windows). It validates, pre-flights the header, runs the engine with a
   `results=` folder, and prints a JSON summary:
   ```
   cd references\runner
   .\run.ps1 -Script path\to\Script.cs -EngineDir "C:\ScriptEditor\engine" -EditorDir "C:\ScriptEditor"
   ```
   Optional pass-throughs: `-Parameters`, `-User`, `-Password`, `-Results`, `-Repeats`,
   `-LeaveRunning`, `-DebugMode`. To run a pre-validated script without re-validating, add
   `-SkipValidation` (then `-EditorDir` is not required).
   (The parameter is `-DebugMode`, not `-Debug`, because `-Debug` is a reserved PowerShell common
   parameter.)

2. **Read the JSON** (`exitCode` is the raw engine code — often `0` even on success; ignore it as
   a verdict and use `success`):
   ```json
   { "success": true, "result": "Ended", "exitCode": 0,
     "timers": [ { "name": "Type_Body", "value": 123, "timestamp": "..." } ],
     "resultsCsv": "...", "logPath": "%TEMP%\\LoginPI\\Logs\\Engine ....txt" }
   ```
   - `success:false` → report `result` and point the user at `logPath` for the engine log.
   - `result:"CompilationError"` → the engine could not compile it; re-check with the validator.

   **Exit code semantics:** The engine's `exitCode` field uses Login Enterprise's internal
   `ScriptResult` enum where `1 = Ended` (success). This is NOT a Unix-style exit code
   where 0 means success. The `result` field (`"Ended"`) and the `success` field (`true`)
   are the authoritative verdicts. Do not interpret `exitCode: 1` as a failure.

3. **Only report success after `success:true`** (`result:"Ended"`; `run.ps1` itself exits 0 when
   it judges the run successful).

**Partial success:** A script can produce valid timer measurements but still report
`EndedWithErrors` if cleanup fails (e.g., `StopBrowser()` throws). Timer evidence in
the CSV is still valid. Check the `timers` array in the JSON output — if your target
timers are present with values, the measured interaction succeeded even if the final
verdict is `EndedWithErrors`.

## Confirm the runner is actually wired up

Once per machine, run the bundled smoke test — it proves validate→run works end to end and that
the `1 = success` normalization and CSV timer parsing are correct:

```
cd references\runner
.\run-smoke.ps1 -EngineDir "C:\ScriptEditor\engine" -EditorDir "C:\ScriptEditor"
```

It runs `references/examples/smoke-notepad.cs` (launches Notepad), expects `OVERALL: PASS`
(`success:true`, `result:Ended`, a `Type_Body` timer), and writes `smoke-results.txt`.

## Pure-logic tests

The run-outcome classification (stdout markers), results-CSV parsing, header detection, and arg
building live in `references/runner/runner-lib.ps1` and are covered by `runner-lib.tests.ps1`
(Pester, runs on any OS via `pwsh`): `Invoke-Pester -Path references/runner/runner-lib.tests.ps1`.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Judging success from the engine exit code | Unreliable — the engine exits `0` on success (and the code varies by build). Trust `run.ps1`'s stdout-derived `success`. |
| Running a script with no `// TARGET:`/`// BROWSER:` header | Pre-flight fails (or the engine throws). |
| Using `-SkipValidation` by default | Skips the safety gate; only do so when the user explicitly asks. |
| Claiming a clean run while not on Windows | Dishonest — state the limitation instead. |
| Expecting timers without a `results=` folder | `run.ps1` always sets one; raw engine calls without it emit no CSV. |
| Passing `-Debug` | Not a parameter — use `-DebugMode` (`-Debug` is a reserved common parameter). |
