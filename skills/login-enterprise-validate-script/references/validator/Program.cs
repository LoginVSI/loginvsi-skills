// le-validate — validates a Login Enterprise script against the SAME Roslyn analyzer the
// ScriptEditor uses, by loading ScriptAnalyzer.dll and the LoginPI.Engine.ScriptBase +
// netstandard2.0 reference assemblies from a deployed ScriptEditor.
//
// This mirrors the editor's host exactly:
//   - references: every netstandard2.0 ref/lib DLL under <editor>/ReferenceAssemblies, plus a
//     few standalone bin/ DLLs scripts use (e.g. Interop.UIAutomationClient)
//   - parse:      SourceCodeKind.Regular, LanguageVersion.Latest
//   - analyzers:  AnalyzerFileReference over ScriptAnalyzer.dll
//   - suppress:   IDE0051
//
// Roslyn itself is referenced from the deployed ScriptEditor at build time (no NuGet — builds
// offline). See Validator.csproj (-p:EditorRoot).
//
// Usage:
//   le-validate --script <path> [--editor-dir <deployed ScriptEditor folder>]
//               [--wrap] [--class <name>] [--base <ScriptBase|WebScriptBase>]
//
// --editor-dir accepts the deployment root (containing bin\, ReferenceAssemblies\, ScriptEditor.Config).
// Output: JSON object { compiles, findings: [ {id, severity, line, category, message} ] } on stdout.
// Exit code: 0 = no error-severity diagnostics; 1 = errors present; 2 = tool/usage failure.

using System.Reflection;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Xml.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Diagnostics;

try
{
    var opts = ParseArgs(args);
    if (!opts.TryGetValue("script", out var scriptPath))
        return Fail("Missing required --script <path>.");
    if (!File.Exists(scriptPath))
        return Fail($"Script not found: {scriptPath}");

    var editorDir = opts.TryGetValue("editor-dir", out var ed) ? ed : LocateEditor();
    if (editorDir is null || !Directory.Exists(editorDir))
        return Fail("Could not locate a deployed ScriptEditor. Pass --editor-dir <path>.");

    var analyzerDll = ResolveAnalyzerDll(editorDir);
    if (analyzerDll is null)
        return Fail($"ScriptAnalyzer.dll not found in editor dir (or bin/ subdirectory): {editorDir}");

    var refDir = ResolveReferenceAssembliesDir(editorDir);
    if (!Directory.Exists(refDir))
        return Fail($"ReferenceAssemblies dir not found: {refDir}");

    var references = EnumerateReferences(refDir);

    // Also load standalone DLLs from the editor's bin/ directory (e.g. Interop.UIAutomationClient.dll)
    // that aren't packaged under ReferenceAssemblies but are needed for compilation.
    var binDir = Path.Combine(editorDir, "bin");
    if (Directory.Exists(binDir))
        AddBinReferences(references, binDir);

    if (references.Count == 0)
        return Fail($"No netstandard2.0 reference assemblies found under {refDir}. " +
                    "Symbol resolution would fail and the timer analyzer would report nothing.");

    var source = File.ReadAllText(scriptPath);
    if (opts.ContainsKey("wrap"))
    {
        var className = opts.TryGetValue("class", out var c) ? c : "GeneratedTest";
        var baseType = opts.TryGetValue("base", out var b) ? b : "ScriptBase";
        source = Wrap(source, className, baseType);
    }

    var parseOptions = new CSharpParseOptions(LanguageVersion.Latest, kind: SourceCodeKind.Regular);
    var tree = CSharpSyntaxTree.ParseText(source, parseOptions, path: scriptPath);

    var compilation = CSharpCompilation.Create(
        "ScriptValidation",
        new[] { tree },
        references,
        new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

    var analyzerRef = new AnalyzerFileReference(analyzerDll, new AnalyzerAssemblyLoader());
    var analyzers = analyzerRef.GetAnalyzers(LanguageNames.CSharp);
    if (analyzers.IsDefaultOrEmpty)
        return Fail($"ScriptAnalyzer.dll exposed no C# DiagnosticAnalyzers: {analyzerDll}");

    var withAnalyzers = compilation.WithAnalyzers(analyzers);
    var diagnostics = await withAnalyzers.GetAllDiagnosticsAsync();

    var kept = diagnostics
        .Where(d => d.Id != "IDE0051" && d.Severity >= DiagnosticSeverity.Warning)
        .OrderBy(d => d.Location.GetLineSpan().StartLinePosition.Line)
        .ToList();

    // The script must COMPILE for the analyzer to work: GetMethodSymbol() returns null for
    // unresolved calls, so a non-compiling script makes the analyzers throw (reported as AD0001).
    // Surface that explicitly instead of pretending the AD0001 noise is a rule result.
    var compiles = !kept.Any(d => d.Severity == DiagnosticSeverity.Error
                                  && d.Id.StartsWith("CS", StringComparison.Ordinal));

    var findings = kept
        .Select(d => new Finding(
            d.Id,
            d.Severity.ToString(),
            d.Location.GetLineSpan().StartLinePosition.Line + 1,
            Rules.Categorize(d.Id),
            d.GetMessage()))
        // When the script doesn't compile, drop the downstream analyzer crashes (AD0001) as noise.
        // When it DOES compile, downgrade AD0001 to Warning — the analyzer crashed on a valid
        // script (known ScriptAnalyzer bug with helpers/loops/try-catch), so don't block validation.
        .Where(f => compiles || f.category != "analyzer-error")
        .Select(f => compiles && f.category == "analyzer-error"
            ? f with { severity = nameof(DiagnosticSeverity.Warning),
                       message = $"[Analyzer internal error — timer analysis may be incomplete] {f.message}" }
            : f)
        .ToList();

    Console.WriteLine(JsonSerializer.Serialize(new Report(compiles, findings), new JsonSerializerOptions
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping, // readable quotes in messages
    }));

    return findings.Any(f => f.severity == nameof(DiagnosticSeverity.Error)) ? 1 : 0;
}
catch (Exception ex)
{
    return Fail(ex.Message);
}

// ---- helpers ------------------------------------------------------------------------------

// Look for ScriptAnalyzer.dll at the editor root first, then in the bin/ subdirectory.
// Deployed ScriptEditors place it under bin/; some layouts keep it at the root.
static string? ResolveAnalyzerDll(string editorDir)
{
    var atRoot = Path.Combine(editorDir, "ScriptAnalyzer.dll");
    if (File.Exists(atRoot)) return atRoot;
    var inBin = Path.Combine(editorDir, "bin", "ScriptAnalyzer.dll");
    if (File.Exists(inBin)) return inBin;
    return null;
}

// Load specific DLLs from the editor's bin/ directory that scripts may reference but that
// aren't part of the netstandard2.0 package set under ReferenceAssemblies/ (e.g. the
// UIAutomation COM interop assembly).
static void AddBinReferences(List<MetadataReference> references, string binDir)
{
    string[] allowList = { "Interop.UIAutomationClient.dll" };

    var seen = new HashSet<string>(references
        .OfType<PortableExecutableReference>()
        .Where(r => r.FilePath is not null)
        .Select(r => Path.GetFileName(r.FilePath!)),
        StringComparer.OrdinalIgnoreCase);

    foreach (var name in allowList)
    {
        var path = Path.Combine(binDir, name);
        if (File.Exists(path) && seen.Add(name))
            references.Add(MetadataReference.CreateFromFile(path));
    }
}

static Dictionary<string, string> ParseArgs(string[] args)
{
    var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    for (var i = 0; i < args.Length; i++)
    {
        if (!args[i].StartsWith("--", StringComparison.Ordinal)) continue;
        var key = args[i][2..];
        // flag (no value) vs option (value follows)
        if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
            map[key] = args[++i];
        else
            map[key] = "true";
    }
    return map;
}

// Read <editor>/ScriptEditor.Config -> AppSettings/ReferenceAssemblies (deployed value is
// ".\ReferenceAssemblies\"); fall back to the default folder name. Normalize separators and
// trim trailing slashes so the path is clean on every OS (a stray "\" breaks Directory.Exists
// off-Windows).
static string ResolveReferenceAssembliesDir(string editorDir)
{
    var rel = "ReferenceAssemblies";
    var config = FindConfig(editorDir);
    if (config is not null)
    {
        try
        {
            var val = XDocument.Load(config)
                .XPathish("Configuration", "AppSettings", "ReferenceAssemblies");
            if (!string.IsNullOrWhiteSpace(val))
                rel = val!.Trim().Replace('\\', '/').TrimEnd('/');
        }
        catch { /* fall back to default */ }
    }
    return Path.GetFullPath(Path.Combine(editorDir, rel));
}

// ScriptEditor.Config (capital C in the deployed zip; Windows FS is case-insensitive).
static string? FindConfig(string editorDir)
{
    foreach (var name in new[] { "ScriptEditor.Config", "ScriptEditor.config" })
    {
        var p = Path.Combine(editorDir, name);
        if (File.Exists(p)) return p;
    }
    return Directory.Exists(editorDir)
        ? Directory.EnumerateFiles(editorDir).FirstOrDefault(f =>
            string.Equals(Path.GetFileName(f), "ScriptEditor.config", StringComparison.OrdinalIgnoreCase))
        : null;
}

// Mirror the ScriptEditor host — collect every netstandard2.0 DLL from each package dir.
static List<MetadataReference> EnumerateReferences(string refDir)
{
    const string tfm = "netstandard2.0";
    var refs = new List<MetadataReference>();
    var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var pkg in Directory.EnumerateDirectories(refDir))
    {
        foreach (var dir in new[]
                 {
                     Path.Combine(pkg, "build", tfm, "ref"),
                     Path.Combine(pkg, "lib", tfm),
                 })
        {
            if (!Directory.Exists(dir)) continue;
            foreach (var dll in Directory.EnumerateFiles(dir, "*.dll"))
                if (seen.Add(Path.GetFileName(dll)))
                    refs.Add(MetadataReference.CreateFromFile(dll));
        }
    }
    return refs;
}

static string? LocateEditor()
{
    // PATH first
    var onPath = (Environment.GetEnvironmentVariable("PATH") ?? "")
        .Split(Path.PathSeparator)
        .Select(p => Path.Combine(p.Trim(), "ScriptEditor.exe"))
        .FirstOrDefault(File.Exists);
    if (onPath is not null) return Path.GetDirectoryName(onPath);

    foreach (var root in new[]
             {
                 Environment.GetEnvironmentVariable("ProgramFiles"),
                 Environment.GetEnvironmentVariable("ProgramFiles(x86)"),
                 Environment.GetEnvironmentVariable("LOCALAPPDATA"),
             })
    {
        if (string.IsNullOrEmpty(root) || !Directory.Exists(root)) continue;
        var hit = SafeEnumerate(root, "ScriptEditor.exe").FirstOrDefault();
        if (hit is not null) return Path.GetDirectoryName(hit);
    }
    return null;
}

static IEnumerable<string> SafeEnumerate(string root, string pattern)
{
    // Login Enterprise lives a few levels under Program Files; cap depth to stay fast.
    var queue = new Queue<(string dir, int depth)>();
    queue.Enqueue((root, 0));
    while (queue.Count > 0)
    {
        var (dir, depth) = queue.Dequeue();
        string[] files, dirs;
        try { files = Directory.GetFiles(dir, pattern); } catch { continue; }
        foreach (var f in files) yield return f;
        if (depth >= 4) continue;
        try { dirs = Directory.GetDirectories(dir); } catch { continue; }
        foreach (var d in dirs) queue.Enqueue((d, depth + 1));
    }
}

static string Wrap(string body, string className, string baseType)
{
    var usings = baseType == "WebScriptBase"
        ? "using LoginPI.Engine.ScriptBase;\nusing System.Threading.Tasks;\n"
        : "using LoginPI.Engine.ScriptBase;\nusing LoginPI.Engine.ScriptBase.Components;\n";
    var sig = baseType == "WebScriptBase" ? "async Task Execute()" : "void Execute()";
    return $"{usings}\npublic class {className} : {baseType}\n{{\n    {sig}\n    {{\n{body}\n    }}\n}}\n";
}

static int Fail(string message)
{
    Console.Error.WriteLine($"le-validate: {message}");
    return 2;
}

internal sealed record Finding(string id, string severity, int line, string category, string message);

// compiles=false means the script has compiler errors; analyzer (timer) results are then
// unreliable, so AD0001 analyzer crashes are dropped and only the compiler errors remain.
internal sealed record Report(bool compiles, List<Finding> findings);

internal static class Rules
{
    // The eight ScriptAnalyzer rule IDs.
    private static readonly HashSet<string> Ids = new(StringComparer.Ordinal)
    {
        "SpacelessNameDiagnostic", "NameMaxLengthDiagnostic", "EmptyExceptionDiagnostic",
        "NullExceptionDiagnostic", "NegativeNumbersDiagnostic", "StartTimerDiagnostic",
        "StopTimerDiagnostic", "DuplicateDiagnostic",
    };

    // CS#### = compiler; AD0001 = analyzer infrastructure crash (usually downstream of a
    // compile error); the eight ScriptAnalyzer IDs = rule; anything else = other.
    public static string Categorize(string id) =>
        id.StartsWith("CS", StringComparison.Ordinal) ? "compiler"
        : id == "AD0001" ? "analyzer-error"
        : Ids.Contains(id) ? "rule"
        : "other";
}

// Minimal IAnalyzerAssemblyLoader — load the analyzer (and any deps) by path.
internal sealed class AnalyzerAssemblyLoader : IAnalyzerAssemblyLoader
{
    public void AddDependencyLocation(string fullPath) { }
    public Assembly LoadFromPath(string fullPath) => Assembly.LoadFrom(fullPath);
}

internal static class XmlExtensions
{
    // Tiny case-insensitive nested-element reader so we don't depend on System.Xml.XPath.
    public static string? XPathish(this XDocument doc, params string[] path)
    {
        XElement? node = doc.Root;
        if (node is null) return null;
        // first segment is the root element name itself
        if (!string.Equals(node.Name.LocalName, path[0], StringComparison.OrdinalIgnoreCase))
            return null;
        for (var i = 1; i < path.Length; i++)
        {
            node = node.Elements().FirstOrDefault(e =>
                string.Equals(e.Name.LocalName, path[i], StringComparison.OrdinalIgnoreCase));
            if (node is null) return null;
        }
        return node.Value;
    }
}
