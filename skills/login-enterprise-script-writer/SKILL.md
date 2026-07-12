---
name: login-enterprise-script-writer
description: Use when a user wants a Login Enterprise application script for native Windows automation, NativeAutomationElement workflows, recorder-compatible built-in scripting functions, timer instrumentation, secure credential use, or Playwright-based web recorder functions. Generates a complete .cs script for the ScriptEditor/Engine and outputs ONLY the final script with no explanation.
license: Apache-2.0
compatibility: No specific requirements. Works on any platform.
metadata:
  author: loginvsi
  version: "1.0"
---

# Login Enterprise Script Writer

Generate a complete Login Enterprise application script (`.cs`) from a natural-language
request. The script must compile in the ScriptEditor (RoslynPad host) and run on the Engine.

## Absolute rules

1. **Output ONLY the final `.cs` script.** No prose, no markdown fences, no commentary —
   unless the user explicitly asks for an explanation.
2. **Use only the allowed library surface** (`references/allowlist.md`): netstandard2.0 +
   Interop.UIAutomationClient + LoginPI.Engine.ScriptBase. The host runs .NET 8 but does NOT
   reference the .NET 8 BCL. Modern C# *language* syntax is fine; modern *library* APIs are not.
3. **Never hardcode credentials.** Use `ApplicationUser` / `ApplicationPassword` /
   `GetParameterValue(...)` and type secrets with `hideInLogging: true`.
4. **Emit a full compilation unit** (`using …; public class X : ScriptBase { void Execute() {…} }`),
   never a loose method body — the ScriptEditor's analyzer resolves calls by fully-qualified
   symbol, so an unwrapped body produces zero diagnostics that look exactly like "clean."

## What this skill can and can't know

This skill generates scripts grounded against the **API surface** (allowlist, cheatsheet,
skeletons, timer rules), but it **guesses** app-specific identifiers — desktop
`AutomationId`/`ClassName`/`Name`/`controlType`/XPath and web CSS/Playwright selectors.
A script that validates clean still compiles with selectors that point at nothing.

**Validated does not mean drives the app.** Mitigations:
- **Before writing:** use `login-enterprise-app-mapper` to capture real identifiers into an
  `app-map.json`, then pass it to this skill. The writer will use `suggestedFinder` calls from
  the map instead of guessing.
- **After writing:** use `login-enterprise-script-runner` to verify the script actually drives
  the app on the real engine.

## Procedure

1. **Check for an app map.** If the user provides an `app-map.json` (or one exists in the
   agent's app-map catalog for the target app), read it and use the `controls[]`
   entries — specifically `suggestedFinder`, `xpath`, `className`, `controlType`, and `name` —
   instead of guessing identifiers. Note the map's `coverage.confidence` in your internal
   self-check; if confidence is low, mention that some selectors may need adjustment.
   If no map is available, proceed as before — the skill works without one.
2. **Classify the request → mode.** Read `references/modes.md`. Choose:
   - Desktop (native Windows / UIAutomation) → base class `ScriptBase`.
   - Web → default to **Playwright** (`WebScriptBase`); use **legacy CSS/Selenium**
     (`FindWebComponentBySelector`) ONLY if the user explicitly names the legacy recorder.
   For desktop element finding, **ALWAYS use** `MainWindow.FindControlWithXPath(xPath: "...")` which uses
   the `ControlType:ClassName` XPath format (e.g., `"Pane:MyClass/Button:ButtonClass"`).
   This matches the recorder's behavior and the app-mapper's `suggestedFinder` output.

   **CRITICAL: DO NOT use `FindAutomationElementByXPathOrInformation` or `FindAutomationElementByXPath`.**
   These use a different XPath format (`/ControlType/ControlType`) that doesn't work reliably.
   If an app map provides a `suggestedFinder`, copy it EXACTLY as shown.
3. **Pick the skeleton** from `references/skeletons.md` (magic comments, base class, `Execute`
   signature, usings, lifecycle calls). **Magic comments are mandatory** — they must appear
   before the `using` lines. See `references/skeletons.md` for the required comments per mode.
   Add `using Interop.UIAutomationClient;` only if the script touches `NativeAutomationElement`.
4. **Map intent → API calls** using `references/api-cheatsheet.md`. Use exact signatures. Give
   finders sensible `timeout` and `continueOnError` values. If an app map is available, use
   `suggestedFinder` calls from the map for element finding instead of guessing identifiers.
5. **Instrument with timers.** Wrap each user-perceived action (search, open, save, navigate,
   report) in `StartTimer("name")` / `StopTimer("name")`. Use `SetTimer("name", milliseconds)`
   for precomputed measurements. Timer names must satisfy the analyzer rules in
   `references/validation-rules.md`:
   - No whitespace, ≤64 chars, not `""`, not `null`.
   - **NEVER use reserved timer names:** `app_start_time`, `app_stop_time`, `page_load_time`,
     `login_time`, `logout_time`. These are reserved by the engine and will cause runtime errors.
     Use descriptive alternatives like `application_launch`, `open_app`, `navigate_to_page`, etc.
   - Every `StartTimer("N")` has a later `StopTimer("N")` on every path.
   - Every `StopTimer("N")` has an earlier `StartTimer("N")`.
   - Each timer name is unique per path (or `CancelTimer` before reuse).
   - Every `SetTimer` value ≥ 0.
   - Screenshot names: no whitespace.
6. **Handle credentials** via the documented pattern (see `api-cheatsheet.md` → Credentials).
7. **Draft the script.**
8. **Internal self-check (do NOT show this to the user). Verify against `references/allowlist.md`
   and `references/validation-rules.md`:**
   - Magic comments are present and correct for the mode (see `references/skeletons.md`).
   - Every `using` is in the allowlist.
   - Every API/type used exists in the cheatsheet (Engine) or netstandard2.0 / UIAutomation.
     No post-netstandard2.0 BCL APIs.
   - Correct base class + `Execute` signature for the mode (sync `void` vs `async Task`).
   - Lifecycle balanced: `START`/`STOP` (desktop) or `StartBrowser`/`StopBrowser` (web).
   - Timer instrumentation satisfies all 8 analyzer rules (see `references/validation-rules.md`).
   - No reserved timer names (`app_start_time`, `app_stop_time`, `page_load_time`, etc.).
   - No hardcoded credentials.
   - If an app map was used: verify every `suggestedFinder` call matches the map's schema.
   - If web is async: all awaitable calls are `await`ed; `Execute` is `async Task`.
   Fix any violation silently and re-check.
9. **Emit ONLY the final `.cs` script.**

## References
- `references/allowlist.md` — what you may use (and the negative list of what you may not).
- `references/skeletons.md` — exact templates per mode.
- `references/modes.md` — how to pick the mode and element strategy.
- `references/api-cheatsheet.md` — categorized signatures.
- `references/validation-rules.md` — the 8 ScriptAnalyzer rules for timers and names.
- `references/examples/` — real, working scripts to pattern-match against.
