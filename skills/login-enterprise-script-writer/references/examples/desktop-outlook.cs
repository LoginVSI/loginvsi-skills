// TARGET:outlook.exe
// START_IN:

// Microsoft Outlook Script - Production Example
// Demonstrates: Email handling, calendar navigation, dialog management, timers

using LoginPI.Engine.ScriptBase;
using LoginPI.Engine.ScriptBase.Components;
using System;

public class OutlookWorkload : ScriptBase
{
    private void Execute()
    {
        // This is a language dependent script. English is required.
        var userProfileDir = GetEnvironmentVariable("USERPROFILE");

        // Start Application
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Starting Outlook");
        START(mainWindowTitle: "Inbox*", mainWindowClass: "Win32 Window:rctrl_renwnd32",
              processName: "OUTLOOK", timeout: 60, continueOnError: true);
        MainWindow.Maximize();

        // Handle first-run dialogs and sign-in prompts
        try
        {
            var signinWindow = MainWindow.FindControlWithXPath(xPath: "Win32 Window:NUIDialog", timeout: 10);
            signinWindow.Type("{ESC}", cpm: 50);
        }
        catch { }
        SkipFirstRunDialogs();

        // Select an item in the Inbox
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Select An Item");
        StartTimer("Find_Inbox");
        var inboxTable = MainWindow.FindControlWithXPath(xPath: "Table:SuperGrid");
        StopTimer("Find_Inbox");
        inboxTable.Click();
        Wait(3);

        // Scroll through E-mail inbox
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Scroll Inbox");
        inboxTable.Type("{DOWN}".Repeat(3), cpm: 80);
        Wait(3);

        // Dismiss all reminders if present
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Dismiss Reminders");
        var reminderWindow = FindWindow(className: "Win32 Window:#32770", title: "*Reminder(s)",
                                        processName: "OUTLOOK", timeout: 3, continueOnError: true);
        if (reminderWindow != null)
        {
            Wait(1);
            reminderWindow.Focus();
            reminderWindow.FindControl(className: "Button:Button", title: "Dismiss &All").Click();
            Wait(1);
            reminderWindow.FindControl(className: "Button:Button", title: "&Yes").Click();
        }
        Wait(1);

        // Keep scrolling
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Keep Scrolling");
        inboxTable.Type("{DOWN}".Repeat(4), cpm: 80);
        inboxTable.Type("{UP}".Repeat(8), cpm: 80);
        Wait(2);

        // Open an email, read it, and close it
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Open and Read an Email");
        inboxTable.Focus();
        inboxTable.Click();
        inboxTable.Type("{DOWN}");
        inboxTable.Type("{ENTER}");
        Wait(2);

        StartTimer("Open_Email");
        var openEmail = FindWindow(className: "Win32 Window:rctrl_renwnd32",
                                   title: "*Message*", processName: "OUTLOOK", timeout: 10);
        StopTimer("Open_Email");

        openEmail.Focus();
        openEmail.Type("{DOWN}".Repeat(5), cpm: 500);
        Wait(3);
        openEmail.Type("{UP}".Repeat(3), cpm: 500);
        Wait(3);
        openEmail.Type("{ESC}", cpm: 50);
        Wait(2);

        // Compose a new email
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Compose a new email");
        MainWindow.Type("{CTRL+N}");
        Wait(3);

        var typingSpeed = 900;
        StartTimer("Compose_Email");
        var newEmail = FindWindow(className: "Win32 Window:rctrl_renwnd32",
                                  title: "Untitled - Message*", processName: "OUTLOOK").Focus();
        newEmail.FindControl(className: "*RichEdit20WPT", title: "To")
                .Type("test@example.com", cpm: typingSpeed);
        newEmail.Type("{TAB}".Repeat(3), 50);
        newEmail.Type("Test Subject Line", cpm: typingSpeed);
        newEmail.Type("{TAB}", cpm: 50);
        newEmail.Type("{ENTER}", cpm: 50);
        newEmail.Type("This is the body of the test email.", cpm: typingSpeed);
        StopTimer("Compose_Email");

        Wait(2);
        newEmail.Type("{ESC}", cpm: 50);  // Close without sending
        Wait(2);
        newEmail.Type("{ENTER}", cpm: 50);  // Confirm discard
        Wait(3);

        // Navigate to Calendar
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Calendar Navigation");
        MainWindow.FindControlWithXPath(xPath: "Group:Navigation Bar/Button:Navigation Module[1]").Click();
        Wait(2);
        MainWindow.Type("{TAB}", cpm: 50);
        Wait(2);

        // Return to Mail
        MainWindow.FindControl(className: "Button:Navigation Module", title: "Mail").Click();
        Wait(1);

        STOP();
    }

    private void SkipFirstRunDialogs()
    {
        var dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "OUTLOOK",
                               continueOnError: true, timeout: 1);
        while (dialog != null)
        {
            dialog.Close();
            dialog = FindWindow(className: "Win32 Window:NUIDialog", processName: "OUTLOOK",
                               continueOnError: true, timeout: 10);
        }
    }
}
