# Script skeletons

## Magic comments

Every script **must** start with magic comments before the `using` lines. The ScriptEditor
parses these to configure the execution environment. The set of comments depends on the mode.
Comments that say "required" must have a value; comments that say "must exist" must be present
but may be blank.

### Desktop / Windows
```
// TARGET:C:\Windows\System32\notepad.exe
// START_IN:
```
- `// TARGET:` — **required**, path to the executable (with optional args).
- `// START_IN:` — **must exist**, working directory (value is optional).

### Web — Playwright (default)
```
// BROWSER:chrome
// BROWSER_ARGUMENTS:
// URL:https://example.com
// PROFILE:
```
- `// BROWSER:` — **required** (`chrome` or `edgechromium`).
- `// BROWSER_ARGUMENTS:` — **must exist** (value is optional).
- `// URL:` — **required**, the starting URL.
- `// PROFILE:` — **must exist** (value is optional).

### Web — Legacy CSS/Selenium
```
// BROWSER:edgechromium
// URL:https://example.com
// PROFILE:
```
- `// BROWSER:` — **required** (`edgechromium`, `firefox`, `chrome`, `edge42`, or `edge44`).
- `// URL:` — **required**, the starting URL.
- `// PROFILE:` — **must exist** (value is optional).

---

## Desktop / Windows (synchronous)
```csharp
// TARGET:C:\Path\app.exe
// START_IN:
using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;

public class MyScript : ScriptBase
{
    void Execute()
    {
        START(mainWindowTitle: "*Title*", mainWindowClass: "*Class*", timeout: 30);

        // interact via MainWindow / Find* + timers

        STOP();
    }
}
```
Add `using Interop.UIAutomationClient;` if you reference `NativeAutomationElement`.

## Web — Playwright (DEFAULT, async)
```csharp
// BROWSER:chrome
// BROWSER_ARGUMENTS:
// URL:https://example.com
// PROFILE:
using LoginPI.Engine.ScriptBase;
using System.Threading.Tasks;

public class MyWebScript : WebScriptBase
{
    async Task Execute()
    {
        await StartBrowser();
        await NavigateAsync("https://example.com", "Navigate_Home");

        // await Locator("selector").ClickAsync(); etc.

        // Robust cleanup: StopBrowser() can throw if the browser process exited early
        // (sandbox, self-closing page). Timers already recorded remain valid.
        try { await StopBrowser(); } catch { /* browser already closed */ }
    }
}
```

## Web — Legacy CSS/Selenium (only if user explicitly asks)
```csharp
// BROWSER:edgechromium
// URL:https://example.com
// PROFILE:
using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;

public class MyLegacyWebScript : ScriptBase
{
    void Execute()
    {
        StartBrowser(expectedUrl: "https://example.com", timeout: 60);
        Navigate("https://example.com", "Navigate_Home");

        FindWebComponentBySelector("button[id='go']", timeout: 30).Click();

        StopBrowser();
    }
}
```

## Rules
- Exactly one public class; PascalCase name derived from the task unless the user names it.
- Desktop = `ScriptBase` + `void Execute()`. Playwright = `WebScriptBase` + `async Task Execute()`.
- Never mix Playwright (`WebScriptBase`) and legacy (`ScriptBase` web) in one script.
- Magic comments are **mandatory** and must appear before the `using` lines.
