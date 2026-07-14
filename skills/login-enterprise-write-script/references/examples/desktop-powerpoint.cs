// TARGET:powerpnt.exe
// START_IN:

// Microsoft PowerPoint Script - Production Example
// Demonstrates: Presentation handling, slideshow, transitions, ribbon navigation, formatting

using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;
using System;

public class PowerPointWorkload : ScriptBase
{
    private void Execute()
    {
        // This is a language dependent script. English is required.
        var temp = GetEnvironmentVariable("TEMP");

        // Define random integer for variable wait times
        var rand = new Random();
        var RandomNumber = rand.Next(2, 9);

        // Download file from the appliance through the KnownFiles method
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Get .pptx file");
        if (!(FileExists($"{temp}\\LoginPI\\loginvsi.pptx")))
        {
            Log("Downloading File");
            CopyFile(KnownFiles.PowerPointPresentation, $"{temp}\\LoginPI\\loginvsi.pptx");
        }
        else
        {
            Log("File already exists");
        }

        // Click the Start Menu (warm up interaction)
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Start Menu");
        Type("{LWIN}");
        Wait(3);
        Type("{ESC}");

        // Start Application
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Starting PowerPoint");
        START(mainWindowTitle: "*PowerPoint*", mainWindowClass: "*PPTFrameClass*", timeout: 30);
        MainWindow.Maximize();

        // Handle "keep app running" scenario
        var newDocName = "edited";
        var appWasLeftOpen = MainWindow.GetTitle().Contains(newDocName);
        if (appWasLeftOpen)
        {
            Log("PPT was left open from previous run");
        }
        else
        {
            Wait(20);
            SkipFirstRunDialogs();
        }

        // Open "Open File" window using ribbon navigation
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Open File Window");
        var PPTWindow = FindWindow(className: "Win32 Window:PPTFrameClass", title: "*PowerPoint", processName: "POWERPNT");
        PPTWindow.Focus();
        PPTWindow.Type("{ALT+F}");
        PPTWindow.FindControl(className: "ListItem:NetUIRibbonTab", title: "Open", timeout: 15).Click();
        Wait(1);
        var PPTBrowse = PPTWindow.FindControl(className: "Button:NetUISimpleButton", title: "Browse");
        PPTBrowse.Click();
        StartTimer("Open_Window");
        var OpenWindow = GetFileDialog();
        StopTimer("Open_Window");
        Wait(1);
        OpenWindow.Click();

        // Navigate to copied PPTX file and press Open
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Open File");
        var fileNameBox = OpenWindow.FindControl(className: "Edit:Edit", title: "File name:");
        fileNameBox.Click();
        Wait(1);
        ScriptHelpers.SetTextBoxText(this, fileNameBox, $"{temp}\\LoginPI\\loginvsi.pptx", cpm: 600);
        Wait(1);
        OpenWindow.FindControl(className: "SplitButton:Button", title: "&Open").Click();
        StartTimer("Open_Powerpoint_Document");
        var newPowerpoint = FindWindow(className: "Win32 Window:PPTFrameClass", title: "loginvsi*", processName: "POWERPNT");
        newPowerpoint.Focus();
        newPowerpoint.FindControl(className: "TabItem:NetUIRibbonTab", title: "Insert");
        StopTimer("Open_Powerpoint_Document");

        // Close leftover document if app was already open
        if (appWasLeftOpen)
        {
            MainWindow.Close();
            Wait(1);
        }

        // Scroll through Powerpoint presentation
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Scroll");
        newPowerpoint.Focus();
        newPowerpoint.Type("{PAGEDOWN}".Repeat(RandomNumber), cpm: 100);
        Wait(RandomNumber);
        newPowerpoint.Type("{PAGEUP}".Repeat(RandomNumber), cpm: 100);
        Wait(RandomNumber);

        // Reformat slides to 16:9 using keyboard shortcuts
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Reformat Slide Size");
        newPowerpoint.Type("{ALT+G}");
        newPowerpoint.Type("{ALT+S}");
        Type("{DOWN}");
        Wait(1);
        Type("{ENTER}");
        Wait(1);
        Type("{ENTER}");
        Wait(5);

        // Reformat slides with different color theme
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Reformat Slide Color");
        newPowerpoint.Type("{ALT+G}");
        newPowerpoint.Type("{ALT+H}");
        Wait(1);
        Type("{DOWN}");
        Wait(1);
        Type("{ENTER}");
        Wait(5);

        // Reformat first slide transition
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Reformat Slide Transition");
        newPowerpoint.Type("{ALT+K}");
        newPowerpoint.Type("{ALT+T}");
        Wait(2);
        Type("{DOWN}");
        Wait(1);
        Type("{DOWN}");
        Wait(1);
        Type("{LEFT}");
        Wait(1);
        Type("{LEFT}");
        Wait(1);
        Type("{ENTER}");
        Wait(RandomNumber);

        // Let's do a slideshow
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Slideshow");
        newPowerpoint.Type("{F5}", cpm: 0);
        Wait(10);
        Type("{DOWN}");
        Wait(RandomNumber);
        Type("{DOWN}");
        Wait(RandomNumber);
        Type("{DOWN}");
        Wait(RandomNumber);
        Type("{ESC}");
        Wait(RandomNumber);
        Type("{HOME}");
        Wait(RandomNumber);

        // Saving the file in temp
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Saving");
        newPowerpoint.Type("{F12}");
        Wait(1);

        var filename = $"{temp}\\LoginPI\\{newDocName}.pptx";
        // Remove file if it already exists
        if (FileExists(filename))
        {
            Log("Removing file");
            RemoveFile(path: filename);
        }

        var SaveAs = GetFileDialog();
        fileNameBox = SaveAs.FindControl(className: "Edit:Edit", title: "File name:");
        fileNameBox.Click();
        Wait(1);
        ScriptHelpers.SetTextBoxText(this, fileNameBox, filename, cpm: 300);
        StartTimer("Saving_file");
        SaveAs.Type("{ENTER}");
        FindWindow(title: $"{newDocName}*", processName: "POWERPNT", timeout: 60);
        StopTimer("Saving_file");
        Wait(2);

        // Stop application
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Stop App");
        STOP();
    }

    private void SkipFirstRunDialogs()
    {
        var dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "POWERPNT", continueOnError: true, timeout: 1);
        while (dialog != null)
        {
            dialog.Close();
            dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "POWERPNT", continueOnError: true, timeout: 10);
        }
    }

    private IWindow GetFileDialog()
    {
        var dialog = FindWindow(className: "Win32 Window:#32770", processName: "POWERPNT", continueOnError: true, timeout: 10);
        if (dialog is null)
        {
            ABORT("File dialog could not be found");
        }
        return dialog;
    }
}

// Helper class for robust text input validation (can be shared across Office scripts)
public static class ScriptHelpers
{
    /// <summary>
    /// Types the given text to the textbox (clears existing text first).
    /// Confirms the resulting value and retries if it doesn't match.
    /// </summary>
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
