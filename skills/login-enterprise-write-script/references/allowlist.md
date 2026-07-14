# Allowlist — what generated scripts may use

The ScriptEditor registers three assembly references at startup. Engine version: `LoginPI.Engine.ScriptBase` 3.1.611.

## Allowed assemblies (the ONLY ones referenced)
- `NETStandard.Library` 2.0.3 — the **netstandard2.0** BCL surface only.
- `Interop.UIAutomationClient` 10.19041.0 — native UIAutomation (`IUIAutomationElement`).
- `LoginPI.Engine.ScriptBase` 3.1.611 — the script API.

## Always-safe usings
```csharp
using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;                 // netstandard2.0 members only
using System.Threading.Tasks;    // required for Playwright/WebScriptBase
```

## Conditionally required usings
- `using Interop.UIAutomationClient;` — add ONLY when the script uses `NativeAutomationElement`.

## DO NOT USE (not in the reference set — will fail to resolve)
The host runs on .NET 8 but only references netstandard2.0. Do **not** use APIs added after
netstandard2.0, even if they exist in .NET 8. Common temptations to avoid:
- `System.Text.Json` (not in netstandard2.0) — if JSON is unavoidable, parse manually or avoid it.
- `System.Net.Http.HttpClient` advanced/.NET-5+ overloads; `IHttpClientFactory`.
- File APIs added after 2.0 (e.g. `File.ReadAllLinesAsync`, `File.AppendAllTextAsync`) — use the
  synchronous netstandard2.0 versions (`File.ReadAllText`, `File.WriteAllText`).
- `System.Range`/`System.Index` ranges on arbitrary types, `record` types requiring `init`-only
  setters polyfills, `DateOnly`/`TimeOnly`, `System.MemoryExtensions` span helpers added post-2.0.
- Any third-party NuGet package — only the three assemblies above exist.
- Inventing APIs: there is **no** image-matching API, **no** `GetUserName()`/`GetPassword()`.

## Language version
C# `LanguageVersion.Latest` is used for parsing, so modern *syntax* (top-level locals, pattern
matching, `var`, string interpolation, `using` declarations) is fine. The constraint is the
**library** surface, not the language version.
