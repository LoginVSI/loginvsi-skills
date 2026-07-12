# Mode & element-strategy selection

## Step 1 — pick the mode
| Request looks like… | Mode | Base class | Execute |
|---|---|---|---|
| A Windows desktop app (Notepad, Office, an .exe, UIAutomation, file ops) | Desktop | `ScriptBase` | `void Execute()` |
| A website / browser flow (modern, default) | Playwright | `WebScriptBase` | `async Task Execute()` |
| User explicitly says "legacy", "Selenium", or "CSS selector recorder" | Legacy web | `ScriptBase` | `void Execute()` |

Default web = Playwright. Mixing modern + legacy in one script is unsupported.

## Step 2 — desktop element-location strategy
Mirror the WinApp recorder's strategies (these are NOT mode toggles — they are how you write finders):
- **FindControlWithXPath (DEFAULT/recommended):** use
  `MainWindow.FindControlWithXPath(xPath: "ControlType:ClassName/ControlType:ClassName", timeout: 10)`.
  XPath format is `ControlType:ClassName` segments separated by `/` (e.g., `"Pane:MyPanel/Button:ButtonClass"`).
  This matches the recorder output and the app-mapper's `suggestedFinder` calls.
- **Information only:** `FindAutomationElementByInformation(automationId, className, name, controlType, timeout)`
  — resilient to structure change, slower. Use when XPath fails.

Prefer `FindControlWithXPath` unless the user asks for something specifically.

### Grounding with an app map

If an `app-map.json` is available for the target app (from `login-enterprise-app-mapper` or the
catalog at `~/.claude/le-app-maps/`), use its `controls[].suggestedFinder` calls directly —
these contain real `xpath`, `className`, `name`, and `controlType` values observed from the live
app. This replaces guessing. Note the map's `coverage.confidence`; if `"low"`, some controls may
be missing and fallbacks may still be needed.

## Step 3 — difficult-app fallbacks (no image mode exists in 6.6)
When controls cannot be found by UIAutomation:
- Coordinate clicks — prefer `GetBounds()`-relative chained clicks over absolute `Click(x,y)`.
- Keyboard navigation — `Type("{TAB}")`, `Type("{ENTER}")`, `KeyDown/KeyUp`.
- `NativeAutomationElement` (requires `using Interop.UIAutomationClient;`).
- `DumpHierarchy("C:\\path.txt")` to discover control identifiers (troubleshooting only).
- Java apps, RDP/VDI windows, and embedded non-Chromium browsers are black boxes — only
  start/stop + timing are reliable.

## Recorder-compatible built-ins (use these names, recorder emits them)
START, STOP, ShellExecute, Wait, Log, CreateEvent, TakeScreenshot, StartTimer/StopTimer/
CancelTimer/SetTimer, FindWindow(s), FindControl, Find*AutomationElement*, Type/TypeCommand,
KeyDown/KeyUp, Click/DoubleClick/RightClick/MouseMove, CopyFile (+KnownFiles), StartBrowser/
StopBrowser/Navigate(Async), FindWebComponentBySelector, Locator.
