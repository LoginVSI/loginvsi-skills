// BROWSER:chrome
// BROWSER_ARGUMENTS:
// URL:https://example.com
// PROFILE:
using LoginPI.Engine.ScriptBase;
using System.Threading.Tasks;

namespace ExampleScripts
{
    public class TestScript : WebScriptBase
    {
        async Task Execute()
        {
            await StartBrowser();

            Wait(5000);
            
            await Locator("//input[@id='search' and @aria-label='Search']").ClickAsync();

            await StopBrowser();
        }
    }
}
