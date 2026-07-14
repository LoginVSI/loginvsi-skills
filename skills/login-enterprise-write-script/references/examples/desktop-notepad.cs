// TARGET:C:\Windows\System32\notepad.exe
// START_IN:
using LoginPI.Engine.ScriptBase;

public class Notepad : ScriptBase
{
    void Execute()
    {
        START();
        Wait(2);

        var textArea = MainWindow.FindControl(className: "Edit:Edit", continueOnError: true, timeout: 5);
        if (textArea == null)
        {
            textArea = MainWindow.FindControl(className: "Document:Edit", continueOnError: true, timeout: 5);
        }
        STOP();
    }
}
