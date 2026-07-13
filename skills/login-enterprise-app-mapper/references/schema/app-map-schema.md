# app-map.json Schema (v2.0)

## Top-level fields

| Field | Type | Description |
|---|---|---|
| `schemaVersion` | `string` | Always `"2.0"`. |
| `app` | `object` | Application metadata. |
| `capturedAt` | `string` | ISO 8601 UTC timestamp of the capture. |
| `workflows` | `array` | Ordered list of workflow names exercised during capture (e.g. `["open-file", "edit-text"]`). |
| `coverage` | `object` | What was captured and how confident it is. |
| `controls` | `array` | Array of control descriptor objects. |

## `app` object

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Friendly name (e.g. `"notepad"`). |
| `kind` | `string` | `"desktop"` or `"web"`. |
| `exePath` | `string` | Absolute path to the target executable (desktop only; omit for web). |
| `mainWindowTitle` | `string` | Wildcard title passed to `START()`, or empty (desktop only). |

> **v2.0 change:** `app.process` has been removed. Use `exePath` and `mainWindowTitle` directly on the `app` object.

## `workflows` array

A flat ordered list of string identifiers for the workflows exercised during this capture session. Each workflow name is referenced in `controls[].discoveredBy` to show which workflow(s) first exposed a control.

```json
"workflows": ["open-file", "edit-text"]
```

## `coverage` object

| Field | Type | Description |
|---|---|---|
| `method` | `string` | Capture method: `"DumpHierarchy"` (desktop) or `"AriaSnapshot"` (web). |
| `confidence` | `string` | `"high"`, `"medium"`, or `"low"`. |
| `notes` | `string` | Caveats (e.g. black-box regions, dynamic content). |

## `controls[]` — control descriptor

### Desktop controls (`kind: "desktop"`)

| Field | Type | Description |
|---|---|---|
| `id` | `string` | Kebab-case identifier unique within this map (e.g. `"file-menu"`). |
| `label` | `string` | Human-readable label for display and agent use. |
| `controlType` | `string` | UIAutomation `ControlType` (e.g. `"Button"`, `"Document"`, `"MenuItem"`). |
| `className` | `string` | UIAutomation `ClassName` property. May be empty. |
| `name` | `string` | UIAutomation `Name` property. May be empty. |
| `xpath` | `string` | Computed XPath from UIAutomation nesting (e.g. `"/Menu/MenuItem"`). |
| `finders` | `object` | Finder methods tried during capture, keyed by method name. |
| `preferredFinder` | `string` | Name of the recommended finder to use at script time. |
| `discoveredBy` | `array` | List of workflow names (from `workflows`) that exposed this control. |

### `finders` object

Each key is a Login Enterprise script finder method name. Each value has:

| Field | Type | Description |
|---|---|---|
| `status` | `string` | `"OK"` if the finder located the control, `"FAIL"` if it did not. |
| `params` | `object` | Named parameters to pass to the finder. Shape varies by finder method (see below). |

#### `FindAutomationElementByXPathOrInformation` params

This is the **primary finder** for desktop controls. It uses both XPath and UIAutomation property matching for robust element location.

| Param | Type | Description |
|---|---|---|
| `xpath` | `string` | UIAutomation XPath (e.g. `"/Menu/MenuItem"`). |
| `name` | `string` | UIAutomation `Name` to match. |
| `controlType` | `string` | UIAutomation `ControlType` to match. |
| `className` | `string` | UIAutomation `ClassName` to match. |
| `automationId` | `string` | UIAutomation `AutomationId` to match. Usually `""`. |

#### `FindControlWithXPath` params

| Param | Type | Description |
|---|---|---|
| `xPath` | `string` | Login Enterprise XPath notation (e.g. `"MenuBar:MenuBar/MenuItem"`). |

#### `FindControl` params

| Param | Type | Description |
|---|---|---|
| `title` | `string` | Window or control title to match. |

### Web controls (`kind: "web"`)

For web applications (`app.kind: "web"`), controls use a simplified structure:

| Field | Type | Description |
|---|---|---|
| `id` | `string` | Kebab-case identifier unique within this map. |
| `label` | `string` | Human-readable label. |
| `kind` | `string` | Always `"web"` for web controls. |
| `tag` | `string` | HTML tag name (e.g. `"button"`, `"input"`). |
| `role` | `string` | ARIA role if present. |
| `name` | `string` | `aria-label` value if present. |
| `suggestedLocator` | `string` | Ready-to-use Playwright/CSS locator string. |
| `discoveredBy` | `array` | List of workflow names that exposed this control. |

> Web controls use `suggestedLocator` (a CSS or ARIA selector) instead of the `finders` object, because web probing uses Playwright rather than UIAutomation.

## Merge behavior

When `mapper-lib.ps1` is run against an existing `app-map.json`, it performs an **additive merge**:

1. Controls with matching `id` are updated — new finders are added to their `finders` object and `discoveredBy` is extended.
2. Controls not present in the existing map are appended.
3. Controls in the existing map that are not re-discovered are **preserved** (not removed).
4. `workflows` array is extended with any new workflow names; existing entries are not duplicated.
5. `capturedAt` is updated to the current run's timestamp.
6. `preferredFinder` is only updated if the new run finds a higher-priority finder (priority: `FindAutomationElementByXPathOrInformation` > `FindControlWithXPath` > `FindControl`).

This means incremental workflow runs progressively enrich a single map file without losing previously captured data.

## Version compatibility

- v1.0 maps are **not compatible** with v2.0 tooling. The `suggestedFinder` string field (v1.0) has been replaced by the structured `finders` object (v2.0).
- `app.process` (v1.0) is removed in v2.0. Migrate by moving `app.process.exePath` to `app.exePath` and `app.process.mainWindowTitle` to `app.mainWindowTitle`.
- Re-run the mapper against any v1.0 maps to generate a fresh v2.0 map.
