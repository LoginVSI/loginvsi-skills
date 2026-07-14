// TARGET:C:\Windows\System32\cmd.exe
// START_IN:
using LoginPI.Engine.ScriptBase;

public class FileSystem : ScriptBase
{
    private void Execute()
    {
        var fileName = "./testFile";

        START();

        RemoveFile(fileName, true);

        CopyFile(KnownFiles.RichTextFile, fileName);

        RemoveFile(fileName);

        STOP();
    }

}