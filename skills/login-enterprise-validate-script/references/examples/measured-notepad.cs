// TARGET:C:\Windows\System32\notepad.exe
// START_IN:
using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;

// Known-GOOD self-test: every StartTimer has a later StopTimer, names are clean and unique.
// Validating this should produce zero `rule`-category findings (exit 0).
public class MeasuredNotepad : ScriptBase
{
    void Execute()
    {
        START(mainWindowTitle: "*Notepad*", mainWindowClass: "*Notepad*", timeout: 30);

        StartTimer("Open_Document");
        MainWindow.Type("^o");
        FindAutomationElementByInformation(automationId: null, className: null, name: "Open", controlType: null, timeout: 15).Click();
        StopTimer("Open_Document");

        StartTimer("Type_Body");
        MainWindow.Type("The quick brown fox.");
        StopTimer("Type_Body");

        // Aggregate/explicit measurement also passes the rules.
        SetTimer("Save_Latency", 1200);

        STOP();
    }
}
