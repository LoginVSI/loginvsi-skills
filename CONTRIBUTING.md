# Contributing to loginvsi-skills

This guide explains how to create skills that are compliant with this repository and the [Agent Skills specification](https://agentskills.io/specification).

## Skill Compliance Requirements

Every skill in this repository must:

1. Conform to the [agentskills.io specification](https://agentskills.io/specification)
2. Work with any agent that implements the spec (not just one specific agent)
3. Pass CI validation (`skills-ref validate`)
4. Follow the naming and structural conventions below

## Creating a New Skill

### Step 1: Choose a Name

Skill names must:
- Start with `login-enterprise-` prefix
- Use only lowercase letters, numbers, and hyphens
- Not start or end with a hyphen
- Not contain consecutive hyphens (`--`)
- Be 1-64 characters total
- Match the parent directory name exactly

**Examples:**
- `login-enterprise-report-builder` (good)
- `login-enterprise-load-test-config` (good)
- `Login-Enterprise-Script` (bad — uppercase)
- `le-script` (bad — missing prefix)

### Step 2: Create the Directory Structure

```bash
mkdir -p skills/login-enterprise-your-skill/{references,scripts,assets}
```

Minimum required structure:

```
skills/login-enterprise-your-skill/
├── SKILL.md              # Required
├── references/           # Optional: detailed docs loaded on demand
├── scripts/              # Optional: executable scripts
└── assets/               # Optional: templates, schemas, static resources
```

### Step 3: Write the SKILL.md

The `SKILL.md` has two parts: YAML frontmatter and Markdown body.

#### Frontmatter (Required Fields)

```yaml
---
name: login-enterprise-your-skill
description: >-
  One to three sentences describing what this skill does and when to use it.
  Include keywords that help agents identify relevant tasks. Max 1024 characters.
license: Apache-2.0
compatibility: >-
  List platform/tool requirements. Example: Requires Windows, .NET 8 SDK,
  and Login Enterprise ScriptEditor installed.
metadata:
  author: loginvsi
  version: "1.0"
---
```

#### Frontmatter Field Rules

| Field | Required | Rules |
|-------|----------|-------|
| `name` | Yes | Must match directory name. 1-64 chars, lowercase + hyphens only. |
| `description` | Yes | 1-1024 chars. Describe what it does AND when to trigger it. |
| `license` | No | Use `Apache-2.0` for this repo. |
| `compatibility` | No | 1-500 chars. Only include if the skill has specific environment needs. |
| `metadata` | No | Key-value pairs. Always include `author: loginvsi` and a `version`. |
| `allowed-tools` | No | Space-separated tool names. Experimental — use sparingly. |

#### Body (Instructions)

The Markdown body after `---` contains instructions the agent follows when the skill is activated. Guidelines:

- **Keep it under 500 lines.** Move detailed references to `references/` files.
- **Be imperative.** Write instructions as commands: "Generate a script that...", "Validate by running..."
- **Include examples.** Show sample inputs and expected outputs.
- **Handle edge cases.** Tell the agent what to do when things go wrong.
- **Reference files with relative paths:** `See [API reference](references/api-reference.md)`
- **Be agent-agnostic.** Don't use Claude-specific or Codex-specific syntax. Write plain instructions any LLM can follow.

#### Example SKILL.md

```markdown
---
name: login-enterprise-script-writer
description: >-
  Generate a complete Login Enterprise .cs automation script from natural-language
  instructions. Supports Desktop (UIAutomation), Playwright web, and legacy CSS/Selenium
  patterns. Use when the user asks to write, create, or generate a Login Enterprise
  script, test script, or automation script.
license: Apache-2.0
compatibility: No specific requirements. Works on any platform.
metadata:
  author: loginvsi
  version: "1.0"
---

# Login Enterprise Script Writer

## When to activate

Activate when the user asks to:
- Write, create, or generate a Login Enterprise script
- Create a .cs automation script for an application
- Build a test that drives a desktop or web application

## Instructions

1. Ask the user which application they want to test and what actions to perform.
2. Determine the script type:
   - **Desktop**: Uses UIAutomation via `FindControl()` methods
   - **Web (Playwright)**: Uses `Browser.NewPage()` and Playwright locators
   - **Legacy web**: Uses CSS selectors (only if explicitly requested)
3. Generate a complete `.cs` file following the patterns in
   [references/patterns-desktop.md](references/patterns-desktop.md) or
   [references/patterns-web.md](references/patterns-web.md).
4. Include proper timer pairs (`StartTimer`/`StopTimer`) around meaningful operations.
5. Output ONLY the `.cs` file content — no markdown fences, no explanation.

## Output format

Raw `.cs` file content. The file must:
- Inherit from `ScriptBase`
- Override `void Execute()`
- Use `StartTimer()`/`StopTimer()` around key operations
- Follow naming rules in [references/api-reference.md](references/api-reference.md)

## Examples

**User request:** "Write a script that opens Notepad, types hello world, and saves to C:\temp\test.txt"

**Output:** A complete `.cs` file using UIAutomation patterns to drive Notepad.

See [references/examples/](references/examples/) for full example scripts.
```

### Step 4: Add References (Progressive Disclosure)

Agents load skills progressively:
1. **Metadata** (~100 tokens): `name` and `description` loaded at startup for all skills
2. **Instructions** (< 5000 tokens): Full `SKILL.md` body loaded when skill activates
3. **Resources** (on demand): Files in `references/`, `scripts/`, `assets/` loaded only when needed

Structure your content accordingly:

- **`SKILL.md` body**: High-level instructions, decision logic, output format
- **`references/`**: Detailed API docs, pattern libraries, rule definitions
- **`scripts/`**: Executable code the agent can run
- **`assets/`**: Templates, schemas, static data files

Keep each reference file focused on a single topic. Smaller files = less context consumption.

### Step 5: Add Scripts (Optional)

Scripts in `scripts/` should:
- Be self-contained or clearly document their dependencies
- Include error messages that help the agent understand what went wrong
- Handle common failure modes (missing tools, wrong platform, permission errors)
- Work cross-platform where possible, or clearly state platform requirements in `compatibility`

Supported script languages (depends on agent and environment):
- PowerShell (`.ps1`) — primary for Windows/Login Enterprise workflows
- Bash (`.sh`) — Unix utilities
- Python (`.py`) — cross-platform tooling

### Step 6: Validate

Run the reference validator:

```bash
npx skills-ref validate ./skills/login-enterprise-your-skill
```

Or run CI locally:

```bash
# Validate all skills
for dir in skills/*/; do
  npx skills-ref validate "$dir"
done
```

Check for:
- Valid YAML frontmatter
- `name` matches directory name
- `description` is non-empty and within length limits
- No invalid characters in `name`

### Step 7: Test with Multiple Agents

Before submitting, verify your skill works with at least two different agents. The primary test targets for this repository are **Claude Code** and **OpenAI Codex**:

1. Install the skill in your agent's skill directory
2. Start a new session
3. Ask the agent a question that should trigger your skill
4. Verify the skill activates and produces correct output
5. Test edge cases (missing prerequisites, invalid input)

## Writing Agent-Agnostic Instructions

Skills must work across all compatible agents. Follow these rules:

### Do

- Write clear, imperative instructions any LLM can follow
- Use standard Markdown formatting
- Reference files with relative paths from the skill root
- Describe expected inputs and outputs explicitly
- Include examples of both successful and failed scenarios

### Don't

- Use agent-specific syntax (`/slash-commands`, `@mentions`, tool-specific APIs)
- Assume specific tool names (e.g., don't say "use the Bash tool" — say "run the following command")
- Hardcode paths that only work on one OS (provide alternatives)
- Assume the agent has access to the internet (unless stated in `compatibility`)
- Write instructions that depend on conversation history or memory features

### Platform Considerations

Many Login Enterprise skills require Windows. When writing cross-platform skills:

```markdown
## Platform requirements

This skill requires Windows with Login Enterprise ScriptEditor installed.

If running on a non-Windows platform:
- The script can still be generated (no platform restriction for writing)
- Validation and execution require Windows — inform the user and suggest
  they run those steps on a Windows machine with the prerequisites installed.
```

## Submitting Your Skill

### Pull Request Checklist

- [ ] Skill directory name matches the `name` field in `SKILL.md`
- [ ] `name` starts with `login-enterprise-` prefix
- [ ] `description` clearly explains what the skill does and when to use it
- [ ] `SKILL.md` body is under 500 lines
- [ ] Reference files are focused and individually useful
- [ ] Scripts include error handling and helpful error messages
- [ ] `compatibility` field lists all environment requirements
- [ ] No internal/proprietary references (package feeds, internal URLs, etc.)
- [ ] No secrets, credentials, or API keys
- [ ] Tested with Claude Code and OpenAI Codex (primary targets)
- [ ] `skills-ref validate` passes
- [ ] README.md skills table updated (if adding a new skill)

### PR Template

```markdown
## New Skill: login-enterprise-your-skill

### What it does
Brief description of the skill's purpose.

### When it triggers
List the keywords/intents that activate this skill.

### Agents tested
- [ ] Claude Code
- [ ] OpenAI Codex
- [ ] Other: ___

### Prerequisites
List any environment requirements.

### Validation
- [ ] `skills-ref validate` passes
- [ ] Skill activates on relevant prompts
- [ ] Output is correct and complete
```

## Updating Existing Skills

When modifying an existing skill:

1. Increment the `version` in `metadata`
2. Test that the change doesn't break activation (description changes can affect when agents trigger the skill)
3. If changing `compatibility`, update the README prerequisites table
4. Run validation

## Style Guide

### Naming
- Skill names: `login-enterprise-<verb-or-noun>` (e.g., `login-enterprise-report-builder`)
- Reference files: descriptive kebab-case (e.g., `api-reference.md`, `patterns-desktop.md`)
- Script files: descriptive with appropriate extension (e.g., `validate.ps1`, `extract-frames.py`)

### Description Writing
- Lead with the action verb: "Generate...", "Validate...", "Execute...", "Map..."
- Include trigger keywords the agent will match against user prompts
- Mention the output format: "...outputs a .cs file", "...produces app-map.json"

### Instruction Writing
- Use numbered steps for sequential operations
- Use bullet lists for options/alternatives
- Bold key terms on first use
- Include a "When to activate" section at the top
- Include an "Output format" section describing what the skill produces

## CI/CD

The repository runs automated checks on every PR:

1. **Format validation**: `skills-ref validate` on all skills
2. **Name compliance**: Directory names match `SKILL.md` `name` fields
3. **Length checks**: `SKILL.md` body under 500 lines, `description` under 1024 chars
4. **Secret scanning**: No credentials or API keys committed
5. **Link checking**: Internal file references resolve correctly

## Questions?

- Open a [GitHub Issue](https://github.com/loginvsi/loginvsi-skills/issues) for bugs or feature requests
- Use the [New Skill Proposal](https://github.com/loginvsi/loginvsi-skills/issues/new?template=new-skill-proposal.md) template to suggest new skills
- See [docs/architecture.md](docs/architecture.md) for how skills relate to each other
