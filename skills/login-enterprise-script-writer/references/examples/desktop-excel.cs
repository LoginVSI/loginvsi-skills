// TARGET:C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE
// START_IN:
// MicrosoftExcel script version 20210813

using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;
using System;

public class M365Excel524 : ScriptBase
{
    private void Execute()
    {
        // This is a language dependent script. English is required.

        // Define environementvariables to use with Workload
        var temp = GetEnvironmentVariable("TEMP");

        // Define random integer
        var rand = new Random();
        var RandomNumber = rand.Next(2, 8);
        // Console.WriteLine("My wait time is = " + RandomNumber);

        // Download file from the appliance through the KnownFiles method, if it already exists: Skip Download.
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Get .xlsx file");
        if (!(FileExists($"{temp}\\LoginPI\\loginvsi.xlsx")))
        {
            Log("Downloading File");
            CopyFile(KnownFiles.ExcelSheet, $"{temp}\\LoginPI\\loginvsi.xlsx", overwrite:true);
        }
        else
        {
            Log("File already exists");
        }

        // Click the Start Menu
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Start Menu");
        Type("{LWIN}");
        Wait(3);
        Type("{ESC}");

        // Start Application
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Starting Excel");
        START(mainWindowTitle: "*Excel*", mainWindowClass: "*XLMAIN*", timeout: 30);
        MainWindow.Maximize();

        // This is going to be the name of document when we save it later on
        var newDocName = "edited";
        var appWasLeftOpen = MainWindow.GetTitle().Contains(newDocName);
        if (appWasLeftOpen)
        {
            Log("Excel was left open from previous run");
        }
        else
        {
            Wait(10);

            SkipFirstRunDialogs();

            // If a previous run of Excel crashed, we need to close the *recover document* frame now
            MainWindow.FindControl(className: "Button:NetUIButton", title: "Close", continueOnError: true, timeout: 5)?.Click();
        }

        // Open "Open File" window and start measurement.
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Open File Window");
        MainWindow.Type("{CTRL+O}");
        MainWindow.Type("{ALT+O+O}");
        StartTimer("Open_Window");
        var OpenWindow = get_file_dialog();
        StopTimer("Open_Window");
        Wait(1);
        OpenWindow.Click();

        //Navigate to copied XLSX file and press Open, measure time to open the file.
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Open File");
        var fileNameBox = OpenWindow.FindControl(className: "Edit:Edit", title: "File name:");
        fileNameBox.Click();
        Wait(1);
        ScriptHelpers.SetTextBoxText(this, fileNameBox, $"{temp}\\LoginPI\\loginvsi.xlsx", cpm: 300);
        Wait(1);
        OpenWindow.FindControl(className: "SplitButton:Button", title: "&Open").Click();
        StartTimer("Open_Excel_Document");
        var newExcel = FindWindow(className: "*XLMAIN*", title: "loginvsi*");
        StopTimer("Open_Excel_Document");

        // We close the old window here, so our FindWindow does not find it window
        if (appWasLeftOpen)
        {
            newExcel.Minimize();
            Wait(5, showOnScreen: true, onScreenText: $"Closing window {MainWindow.GetTitle()}");
            MainWindow.Type("{CNTRL+F4}");
            Wait(1);

            // Win32 Window:NUIDialog   => Excel 365
            // Pane:NUIDialog           => Excel 2019
            var confirmDialog = FindWindow(className: "*NUIDialog", processName: "EXCEL", continueOnError: true, timeout: 10);
            if (confirmDialog != null)
            {
                confirmDialog.FindControl(title: "*Don*")?.Click();
            }
            newExcel.Maximize();
        }



        //Scroll through excel document
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Scroll");
        newExcel.MoveMouseToCenter();
        MouseDown();
        Wait(1);
        MouseUp();
        newExcel.Type("{PAGEDOWN}".Repeat(RandomNumber), cpm: 100);
        Wait(1);
        newExcel.Type("{PAGEUP}".Repeat(RandomNumber), cpm: 100);
        Wait(3);
        newExcel.Type("{PAGEDOWN}".Repeat(RandomNumber), cpm: 100);
        Wait(1);
        newExcel.Type("{PAGEUP}".Repeat(RandomNumber), cpm: 100);
        Wait(2);

        //Copy a row and paste
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Copy & Paste");
        var dataSheetArea = newExcel.FindControlWithXPath(xPath: "Pane:XLDESK");
        var row = dataSheetArea.FindControl("DataItem", "1", continueOnError: true, timeout: 1);
        var isOffice365 = row is object;
        if (!isOffice365)
        {
            Log("This is not office 365");
        }
        // Although excel in the latest versions exposes the rows as UI elements, searching them is pretty expensive.
        // So we go by offset to find them
        var row1Location = dataSheetArea.GetBounds().LeftTop.Move(12, 30);
        var row5Location = dataSheetArea.GetBounds().LeftTop.Move(12, 111);
        row5Location.RightClick();
        Wait(2);
        Type("i"); // Type without window reference to avoid focus setting. Focus setting closes the context menu
        newExcel.Type("{CTRL+Y}".Repeat(15), cpm: 100);
        Wait(1);
        row1Location.Click(); Wait(1);
        newExcel.Type("{CTRL+C}"); Wait(1);
        row5Location.Click(); Wait(1);
        KeyDown(KeyCode.SHIFT); Wait(1);
        newExcel.Type("{DOWN}".Repeat(15), cpm: 100);
        KeyUp(KeyCode.SHIFT); Wait(1);
        newExcel.Type("{CTRL+V}"); Wait(3);

        newExcel.Type("{ESC}"); Wait(1);

        //Create a Chart
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Create a chart");
        row1Location.Click(); Wait(1);
        KeyDown(KeyCode.SHIFT);
        newExcel.Type("{DOWN}".Repeat(10), cpm: 300);
        KeyUp(KeyCode.SHIFT); Wait(1);
        var chartShortcut = isOffice365 ? "{ALT+N}C1" : "{ALT+N}C";
        newExcel.Type(chartShortcut, cpm: 120); Wait(3);
        Type("{ENTER}"); // we do not use the window to type here, because that would force a 'focus window', which breaks the chart selector focus
        KeyDown(KeyCode.SHIFT);
        newExcel.Type("{UP}".Repeat(5), cpm: 100);
        newExcel.Type("{RIGHT}".Repeat(5), cpm: 100);
        KeyUp(KeyCode.SHIFT);
        Wait(RandomNumber);

        // Saving the file in temp
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Saving File");
        newExcel.Type("{F12}", cpm: 0);
        Wait(1);

        var filename = $"{temp}\\LoginPI\\{newDocName}.xlsx";
        // We use a completely different filename here, so its easier to distinguish it from the other window
        // Remove file if it already exists
        if (FileExists(filename))
        {
            Log("Removing file");
            RemoveFile(path: filename);
        }
        else
        {
            Log("File already removed");
        }

        // Saving the file in temp 
        var SaveAs = get_file_dialog();

        fileNameBox = SaveAs.FindControl(className: "Edit:Edit", title: "File name:");
        fileNameBox.Click();
        Wait(1);
        ScriptHelpers.SetTextBoxText(this, fileNameBox, filename, cpm: 300);
        StartTimer("Saving_file");
        SaveAs.Type("{ENTER}");
        FindWindow(title: $"{newDocName}*");
        StopTimer("Saving_file");
        Wait(2);

        // Stop the application
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Stop App");
        Wait(2);
        STOP();

    }

    private void SkipFirstRunDialogs()
    {
        var dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "EXCEL", continueOnError: true, timeout: 1);
        while (dialog != null)
        {
            dialog.Close();
            dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "EXCEL", continueOnError: true, timeout: 10);
        }
    }

    private IWindow get_file_dialog()
    {
        // Finding a dialog window is faster and more reliable if we use the global find window
        var dialog = FindWindow(className: "Win32 Window:#32770", processName: "EXCEL", continueOnError: true, timeout: 10);
        if (dialog is null)
        {
            ABORT("File dialog could not be found");
        }
        return dialog;
    }

    private string create_regfile(string key, string value, string data)
    {
        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        var file = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "reg.reg");

        sb.AppendLine("Windows Registry Editor Version 5.00");
        sb.AppendLine();
        sb.AppendLine($"[{key}]");
        if (data.ToLower().Contains("dword"))
        {
            sb.AppendLine($"\"{value}\"={data.ToLower()}");
        }
        else
        {
            sb.AppendLine($"\"{value}\"=\"{data}\"");
        }
        sb.AppendLine();

        System.IO.File.WriteAllText(file, sb.ToString());

        return file;
    }
}

public static class ScriptHelpers
{
    ///
    /// This method types the given text to the textbox (any existing text is cleared)
    /// After typing, it confirms the resulting value.
    /// If it does not match, it will clear the textbox and try again
    ///
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
}

