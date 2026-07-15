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
INSTALL_COPILOT=false
INSTALL_WINDSURF=false
INSTALL_ROO=false
INSTALL_JUNIE=false
INSTALL_GOOSE=false
INSTALL_ANTIGRAVITY=false
INSTALL_OPENCODE=false
INSTALL_KILO=false
INSTALL_TRAE=false
CLAUDE_MODE="global"        # default for Claude
GEMINI_MODE="project"       # default for Gemini
GOOSE_MODE="project"        # default for Goose
ANTIGRAVITY_MODE="project"  # default for Antigravity
OPENCODE_MODE="project"     # default for OpenCode
KILO_MODE="project"         # default for Kilo Code
TRAE_MODE="project"         # default for Trae

if [ $# -gt 0 ]; then
    for arg in "$@"; do
        case "$arg" in
            --claude)          INSTALL_CLAUDE=true ;;
            --claude-project)  INSTALL_CLAUDE=true; CLAUDE_MODE="project" ;;
            --codex)           INSTALL_CODEX=true ;;
            --gemini)          INSTALL_GEMINI=true ;;
            --gemini-global)   INSTALL_GEMINI=true; GEMINI_MODE="global" ;;
            --cursor)          INSTALL_CURSOR=true ;;
            --copilot)         INSTALL_COPILOT=true ;;
            --windsurf)        INSTALL_WINDSURF=true ;;
            --roo)             INSTALL_ROO=true ;;
            --junie)           INSTALL_JUNIE=true ;;
            --goose)           INSTALL_GOOSE=true ;;
            --goose-global)    INSTALL_GOOSE=true; GOOSE_MODE="global" ;;
            --antigravity)     INSTALL_ANTIGRAVITY=true ;;
            --antigravity-global) INSTALL_ANTIGRAVITY=true; ANTIGRAVITY_MODE="global" ;;
            --opencode)        INSTALL_OPENCODE=true ;;
            --opencode-global) INSTALL_OPENCODE=true; OPENCODE_MODE="global" ;;
            --kilo)            INSTALL_KILO=true ;;
            --kilo-global)     INSTALL_KILO=true; KILO_MODE="global" ;;
            --trae)            INSTALL_TRAE=true ;;
            --trae-global)     INSTALL_TRAE=true; TRAE_MODE="global" ;;
            --all)             INSTALL_CLAUDE=true; INSTALL_CODEX=true; INSTALL_GEMINI=true; INSTALL_CURSOR=true; INSTALL_COPILOT=true; INSTALL_WINDSURF=true; INSTALL_ROO=true; INSTALL_JUNIE=true; INSTALL_GOOSE=true; INSTALL_ANTIGRAVITY=true; INSTALL_OPENCODE=true; INSTALL_KILO=true; INSTALL_TRAE=true ;;
            --help)
                echo "Usage: install.sh [--claude] [--codex] [--gemini] [--cursor] [--copilot] [--windsurf] [--roo] [--junie] [--goose] [--antigravity] [--opencode] [--kilo] [--trae] [--all]"
                echo ""
                echo "  --claude              Install for Claude Code (global: ~/.claude/skills/)"
                echo "  --claude-project      Install for Claude Code (project: .claude/skills/)"
                echo "  --codex               Install for OpenAI Codex (project: .agent-skills/)"
                echo "  --gemini              Install for Gemini CLI (project: .gemini/skills/)"
                echo "  --gemini-global       Install for Gemini CLI (global: ~/.gemini/skills/)"
                echo "  --cursor              Install for Cursor (project: .cursor/skills/)"
                echo "  --copilot             Install for GitHub Copilot (project: .github/skills/)"
                echo "  --windsurf            Install for Windsurf (project: .windsurf/skills/)"
                echo "  --roo                 Install for Roo Code (project: .roo/skills/)"
                echo "  --junie               Install for Junie (project: .junie/skills/)"
                echo "  --goose               Install for Goose (project: .goose/skills/)"
                echo "  --goose-global        Install for Goose (global: ~/.agents/skills/)"
                echo "  --antigravity         Install for Antigravity (project: .agents/skills/)"
                echo "  --antigravity-global  Install for Antigravity (global: ~/.gemini/config/skills/)"
                echo "  --opencode            Install for OpenCode (project: .opencode/skills/)"
                echo "  --opencode-global     Install for OpenCode (global: ~/.config/opencode/skills/)"
                echo "  --kilo                Install for Kilo Code (project: .kilo/skills/)"
                echo "  --kilo-global         Install for Kilo Code (global: ~/.kilo/skills/)"
                echo "  --trae                Install for Trae (project: .trae/skills/)"
                echo "  --trae-global         Install for Trae (global: ~/.trae/skills/)"
                echo "  --all                 Install for all supported agents (default locations)"
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
    echo "  5) GitHub Copilot  (project: .github/skills/)"
    echo "  6) Windsurf        (project: .windsurf/skills/)"
    echo "  7) Roo Code        (project: .roo/skills/)"
    echo "  8) Junie           (project: .junie/skills/)"
    echo "  9) Goose           (project: .goose/skills/)"
    echo " 10) Antigravity     (project: .agents/skills/)"
    echo " 11) OpenCode        (project: .opencode/skills/)"
    echo " 12) Kilo Code       (project: .kilo/skills/)"
    echo " 13) Trae            (project: .trae/skills/)"
    echo " 14) All"
    echo ""
    read -rp "Choice [1-14]: " choice
    case "$choice" in
        1) INSTALL_CLAUDE=true ;;
        2) INSTALL_CODEX=true ;;
        3) INSTALL_GEMINI=true ;;
        4) INSTALL_CURSOR=true ;;
        5) INSTALL_COPILOT=true ;;
        6) INSTALL_WINDSURF=true ;;
        7) INSTALL_ROO=true ;;
        8) INSTALL_JUNIE=true ;;
        9) INSTALL_GOOSE=true ;;
        10) INSTALL_ANTIGRAVITY=true ;;
        11) INSTALL_OPENCODE=true ;;
        12) INSTALL_KILO=true ;;
        13) INSTALL_TRAE=true ;;
        14) INSTALL_CLAUDE=true; INSTALL_CODEX=true; INSTALL_GEMINI=true; INSTALL_CURSOR=true; INSTALL_COPILOT=true; INSTALL_WINDSURF=true; INSTALL_ROO=true; INSTALL_JUNIE=true; INSTALL_GOOSE=true; INSTALL_ANTIGRAVITY=true; INSTALL_OPENCODE=true; INSTALL_KILO=true; INSTALL_TRAE=true ;;
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

# GitHub Copilot (project: .github/skills/)
if [ "$INSTALL_COPILOT" = true ]; then
    install_to_dir "GitHub Copilot" "$(pwd)/.github/skills"
fi

# Windsurf (project: .windsurf/skills/)
if [ "$INSTALL_WINDSURF" = true ]; then
    install_to_dir "Windsurf" "$(pwd)/.windsurf/skills"
fi

# Roo Code (project: .roo/skills/)
if [ "$INSTALL_ROO" = true ]; then
    install_to_dir "Roo Code" "$(pwd)/.roo/skills"
fi

# Junie (project: .junie/skills/)
if [ "$INSTALL_JUNIE" = true ]; then
    install_to_dir "Junie" "$(pwd)/.junie/skills"
fi

# Goose (default: project .goose/skills/, option: global ~/.agents/skills/)
if [ "$INSTALL_GOOSE" = true ]; then
    if [ "$GOOSE_MODE" = "global" ]; then
        install_to_dir "Goose (global)" "$HOME/.agents/skills"
    else
        install_to_dir "Goose" "$(pwd)/.goose/skills"
    fi
fi

# Antigravity (default: project .agents/skills/, option: global ~/.gemini/config/skills/)
if [ "$INSTALL_ANTIGRAVITY" = true ]; then
    if [ "$ANTIGRAVITY_MODE" = "global" ]; then
        install_to_dir "Antigravity (global)" "$HOME/.gemini/config/skills"
    else
        install_to_dir "Antigravity" "$(pwd)/.agents/skills"
    fi
fi

# OpenCode (default: project .opencode/skills/, option: global ~/.config/opencode/skills/)
if [ "$INSTALL_OPENCODE" = true ]; then
    if [ "$OPENCODE_MODE" = "global" ]; then
        install_to_dir "OpenCode (global)" "$HOME/.config/opencode/skills"
    else
        install_to_dir "OpenCode" "$(pwd)/.opencode/skills"
    fi
fi

# Kilo Code (default: project .kilo/skills/, option: global ~/.kilo/skills/)
if [ "$INSTALL_KILO" = true ]; then
    if [ "$KILO_MODE" = "global" ]; then
        install_to_dir "Kilo Code (global)" "$HOME/.kilo/skills"
    else
        install_to_dir "Kilo Code" "$(pwd)/.kilo/skills"
    fi
fi

# Trae (default: project .trae/skills/, option: global ~/.trae/skills/)
if [ "$INSTALL_TRAE" = true ]; then
    if [ "$TRAE_MODE" = "global" ]; then
        install_to_dir "Trae (global)" "$HOME/.trae/skills"
    else
        install_to_dir "Trae" "$(pwd)/.trae/skills"
    fi
fi

echo ""
echo -e "${GREEN}Done. $installed skill(s) installed.${NC}"
echo ""
echo "Verify by opening your agent and asking:"
echo '  "What Login Enterprise skills are available?"'
