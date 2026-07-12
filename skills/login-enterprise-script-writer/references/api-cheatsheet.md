# API cheatsheet (LoginPI.Engine.ScriptBase 3.1.611-LE-7698)

Namespaces: `LoginPI.Engine.ScriptBase`, `LoginPI.Engine.ScriptBase.Components`.

## Lifecycle (ScriptBase.application.cs)
```csharp
bool START(string mainWindowTitle=null, string mainWindowClass=null, string processName=null,
           int timeout=180, bool continueOnError=false, bool forceKillOnExit=true);
bool StartApplication(string mainWindowTitle=null, string mainWindowClass=null,
           int timeout=180, bool continueOnError=false, bool forceKillOnExit=true);
void STOP(int timeout=5);
void ABORT(string error);
IWindow MainWindow { get; }     // set by START
string CommandLine { get; set; }
string WorkingDirectory { get; set; }
```
Wildcards in title/class/process: `*` (any chars), `?` (one char).

## Timers / instrumentation
```csharp
void StartTimer(string name);
void StopTimer(string name);
void CancelTimer(string name);
void SetTimer(string name, int value);  // inject precomputed measurement, no pair
```
Names: alphanumeric + underscore, ≤32 chars (docs say 64; stay ≤32). Stop/Cancel must match Start.
**⚠️ IMPORTANT: DO NOT use timers in a loop.** Each timer name can only be started and stopped once per script execution.

## Waits / logging / events
```csharp
void Wait(double seconds, bool showOnScreen=false, string onScreenText="Waiting...");
void Log(string message);
void Log(object component);
void CreateEvent(string title, string description=null);
void TakeScreenshot(string name, string description=null);  // name: no spaces
```

## Window finding (ScriptBase.os.cs)
```csharp
IProcess ShellExecute(string commandLine, string workingFolder="", bool waitForProcessEnd=true,
           int timeout=180, bool continueOnError=false, bool forceKillOnExit=true);
IWindow   FindWindow(string title=null, string className=null, string processName=null,
           int timeout=30, bool continueOnError=false);
IWindow[] FindWindows(string title=null, string className=null, string processName=null, int timeout=30);
IWindow   FindWindowByClassAndName(string name=null, string className=null, int timeout=30, bool continueOnError=false);
IWindow[] FindWindowsByClassAndName(string name=null, string className=null, int timeout=30);
IWindow   FromNativeWindowHandle(IntPtr handle);
```
Wildcards `*` (any chars) and `?` (one char) work in title, className, and processName.

## IProcess (from ShellExecute)
```csharp
void Stop();                    // gracefully exit, kill if needed
IWindow GetMainWindow();        // get the main window of the process
bool ProcessHasExited { get; }  // check if process has exited
int ProcessExitCode { get; }    // get exit code (0 = success)
```
Example:
```csharp
var cmd = ShellExecute("cmd /c dir", waitForProcessEnd: false);
if (cmd.ProcessExitCode == 0) { Log("Success"); }
```

## IWindow (Components/IWindow.cs)
```csharp
IWindow Maximize(); IWindow Minimize(); IWindow Restore(); IWindow Focus(); void Close();
void SwitchTopMostWindow(bool isTopLevel);
IWindow[] GetAllChildControls();
IWindow FindControl(string className=null, string title=null, int timeout=5,
           bool searchRecursively=true, bool continueOnError=false, string text=null);
IWindow FindControlWithXPath(string xPath, int timeout=5, bool continueOnError=false);
// XPath format: "ControlType:ClassName/ControlType:ClassName" e.g. "Pane:MyPanel/Button:ButtonClass"
// Use [n] index notation for multiple siblings: "Menu:NetUIKeyboardTabElement/TabItem:NetUIRibbonTab[3]"
// This is the PREFERRED method for element finding - matches recorder and app-mapper output.
IProcess GetProcess(); string GetTitle(); string GetClass(); string GetControlType();
string GetFrameworkType(); string GetText(); WindowCoordinates GetBounds();
Location PointAt(int xOffset, int yOffset);
IntPtr NativeWindowHandle { get; }
IUIAutomationElement NativeAutomationElement { get; }   // needs using Interop.UIAutomationClient;
IWindow Type(string text, int cpm=300, bool hideInLogging=true, bool forceFocus=true);
bool Click(bool continueOnError=false, bool forceFocus=true);
bool DoubleClick(bool continueOnError=false, bool forceFocus=true);
bool RightClick(bool continueOnError=false, bool forceFocus=true);
bool MoveMouseToCenter(bool continueOnError=false, double hoverTimeAfterMove=0, bool forceFocus=true);
bool Click(double x, double y, bool continueOnError=false, bool forceFocus=true);
IWindow DumpHierarchy(string filePath, bool refreshBeforeDump=false);
```
**Common control actions** (available on IWindow from FindControl/FindWindow):
```csharp
control.Click();              // left click
control.DoubleClick();        // double click
control.RightClick();         // right click
control.Focus();              // focus the control
control.Type("text", cpm:300);// type text to this control
control.GetTitle();           // get control title
control.GetClass();           // get control class name
control.GetText();            // get control text content
control.GetBounds();          // get coordinates (WindowCoordinates)
control.GetAllChildControls();// get direct child controls
```
`WindowCoordinates` (from `GetBounds()`) exposes Center/North/South/East/West/corners/X/Y/Width/Height
and supports chained `.Click()/.MouseMove()` — prefer this over absolute coordinates.

## IAutomationElement (Components/IAutomationElement.cs) — script-level finders also exist on ScriptBase
**⚠️ DEPRECATED - DO NOT USE THESE METHODS:**
These methods use a DIFFERENT XPath format (`/ControlType/ControlType`) that doesn't work reliably.
**ALWAYS use `MainWindow.FindControlWithXPath()`** instead, which uses the `ControlType:ClassName` format
that matches the recorder and app-mapper output. If an app map provides a `suggestedFinder`, use it exactly.
```csharp
IAutomationElement FindAutomationElementByXPath(string xpath, int timeout=30, bool continueOnError=false);
IAutomationElement FindAutomationElementByInformation(string automationId, string className,
           string name, string controlType, int timeout=30, bool continueOnError=false);
IAutomationElement FindAutomationElementByXPathOrInformation(string xpath, string automationId,
           string className, string name, string controlType, int timeout=30, bool continueOnError=false);
IEnumerable<IAutomationElement> FindAllAutomationElementByXPath(string xpath, int timeout=30, bool continueOnError=false);
IEnumerable<IAutomationElement> FindAllAutomationElementByInformation(string automationId, string className,
           string name, string controlType, int timeout=30, bool continueOnError=false);
IEnumerable<IAutomationElement> FindAllAutomationElementByXPathOrInformation(string xpath, string automationId,
           string className, string name, string controlType, int timeout=30, bool continueOnError=false);
void Type(string text, int cpm, bool hideInLogging, bool forceFocus=true);
bool Click(bool continueOnError=false, bool forceFocus=true);    // + DoubleClick/RightClick/MoveMouse*
IAutomationWindow GetRootWindow(); IAutomationWindow AsWindow();
```

## Keyboard (ScriptBase.keyboard.cs)
```csharp
void Type(string text, int cpm=300, bool hideInLogging=true);
void TypeCommand(string commandText);   // e.g. "CTRL+s"
void KeyDown(params KeyCode[] keys);
void KeyUp(params KeyCode[] keys);
```
**Type tips:**
- Use `{ENTER}`, `{CTRL+O}`, `{TAB}`, `{ESC}`, `{PAGEDOWN}`, `{F12}`, etc. for special keys
- Use `.Repeat(n)` to repeat keys: `"{PAGEDOWN}".Repeat(3)` sends PAGEDOWN 3 times
- Use `@"C:\path"` verbatim strings for paths (backslash is normally escape char)
- Text case is preserved: `"HELLO"` types uppercase, `"hello"` types lowercase

`KeyCode` enum (Constants/KeyCode.cs): BACK, TAB, ENTER, SHIFT, CTRL, ALT, ESCAPE, SPACE, PAGEUP,
PAGEDOWN, END, HOME, LEFT, UP, RIGHT, DOWN, INSERT, DELETE, KEY_A..KEY_Z, NUMPAD0..9, F1..F12,
NUMLOCK, MULTIPLY, ADD, SUBTRACT, DECIMAL, DIVIDE, LWIN, RWIN.

## Mouse (ScriptBase.mouse.cs)
```csharp
bool Click(double x, double y, bool continueOnError=false); void Click();
bool RightClick(double x, double y, bool continueOnError=false);
bool DoubleClick(double x, double y, bool continueOnError=false);
bool MouseMove(double x, double y, bool continueOnError=false);
bool MouseMoveBy(double dx, double dy, bool continueOnError=false);
void MouseDown(); void MouseUp();
```

## Credentials / parameters (ScriptBase.parameters.cs)
```csharp
string ApplicationUser { get; }            // the __user__ parameter
string ApplicationPassword { get; }        // the __password__ parameter
string GetParameterValue(string parameterId);
double GetNumericParameterValue(string parameterId);
string GetEnvironmentVariable(string variableName, bool continueOnError=false);
```
Documented login pattern:
```csharp
Type(ApplicationUser, hideInLogging: true);
Type("{ENTER}");
Type(ApplicationPassword, hideInLogging: true);
```
There is NO `GetUserName()`/`GetPassword()`. Never hardcode secrets.

## File system (ScriptBase.os.cs) + KnownFiles (Constants/KnownFiles.cs)
```csharp
void CopyFile(string src, string dst, bool continueOnError=false, bool overwrite=true);
void CopyFolder(string src, string dst, bool continueOnError=false, bool overwrite=true);
void RemoveFile(string path, bool continueOnError=false);
void RemoveFolder(string path, bool continueOnError=false);
void UnzipFile(string src, string dstFolder, bool continueOnError=false, bool overWrite=false);
bool FileExists(string path); bool DirectoryExists(string path);
void RegImport(string registryFile, bool continueOnError=false);
// KnownFiles static strings: WordDocument, PdfFile, PowerPointPresentation, RichTextFile,
// PlainTextFile, ExcelSheet, OutlookConfiguration, OutlookData, WebSite
// Usage: CopyFile(KnownFiles.ExcelSheet, @"C:\Temp\loginvsi.xlsx");
```

## Legacy web (ScriptBase.webbrowser.cs)
```csharp
bool StartBrowser(bool useInPrivateBrowsing=false, string expectedUrl=null, int timeout=60, bool continueOnError=false);
void StopBrowser();
void Navigate(string url, string timerName=null);
bool WaitForUrl(string url, string timerName=null, int timeout=60, bool continueOnError=false);
void Back();
string InitialUrl { get; } string CurrentUrl { get; }
IWebComponent   FindWebComponentBySelector(string selector, int timeout=30, bool continueOnError=false, string text=null);
IWebComponent[] FindAllWebComponentsBySelector(string selector, int timeout=30, string text=null);
bool SwitchToFrame(int index, bool continueOnError=false);   // also (string name), (IWebComponent), (Frames)
// IWebComponent: Type(...), Click(...), MoveMouseToCenter(...), FindChildBySelector(...),
//                GetBounds(), Tag, Text, CssSelector
```

## Playwright web (WebScriptBase.cs / Components/IPlaywrightBrowser.cs / IPlaywrightLocator.cs)
```csharp
Task StartBrowser(); Task StopBrowser();
Task NavigateAsync(string url, string timerName=null);
// NOTE: NavigateAsync's timerName parameter auto-starts/stops the timer internally.
// If you use timerName, do NOT also wrap with StartTimer/StopTimer - that causes
// "Timer was started twice" error. Either use timerName OR manual Start/StopTimer, not both.
IPlaywrightLocator Locator(string selector, string frameSelector=null, string innerText=null, int? timeout=null);
Task TypeAsync(string input, int cpm, bool hideInLogging=false);
Task PressAsync(string input);
void KeyDown(params KeyCode[] keys); void KeyUp(params KeyCode[] keys);
Task ScrollAsync(int x, int y, string scrollStartSelector=null, string scrollStartTextSelector=null,
                 string scrollEndSelector=null, string scrollEndTextSelector=null);
Task AlertAsync(string type, bool isConfirmed=true, string promptInput=null);
void Wait(int seconds); // NOTE: Wait takes SECONDS, not milliseconds. Wait(1) = 1 second.
void Log(string message); void CreateEvent(string title, string description=null);
void ABORT(string error); string GetEnvironmentVariable(string variableName, bool continueOnError=false);
// IPlaywrightLocator methods (ONLY these are available):
//   Task ClickAsync(LocatorClickOptions opts=default);
//   Task RightClickAsync(LocatorClickOptions opts=default);
//   Task DblClickAsync(LocatorClickOptions opts=default);
//   Task HoverAsync(LocatorHoverOptions opts=default);
// NOTE: There is NO WaitForAsync() method. To wait for an element:
//   - Use the `timeout` parameter on Locator(): Locator("selector", timeout: 10)
//   - Or use HoverAsync() which implicitly waits for the element
```

## Common patterns

### Skip first-run dialogs (Office apps)
```csharp
private void SkipFirstRunDialogs()
{
    var dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "WINWORD",
                           continueOnError: true, timeout: 1);
    while (dialog != null)
    {
        dialog.Close();
        dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "WINWORD",
                           continueOnError: true, timeout: 10);
    }
}
```

### Robust text input with validation
```csharp
public static void SetTextBoxText(ScriptBase script, IWindow textBox, string text, int cpm = 800)
{
    var numTries = 1;
    string currentText = null;
    do
    {
        textBox.Type("{CTRL+a}");
        script.Wait(0.5);
        textBox.Type(text, cpm: cpm);
        script.Wait(1);
        currentText = textBox.GetText();
        if (currentText != text)
            script.CreateEvent($"Typing error in attempt {numTries}", $"Expected '{text}', got '{currentText}'");
    }
    while (++numTries < 5 && currentText != text);
    if (currentText != text)
        script.ABORT($"Unable to set the correct text '{text}', got '{currentText}'");
}
```

### Get file dialog helper
```csharp
private IWindow GetFileDialog()
{
    var dialog = FindWindow(className: "Win32 Window:#32770", processName: "WINWORD",
                           continueOnError: true, timeout: 10);
    if (dialog is null)
    {
        ABORT("File dialog could not be found");
    }
    return dialog;
}
```

### Conditional control handling
```csharp
var button = MainWindow.FindControl(title: "Save", continueOnError: true);
if (button != null)
{
    button.Click();
}
else
{
    CreateEvent("Button not found", "Save button was not found, skipping");
}
```
