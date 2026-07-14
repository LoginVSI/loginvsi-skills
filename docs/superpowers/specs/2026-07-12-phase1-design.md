# Phase 1 Design: loginvsi-skills

**Date:** 2026-07-12
**Approach:** Vertical slices — each skill ships end-to-end before starting the next

## Decisions

| Decision | Choice |
|----------|--------|
| Internal content availability | All existing content ready to port |
| Target agents (Phase 1) | Claude Code + OpenAI Codex |
| Install scripts | Included — needed for external user testing |
| ScriptEditor detection | Auto-detect at `C:\Program Files\Login VSI\ScriptEditor\`; guide download from Login Enterprise appliance if missing |
| PRD docs | Move `PRD.md` to `docs/`; update `README.md` and `CONTRIBUTING.md` to reflect real implementation |
| Implementation approach | Vertical slices — complete one skill end-to-end, then the next |

## Final Repository Structure

```
loginvsi-skills/
├── CLAUDE.md
├── README.md
├── CONTRIBUTING.md
├── LICENSE                                # Apache-2.0
├── .github/
│   └── workflows/
│       └── validate-skills.yml
├── skills/
│   ├── login-enterprise-write-script/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── api-reference.md
│   │   │   ├── patterns-desktop.md
│   │   │   ├── patterns-web.md
│   │   │   └── examples/
│   │   │       ├── notepad-basic.cs
│   │   │       └── web-login.cs
│   │   └── assets/
│   │       └── script-template.cs
│   └── login-enterprise-validate-script/
│       ├── SKILL.md
│       ├── scripts/
│       │   └── validate.ps1
│       └── references/
│           └── analyzer-rules.md
├── install/
│   ├── install.sh
│   ├── install.ps1
│   └── agent-configs/
│       ├── claude-code.md
│       └── codex.md
└── docs/
    ├── PRD.md
    └── architecture.md
```

## Pre-Work: Repository Rename

Before starting implementation, rename the GitHub repo from `loginvsi/loginvsi-skills-prd` to `loginvsi/loginvsi-skills`. GitHub auto-redirects the old URL. Re-clone or update the local remote after renaming:

```bash
git remote set-url origin https://github.com/loginvsi/loginvsi-skills.git
```

Optionally rename the local directory to match:

```bash
cd .. && mv loginvsi-skills-prd loginvsi-skills && cd loginvsi-skills
```

## Slice 1: `script-writer`

The first end-to-end deliverable. When complete, a user can clone the repo, run the install script, and use `script-writer` with Claude Code or Codex.

### Skill Content (ported from internal repo)

- **`SKILL.md`** — YAML frontmatter + instructions body (< 500 lines). Covers when to activate, script types (Desktop/UIAutomation, Playwright web, legacy CSS), output format, examples.
- **`references/api-reference.md`** — `ScriptBase` API, `FindControl()`, `StartTimer`/`StopTimer`, naming rules.
- **`references/patterns-desktop.md`** — UIAutomation patterns with examples.
- **`references/patterns-web.md`** — Playwright patterns with examples.
- **`references/examples/notepad-basic.cs`** — Simple desktop example.
- **`references/examples/web-login.cs`** — Web example.
- **`assets/script-template.cs`** — Blank template inheriting `ScriptBase`.

### Install Scripts (Claude Code + Codex)

- **`install.sh`** — Detects `~/.claude/` directory and creates symlinks for Claude Code. Creates `.agent-skills/` in the current project directory for Codex. User selects which agents to install for via flags or interactive prompt.
- **`install.ps1`** — Same logic for Windows using `New-Item -ItemType SymbolicLink`. Same agent selection behavior.
- **`install/agent-configs/claude-code.md`** — Manual setup notes.
- **`install/agent-configs/codex.md`** — Manual setup notes.

### CI

- **`.github/workflows/validate-skills.yml`** — Runs `npx skills-ref validate` on each skill directory. Checks name matches directory, description length, body line count.

### Docs

- **`README.md`** — Updated to reflect only `script-writer` available initially.
- **`CONTRIBUTING.md`** — Updated with real validation commands.
- **`docs/PRD.md`** — Moved from root.
- **`LICENSE`** — Apache-2.0 added.

### Done Criteria

1. `npx skills-ref validate skills/login-enterprise-write-script` passes.
2. Install script works on Windows (PowerShell) and Unix (bash) for Claude Code and Codex.
3. Claude Code activates the skill when asked to "write a Login Enterprise script."
4. CI runs and passes on push/PR.
5. No internal/proprietary references in any file.

## Slice 2: `script-validator`

Built on top of Slice 1. Adds the second skill with runtime ScriptEditor detection.

### Skill Content (ported from internal repo)

- **`SKILL.md`** — YAML frontmatter + instructions. Covers when to activate, how validation works, the 8 Roslyn analyzer rules, output format, error handling.
- **`references/analyzer-rules.md`** — Detailed description of all 8 rules with examples of passing/failing code.
- **`scripts/validate.ps1`** — Core validation script:
  1. Checks for ScriptEditor at `C:\Program Files\Login VSI\ScriptEditor\`.
  2. If missing: guides the user to download from their Login Enterprise appliance and unzip to that path.
  3. If present: runs the Roslyn analyzers against the provided `.cs` file.
  4. Returns structured results (pass/fail per rule, error messages, line numbers).

### Compatibility

- `compatibility` field states: `Requires Windows, .NET 8 SDK, and Login Enterprise ScriptEditor`.
- SKILL.md instructions tell the agent: if on non-Windows, inform the user that validation requires Windows.

### Updates to Existing Deliverables

- **CI:** `validate-skills.yml` validates both skill directories.
- **Install scripts:** Updated to symlink both skills.

### Done Criteria

1. `npx skills-ref validate skills/login-enterprise-validate-script` passes.
2. `validate.ps1` detects ScriptEditor presence correctly.
3. `validate.ps1` provides clear download guidance when ScriptEditor is missing.
4. `validate.ps1` successfully validates a `.cs` file when ScriptEditor is present.
5. CI passes for both skills.
6. Claude Code activates the skill when asked to "validate a Login Enterprise script."

## Docs Cleanup & Final Polish

After both slices are complete, before external user testing.

### README.md

- Skills table shows only `script-writer` and `script-validator` (future skills marked "Coming Soon").
- Supported agents: Claude Code and Codex as "Supported", others as "Planned".
- Quick Start points to real install scripts.
- Prerequisites table reflects Phase 1 skills only.
- Examples updated with real prompts.

### CONTRIBUTING.md

- Validation commands reference real CI workflow.
- PR checklist reflects actual repo state.
- "Test with at least two agents" specifies Claude Code and Codex.

### Other Docs

- **`docs/architecture.md`** — Brief doc explaining script-writer → script-validator flow.
- **`CLAUDE.md`** — Updated to reflect the real repo.

## External User Test Plan

1. Fresh clone on a Windows machine.
2. Run `install.ps1` — verify skills symlinked for Claude Code.
3. Open Claude Code, ask "What Login Enterprise skills are available?" — verify both listed.
4. Ask to write a script — verify `script-writer` activates and produces valid `.cs`.
5. Ask to validate the script — verify `script-validator` activates and runs.
6. Repeat steps 2-5 with Codex.
7. Push a PR — verify CI passes.
