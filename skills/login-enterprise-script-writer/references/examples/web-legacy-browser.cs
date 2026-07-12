// BROWSER:EdgeChromium
// URL:https://example.com

// Microsoft Edge Legacy Browser Script - Production Example
// Demonstrates: StartBrowser, Navigate, FindWebComponentBySelector, local files, CSS selectors

using LoginPI.Engine.ScriptBase;
using System;

public class EdgeBrowser : ScriptBase
{
    private void Execute()
    {
        var temp = GetEnvironmentVariable("TEMP");
        var waitTime = 2;
        var waitTimeWithDisplay = 3;

        // Download the website files from the appliance and unzip in the %temp% folder
        CopyFile(KnownFiles.WebSite, $"{temp}\\LoginPI\\vsiwebsite.zip", overwrite: true);
        UnzipFile($"{temp}\\LoginPI\\vsiwebsite.zip", $"{temp}\\LoginPI\\vsiwebsite", overWrite: true);

        // Start Browser in private mode
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Start Browser");
        StartBrowser(useInPrivateBrowsing: true);
        MainWindow.Maximize();
        Wait(waitTime);

        // Handle Edge "Personalize your web experience" dialog
        try
        {
            var edgeWindow = FindWindow(className: "Pane:Chrome_WidgetWin_1", title: "Microsoft Edge", processName: "msedge");
            var expWindow = edgeWindow.FindControl(className: "Button:MdTextButton", title: "Got it!");
            if (expWindow != null)
            {
                Log("Found Personalize window notification. Attempting to click Got it! button");
                expWindow.Click();
            }
        }
        catch (Exception)
        { }

        // Navigate to the local html file
        Navigate($"file:///{temp}/LoginPI/vsiwebsite/chromescript/logonpage.html");

        // Click on the login button using keyboard (Tab + Space)
        Wait(seconds: waitTimeWithDisplay, showOnScreen: true, onScreenText: "Click Logon Button");
        Type("{TAB}");
        Wait(1);
        Type("{SPACE}");
        Wait(1);

        // Enter login credentials using CSS selectors
        FindWebComponentBySelector("input[id='username']").Click();
        Type("Admin");
        FindWebComponentBySelector("input[id='password']").Click();
        Type("Admin");
        FindWebComponentBySelector("button[id='submit']").Click();

        // Time the logon operation
        StartTimer("Logon");
        FindWebComponentBySelector("a[id='videopage']");
        StopTimer("Logon");

        // Select the video page tab
        Wait(seconds: waitTimeWithDisplay, showOnScreen: true, onScreenText: "Watch a video");
        FindWebComponentBySelector("a[id='videopage']").Click();

        // Watch video for 20 seconds
        Wait(20);

        // Navigate back to main homepage and Click on Article
        Back();
        Wait(2);
        FindWebComponentBySelector("a[id='articlepage']").Click();
        Wait(2);

        // Scroll through webpage
        Wait(seconds: 3, showOnScreen: true, onScreenText: "Browse a Web Page");
        MainWindow.Click();
        MainWindow.Type("{PAGEDOWN}".Repeat(2), cpm: 600);
        MainWindow.Type("{PAGEUP}".Repeat(2), cpm: 600);

        // Stop the browser
        Wait(seconds: waitTimeWithDisplay, showOnScreen: true, onScreenText: "Stopping Browser");
        StopBrowser();
    }
}
