// TARGET:C:\Windows\System32\notepad.exe
// START_IN:
using LoginPI.Engine.ScriptBase;

public class UIAutomation : ScriptBase
{
    void Execute()
    {
        START();

        var nativeAutomation = MainWindow.NativeAutomationElement;

        STOP();
    }
}
