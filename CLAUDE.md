# CLAUDE.md — loginvsi-skills PRD

## What This Repo Is

This is the **product requirements and specification repo** for `loginvsi/loginvsi-skills` — a public GitHub project that provides AI coding agent skills for [Login Enterprise](https://www.loginvsi.com/).

The repo currently contains only planning documents (PRD, README, CONTRIBUTING). The actual skills, install scripts, CI, and docs have not been built yet.

## Key Documents

- `PRD.md` — Full product requirements: goals, skill list, repo structure, agent compatibility matrix, success criteria, timeline
- `README.md` — User-facing documentation (draft): installation, usage, examples, prerequisites
- `CONTRIBUTING.md` — Contributor guide: skill format rules, SKILL.md spec, validation, PR checklist

## What the Project Builds

Six AI agent skills packaged per the [agentskills.io specification](https://agentskills.io/specification):

| Skill | Purpose |
|-------|---------|
| `login-enterprise-create-test` | Orchestrate full test lifecycle |
| `login-enterprise-script-writer` | Generate `.cs` automation scripts |
| `login-enterprise-script-validator` | Validate scripts against 8 Roslyn analyzer rules |
| `login-enterprise-script-runner` | Execute scripts on standalone engine |
| `login-enterprise-app-mapper` | Map desktop UI trees or web DOMs to `app-map.json` |
| `login-enterprise-transcribe-video` | Convert screen recordings to step-by-step docs |

## Skill Format (agentskills.io spec)

Each skill is a directory under `skills/` containing:
- `SKILL.md` — YAML frontmatter (name, description, license, compatibility, metadata) + Markdown body (< 500 lines)
- `references/` — Detailed docs loaded on demand
- `scripts/` — Executable scripts (`.ps1`, `.sh`, `.py`)
- `assets/` — Templates, schemas, static resources

Naming: `login-enterprise-<name>`, lowercase + hyphens only, 1-64 chars, must match directory name.

## Supported Agents

Claude Code, OpenAI Codex, GitHub Copilot, Cursor, Windsurf, Gemini CLI, Roo Code, Junie — any agent implementing agentskills.io.

## Key Constraints

- **Agent-agnostic**: No agent-specific syntax in skill instructions
- **No internal secrets**: No ProGet feeds, TFS refs, internal URLs
- **No bundled binaries**: Users supply their own Login Enterprise installation
- **Cross-platform where possible**: Script generation works anywhere; validation/execution require Windows + .NET 8 + ScriptEditor

## Working Conventions

- Skills must pass `npx skills-ref validate`
- PR checklist in CONTRIBUTING.md must be followed
- Increment `metadata.version` when updating existing skills
- Test with at least two different AI agents before submitting

## Current Status

**Planning phase** — documents define what to build. No implementation exists yet. The planned build phases are:
1. Repo structure + install scripts + `script-writer` + `script-validator`
2. `script-runner` + `app-mapper` + `create-test`
3. `transcribe-video` + CI pipeline
4. Community launch + docs site
