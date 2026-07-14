#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Login Enterprise Skills Installer"
echo "================================="
echo ""

# Collect available skills
SKILLS=()
for dir in "$SKILLS_DIR"/login-enterprise-*/; do
    if [ -f "$dir/SKILL.md" ]; then
        SKILLS+=("$(basename "$dir")")
    fi
done

if [ ${#SKILLS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No skills found in $SKILLS_DIR${NC}"
    exit 1
fi

echo "Found ${#SKILLS[@]} skill(s): ${SKILLS[*]}"
echo ""

# Agent selection
# Defaults: Claude=global, Codex/Gemini/Cursor=project-level
# Override with --claude-project or --gemini-global
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_GEMINI=false
INSTALL_CURSOR=false
CLAUDE_MODE="global"   # default for Claude
GEMINI_MODE="project"  # default for Gemini

if [ $# -gt 0 ]; then
    for arg in "$@"; do
        case "$arg" in
            --claude)          INSTALL_CLAUDE=true ;;
            --claude-project)  INSTALL_CLAUDE=true; CLAUDE_MODE="project" ;;
            --codex)           INSTALL_CODEX=true ;;
            --gemini)          INSTALL_GEMINI=true ;;
            --gemini-global)   INSTALL_GEMINI=true; GEMINI_MODE="global" ;;
            --cursor)          INSTALL_CURSOR=true ;;
            --all)             INSTALL_CLAUDE=true; INSTALL_CODEX=true; INSTALL_GEMINI=true; INSTALL_CURSOR=true ;;
            --help)
                echo "Usage: install.sh [--claude] [--codex] [--gemini] [--cursor] [--all]"
                echo ""
                echo "  --claude          Install for Claude Code (global: ~/.claude/skills/)"
                echo "  --claude-project  Install for Claude Code (project: .claude/skills/)"
                echo "  --codex           Install for OpenAI Codex (project: .agent-skills/)"
                echo "  --gemini          Install for Gemini CLI (project: .gemini/skills/)"
                echo "  --gemini-global   Install for Gemini CLI (global: ~/.gemini/skills/)"
                echo "  --cursor          Install for Cursor (project: .cursor/skills/)"
                echo "  --all             Install for all supported agents (default locations)"
                echo "  (no args)         Interactive selection"
                exit 0
                ;;
            *) echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        esac
    done
else
    echo "Select agents to install for:"
    echo ""
    echo "  1) Claude Code     (global: ~/.claude/skills/)"
    echo "  2) OpenAI Codex    (project: .agent-skills/)"
    echo "  3) Gemini CLI      (project: .gemini/skills/)"
    echo "  4) Cursor          (project: .cursor/skills/)"
    echo "  5) All"
    echo ""
    read -rp "Choice [1/2/3/4/5]: " choice
    case "$choice" in
        1) INSTALL_CLAUDE=true ;;
        2) INSTALL_CODEX=true ;;
        3) INSTALL_GEMINI=true ;;
        4) INSTALL_CURSOR=true ;;
        5) INSTALL_CLAUDE=true; INSTALL_CODEX=true; INSTALL_GEMINI=true; INSTALL_CURSOR=true ;;
        *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
    esac
fi

installed=0

# Helper: install skills to a target directory
install_to_dir() {
    local agent_name="$1"
    local target_dir="$2"
    mkdir -p "$target_dir"
    echo ""
    echo "Installing for $agent_name → $target_dir"
    for skill in "${SKILLS[@]}"; do
        local target="$target_dir/$skill"
        # Remove broken symlinks
        if [ -L "$target" ] && [ ! -e "$target" ]; then
            echo -e "  ${YELLOW}Removing broken symlink: $skill${NC}"
            rm "$target"
        fi
        if [ -L "$target" ] || [ -d "$target" ]; then
            echo -e "  ${YELLOW}Skipping $skill (already exists)${NC}"
        else
            ln -s "$SKILLS_DIR/$skill" "$target"
            echo -e "  ${GREEN}✓ $skill${NC}"
            installed=$((installed + 1))
        fi
    done
}

# Claude Code (default: global ~/.claude/skills/, option: project .claude/skills/)
if [ "$INSTALL_CLAUDE" = true ]; then
    if [ "$CLAUDE_MODE" = "project" ]; then
        install_to_dir "Claude Code (project)" "$(pwd)/.claude/skills"
    else
        install_to_dir "Claude Code" "$HOME/.claude/skills"
    fi
fi

# OpenAI Codex (project: .agent-skills/)
if [ "$INSTALL_CODEX" = true ]; then
    install_to_dir "OpenAI Codex" "$(pwd)/.agent-skills"
fi

# Gemini CLI (default: project .gemini/skills/, option: global ~/.gemini/skills/)
if [ "$INSTALL_GEMINI" = true ]; then
    if [ "$GEMINI_MODE" = "global" ]; then
        install_to_dir "Gemini CLI (global)" "$HOME/.gemini/skills"
    else
        install_to_dir "Gemini CLI" "$(pwd)/.gemini/skills"
    fi
fi

# Cursor (project: .cursor/skills/)
if [ "$INSTALL_CURSOR" = true ]; then
    install_to_dir "Cursor" "$(pwd)/.cursor/skills"
fi

echo ""
echo -e "${GREEN}Done. $installed skill(s) installed.${NC}"
echo ""
echo "Verify by opening your agent and asking:"
echo '  "What Login Enterprise skills are available?"'
