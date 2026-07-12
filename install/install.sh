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
INSTALL_CLAUDE=false
INSTALL_CODEX=false

if [ $# -gt 0 ]; then
    for arg in "$@"; do
        case "$arg" in
            --claude) INSTALL_CLAUDE=true ;;
            --codex)  INSTALL_CODEX=true ;;
            --all)    INSTALL_CLAUDE=true; INSTALL_CODEX=true ;;
            --help)
                echo "Usage: install.sh [--claude] [--codex] [--all]"
                echo "  --claude  Install for Claude Code"
                echo "  --codex   Install for OpenAI Codex"
                echo "  --all     Install for all supported agents"
                echo "  (no args) Interactive selection"
                exit 0
                ;;
            *) echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        esac
    done
else
    echo "Select agents to install for:"
    echo ""
    echo "  1) Claude Code (~/.claude/skills/)"
    echo "  2) OpenAI Codex (.agent-skills/ in current project)"
    echo "  3) All"
    echo ""
    read -rp "Choice [1/2/3]: " choice
    case "$choice" in
        1) INSTALL_CLAUDE=true ;;
        2) INSTALL_CODEX=true ;;
        3) INSTALL_CLAUDE=true; INSTALL_CODEX=true ;;
        *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
    esac
fi

installed=0

# Claude Code
if [ "$INSTALL_CLAUDE" = true ]; then
    CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
    mkdir -p "$CLAUDE_SKILLS_DIR"
    echo ""
    echo "Installing for Claude Code → $CLAUDE_SKILLS_DIR"
    for skill in "${SKILLS[@]}"; do
        target="$CLAUDE_SKILLS_DIR/$skill"
        if [ -L "$target" ] || [ -d "$target" ]; then
            echo -e "  ${YELLOW}Skipping $skill (already exists)${NC}"
        else
            ln -s "$SKILLS_DIR/$skill" "$target"
            echo -e "  ${GREEN}✓ $skill${NC}"
            ((installed++))
        fi
    done
fi

# Codex
if [ "$INSTALL_CODEX" = true ]; then
    CODEX_SKILLS_DIR="$(pwd)/.agent-skills"
    mkdir -p "$CODEX_SKILLS_DIR"
    echo ""
    echo "Installing for OpenAI Codex → $CODEX_SKILLS_DIR"
    for skill in "${SKILLS[@]}"; do
        target="$CODEX_SKILLS_DIR/$skill"
        if [ -L "$target" ] || [ -d "$target" ]; then
            echo -e "  ${YELLOW}Skipping $skill (already exists)${NC}"
        else
            ln -s "$SKILLS_DIR/$skill" "$target"
            echo -e "  ${GREEN}✓ $skill${NC}"
            ((installed++))
        fi
    done
fi

echo ""
echo -e "${GREEN}Done. $installed skill(s) installed.${NC}"
echo ""
echo "Verify by opening your agent and asking:"
echo '  "What Login Enterprise skills are available?"'
