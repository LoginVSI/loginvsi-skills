// TARGET:winword.exe
// START_IN:

// Microsoft Word Script - Production Example
// Demonstrates: File dialogs, KnownFiles, typing validation, first-run handling, save operations

using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;
using System;

public class WordWorkload : ScriptBase
{
    private void Execute()
    {
        // This is a language dependent script. English is required.
        var temp = GetEnvironmentVariable("TEMP");

        // Download file from the appliance through the KnownFiles method, if it already exists: Skip Download.
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Get .docx file");
        if (!(FileExists($"{temp}\\LoginPI\\loginvsi.docx")))
        {
            Log("Downloading File");
            CopyFile(KnownFiles.WordDocument, $"{temp}\\LoginPI\\loginvsi.docx");
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
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Starting Word");
        START(mainWindowTitle: "*Word*", mainWindowClass: "Win32 Window:OpusApp", processName: "WINWORD", timeout: 30);
        MainWindow.Maximize();

        // Handle "keep app running" scenario - check if document from previous run is open
        var newDocName = "edited";
        var appWasLeftOpen = MainWindow.GetTitle().Contains(newDocName);
        if (appWasLeftOpen)
        {
            Log("Word was left open from previous run");
        }
        else
        {
            Wait(10);
            SkipFirstRunDialogs();
        }

        // Open "Open File" window and start measurement
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Open File Window");
        MainWindow.Type("{CTRL+O}");
        MainWindow.Type("{ALT+O+O}");
        StartTimer("Open_Window");
        var OpenWindow = GetFileDialog();
        StopTimer("Open_Window");
        OpenWindow.Click();

        // Navigate to copied DOCX file and press Open, measure time to open the file
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Open File");
        var fileNameBox = OpenWindow.FindControl(className: "Edit:Edit", title: "File name:");
        fileNameBox.Click();
        Wait(1);
        ScriptHelpers.SetTextBoxText(this, fileNameBox, $"{temp}\\LoginPI\\loginvsi.docx", cpm: 300);
        Wait(1);
        OpenWindow.FindControl(className: "SplitButton:Button", title: "&Open").Click();
        StartTimer("Open_Word_Document");
        var newWord = FindWindow(className: "Win32 Window:OpusApp", title: "loginvsi*", processName: "WINWORD");
        newWord.Focus();
        StopTimer("Open_Word_Document");

        // Close the leftover document if the app was already open
        if (appWasLeftOpen)
        {
            MainWindow.Close();
            Wait(1);
        }

        // Scroll through Word Document
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Scroll");
        newWord.MoveMouseToCenter();
        MouseDown();
        Wait(1);
        MouseUp();
        newWord.Type("{PAGEDOWN}".Repeat(2));
        Wait(1);
        newWord.Type("{PAGEUP}".Repeat(2));

        // Type in the document
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Type");
        newWord.Type("The snappy guy blossomed. The old fogey sat down in order to pass the time. ", cpm: 900);
        newWord.Type("The slippery townspeople had an unshakable fear while encountering a whirling dervish. ", cpm: 900);
        Wait(1);

        newWord.Type("{ENTER}");
        newWord.Type("The intelligent baby felt sick after watching a silent film. As usual, the beekeeper spoke on a cellphone. ", cpm: 900);
        newWord.Type("A behemoth of a horde committed a small crime and then chuckled arrogantly. The typical girl frequently wore a toga. ", cpm: 900);

        newWord.Minimize();
        Wait(2);
        newWord.Maximize();

        // Copy some text and paste it
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Copy & Paste");
        KeyDown(KeyCode.SHIFT);
        Type("{UP}".Repeat(10));
        KeyUp(KeyCode.SHIFT);
        Wait(1);
        newWord.Type("{CTRL+C}");
        Wait(1);
        newWord.Type("{CTRL+V}");
        Wait(1);
        newWord.Type("{PAGEUP}");
        Wait(1);
        newWord.Type("{CTRL+V}");
        Wait(1);

        // Saving the file in temp
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Saving File");
        newWord.Type("{F12}", cpm: 0);
        Wait(1);

        var filename = $"{temp}\\LoginPI\\{newDocName}.docx";
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
        FindWindow(title: $"{newDocName}*", processName: "WINWORD");
        StopTimer("Saving_file");
        Wait(2);

        // Stop application
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Stopping App");
        STOP();
    }

    private void SkipFirstRunDialogs()
    {
        var dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "WINWORD", continueOnError: true, timeout: 1);
        while (dialog != null)
        {
            dialog.Close();
            dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "WINWORD", continueOnError: true, timeout: 10);
        }
    }

    private IWindow GetFileDialog()
    {
        var dialog = FindWindow(className: "Win32 Window:#32770", processName: "WINWORD", continueOnError: true, timeout: 10);
        if (dialog is null)
        {
            ABORT("File dialog could not be found");
        }
        return dialog;
    }

    // Helper class for robust text input validation
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
}
