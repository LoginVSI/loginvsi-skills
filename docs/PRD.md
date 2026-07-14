# Product Requirements Document: loginvsi-skills

## Overview

**Repository:** `loginvsi/loginvsi-skills` (public GitHub)
**Format:** [Agent Skills Specification](https://agentskills.io/specification)
**Purpose:** Provide AI coding agents with Login Enterprise domain expertise — script generation, validation, execution, UI mapping, and test documentation — in a standard, multi-agent format.

## Problem Statement

Login Enterprise automation scripts require deep knowledge of the `LoginPI.Engine.ScriptBase` API, Roslyn analyzer rules, UIAutomation/Playwright patterns, and the standalone engine runtime. Today this expertise lives in an internal, Claude-Code-only repository. Engineers using other AI agents (Codex, Cursor, Windsurf, Copilot, Gemini CLI, etc.) get no assistance, and the proprietary packaging prevents community contribution.

## Goals

1. **Multi-agent compatibility** — Skills work out-of-the-box with any agent that implements the [agentskills.io specification](https://agentskills.io/specification), including Claude Code, OpenAI Codex, GitHub Copilot, Cursor, Windsurf/Codeium, Gemini CLI, Roo Code, Junie, and others listed on the [Client Showcase](https://agentskills.io/clients).
2. **Standard format** — Every skill is a directory with a `SKILL.md` conforming to the spec (YAML frontmatter + Markdown body), progressive disclosure via `references/`, `scripts/`, and `assets/`.
3. **Easy installation** — Single clone + one command to install for any supported agent. Provide agent-specific setup helpers where the spec alone is insufficient.
4. **Community contribution** — Clear guidelines for adding new skills or improving existing ones. Public CI validates skill format compliance.
5. **No internal secrets** — All references to internal infrastructure (ProGet feeds, TFS submodules, internal package versions) are removed or replaced with public equivalents.

## Non-Goals

- Hosting a skill registry or marketplace (rely on agentskills.io ecosystem).
- Providing the ScriptEditor or Engine binaries (users must install Login Enterprise separately).
- Supporting non-coding agents (chatbots, data-analysis agents, etc.).

## Target Users

| Persona | Need |
|---------|------|
| Login Enterprise customer (QA engineer) | Generate and validate automation scripts using their preferred AI coding tool |
| Login Enterprise partner/SI | Build custom test libraries with AI assistance |
| Login VSI field engineer | Quickly scaffold demos and POCs |
| Community contributor | Add new skill patterns or improve prompts |

## Skills (Initial Release)

| Skill name | Description |
|------------|-------------|
| `login-enterprise-create-test` | Orchestrate the full test workflow: environment check, app mapping, script writing, validation, and execution |
| `login-enterprise-write-script` | Generate a complete `.cs` automation script from natural-language instructions |
| `login-enterprise-validate-script` | Validate a `.cs` script against the 8 Roslyn analyzer rules |
| `login-enterprise-run-script` | Execute a script on the standalone engine and report results |
| `login-enterprise-map-application` | Map a desktop app's UI tree or a web page's DOM into an `app-map.json` |
| `login-enterprise-transcribe-video` | Convert a screen recording into step-by-step documentation with screenshots |

## Repository Structure

```
loginvsi-skills/
├── README.md                          # Installation, usage, agent compatibility
├── CONTRIBUTING.md                    # How to create compliant skills
├── LICENSE                            # Apache-2.0
├── .github/
│   ├── workflows/
│   │   └── validate-skills.yml        # CI: validate all SKILL.md files
│   └── ISSUE_TEMPLATE/
│       └── new-skill-proposal.md
├── skills/
│   ├── login-enterprise-create-test/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── check-setup.ps1
│   │   │   └── workflow-guide.md
│   │   └── assets/
│   │       └── flow-diagram.md
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
│   ├── login-enterprise-validate-script/
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── validate.ps1
│   │   └── references/
│   │       ├── analyzer-rules.md
│   │       └── install.ps1
│   ├── login-enterprise-run-script/
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── run.ps1
│   │   └── references/
│   │       ├── engine-guide.md
│   │       └── install.ps1
│   ├── login-enterprise-map-application/
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   ├── map.ps1
│   │   │   └── map-web.ps1
│   │   └── references/
│   │       ├── app-map-schema.json
│   │       └── mapping-guide.md
│   └── login-enterprise-transcribe-video/
│       ├── SKILL.md
│       ├── scripts/
│       │   ├── extract-frames.py
│       │   └── win_setup_and_capture.ps1
│       └── references/
│           └── transcription-guide.md
├── install/
│   ├── install.sh                     # Unix: symlinks skills to agent skill dirs
│   ├── install.ps1                    # Windows: symlinks or copies skills
│   └── agent-configs/
│       ├── claude-code.md             # Agent-specific setup notes
│       ├── codex.md
│       ├── cursor.md
│       ├── windsurf.md
│       ├── copilot.md
│       └── gemini-cli.md
└── docs/
    ├── architecture.md                # How skills relate to each other
    └── changelog.md
```

## Agent Compatibility Matrix

| Agent | Skills Discovery | Installation Method |
|-------|-----------------|-------------------|
| Claude Code | `~/.claude/skills/` or project `.claude/skills/` | Symlink/copy skill dirs |
| OpenAI Codex | Workspace `.agent-skills/` or configured path | Symlink/copy skill dirs |
| Cursor | Project `.cursor/skills/` | Symlink/copy skill dirs |
| Windsurf/Codeium | Project `.windsurf/skills/` or `~/.codeium/skills/` | Symlink/copy skill dirs |
| GitHub Copilot | `.github/skills/` in repo | Copy skill dirs into repo |
| Gemini CLI | `~/.gemini/skills/` or project `.gemini/skills/` | Symlink/copy skill dirs |
| VS Code (generic) | `.vscode/skills/` | Copy skill dirs into workspace |
| Roo Code | Project `.roo/skills/` | Symlink/copy skill dirs |
| Junie (JetBrains) | Project `.junie/skills/` | Symlink/copy skill dirs |

> Note: Agent-specific paths may change as the ecosystem evolves. The install scripts detect which agents are present and install to appropriate locations.

## SKILL.md Requirements (per agentskills.io spec)

Each skill directory must contain a `SKILL.md` with:

```yaml
---
name: login-enterprise-<skill-name>    # lowercase, hyphens, matches directory name
description: >-                         # 1-1024 chars, describes what + when to use
  <clear description with trigger keywords>
license: Apache-2.0
compatibility: >-                       # environment requirements
  <platform/tool requirements>
metadata:
  author: loginvsi
  version: "1.0"
---
```

Body contains agent instructions (< 500 lines), with detailed references in separate files for progressive disclosure.

## Success Criteria

1. All skills pass `skills-ref validate` in CI.
2. Skills load and activate correctly in at least Claude Code, Codex, and Cursor.
3. README install instructions work on Windows and macOS/Linux.
4. A new contributor can follow CONTRIBUTING.md to create and submit a valid skill within 30 minutes.
5. No internal/proprietary references remain in the public repo.

## Security Considerations

- Scripts execute locally on the user's machine; document this clearly.
- No credentials or API keys stored in the repo.
- Engine/ScriptEditor binaries are not distributed — users supply their own licensed installation.
- CI checks for accidental secret commits.

## Timeline

| Phase | Scope |
|-------|-------|
| Phase 1 | Repo structure, README, CONTRIBUTING, install scripts, `script-writer` and `script-validator` skills ported from internal repo |
| Phase 2 | `script-runner`, `app-mapper`, `create-test` skills ported |
| Phase 3 | `transcribe-video`, CI pipeline, agent-specific install verification |
| Phase 4 | Community launch, issue templates, documentation site |

## Open Questions

1. Should we publish to a future agentskills.io registry when one becomes available?
2. Should the install script auto-detect agent installations, or require explicit agent selection?
3. Do we need skill variants for different Login Enterprise versions, or can version detection be handled within the skill logic?
