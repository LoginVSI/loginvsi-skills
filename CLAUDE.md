# CLAUDE.md — loginvsi-skills

## What This Repo Is

This is the **implementation repo** for `loginvsi/loginvsi-skills` — a public GitHub project that provides AI coding agent skills for [Login Enterprise](https://www.loginvsi.com/).

Phase 1 Slice 1 is complete: the repo structure, install scripts, CI workflow, and the `script-writer` skill are all in place.

## Repo Contents

- `skills/` — Packaged agent skills (agentskills.io format)
  - `login-enterprise-script-writer/` — Available now
  - `login-enterprise-script-validator/` — In development (Slice 2)
- `install/` — Install scripts for Claude Code and OpenAI Codex (`install.sh`, `install.ps1`)
- `docs/PRD.md` — Full product requirements: goals, skill list, repo structure, agent compatibility matrix, success criteria, timeline
- `docs/architecture.md` — How skills relate to each other
- `README.md` — User-facing documentation: installation, usage, examples, prerequisites
- `CONTRIBUTING.md` — Contributor guide: skill format rules, SKILL.md spec, validation, PR checklist
- `.github/workflows/` — CI pipeline (skills-ref validate on every PR)

## What the Project Builds

Six AI agent skills packaged per the [agentskills.io specification](https://agentskills.io/specification):

| Skill | Purpose | Status |
|-------|---------|--------|
| `login-enterprise-script-writer` | Generate `.cs` automation scripts | Available |
| `login-enterprise-script-validator` | Validate scripts against 8 Roslyn analyzer rules | Slice 2 |
| `login-enterprise-script-runner` | Execute scripts on standalone engine | Slice 3 |
| `login-enterprise-app-mapper` | Map desktop UI trees or web DOMs to `app-map.json` | Slice 3 |
| `login-enterprise-create-test` | Orchestrate full test lifecycle | Slice 3 |
| `login-enterprise-transcribe-video` | Convert screen recordings to step-by-step docs | Slice 4 |

## Skill Format (agentskills.io spec)

Each skill is a directory under `skills/` containing:
- `SKILL.md` — YAML frontmatter (name, description, license, compatibility, metadata) + Markdown body (< 500 lines)
- `references/` — Detailed docs loaded on demand
- `scripts/` — Executable scripts (`.ps1`, `.sh`, `.py`)
- `assets/` — Templates, schemas, static resources

Naming: `login-enterprise-<name>`, lowercase + hyphens only, 1-64 chars, must match directory name.

## Supported Agents

Claude Code and OpenAI Codex are the primary supported agents. GitHub Copilot, Cursor, Windsurf, Gemini CLI, Roo Code, and Junie are planned for future slices.

## Key Constraints

- **Agent-agnostic**: No agent-specific syntax in skill instructions
- **No internal secrets**: No ProGet feeds, TFS refs, internal URLs
- **No bundled binaries**: Users supply their own Login Enterprise installation
- **Cross-platform where possible**: Script generation works anywhere; validation/execution require Windows + .NET 8 + ScriptEditor

## Working Conventions

- Skills must pass `npx skills-ref validate`
- PR checklist in CONTRIBUTING.md must be followed
- Increment `metadata.version` when updating existing skills
- Test with Claude Code and OpenAI Codex before submitting

## Current Status

**Phase 1 Slice 1 complete.** The following are in place:
- Repo structure and CI workflow
- Install scripts (`install.sh` / `install.ps1`) supporting `--claude`, `--codex`, `--all` (bash) and `-Agent Claude/Codex/All` (PowerShell)
- `login-enterprise-script-writer` skill

Remaining build phases:
2. `script-validator` (Slice 2)
3. `script-runner` + `app-mapper` + `create-test` (Slice 3)
4. `transcribe-video` + docs site (Slice 4)
