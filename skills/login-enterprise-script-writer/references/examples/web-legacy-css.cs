// BROWSER:edgechromium
// URL:https://example.com
// PROFILE:
using LoginPI.Engine.ScriptBase;

public class Edge : ScriptBase
{
    private void Execute()
    {
        StartBrowser();

        //GetBrowserViewPortBounds().LeftTop.MouseMove();

        //Wait(2);


        //GetBrowserViewPortBounds().RightBottom.MouseMove();
        //Wait(2);


        FindWebComponentBySelector("input[id='Username']").Click(321, 23);

        Wait(2);

        MouseMove(0, 0);

        Wait(2);

        MouseMove(3400, 900);

        //FindWebComponentBySelector("input[id='Password']").Click();


        Wait(2);

        //FindWebComponentBySelector("button[class='btn btn-default btn-auth']").Click();

        //Wait(5);

        //if (CurrentUrl.EndsWith("/eula"))
        //{
        //    Log("Current Url is " + CurrentUrl);

        //    FindWebComponentBySelector("button[class='mat-raised-button mat-button-base mat-primary']").Click();
        //    Wait(2);
        //}


        //if (CurrentUrl.EndsWith("/release-notes"))
        //{
        //    Log("Current Url is " + CurrentUrl);
        //    FindWebComponentBySelector("button[class='mat-raised-button mat-button-base mat-primary']").Click();
        //    Wait(2);
        //}

        //Log("Current Url is " + CurrentUrl);

        //Navigate("https://www.google.com", "google");

        //Wait(2);

        StopBrowser();
    }

    private void AddAccount(int i)
    {
        FindWebComponentBySelector("button[id='configuration_account-add-new-account']").Click();

        Wait(2);

        FindWebComponentBySelector("input[id='configuration__add-user-account__add-username']").Type("User" + i);

        FindWebComponentBySelector("input[id='configuration__add-user-account__edit-password']").Type("Password!");

        FindWebComponentBySelector("input[id='configuration__add-user-account__edit-domainId']").Type("play");

        FindWebComponentBySelector("button[id='configuration__add-user-account__submit']").Click();

        Wait(1);
    }
}
