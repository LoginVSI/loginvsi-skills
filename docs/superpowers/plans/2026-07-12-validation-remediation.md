# Validation Remediation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address remaining findings from the external TPM validation pass — fix incorrect examples, improve documentation clarity, and add missing guidance for setup, runtime behavior, and cross-platform usage.

**Architecture:** Small targeted fixes across existing skill files and docs. No new skills or major refactoring.

**Tech Stack:** Markdown (SKILL.md, README), C# (example scripts), PowerShell (check-setup.ps1)

## Global Constraints

- No internal/proprietary references
- Agent-agnostic instructions only
- SKILL.md body under 500 lines
- All skills must pass `npx skills-ref validate`
- Do not change runtime behavior of existing scripts — documentation and example fixes only

---

### Task 1: Fix Wait() Example Bug

The most critical finding. The Login Enterprise `Wait()` API takes **seconds**, but shipped example `web-playwright.cs` may use `Wait(5000)` which would mean 5000 seconds, not 5 seconds.

**Files:**
- Audit: `skills/login-enterprise-script-writer/references/examples/*.cs`
- Audit: `skills/login-enterprise-script-validator/references/examples/*.cs`
- Audit: `skills/login-enterprise-script-runner/references/examples/*.cs`
- Modify: any files with incorrect `Wait()` values

**Interfaces:**
- Consumes: nothing
- Produces: correct example scripts

- [ ] **Step 1: Search all example .cs files for Wait() calls**

```bash
grep -rn "Wait(" skills/*/references/examples/ skills/*/references/validator/
```

Check every `Wait()` call. The API signature is `Wait(double seconds)`. Any value over ~60 is suspicious. `Wait(5000)` is definitely wrong — should be `Wait(5)`.

- [ ] **Step 2: Fix any incorrect Wait() values**

Change `Wait(5000)` to `Wait(5)`, `Wait(2000)` to `Wait(2)`, etc.

- [ ] **Step 3: Search SKILL.md files and reference docs for Wait() examples**

```bash
grep -rn "Wait(" skills/*/SKILL.md skills/*/references/*.md
```

Fix any documentation examples that show millisecond values.

- [ ] **Step 4: Add a Wait() clarification to script-writer's api-cheatsheet.md**

Read `skills/login-enterprise-script-writer/references/api-cheatsheet.md` and find the `Wait()` entry. If it doesn't already say "seconds, not milliseconds", add a note:

```markdown
// Wait takes SECONDS, not milliseconds. Wait(5) = 5 seconds. Wait(0.5) = 500ms.
```

- [ ] **Step 5: Commit**

```bash
git add skills/
git commit -m "fix: correct Wait() values in examples — API takes seconds, not milliseconds"
```

---

### Task 2: Document Browser Cleanup / StopBrowser Behavior

The validation found that `StopBrowser()` can throw after successful page interaction. Timer evidence is still valid but the final result shows as failed.

**Files:**
- Modify: `skills/login-enterprise-script-writer/SKILL.md`
- Modify: `skills/login-enterprise-script-writer/references/skeletons.md`
- Modify: `skills/login-enterprise-script-runner/SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: clear documentation about browser cleanup behavior

- [ ] **Step 1: Add StopBrowser guidance to script-writer SKILL.md**

Read the file. Find the section about Playwright/web scripts. Add a note about browser cleanup:

```markdown
**Browser cleanup:** `StopBrowser()` may throw if the browser process exited before cleanup
(e.g., due to sandbox restrictions or the page closing itself). This does not invalidate
timer measurements taken before the cleanup call. Wrap `StopBrowser()` in a try/catch
if cleanup failures should not fail the overall test:

```csharp
try { StopBrowser(); } catch { /* browser already closed */ }
```
```

- [ ] **Step 2: Add runtime verdict guidance to script-runner SKILL.md**

Read the file. Find where it describes success/failure. Add:

```markdown
**Partial success:** A script can produce valid timer measurements but still report
`EndedWithErrors` if cleanup fails (e.g., `StopBrowser()` throws). Timer evidence in
the CSV is still valid. Check the `timers` array in the JSON output — if your target
timers are present with values, the measured interaction succeeded even if the final
verdict is `EndedWithErrors`.
```

- [ ] **Step 3: Add cleanup pattern to skeletons.md**

Read `skills/login-enterprise-script-writer/references/skeletons.md`. If the Playwright skeleton has a bare `StopBrowser()`, add the try/catch pattern as a comment showing the robust alternative.

- [ ] **Step 4: Commit**

```bash
git add skills/login-enterprise-script-writer/ skills/login-enterprise-script-runner/
git commit -m "docs: add browser cleanup and partial success guidance"
```

---

### Task 3: Document Engine exitCode vs Wrapper Success

The validation found `exitCode: 1` in the engine JSON while wrapper reports `success: true`. This confuses evaluators.

**Files:**
- Modify: `skills/login-enterprise-script-runner/SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: clear documentation about exit code semantics

- [ ] **Step 1: Add exitCode clarification to runner SKILL.md**

Read the file. Find the output format / JSON section. Add or expand:

```markdown
**Exit code semantics:** The engine's `exitCode` field uses Login Enterprise's internal
`ScriptResult` enum where `1 = Ended` (success). This is NOT a Unix-style exit code
where 0 means success. The `result` field (`"Ended"`) and the `success` field (`true`)
are the authoritative verdicts. Do not interpret `exitCode: 1` as a failure.
```

- [ ] **Step 2: Commit**

```bash
git add skills/login-enterprise-script-runner/SKILL.md
git commit -m "docs: clarify engine exitCode vs wrapper success semantics"
```

---

### Task 4: Document Timer Name Normalization

Timer names are case-normalized in CSV output: `Load_Example` becomes `load_example`.

**Files:**
- Modify: `skills/login-enterprise-script-writer/SKILL.md`
- Modify: `skills/login-enterprise-script-runner/SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: documented timer naming behavior

- [ ] **Step 1: Add timer normalization note to script-writer SKILL.md**

Read the file. Find the timer naming rules section. Add:

```markdown
**Timer name normalization:** The Login Enterprise engine normalizes timer names to
lowercase in CSV output. `Load_Example` in your script becomes `load_example` in the
results CSV. This is expected engine behavior. Use lowercase + underscores in timer
names to avoid confusion: `load_example`, not `Load_Example`.
```

- [ ] **Step 2: Add same note to script-runner SKILL.md**

Read the file. Add near the output format section:

```markdown
**Timer names in CSV:** Timer names are normalized to lowercase by the engine.
`Load_Example` → `load_example`. This is expected — compare timer names
case-insensitively when correlating script timers with CSV output.
```

- [ ] **Step 3: Commit**

```bash
git add skills/login-enterprise-script-writer/ skills/login-enterprise-script-runner/
git commit -m "docs: document timer name normalization to lowercase in CSV output"
```

---

### Task 5: Add Smoke/Mapping Safety Warning

The validation found the mapper can attach to a similarly named app (Notepad++ when testing Notepad) and close it.

**Files:**
- Modify: `skills/login-enterprise-app-mapper/SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: safety guidance in mapper skill

- [ ] **Step 1: Add safety warning to app-mapper SKILL.md**

Read the file. Find the "Absolute rules" or prerequisites section. Add:

```markdown
**Before mapping a desktop app:**
- Close any similarly named applications. The engine uses window title matching and
  may attach to `Notepad++` when targeting `Notepad`, or `WordPad` when targeting `Word`.
- The engine will stop (close) the attached application when the probe completes.
  Unsaved work in the wrong app will be lost.
- Use specific `mainWindowTitle` patterns (e.g., `"*Untitled - Notepad"` instead of
  `"*Notepad*"`) to reduce false matches.
```

- [ ] **Step 2: Commit**

```bash
git add skills/login-enterprise-app-mapper/SKILL.md
git commit -m "docs: add safety warning about closing similar apps before mapping"
```

---

### Task 6: Windows Setup Improvements

Three related issues: Python `py` vs `python`, check-setup.ps1 lacking path overrides, and validator build purpose unclear.

**Files:**
- Modify: `README.md`
- Modify: `install/check-setup.ps1`

**Interfaces:**
- Consumes: nothing
- Produces: clearer setup experience for Windows users

- [ ] **Step 1: Add Windows Python note to README.md**

Read README.md. Find the Prerequisites section. Add a note:

```markdown
> **Windows Python note:** If `python` opens the Microsoft Store instead of Python,
> use the Windows Python launcher: `py -m pip install playwright` and
> `py -m playwright install chromium`. Alternatively, disable the Microsoft Store
> Python alias in Settings > Apps > Advanced app settings > App execution aliases.
```

- [ ] **Step 2: Add -EditorRoot and -EngineDir parameters to check-setup.ps1**

Read `install/check-setup.ps1`. Add two optional parameters to the param block:

```powershell
param(
    [switch]$Json,
    [string]$SkillsRoot,
    [string]$EditorRoot,
    [string]$EngineDir
)
```

Then in the detection section, use the explicit values if provided:

```powershell
$editorRoot = if ($EditorRoot) { $EditorRoot }
              elseif ($onWindows) { Find-EditorRoot }
              else { $null }

$engineDir = if ($EngineDir) { $EngineDir }
             elseif ($onWindows) { Find-EngineDir }
             else { $null }
```

- [ ] **Step 3: Improve validatorDll messaging**

In check-setup.ps1, in the human-readable output section, change the validator display from:

```
Validator:         (not built)
```

to:

```
Validator:         (not built -- run install.ps1 in the script-validator skill)
```

- [ ] **Step 4: Commit**

```bash
git add README.md install/check-setup.ps1
git commit -m "docs: add Windows Python guidance and check-setup path overrides"
```

---

### Task 7: Transcribe-Video PATH Diagnostics

The validation found ffmpeg was installed but not visible to the agent's process. The extractor should give better error messages.

**Files:**
- Modify: `skills/login-enterprise-transcribe-video/references/scripts/extract_frames.py`
- Modify: `skills/login-enterprise-transcribe-video/SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: better diagnostic output and explicit path override

- [ ] **Step 1: Add explicit ffmpeg/ffprobe path arguments to extract_frames.py**

Read the file. Add two optional CLI arguments:

```python
ap.add_argument("--ffmpeg", default=None, help="Explicit path to ffmpeg binary")
ap.add_argument("--ffprobe", default=None, help="Explicit path to ffprobe binary")
```

In `check_tools()`, use the explicit paths if provided, falling back to `shutil.which()`:

```python
def check_tools(ffmpeg_path=None, ffprobe_path=None):
    ffmpeg = ffmpeg_path or shutil.which("ffmpeg")
    ffprobe = ffprobe_path or shutil.which("ffprobe")
    if not ffmpeg:
        print("ERROR: ffmpeg not found.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Possible causes:", file=sys.stderr)
        print("  1. ffmpeg is not installed: winget install Gyan.FFmpeg", file=sys.stderr)
        print("  2. ffmpeg is installed but not on this process's PATH.", file=sys.stderr)
        print("     Try: --ffmpeg /path/to/ffmpeg --ffprobe /path/to/ffprobe", file=sys.stderr)
        print("  3. PATH was modified after this shell/agent started.", file=sys.stderr)
        print("     Try restarting your terminal or agent.", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"Current PATH: {os.environ.get('PATH', '(not set)')}", file=sys.stderr)
        sys.exit(1)
    if not ffprobe:
        print("ERROR: ffprobe not found. It is usually included with ffmpeg.", file=sys.stderr)
        print(f"Current PATH: {os.environ.get('PATH', '(not set)')}", file=sys.stderr)
        sys.exit(1)
    return ffmpeg, ffprobe
```

Pass the returned paths through to the subprocess calls that invoke ffmpeg/ffprobe.

- [ ] **Step 2: Add PATH troubleshooting to transcribe-video SKILL.md**

Read the file. Add a section:

```markdown
## Troubleshooting

**ffmpeg not found but is installed:**
Some AI agents run commands in a subprocess that may not see recent PATH changes.
- Restart your terminal or agent after installing ffmpeg.
- Use explicit paths: `--ffmpeg "C:\path\to\ffmpeg.exe" --ffprobe "C:\path\to\ffprobe.exe"`
- On Windows, check aliases: `where.exe ffmpeg`

**Python `python` opens Microsoft Store:**
Use the Windows Python launcher instead: `py extract_frames.py ...`
```

- [ ] **Step 3: Commit**

```bash
git add skills/login-enterprise-transcribe-video/
git commit -m "fix: add ffmpeg path override and improved PATH diagnostics to transcribe-video"
```

---

### Task 8: Validate and Push

**Files:** none (testing only)

- [ ] **Step 1: Validate all skills**

```bash
for dir in skills/login-enterprise-*/; do
    npx skills-ref validate "$dir"
done
```

Expected: all 5 skills pass.

- [ ] **Step 2: Run Pester tests**

```powershell
Get-ChildItem -Path skills/ -Recurse -Filter '*.tests.ps1' | ForEach-Object {
    Invoke-Pester -Path $_.FullName -PassThru
}
```

Expected: all tests pass.

- [ ] **Step 3: Verify SKILL.md body lengths**

```bash
for f in skills/*/SKILL.md; do
    lines=$(awk '/^---$/{n++; next} n>=2' "$f" | wc -l)
    echo "$f: $lines lines"
done
```

Expected: all under 500.

- [ ] **Step 4: Push**

```bash
git push origin master
```

- [ ] **Step 5: Test with Claude Code**

```bash
claude -p "What Login Enterprise skills are available?"
```

Expected: all 5 skills listed.
