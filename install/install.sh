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

# ---------------------------------------------------------------------------
# Agent registry
# ---------------------------------------------------------------------------
# Each agent has:
#   AGENT_NAMES[i]           — display name
#   AGENT_FLAGS[i]           — CLI flag (e.g. --claude)
#   AGENT_SCANS_DOTAGENTS[i] — 1 if it scans .agents/skills/, 0 if not
#   AGENT_NATIVE_REL[i]     — native relative path (for project scope), empty if N/A
#   AGENT_NATIVE_GLOBAL[i]  — native global path, empty if N/A

AGENT_NAMES=(
    "Claude Code"
    "OpenAI Codex"
    "Gemini CLI"
    "Cursor"
    "GitHub Copilot"
    "Windsurf"
    "Roo Code"
    "Junie"
    "Goose"
    "OpenCode"
    "Trae"
    "Kilo Code"
    "Antigravity"
)

AGENT_FLAGS=(
    "--claude"
    "--codex"
    "--gemini"
    "--cursor"
    "--copilot"
    "--windsurf"
    "--roo"
    "--junie"
    "--goose"
    "--opencode"
    "--trae"
    "--kilo"
    "--antigravity"
)

# 1 = scans .agents/skills/ automatically, 0 = needs native path too
AGENT_SCANS_DOTAGENTS=(0 1 1 1 1 1 1 0 1 1 0 0 1)

# Native relative paths (project scope) — only for agents that don't scan .agents/skills/
AGENT_NATIVE_REL=(
    ".claude/skills"    # Claude Code
    ""                  # Codex
    ""                  # Gemini
    ""                  # Cursor
    ""                  # Copilot
    ""                  # Windsurf
    ""                  # Roo
    ".junie/skills"     # Junie
    ""                  # Goose
    ""                  # OpenCode
    ".trae/skills"      # Trae
    ".kilo/skills"      # Kilo Code
    ""                  # Antigravity
)

# Native global paths — only for agents that don't scan .agents/skills/
AGENT_NATIVE_GLOBAL=(
    "$HOME/.claude/skills"   # Claude Code
    ""                       # Codex
    ""                       # Gemini
    ""                       # Cursor
    ""                       # Copilot
    ""                       # Windsurf
    ""                       # Roo
    "$HOME/.junie/skills"    # Junie
    ""                       # Goose
    ""                       # OpenCode
    "$HOME/.trae/skills"     # Trae
    "$HOME/.kilo/skills"     # Kilo Code
    ""                       # Antigravity
)

AGENT_COUNT=${#AGENT_NAMES[@]}

# ---------------------------------------------------------------------------
# Discover skills
# ---------------------------------------------------------------------------
echo "Login Enterprise Skills Installer"
echo "==================================="
echo ""

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

# ---------------------------------------------------------------------------
# Install helper — copy skills to a target directory
# ---------------------------------------------------------------------------
installed=0

install_to_dir() {
    local target_dir="$1"
    mkdir -p "$target_dir"
    echo ""
    echo "Copying skills to $target_dir"
    for skill in "${SKILLS[@]}"; do
        local target="$target_dir/$skill"
        local source="$SKILLS_DIR/$skill"
        if [ -d "$target" ] || [ -L "$target" ]; then
            # Remove existing (including old symlinks) and re-copy
            rm -rf "$target"
            cp -r "$source" "$target"
            echo -e "  ${YELLOW}~ $skill (updated)${NC}"
        else
            cp -r "$source" "$target"
            echo -e "  ${GREEN}✓ $skill${NC}"
        fi
        installed=$((installed + 1))
    done
}

# ---------------------------------------------------------------------------
# Build target directories for a selected agent at a given scope/path
# ---------------------------------------------------------------------------
# Populates TARGET_DIRS (global array used as accumulator — caller deduplicates)
TARGET_DIRS=()

add_targets_for_agent() {
    local idx="$1"       # agent index
    local scope="$2"     # "global" or "project"
    local proj_dir="$3"  # project directory (only used when scope=project)

    if [ "$scope" = "global" ]; then
        TARGET_DIRS+=("$HOME/.agents/skills")
        # If agent doesn't scan .agents/skills/, also add native global path
        if [ "${AGENT_SCANS_DOTAGENTS[$idx]}" -eq 0 ] && [ -n "${AGENT_NATIVE_GLOBAL[$idx]}" ]; then
            TARGET_DIRS+=("${AGENT_NATIVE_GLOBAL[$idx]}")
        fi
    else
        TARGET_DIRS+=("$proj_dir/.agents/skills")
        # If agent doesn't scan .agents/skills/, also add native project path
        if [ "${AGENT_SCANS_DOTAGENTS[$idx]}" -eq 0 ] && [ -n "${AGENT_NATIVE_REL[$idx]}" ]; then
            TARGET_DIRS+=("$proj_dir/${AGENT_NATIVE_REL[$idx]}")
        fi
    fi
}

# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------
SELECTED=()
for (( i=0; i<AGENT_COUNT; i++ )); do
    SELECTED+=(0)
done

CLI_MODE=false
SCOPE=""        # "" = ask per agent, "global" or "project" = forced
PROJECT_PATH=""

if [ $# -gt 0 ]; then
    CLI_MODE=true
    SCOPE="project"  # default for CLI

    while [ $# -gt 0 ]; do
        case "$1" in
            --global)  SCOPE="global" ;;
            --project) SCOPE="project" ;;
            --path)
                shift
                if [ $# -eq 0 ]; then
                    echo -e "${RED}Error: --path requires a directory argument${NC}"
                    exit 1
                fi
                PROJECT_PATH="$1"
                ;;
            --all)
                for (( i=0; i<AGENT_COUNT; i++ )); do
                    SELECTED[$i]=1
                done
                ;;
            --help)
                echo "Usage: install.sh [OPTIONS] [AGENTS]"
                echo ""
                echo "Agents:"
                echo "  --claude        Claude Code"
                echo "  --codex         OpenAI Codex"
                echo "  --gemini        Gemini CLI"
                echo "  --cursor        Cursor"
                echo "  --copilot       GitHub Copilot"
                echo "  --windsurf      Windsurf"
                echo "  --roo           Roo Code"
                echo "  --junie         Junie"
                echo "  --goose         Goose"
                echo "  --opencode      OpenCode"
                echo "  --trae          Trae"
                echo "  --kilo          Kilo Code"
                echo "  --antigravity   Antigravity"
                echo "  --all           All agents"
                echo ""
                echo "Options:"
                echo "  --global        Install globally for selected agents"
                echo "  --project       Install at project level (default)"
                echo "  --path <dir>    Specify project directory (default: current dir)"
                echo "  --help          Show this help"
                exit 0
                ;;
            *)
                # Match against agent flags
                matched=false
                for (( i=0; i<AGENT_COUNT; i++ )); do
                    if [ "$1" = "${AGENT_FLAGS[$i]}" ]; then
                        SELECTED[$i]=1
                        matched=true
                        break
                    fi
                done
                if [ "$matched" = false ]; then
                    echo -e "${RED}Unknown option: $1${NC}"
                    exit 1
                fi
                ;;
        esac
        shift
    done

    # Validate at least one agent selected
    any_selected=false
    for (( i=0; i<AGENT_COUNT; i++ )); do
        if [ "${SELECTED[$i]}" -eq 1 ]; then
            any_selected=true
            break
        fi
    done
    if [ "$any_selected" = false ]; then
        echo -e "${RED}Error: No agents selected. Use --help for usage.${NC}"
        exit 1
    fi

    # Resolve project path
    if [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="$(pwd)"
    fi

    # Build target list from CLI selections
    for (( i=0; i<AGENT_COUNT; i++ )); do
        if [ "${SELECTED[$i]}" -eq 1 ]; then
            add_targets_for_agent "$i" "$SCOPE" "$PROJECT_PATH"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Interactive mode
# ---------------------------------------------------------------------------
if [ "$CLI_MODE" = false ]; then

    # --- Step 1: Checkbox selection ---
    draw_menu() {
        for (( i=0; i<AGENT_COUNT; i++ )); do
            local check=" "
            if [ "${SELECTED[$i]}" -eq 1 ]; then
                check="x"
            fi
            printf "  [%s] %2d) %s\n" "$check" "$((i+1))" "${AGENT_NAMES[$i]}"
        done
        echo ""
    }

    MENU_LINES=$((AGENT_COUNT + 1))  # agent lines + blank line

    echo "Select agents to install for (enter numbers to toggle, Enter to confirm):"
    echo ""
    draw_menu

    while true; do
        read -rp "Select [ex. 1,2,13 or 1-13, a=all, Enter=continue]: " input

        if [ -z "$input" ]; then
            # Confirm selection
            break
        elif [ "$input" = "a" ] || [ "$input" = "A" ]; then
            # Toggle all on
            for (( i=0; i<AGENT_COUNT; i++ )); do
                SELECTED[$i]=1
            done
        else
            # Parse comma-separated tokens, each may be a number or range
            IFS=',' read -ra tokens <<< "$input"
            for token in "${tokens[@]}"; do
                token="$(echo "$token" | tr -d ' ')"
                if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    # Range
                    range_start="${BASH_REMATCH[1]}"
                    range_end="${BASH_REMATCH[2]}"
                    for (( n=range_start; n<=range_end; n++ )); do
                        if [ "$n" -ge 1 ] && [ "$n" -le "$AGENT_COUNT" ]; then
                            idx=$((n-1))
                            SELECTED[$idx]=$(( 1 - SELECTED[$idx] ))
                        fi
                    done
                elif [[ "$token" =~ ^[0-9]+$ ]]; then
                    # Single number — toggle
                    num="$token"
                    if [ "$num" -ge 1 ] && [ "$num" -le "$AGENT_COUNT" ]; then
                        idx=$((num-1))
                        SELECTED[$idx]=$(( 1 - SELECTED[$idx] ))
                    fi
                fi
            done
        fi

        # Move cursor up and redraw menu
        printf '\033[%dA' "$((MENU_LINES + 1))"  # +1 for the prompt line
        draw_menu
    done

    # Validate at least one selected
    any_selected=false
    for (( i=0; i<AGENT_COUNT; i++ )); do
        if [ "${SELECTED[$i]}" -eq 1 ]; then
            any_selected=true
            break
        fi
    done
    if [ "$any_selected" = false ]; then
        echo -e "${RED}No agents selected. Exiting.${NC}"
        exit 1
    fi

    # --- Step 2: Per-agent scope questions ---
    for (( i=0; i<AGENT_COUNT; i++ )); do
        if [ "${SELECTED[$i]}" -ne 1 ]; then
            continue
        fi

        local_name="${AGENT_NAMES[$i]}"
        echo ""
        echo "$local_name supports installing skills globally or at a project level."
        echo "  Global  — available in all your projects"
        echo "  Project — available in one project folder only"
        read -rp "Install globally or at project level? [g/p]: " scope_choice

        if [ "$scope_choice" = "g" ] || [ "$scope_choice" = "G" ]; then
            add_targets_for_agent "$i" "global" ""
        else
            # Project scope — ask which folder
            current_dir="$(pwd)"
            echo ""
            echo "Install to this folder? ($current_dir)"
            echo "  1) Yes, use this folder"
            echo "  2) Different folder"
            read -rp "Choice [1-2]: " folder_choice

            if [ "$folder_choice" = "2" ]; then
                read -rp "Enter project folder path: " custom_path
                # Expand ~ if present
                custom_path="${custom_path/#\~/$HOME}"
                add_targets_for_agent "$i" "project" "$custom_path"
            else
                add_targets_for_agent "$i" "project" "$current_dir"
            fi
        fi
    done
fi

# ---------------------------------------------------------------------------
# Step 3: Deduplicate targets and copy skills
# ---------------------------------------------------------------------------
UNIQUE_DIRS=()
for dir in "${TARGET_DIRS[@]}"; do
    # Normalize path (resolve . and ..)
    dir="$(cd "$(dirname "$dir")" 2>/dev/null && pwd)/$(basename "$dir")" 2>/dev/null || dir="$dir"
    duplicate=false
    for udir in "${UNIQUE_DIRS[@]+"${UNIQUE_DIRS[@]}"}"; do
        if [ "$dir" = "$udir" ]; then
            duplicate=true
            break
        fi
    done
    if [ "$duplicate" = false ]; then
        UNIQUE_DIRS+=("$dir")
    fi
done

if [ ${#UNIQUE_DIRS[@]} -eq 0 ]; then
    echo -e "${RED}No target directories resolved. Nothing to install.${NC}"
    exit 1
fi

for target_dir in "${UNIQUE_DIRS[@]}"; do
    install_to_dir "$target_dir"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}Done. $installed skill(s) installed across ${#UNIQUE_DIRS[@]} location(s).${NC}"
echo ""
echo "Verify by opening your agent and asking:"
echo '  "What Login Enterprise skills are available?"'
