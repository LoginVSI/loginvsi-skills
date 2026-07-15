# CLAUDE.md — loginvsi-skills

## What This Repo Is

This is the **implementation repo** for `loginvsi/loginvsi-skills` — a public GitHub project that provides AI coding agent skills for [Login Enterprise](https://www.loginvsi.com/).

Phases 1 and 2 are complete: the repo structure, install scripts, CI workflow, `script-writer`, `script-validator`, `script-runner`, `app-mapper`, and `transcribe-video` skills are all in place.

## Repo Contents

- `skills/` — Packaged agent skills (agentskills.io format)
  - `login-enterprise-write-script/` — Available now
  - `login-enterprise-validate-script/` — Available now
  - `login-enterprise-run-script/` — Available now
  - `login-enterprise-map-application/` — Available now
  - `login-enterprise-transcribe-video/` — Available now
- `install/` — Install scripts for supported AI coding agents (`install.sh`, `install.ps1`)
- `docs/PRD.md` — Full product requirements: goals, skill list, repo structure, agent compatibility matrix, success criteria, timeline
- `docs/architecture.md` — How skills relate to each other
- `README.md` — User-facing documentation: installation, usage, examples, prerequisites
- `CONTRIBUTING.md` — Contributor guide: skill format rules, SKILL.md spec, validation, PR checklist
- `.github/workflows/` — CI pipeline (skills-ref validate on every PR)

## What the Project Builds

Six AI agent skills packaged per the [agentskills.io specification](https://agentskills.io/specification):

| Skill | Purpose | Status |
|-------|---------|--------|
| `login-enterprise-write-script` | Generate `.cs` automation scripts | Available |
| `login-enterprise-validate-script` | Validate scripts against 8 Roslyn analyzer rules | Available |
| `login-enterprise-run-script` | Execute scripts on standalone engine | Available |
| `login-enterprise-map-application` | Map desktop UI trees or web DOMs to `app-map.json` | Available |
| `login-enterprise-transcribe-video` | Convert screen recordings to step-by-step docs | Available |

## Skill Format (agentskills.io spec)

Each skill is a directory under `skills/` containing:
- `SKILL.md` — YAML frontmatter (name, description, license, compatibility, metadata) + Markdown body (< 500 lines)
- `references/` — Detailed docs loaded on demand
- `scripts/` — Executable scripts (`.ps1`, `.sh`, `.py`)
- `assets/` — Templates, schemas, static resources

Naming: `login-enterprise-<name>`, lowercase + hyphens only, 1-64 chars, must match directory name.

## Supported Agents

Claude Code, OpenAI Codex, Gemini CLI, Cursor, GitHub Copilot, Windsurf, Roo Code, Junie, Goose, Antigravity, OpenCode, Kilo Code, and Trae are the supported agents.

## Key Constraints

- **Agent-agnostic**: No agent-specific syntax in skill instructions
- **No internal secrets**: No ProGet feeds, TFS refs, internal URLs
- **No bundled binaries**: Users supply their own Login Enterprise installation
- **Cross-platform where possible**: Script generation works anywhere; validation/execution require Windows + .NET 8 + ScriptEditor

## Working Conventions

- Skills must pass `npx skills-ref validate`
- PR checklist in CONTRIBUTING.md must be followed
- Increment `metadata.version` when updating existing skills
- Test with Claude Code, OpenAI Codex, and Gemini CLI before submitting

## Current Status

**5 skills available.** The following are in place:
- Repo structure and CI workflow
- Install scripts (`install.sh` / `install.ps1`) supporting 13 agents: Claude, Codex, Gemini, Cursor, Copilot, Windsurf, Roo, Junie, Goose, Antigravity, OpenCode, Kilo, Trae (plus `--all`)
- `login-enterprise-write-script` skill
- `login-enterprise-validate-script` skill (requires Windows, .NET 8 SDK, ScriptEditor at `C:\Program Files\Login VSI\ScriptEditor\`)
- `login-enterprise-run-script` skill (requires Windows, Login Enterprise Engine standalone, and `le-validate.dll` built from `script-validator`'s `install.ps1`)
- `login-enterprise-map-application` skill (desktop mapping requires Windows + Login Enterprise Engine + script-runner skill; web mapping requires Python 3 + Playwright)
- `login-enterprise-transcribe-video` skill (requires Python 3 and ffmpeg)

The map → write → validate → run pipeline is fully functional. `transcribe-video` is available as an independent utility skill. Any AI agent with these skills installed can orchestrate the full workflow naturally.
