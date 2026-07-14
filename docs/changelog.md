# Changelog

## v1.0.0 — 2026-07-12

Initial public release.

### Skills

- **login-enterprise-write-script** (v1.0) — Generate `.cs` automation scripts from natural language
- **login-enterprise-validate-script** (v1.0) — Validate scripts against 8 Roslyn analyzer rules
- **login-enterprise-run-script** (v1.0) — Execute scripts on the standalone Login Enterprise engine
- **login-enterprise-map-application** (v2.0) — Map desktop UI trees or web DOMs with workflow-based multi-finder probes
- **login-enterprise-transcribe-video** (v1.0) — Convert screen recordings into step-by-step documentation

### Infrastructure

- Install scripts for Claude Code, OpenAI Codex, and Gemini CLI (`install.sh`, `install.ps1`)
- Environment check utility (`install/check-setup.ps1`) with engine version reporting
- CI pipeline with skill validation, secret scanning, internal reference scanning, file reference verification, and Pester tests
- Getting Started on Windows guide

### Supported Agents

- Claude Code
- OpenAI Codex
- Gemini CLI
