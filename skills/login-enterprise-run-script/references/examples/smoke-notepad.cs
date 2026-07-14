// TARGET:C:\Windows\System32\notepad.exe
// START_IN:
using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;

// Known-GOOD smoke test for the RUNNER: launches Notepad and types text under one timer.
// A clean run ends as ScriptResult.Ended (engine exit code 1); run.ps1 normalizes that to
// success:true and parses the "Type_Body" timer out of the results CSV.
public class SmokeNotepad : ScriptBase
{
    void Execute()
    {
        START(mainWindowTitle: "*Notepad*", mainWindowClass: "*Notepad*", timeout: 30);

        StartTimer("Type_Body");
        MainWindow.Type("Login Enterprise runner smoke test.");
        StopTimer("Type_Body");

        STOP();
    }
}
