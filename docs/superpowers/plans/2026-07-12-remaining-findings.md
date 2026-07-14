# Remaining Findings Remediation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address the remaining LOW and MEDIUM findings from the external validation and hardening audit — documentation improvements, locator guidance, and transcribe-video enhancements.

**Architecture:** Small targeted changes across existing SKILL.md files and reference docs. No new skills or major refactoring.

**Tech Stack:** Markdown (SKILL.md, reference docs), Python (extract_frames.py)

## Global Constraints

- No internal/proprietary references
- Agent-agnostic instructions only
- SKILL.md body under 500 lines
- All skills must pass `npx skills-ref validate`
- Documentation-only changes — no runtime behavior changes

---

### Task 1: Document Browser Naming in Script-Writer

The validation found confusion between `chrome`, `chromium`, and `edge` in `// BROWSER:` magic comments. Users don't know which value maps to which browser.

**Files:**
- Modify: `skills/login-enterprise-write-script/references/skeletons.md`

**Interfaces:**
- Consumes: nothing
- Produces: clear browser naming documentation

- [ ] **Step 1: Read skeletons.md and find the BROWSER magic comment section**

Read `skills/login-enterprise-write-script/references/skeletons.md`. Find where `// BROWSER:` is documented.

- [ ] **Step 2: Add a browser naming table**

After the `// BROWSER:` magic comment documentation, add:

```markdown
**Browser values and what they launch:**

| `// BROWSER:` value | What the engine launches |
|---------------------|-------------------------|
| `chrome` | Installed Google Chrome (`C:\Program Files\Google\Chrome\...`) |
| `edge` | Installed Microsoft Edge |
| `chromium` | Playwright's bundled Chromium (if installed via `playwright install chromium`) |
| `firefox` | Installed Firefox or Playwright's bundled Firefox |
| `webkit` | Playwright's bundled WebKit |

The engine looks for installed browsers first. If you want to use Playwright's
bundled browser, ensure it is installed: `playwright install chromium`.
```

- [ ] **Step 3: Commit**

```bash
git add skills/login-enterprise-write-script/references/skeletons.md
git commit -m "docs: add browser naming table to skeletons.md"
```

---

### Task 2: Improve Web Locator Guidance in Script-Writer

The validation found that generated text assertions using `innerText` were brittle. Script-writer should guide agents toward more robust Playwright locator strategies.

**Files:**
- Modify: `skills/login-enterprise-write-script/SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: better locator guidance for web scripts

- [ ] **Step 1: Read script-writer SKILL.md**

Read the file and find the section about Playwright/web script generation.

- [ ] **Step 2: Add robust locator guidance**

Add a section (or append to an existing web section):

```markdown
## Web locator best practices

When generating Playwright locators for text-based assertions:

- **Prefer `GetByRole` or `GetByText`** over CSS selectors with `innerText` matching.
  `GetByText` is more resilient to whitespace and formatting differences.
- **Avoid exact full-paragraph matching.** Match a distinctive substring rather than
  the entire text content:
  ```csharp
  // Fragile — fails on whitespace differences
  await Locator("p", innerText: "This domain is for use in illustrative examples...").ClickAsync();
  
  // Robust — matches a distinctive substring
  await Locator("text=illustrative examples").ClickAsync();
  ```
- **Use `WaitForSelectorAsync` with a timeout** for elements that may load dynamically,
  rather than a fixed `Wait()` delay.
- **For heading assertions**, prefer the heading tag directly:
  ```csharp
  await Locator("h1:has-text('Example Domain')").WaitForAsync();
  ```
```

Keep it concise — this is guidance, not a reference doc.

- [ ] **Step 3: Verify body is under 500 lines**

```bash
awk '/^---$/{n++; next} n>=2' skills/login-enterprise-write-script/SKILL.md | wc -l
```

- [ ] **Step 4: Commit**

```bash
git add skills/login-enterprise-write-script/SKILL.md
git commit -m "docs: add web locator best practices to script-writer"
```

---

### Task 3: Transcribe-Video — Split Mixed Recordings Guidance

The validation found that a mixed desktop+web recording should be treated as two candidate workflows, not one. The skill should guide agents to identify and separate them.

**Files:**
- Modify: `skills/login-enterprise-transcribe-video/SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: guidance on handling mixed recordings

- [ ] **Step 1: Read transcribe-video SKILL.md**

Read the file.

- [ ] **Step 2: Add mixed recording guidance**

Find the section about interpreting extracted frames or generating output. Add:

```markdown
## Mixed recordings

When a recording shows multiple applications or workflows (e.g., a desktop app
followed by a web browser session):

1. **Identify workflow boundaries** — look for application switches, desktop returns,
   or browser open/close events in the frame sequence.
2. **Split into candidate workflows** — each application or distinct task becomes its
   own candidate. Do not try to generate a single script for a mixed recording.
3. **Ask follow-up questions** before generating scripts:
   - "The recording shows two workflows: [desktop app] and [web navigation].
     Which would you like to create a script for first?"
   - "What timer names should be used for each workflow?"
4. **Output candidate workflows** as a structured list with:
   - Workflow name
   - Application type (desktop / web)
   - Frame range (timestamps)
   - Observed actions
   - What additional information is needed to generate a script
```

- [ ] **Step 3: Verify body is under 500 lines**

- [ ] **Step 4: Commit**

```bash
git add skills/login-enterprise-transcribe-video/SKILL.md
git commit -m "docs: add mixed recording guidance to transcribe-video"
```

---

### Task 4: Transcribe-Video — Improve Error Reporting in extract_frames.py

The audit found that `run()` discards ffmpeg stderr on failure, and per-frame extraction failures are silently skipped.

**Files:**
- Modify: `skills/login-enterprise-transcribe-video/references/scripts/extract_frames.py`

**Interfaces:**
- Consumes: nothing
- Produces: better error reporting

- [ ] **Step 1: Read extract_frames.py**

Read the file and find the `run()` helper function and the `extract_one` function.

- [ ] **Step 2: Add stderr reporting to run()**

Find the `run()` function. After `subprocess.run(cmd, ...)`, check the return code and print stderr if non-zero:

```python
def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 and r.stderr:
        print(f"Warning: command failed (exit {r.returncode}): {' '.join(cmd)}", file=sys.stderr)
        print(f"  stderr: {r.stderr.strip()[:500]}", file=sys.stderr)
    return r
```

- [ ] **Step 3: Report per-frame extraction failures**

Find the loop that calls `extract_one`. When `ok` is `False`, print a warning instead of silently skipping:

```python
ok, err = extract_one(...)
if not ok:
    print(f"Warning: failed to extract frame at {ts}s: {err}", file=sys.stderr)
```

- [ ] **Step 4: Commit**

```bash
git add skills/login-enterprise-transcribe-video/references/scripts/extract_frames.py
git commit -m "fix: report ffmpeg stderr and per-frame extraction failures in extract_frames.py"
```

---

### Task 5: Runner — Improve logPath Detection

The validation found `logPath: null` in runner output even when the engine printed a log path to stdout.

**Files:**
- Modify: `skills/login-enterprise-run-script/references/runner/run.ps1`

**Interfaces:**
- Consumes: nothing
- Produces: more reliable log path detection

- [ ] **Step 1: Read run.ps1 and find the log path detection logic**

Read `skills/login-enterprise-run-script/references/runner/run.ps1`. Find where `logPath` is resolved — likely searching a temp directory for the engine log.

- [ ] **Step 2: Add stdout-based log path detection**

The engine prints the log path to stdout during execution. After running the engine, scan the captured stdout for a line containing a `.log` file path. If the filesystem-based detection fails, fall back to the stdout-detected path:

```powershell
# Try to detect log path from engine stdout
$logFromStdout = $null
foreach ($line in $engineOutput) {
    if ($line -match '([A-Z]:\\[^\s]+\.log)') {
        $candidate = $Matches[1]
        if (Test-Path $candidate) {
            $logFromStdout = $candidate
            break
        }
    }
}

# Use filesystem detection first, fall back to stdout
if (-not $logPath -and $logFromStdout) {
    $logPath = $logFromStdout
}
```

- [ ] **Step 3: Commit**

```bash
git add skills/login-enterprise-run-script/references/runner/run.ps1
git commit -m "fix: improve engine log path detection with stdout fallback"
```

---

### Task 6: Validate and Push

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

- [ ] **Step 3: Push**

```bash
git push origin master
```
