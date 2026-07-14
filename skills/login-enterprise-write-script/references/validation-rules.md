# Login Enterprise analyzer rules

These are the rules enforced by `ScriptAnalyzer` (shipped inside ScriptEditor and loaded by the
RoslynPad host). The analyzer inspects timer instrumentation calls and screenshot names for
correctness at compile time.

> The active rule set and the `LoginPI.Engine.ScriptBase` version are whatever the **installed
> ScriptEditor** shipped. This file documents the rule set as of ScriptBase 3.1.611; the
> validator always reflects the installed build, which is the source of truth.

## Targeted methods

The analyzer only fires on these fully-qualified calls — which is why the script must compile
with the `ScriptBase` reference for symbols to resolve:

- `LoginPI.Engine.ScriptBase.ScriptBase.StartTimer(string)`
- `LoginPI.Engine.ScriptBase.ScriptBase.StopTimer(string)`
- `LoginPI.Engine.ScriptBase.ScriptBase.CancelTimer(string)`
- `LoginPI.Engine.ScriptBase.ScriptBase.SetTimer(string, int)`
- `LoginPI.Engine.ScriptBase.ScriptBase.TakeScreenshot(string, string)`

## The 8 rules

| ID | Severity | Rule |
|---|---|---|
| `SpacelessNameDiagnostic` | Error | Name arg to `StartTimer`/`SetTimer`/`TakeScreenshot` cannot contain whitespace (checked after trimming ends). |
| `NameMaxLengthDiagnostic` | Error | Timer name > 64 chars. |
| `EmptyExceptionDiagnostic` | Error | Timer name is `""`. |
| `NullExceptionDiagnostic` | Error | Timer name is `null`. |
| `NegativeNumbersDiagnostic` | Error | `SetTimer(name, value)` value < 0. |
| `StartTimerDiagnostic` | Error | `StartTimer(x)` has no matching `StopTimer(x)` *after* it (by source position). |
| `StopTimerDiagnostic` | Error | `StopTimer(x)` has no matching `StartTimer(x)` *before* it. |
| `DuplicateDiagnostic` | Warning | Same timer name defined twice in the same execution path (an intervening `CancelTimer(x)` clears it). |

## Two classes of rule

**Lexical / local** — inspect a single literal argument; safe to pre-check with text for fast
feedback, but not authoritative:
`SpacelessNameDiagnostic`, `NameMaxLengthDiagnostic`, `EmptyExceptionDiagnostic`,
`NullExceptionDiagnostic`, `NegativeNumbersDiagnostic`.

**Structural / semantic** — need Roslyn's semantic model + cross-statement analysis; do NOT
reimplement these in text:
`StartTimerDiagnostic`, `StopTimerDiagnostic`, `DuplicateDiagnostic`.

## Analyzer limitations to know

- **Only compile-time-known arguments are checked.** If a timer name/value isn't a literal the
  analyzer can resolve, it bails. Dynamic names are not validated — so a script can pass
  validation and still have a runtime timer-name problem.
- **Start/Stop matching is positional**, not true control-flow (`SpanStart` ordering). The
  analyzer uses source position ordering rather than true control-flow analysis.
- **`IDE0051`** (unused private member) is suppressed by the host and by the validator.

## Reserved timer names

The Login Enterprise engine reserves certain timer names for internal use. **DO NOT use these names
for your timers** — the engine will reject them at runtime with the error:
`'<name>' is a reserved keyword and cannot be used for timers`

| Reserved Name | Purpose |
|---|---|
| `app_start_time` | Reserved by engine for application startup measurement |
| `app_stop_time` | Reserved by engine for application shutdown measurement |
| `page_load_time` | Reserved by engine for web page load measurement |
| `login_time` | Reserved by engine for login measurement |
| `logout_time` | Reserved by engine for logout measurement |

**Use descriptive alternatives instead:**
- Instead of `app_start_time` → use `application_launch`, `launch_app`, `start_application`, `open_app`
- Instead of `page_load_time` → use `page_navigation`, `navigate_to_page`, `load_page`
- Instead of `login_time` → use `user_login`, `authenticate_user`, `sign_in`

## Generation checklist (make output correct-by-construction)

- [ ] Every `StartTimer("N")` has a later `StopTimer("N")` on every path.
- [ ] Every `StopTimer("N")` has an earlier `StartTimer("N")`.
- [ ] Each timer name is unique per path (or `CancelTimer` before reuse).
- [ ] Names: no whitespace, ≤64 chars, not `""`, not `null`.
- [ ] **Names: not a reserved keyword** (see table above).
- [ ] Every `SetTimer` value is ≥ 0.
- [ ] Screenshot names: no whitespace.
