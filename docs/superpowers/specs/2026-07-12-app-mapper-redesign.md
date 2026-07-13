# App-Mapper Redesign

**Date:** 2026-07-12
**Status:** Approved

## Problem

The current app-mapper does a one-time DumpHierarchy dump, producing a static snapshot of an application's UI tree. This misses the reality of how applications work: UI changes as the user navigates. Clicking "File" opens a menu with new controls that weren't visible before. The current mapper can't capture those — it only sees the initial state.

Script-writer then guesses at control identifiers for steps beyond the initial view, leading to scripts that may not find the right controls at runtime.

## Goal

Redesign app-mapper to walk through a complete workflow step by step, mapping each action's target control against the live UI using multiple finder strategies. Build cumulative app-map.json files that grow across workflows, giving script-writer verified identifiers with known fallbacks.

## Decisions

| Decision | Choice |
|----------|--------|
| Core approach | Monolithic probe script — walks entire workflow in one engine run |
| Finder strategy | `FindAutomationElementByXPathOrInformation` as primary (tries multiple internally), then `FindControlWithXPath` and `FindControl` individually for fallback data |
| Deprecated API status | `FindAutomationElementByXPathOrInformation` is NOT deprecated — remove that label from script-writer docs |
| Map accumulation | Flat `controls[]` pool, union merge on finders, tagged with `discoveredBy` workflows |
| Catalog storage | Two-tier: project-local (`.app-maps/`, default) + global (`~/.login-enterprise/app-maps/`) |
| Web backend | Keep the standalone Playwright probe for web pages |
| Self-healing | Out of scope — schema supports it, but the detect/re-probe/fix flow ships later |
| Conflict resolution | Union merge — keep all finder results ever seen for a control |

## Core Mapping Loop

When the user provides a natural language workflow description, the mapper:

1. **Parses the natural language** into discrete steps: each step has a target control description and an action (click, type, etc.)

2. **Generates a monolithic probe script** (`.cs`) that for each step:
   - Calls `DumpHierarchy` to a temp file to capture current UI state
   - Tries all finder strategies against the target control:
     - `FindAutomationElementByXPathOrInformation` (primary)
     - `FindControlWithXPath` (recorder-compatible)
     - `FindControl` (by className/title)
   - Logs which finders succeeded and which failed, with exact parameters
   - Performs the action using the primary finder's result (with fallback chain)
   - Waits for UI to settle

3. **Runs the probe** on the real engine via `login-enterprise-script-runner`

4. **Parses the structured log output** into control entries with finder results

5. **Merges into app-map.json** — loads existing map if present, union-merges controls, tags with workflow name

## Probe Script Structure

The generated probe uses structured `Log()` lines for reliable parsing:

```csharp
public class AppMapperProbe : ScriptBase
{
    void Execute()
    {
        START(mainWindowTitle: "*Notepad*", timeout: 30);

        // Step 1: File menu
        DumpHierarchy("C:\\temp\\mapper\\step1_before.txt");
        Log("MAPPER_STEP|1|File menu|click");

        // Try all finders, log results
        var f1 = FindAutomationElementByXPathOrInformation(
            xpath: "/Menu/MenuItem", automationId: "", className: "",
            name: "File", controlType: "MenuItem", timeout: 5, continueOnError: true);
        Log("MAPPER_FINDER|1|FindAutomationElementByXPathOrInformation|"
            + (f1 != null ? "OK" : "FAIL") + "|xpath=/Menu/MenuItem;name=File;controlType=MenuItem");

        var f2 = MainWindow.FindControlWithXPath(
            xPath: "MenuItem:MenuBar/MenuItem", timeout: 5, continueOnError: true);
        Log("MAPPER_FINDER|1|FindControlWithXPath|"
            + (f2 != null ? "OK" : "FAIL") + "|xPath=MenuItem:MenuBar/MenuItem");

        var f3 = MainWindow.FindControl(
            title: "File", className: "MenuItem", timeout: 5, continueOnError: true);
        Log("MAPPER_FINDER|1|FindControl|"
            + (f3 != null ? "OK" : "FAIL") + "|title=File;className=MenuItem");

        // Use primary result to perform action
        if (f1 != null) f1.Click();
        else if (f2 != null) f2.Click();
        else if (f3 != null) f3.Click();
        else Log("MAPPER_STEP_FAIL|1|No finder succeeded");

        Wait(1);

        // Step 2: Open menu item
        DumpHierarchy("C:\\temp\\mapper\\step2_before.txt");
        Log("MAPPER_STEP|2|Open|click");
        // ... repeat finder pattern ...

        STOP();
    }
}
```

Key design points:
- `DumpHierarchy` before each step captures the UI state the finders work against
- `continueOnError: true` on all finders — failure doesn't abort the probe
- Structured log prefixes (`MAPPER_STEP`, `MAPPER_FINDER`, `MAPPER_STEP_FAIL`) for reliable parsing
- The agent generates finder parameters by matching step descriptions against DumpHierarchy output — first run is best-guess, real value is which finders succeed on the live app

### Bootstrap: first probe without prior data

On the very first mapping run for an app (no existing map), the agent generates finder parameters using best guesses from the natural language description (e.g., "File menu" → `name: "File", controlType: "MenuItem"`). The probe confirms or refutes these guesses. If a finder fails, the DumpHierarchy files captured during the run provide the real control tree — the agent can read these, refine the parameters, and generate a second probe with corrected finders. In practice, common controls (menus, buttons, text fields) resolve on the first attempt; unusual controls may need one refinement pass.

## App-Map.json Schema (v2.0)

```json
{
  "schemaVersion": "2.0",
  "app": {
    "name": "notepad",
    "kind": "desktop",
    "exePath": "C:\\Windows\\System32\\notepad.exe",
    "mainWindowTitle": "*Notepad*"
  },
  "capturedAt": "2026-07-12T...",
  "workflows": ["open-file", "save-as", "format-text"],
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

### Key schema changes from v1.0

- **`finders`** object per control — records every strategy tried, with status and exact params used. Script-writer uses `preferredFinder` but knows what fallbacks exist.
- **`discoveredBy`** array — which workflows found this control. Grows via union merge.
- **`workflows`** array at top level — all workflows mapped for this app.
- **`id`** field — stable kebab-case identifier derived from the label, used for deduplication across workflows.
- **`preferredFinder`** — set to `FindAutomationElementByXPathOrInformation` when it succeeds, otherwise the first finder that worked.

### Web controls

Web controls live in the same `controls[]` array with `kind: "web"` and use `suggestedLocator` instead of the desktop `finders` object:

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

## Catalog and Merge Behavior

### Two-tier storage

- **Project-local** (default): `.app-maps/` in the project directory. Maps live alongside scripts. Versioned with git.
- **Global**: `~/.login-enterprise/app-maps/` shared across all projects and agents.

### Merge on new workflow

1. Load existing `app-map.json` for the app (check project-local first, then global).
2. Run the probe for the new workflow.
3. For each control found:
   - If control `id` already exists: union merge `finders` (add new successful finders, keep existing), append workflow name to `discoveredBy`.
   - If control is new: add to `controls[]`.
4. Append workflow name to top-level `workflows[]`.
5. Update `capturedAt`.
6. Save back to same location.

### Import/export between tiers

```powershell
# Export a project map to global catalog
Export-AppMap -AppName "notepad" -To Global

# Import a global map into the current project
Import-AppMap -AppName "notepad" -From Global
```

### Skill activation behavior

- When asked to map an app, check for existing map (project-local → global).
- If found, ask: "An existing map for [app] has [N] controls from [workflows]. Add to it or start fresh?"
- Script-writer also checks for maps when generating scripts and offers to use them.

## Integration with Other Skills

### Script-writer

When generating a script, script-writer checks for an app-map (project-local → global). If found, uses `preferredFinder` params directly and can generate fallback chains:

```csharp
// Primary
var fileMenu = FindAutomationElementByXPathOrInformation(
    xpath: "/Menu/MenuItem", name: "File", controlType: "MenuItem",
    className: "", automationId: "", timeout: 5, continueOnError: true);
// Fallback
if (fileMenu == null)
    fileMenu = MainWindow.FindControlWithXPath("MenuItem:MenuBar/MenuItem", timeout: 5);
```

### Script-runner

The mapper uses script-runner to execute probe scripts. Same sibling dependency as the current mapper.

### Deprecated API correction

`FindAutomationElementByXPathOrInformation` and the `IAutomationElement` finder family must no longer be marked deprecated in `api-cheatsheet.md`. The mapper relies on them as the primary finder strategy. This is a doc fix in the script-writer skill.

### Web probe

For web workflows, the mapper uses the existing standalone Python Playwright probe. Web controls get `suggestedLocator` instead of desktop `finders`, but live in the same `controls[]` array.

## Prerequisites

- Windows (for desktop mapping — engine is .NET Framework 4.8)
- `login-enterprise-script-runner` skill installed (sibling path)
- ScriptEditor deployment with standalone engine
- Python 3 + Playwright (for web mapping only)

## Future: Self-Healing

Out of scope for this build. The schema is designed to support it: with multiple finders per control and workflow history, a future self-healing skill could detect a broken finder, re-probe the failing step, and update the map with new finder params. The `finders` object and `discoveredBy` history provide the data foundation.
