---
name: login-enterprise-map-application
description: >-
  Map a desktop application's UI controls or a web page's interactive elements
  by walking through a workflow step by step. For each action, tries multiple
  finder strategies (FindAutomationElementByXPathOrInformation, FindControlWithXPath,
  FindControl) and records which succeeded. Produces an app-map.json with verified
  control identifiers and fallback finders. Maps accumulate across workflows.
  Use when the user asks to map, discover, or identify UI elements in an application.
license: Apache-2.0
compatibility: >-
  Desktop mapping requires Windows, Login Enterprise Engine (standalone), and the
  login-enterprise-run-script skill. Web mapping requires Python 3 and Playwright.
metadata:
  author: loginvsi
  version: "2.0"
---

# Login Enterprise App Mapper

Walk through a user-described workflow step by step, probing each action's
target control against the live UI using multiple finder strategies. Produces
an `app-map.json` with verified control identifiers and known fallbacks.
Maps accumulate across workflows — run the mapper once per workflow, then
pass the map to `login-enterprise-write-script` for reliable scripts.

This skill **discovers** identifiers. It does not generate user scripts
(use `login-enterprise-write-script`) and does not run user scripts
(use `login-enterprise-run-script`).

## When to activate

Activate when the user says "map", "discover", "identify UI elements", "create an
app map", or "find controls" for a desktop application or web page. Also activate
when `login-enterprise-write-script` reports it cannot find a control and the user
wants to supply verified identifiers.

## Safety

**Before mapping a desktop app:**
- Close any similarly named applications. The engine uses window title matching and
  may attach to `Notepad++` when targeting `Notepad`, or `WordPad` when targeting `Word`.
- The engine will stop (close) the attached application when the probe completes.
  Unsaved work in the wrong app will be lost.
- Use specific `mainWindowTitle` patterns (e.g., `"*Untitled - Notepad"` instead of
  `"*Notepad*"`) to reduce false matches.

## Absolute rules

1. **Only emit controls actually observed.** Never fabricate or guess identifiers.
   If a finder fails and DumpHierarchy reveals nothing for a region, record the gap
   in `coverage.notes`. Do not invent controls.
2. **Never claim a map is complete.** Java apps, RDP windows, custom-draw regions,
   and dynamically-created controls may be invisible to UIAutomation. State this in
   `coverage`.
3. **A desktop probe launches the real application** in the current interactive
   Windows session. Warn the user before running.
4. **Probe runs with `-SkipValidation`.** The probe script is generated and
   controlled by the mapper — validation adds latency with no safety benefit.
   This is intentional, not an oversight.
5. **`FindAutomationElementByXPathOrInformation` is the primary finder.** It is
   not deprecated. Use it first; fall back to `FindControlWithXPath` and
   `FindControl` for additional data.

## Prerequisites

### Desktop mapping
- **Windows** — the engine is .NET Framework 4.8.
- `login-enterprise-run-script` skill installed at the expected sibling path.
- A ScriptEditor deployment with the standalone engine (`EngineDir`).

The mapper checks for the engine in this order:
1. Explicit `-EngineDir` parameter
2. Saved config at `~/.login-enterprise/config.json`
3. Standard path `C:\Program Files\Login VSI\ScriptEditor\engine`

**If not found, ask the user** — do not fail silently:
> "Where is your ScriptEditor/engine installed? I need the path to the engine directory
> (containing `LoginEnterprise.Engine.Standalone.exe`)."

Then save it so they don't have to provide it again:
```
.\install\check-setup.ps1 -EngineDir "D:\Tools\ScriptEditor\engine" -Save
```

### Web mapping
- **Python 3** on PATH.
- **Playwright**: `pip install playwright && playwright install chromium`.
- No ScriptEditor, engine, or runner needed.

## Procedure

### 1. Gather workflow description

Ask the user to describe the workflow in natural language, e.g.:
> "Open File menu, click Open, type a path, click OK."

### 2. Parse into discrete steps

Convert each natural language action into a step with:
- `label` — short human-readable description (e.g. "File menu")
- `action` — `click`, `type`, `select`, etc.
- `target` — best-guess control description (name, controlType, className)

### 3. Check for an existing map

Look for `<project>/.app-maps/<appname>.app-map.json` first, then
`~/.login-enterprise/app-maps/<appname>.app-map.json`.

If found, ask:
> "An existing map for [app] has [N] controls from [workflows]. Add to it or start fresh?"

### 4. Generate the probe script

Generate a monolithic `.cs` probe (`ScriptBase` subclass) that walks every
step in sequence. For each step:

```csharp
// Step N: <label>
DumpHierarchy("C:\\temp\\mapper\\stepN_before.txt");
Log("MAPPER_STEP|N|<label>|<action>");

var f1 = FindAutomationElementByXPathOrInformation(
    xpath: "<xpath>", automationId: "", className: "<cls>",
    name: "<name>", controlType: "<type>", timeout: 5, continueOnError: true);
Log("MAPPER_FINDER|N|FindAutomationElementByXPathOrInformation|"
    + (f1 != null ? "OK" : "FAIL") + "|xpath=<xpath>;name=<name>;controlType=<type>");

var f2 = MainWindow.FindControlWithXPath(
    xPath: "<recorder-xpath>", timeout: 5, continueOnError: true);
Log("MAPPER_FINDER|N|FindControlWithXPath|"
    + (f2 != null ? "OK" : "FAIL") + "|xPath=<recorder-xpath>");

var f3 = MainWindow.FindControl(
    title: "<name>", className: "<cls>", timeout: 5, continueOnError: true);
Log("MAPPER_FINDER|N|FindControl|"
    + (f3 != null ? "OK" : "FAIL") + "|title=<name>;className=<cls>");

// Perform action using best available finder
if (f1 != null) f1.<Action>();
else if (f2 != null) f2.<Action>();
else if (f3 != null) f3.<Action>();
else Log("MAPPER_STEP_FAIL|N|No finder succeeded");

Wait(1);

// Post-action verification: dump again and compare
DumpHierarchy("C:\\temp\\mapper\\stepN_after.txt");
// The agent compares before/after dumps using Compare-DumpHierarchy
// and logs the result:
Log("MAPPER_VERIFY|N|new=<count>|removed=<count>|<summary>");
```

Key points:
- `continueOnError: true` on every finder — failure never aborts the probe.
- `DumpHierarchy` before each step captures the live UI the finders work against.
- `DumpHierarchy` **after** each action captures what changed — the agent compares
  before/after to verify the action produced the expected UI state.
- Structured log prefixes (`MAPPER_STEP`, `MAPPER_FINDER`, `MAPPER_VERIFY`,
  `MAPPER_STEP_FAIL`) enable reliable post-run parsing.

### 5. Run the probe

Invoke `login-enterprise-run-script` with `-SkipValidation`:
```
run.ps1 -Script "probe.cs" -EngineDir "C:\ScriptEditor\engine" -SkipValidation
```

### 6. Parse structured log output

After the run, extract lines matching the three prefixes:

| Prefix | Fields (pipe-separated) |
|--------|------------------------|
| `MAPPER_STEP` | step number, label, action |
| `MAPPER_FINDER` | step number, method, OK/FAIL, params |
| `MAPPER_VERIFY` | step number, `new=N`, `removed=N`, summary |
| `MAPPER_STEP_FAIL` | step number, reason |

For each step:
- Collect `MAPPER_FINDER` lines to build the `finders` object. Set
  `preferredFinder` to `FindAutomationElementByXPathOrInformation` when it
  returned `OK`; otherwise the first method that returned `OK`.
- Read `MAPPER_VERIFY` to check post-action results. If `new=0` and
  `removed=0`, the action did not produce a detectable UI change — report
  this to the user rather than retrying blindly. The action itself may have
  failed (e.g., a menu didn't open, a dialog didn't appear).

### 7. Verify actions produced expected UI changes

After parsing the probe log, check each step's `MAPPER_VERIFY` result:

- **`new > 0`**: The action opened new UI (a menu, dialog, or panel). The new
  controls from the post-action dump should be added to the app-map.
- **`new = 0, removed = 0`**: The action did not produce a detectable UI change.
  **Do not retry blindly.** Report to the user: "Clicking [control] did not produce
  new UI elements. The action may have failed, or the resulting UI may not be visible
  to UIAutomation (e.g., custom-drawn controls, Java apps, RDP windows)."
- **`removed > 0`**: Controls disappeared (e.g., a dialog was closed). This is
  expected after close/dismiss actions.

Use the `Compare-DumpHierarchy` function in `mapper-lib.ps1` to compute the
before/after diff when generating the `MAPPER_VERIFY` log line in the probe.

### 8. Merge into app-map.json

1. Load existing map if present.
2. For each control found in this probe run:
   - If control `id` already exists: union-merge `finders` (add new successes,
     keep existing), append workflow name to `discoveredBy`.
   - If control is new: add to `controls[]`.
3. Append workflow name to top-level `workflows[]`.
4. Update `capturedAt` to now.
5. Save to `.app-maps/<appname>.app-map.json` in the project directory.

## App-map.json v2.0 schema

```json
{
  "schemaVersion": "2.0",
  "app": {
    "name": "notepad",
    "kind": "desktop",
    "exePath": "C:\\Windows\\System32\\notepad.exe",
    "mainWindowTitle": "*Notepad*"
  },
  "capturedAt": "2026-07-12T10:00:00Z",
  "workflows": ["open-file", "save-as"],
  "controls": [
    {
      "id": "file-menu",
      "label": "File menu",
      "controlType": "MenuItem",
      "className": "MenuBar",
      "name": "File",
      "xpath": "/Menu/MenuItem",
      "finders": {
        "FindAutomationElementByXPathOrInformation": {
          "status": "OK",
          "params": {
            "xpath": "/Menu/MenuItem",
            "name": "File",
            "controlType": "MenuItem",
            "className": "",
            "automationId": ""
          }
        },
        "FindControlWithXPath": {
          "status": "OK",
          "params": { "xPath": "MenuItem:MenuBar/MenuItem" }
        },
        "FindControl": {
          "status": "OK",
          "params": { "title": "File", "className": "MenuItem" }
        }
      },
      "preferredFinder": "FindAutomationElementByXPathOrInformation",
      "discoveredBy": ["open-file", "save-as"]
    }
  ],
  "coverage": {
    "method": "DumpHierarchy",
    "confidence": "high",
    "notes": "Java/RDP controls may not be visible to UIAutomation"
  }
}
```

Full schema reference: `references/schema/app-map-schema.md`

### Key fields

| Field | Description |
|-------|-------------|
| `id` | Stable kebab-case identifier derived from label; used for deduplication. |
| `finders` | Every strategy tried, with `status` and exact `params`. |
| `preferredFinder` | Strategy to use in generated scripts — `FindAutomationElementByXPathOrInformation` when it succeeds. |
| `discoveredBy` | Workflows that found this control; grows via union merge across runs. |
| `workflows` | All workflows mapped for this app (top-level). |

## Catalog

### Two-tier storage

- **Project-local** (default): `.app-maps/` in the project directory. Maps live
  alongside scripts and can be versioned with git.
- **Global**: `~/.login-enterprise/app-maps/` shared across all projects.

When looking up a map, check project-local first, then global.

### Merge behavior

Re-running the mapper for a new workflow merges into the existing map:
- New controls are appended.
- Existing controls gain new successful finders (union merge).
- `discoveredBy` and `workflows` arrays are union-appended.

### Import/export

```powershell
# Export project map to global catalog
Export-AppMap -AppName "notepad" -To Global

# Import global map into the current project
Import-AppMap -AppName "notepad" -From Global
```

### Index format

`~/.login-enterprise/app-maps/index.json` — one entry per map:
```json
[{
  "name": "notepad",
  "platform": "desktop",
  "version": "unknown",
  "capturedAt": "2026-07-12T10:00:00Z",
  "confidence": "high",
  "path": "notepad-desktop-unknown.app-map.json"
}]
```

## Web backend

Map a web page's interactive elements using a **standalone Playwright probe**
(outside the LE engine — `WebScriptBase` has no DOM enumeration capability).

### Map a web page

```
cd references\mapper
.\map-web.ps1 -Url "https://example.com"
```

Optional: `-AppName`, `-Browser` (chromium/firefox/webkit), `-OutputPath`,
`-WaitSeconds`, `-Headless $false`, `-AppVersion`, `-CatalogDir`.

### Web control format

Web controls live in the same `controls[]` array with `kind: "web"`:

```json
{
  "id": "learn-more-link",
  "label": "Learn more",
  "kind": "web",
  "role": "a",
  "tag": "a",
  "selector": "a",
  "suggestedLocator": "Locator(\"a\", innerText: \"Learn more\")",
  "discoveredBy": ["homepage-nav"]
}
```

`suggestedLocator` is a ready-to-use LE Playwright `Locator(...)` call.
Web map `coverage.confidence` is `"medium"` — SPAs and auth-gated pages may
not be fully captured.

## DumpHierarchy format

The engine's `DumpHierarchy` produces indented plain text (2 spaces per level):

```
(7D035E) Win32 Window:Notepad -- 'Untitled - Notepad'
  (8F02D0) Pane:NotepadTextBox -- ''
    (4F06FA) Document:RichEditD2DPT -- 'Text editor'
  TitleBar -- ''
    Button -- 'Close'
```

Each line: optional `(handle)`, then `ControlType[:ClassName]`, then `-- 'Name'`.
The agent extracts `controlType`, `className`, `name`, derives `xpath` from
nesting depth, and uses these to build finder parameters.

`AutomationId` is not available in DumpHierarchy output — the `automationId`
field in finder params is always empty string for desktop maps.

## Bootstrap: first probe without prior data

On the first mapping run (no existing map), generate finder parameters from
best guesses based on the natural language description, e.g.:
> "File menu" → `name: "File", controlType: "MenuItem"`

After the probe runs, the DumpHierarchy files captured during the run provide
the real control tree. If a finder failed, read the relevant dump file, locate
the actual control, and generate a refined probe with corrected parameters.

Common controls (menus, buttons, text fields) typically resolve on the first
attempt. Unusual controls may need one refinement pass.

## Integration

### Script-writer

When generating a script, `login-enterprise-write-script` checks for an app
map (project-local first, then global). If found, it uses `preferredFinder`
params directly and generates fallback chains:

```csharp
// Primary
var fileMenu = FindAutomationElementByXPathOrInformation(
    xpath: "/Menu/MenuItem", name: "File", controlType: "MenuItem",
    className: "", automationId: "", timeout: 5, continueOnError: true);
// Fallback
if (fileMenu == null)
    fileMenu = MainWindow.FindControlWithXPath(
        "MenuItem:MenuBar/MenuItem", timeout: 5);
```

### Script-runner

The mapper uses `login-enterprise-run-script` to execute probe scripts.
Same sibling path dependency as the runner skill.

## Common mistakes

| Mistake | Consequence |
|---------|-------------|
| Claiming the map is complete | UIAutomation cannot see Java/RDP/custom-draw controls. Always qualify `coverage.confidence`. |
| Running desktop mapper without the runner skill | The probe depends on `run.ps1` at the sibling path; the run will fail. |
| Treating `FindAutomationElementByXPathOrInformation` as deprecated | It is the primary finder; use it first. |
| Expecting `automationId` in desktop maps | DumpHierarchy does not expose it; the field is always empty string. |
| Expecting web maps to capture SPA state | The web probe captures initial page load only; dynamic content may be missing. |
| Skipping union merge when adding a workflow | New workflows must merge into the existing map, not overwrite it. |
| Using `~/.claude/` as catalog storage | The global catalog lives at `~/.login-enterprise/app-maps/`, not `~/.claude/`. |
