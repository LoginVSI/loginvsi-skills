// TARGET:ms-teams.exe
// START_IN:

// Microsoft Teams Script - Production Example
// Demonstrates: Complex app with login, chat, meetings, random user selection, finding controls

using LoginPI.Engine.ScriptBase;
using System;
using System.Linq;

public class TeamsWorkload : ScriptBase
{
    private void Execute()
    {
        LoginPI.Engine.ScriptBase.Components.IWindow chatBtn = null;

        // Script variables
        int interactionWait = 3;    // Wait time between interactions
        int meetingWait = 20;       // Time to stay in meeting

        // Generate random user for chat recipient
        var rand = new Random();
        int number = rand.Next(1, 16);
        string digits = number.ToString("0000");  // adds leading zeros
        string chatRecipient = ("testuser" + digits);  // testuser0001 to testuser0015
        Log($"My chat user will be {chatRecipient}");

        // Meeting credentials (would typically be parameters)
        var meetingID = "384 436 810 684";
        var meetingPwd = "RiVGX7";

        // Start teams - note forceKillOnExit: false to keep Teams running
        START(mainWindowTitle: "*Teams", processName: "ms-teams", forceKillOnExit: false, timeout: 60);
        Wait(interactionWait);

        // Find the Teams window and handle initial login if needed
        var Teams2Window = FindWindow(className: "Win32 Window:TeamsWebView", title: "*Teams", processName: "ms-teams");
        Teams2Window.Focus();

        // Click "Create or use another account" if present
        try
        {
            Teams2Window.FindControl(className: "Button:fui-Button*", title: "Create or use another account").Click();
            Teams2Window.FindControl(className: "Edit", title: "Email, phone, or Skype").Type("user@example.com");
            Teams2Window.FindControl(className: "Edit", title: "Email, phone, or Skype").Type("{enter}");
        }
        catch { }

        // Starting Performance testing
        Wait(15, showOnScreen: true, onScreenText: "Time to test Teams");

        // Chat test function
        Wait(3, showOnScreen: true, onScreenText: "Let's Chat");
        Teams2Window.Focus();
        chatBtn = Teams2Window.FindControl(className: "Button:fui-Button*", title: "Chat").Focus();
        Wait(5, showOnScreen: true, onScreenText: $"Let's chat with random user {chatRecipient}");

        // Search for chat recipient
        Teams2Window.FindControl(className: "ComboBox:*", title: "Search").Click();
        Type("{CTRL+A}");
        Type(chatRecipient, cpm: 600);
        Wait(interactionWait);
        Type("{ENTER}");
        Wait(5);

        // Select the People tab and click on the recipient
        Teams2Window.FindControl(className: "TabItem:fui-Tab*", title: "People").Click();
        Wait(5);
        var msgRecipient = Teams2Window.FindControl(className: "Text", title: chatRecipient, text: chatRecipient);
        msgRecipient.Click();
        Wait(interactionWait);

        // Type and send messages
        Teams2Window.FindControl(className: "Edit:ck ck-content ck-editor__editable*", title: "Type a message", text: "Type a message*").Click();
        Wait(interactionWait);
        Type("{CTRL+A}", cpm: 600);
        Type($"Hi {chatRecipient}! I hope you are having a great day!", cpm: 600);
        Type("{ENTER}", cpm: 600);
        Wait(interactionWait);
        Type("Are you going to join the All-Hands company meeting?", cpm: 600);
        Type("{ENTER}", cpm: 600);

        // Join a test meeting
        Wait(5, showOnScreen: true, onScreenText: "Let's find a Teams meeting to join");
        var calBtn = Teams2Window.FindControl(className: "Button:fui-Button*", title: "Calendar");
        calBtn.Click();
        Wait(interactionWait);

        // Join meeting with ID
        Teams2Window.FindControl(className: "Button:ui-button*", title: "Join with an ID").Click();
        Wait(interactionWait);
        Teams2Window.FindControl(className: "Edit:ui-box*", title: "Meeting ID*").Type(meetingID);
        Teams2Window.FindControl(className: "Edit:ui-box*", title: "Meeting passcode").Type(meetingPwd);
        Wait(5, showOnScreen: true, onScreenText: "Join the meeting");
        Teams2Window.FindControl(className: "Button:fui-Button*", title: "Join meeting").Click();

        // Find meeting window and join
        var meetingWindow = FindWindow(className: "Win32 Window:TeamsWebView", title: "Meeting with*", processName: "ms-teams");
        meetingWindow.Focus();
        meetingWindow.FindControl(className: "Button:fui-Button*", title: "Join now*").Click();
        Wait(interactionWait);

        // Participate in meeting
        Wait(3, showOnScreen: true, onScreenText: $"Participate in the meeting for {meetingWait} seconds");
        Wait(meetingWait);

        // Leave meeting
        Wait(5, showOnScreen: true, onScreenText: "Leaving the meeting");
        meetingWindow.FindControl(className: "Button:fui-Button*", title: "Leave*").Click();
        Wait(5);

        // End script message
        Wait(3, showOnScreen: true, onScreenText: "Ending Teams script");
        // Note: No STOP() because forceKillOnExit: false - Teams stays running
    }
}
