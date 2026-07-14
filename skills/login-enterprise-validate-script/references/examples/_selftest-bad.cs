// TARGET:C:\Windows\System32\notepad.exe
// START_IN:
using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;

// Known-BAD self-test: use this to confirm the validator is actually wired to the analyzer.
// Validating this MUST report (exit 1):
//   StartTimerDiagnostic   - "Open Document" has no matching StopTimer
//   SpacelessNameDiagnostic - timer name "Open Document" contains whitespace
//   StopTimerDiagnostic    - StopTimer("Ghost") has no preceding StartTimer
// If this script validates clean, the analyzer is NOT being applied (most likely the
// LoginPI.Engine.ScriptBase reference didn't load, so symbols don't resolve).
public class SelfTestBad : ScriptBase
{
    void Execute()
    {
        START(mainWindowTitle: "*Notepad*", mainWindowClass: "*Notepad*", timeout: 30);

        StartTimer("Open Document");   // whitespace + never stopped
        MainWindow.Type("hello");

        StopTimer("Ghost");            // never started

        STOP();
    }
}
