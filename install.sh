#!/bin/bash
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="claude"
USE_SYMLINK=false
INSTALL_MCP=false
INSTALL_KOTLIN=false
INSTALL_QUARKUS=false
TARGET_PROJECT=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log_header()  { echo -e "\n${BOLD}${BLUE}$1${NC}"; }
log_install() { echo -e "  ${GREEN}+${NC} $1"; }
log_update()  { echo -e "  ${YELLOW}~${NC} $1"; }
log_skip()    { echo -e "  ${DIM}-${NC} ${DIM}$1${NC}"; }
log_error()   { echo -e "  ${RED}!${NC} $1"; }
log_info()    { echo -e "  ${CYAN}i${NC} $1"; }

print_usage() {
    echo -e "${BOLD}Jimmer AI Toolkit Installer${NC}"
    echo ""
    echo -e "Usage: ${CYAN}./install.sh${NC} [OPTIONS] /path/to/your/project"
    echo ""
    echo "Safe to run on existing projects — won't break existing configs."
    echo ""
    echo "Options:"
    echo -e "  ${CYAN}--tool${NC} claude|qwen|gigacode       Target CLI tool (default: claude)"
    echo -e "  ${CYAN}--kotlin${NC}                          Add Kotlin reference to context"
    echo -e "  ${CYAN}--quarkus${NC}                         Add Quarkus reference to context"
    echo -e "  ${CYAN}--symlink${NC}                         Use symlinks instead of copies"
    echo -e "  ${CYAN}--mcp${NC}                             Install MCP server (Jimmer docs + GitHub issues)"
    echo ""
    echo "Examples:"
    echo -e "  ${DIM}./install.sh /path/to/project${NC}"
    echo -e "  ${DIM}./install.sh --kotlin /path/to/project${NC}"
    echo -e "  ${DIM}./install.sh --kotlin --quarkus --mcp /path/to/project${NC}"
    echo -e "  ${DIM}./install.sh --tool gigacode /path/to/project${NC}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tool)
            TOOL="$2"
            shift 2
            ;;
        --symlink)
            USE_SYMLINK=true
            shift
            ;;
        --kotlin)
            INSTALL_KOTLIN=true
            shift
            ;;
        --quarkus)
            INSTALL_QUARKUS=true
            shift
            ;;
        --mcp)
            INSTALL_MCP=true
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            TARGET_PROJECT="$1"
            shift
            ;;
    esac
done

if [ -z "$TARGET_PROJECT" ]; then
    print_usage
    exit 1
fi

if [ ! -d "$TARGET_PROJECT" ]; then
    echo -e "${RED}Error:${NC} Directory $TARGET_PROJECT does not exist"
    exit 1
fi

if [[ "$TOOL" != "claude" && "$TOOL" != "qwen" && "$TOOL" != "gigacode" ]]; then
    echo -e "${RED}Error:${NC} --tool must be 'claude', 'qwen', or 'gigacode'"
    exit 1
fi

# Tool-specific paths
case "$TOOL" in
    claude)
        CONFIG_DIR=".claude"
        ENTRY_FILE="CLAUDE.md"
        SKILLS_DIR="$CONFIG_DIR/commands"
        ;;
    qwen)
        CONFIG_DIR=".qwen"
        ENTRY_FILE="QWEN.md"
        SKILLS_DIR="$CONFIG_DIR/commands"
        ;;
    gigacode)
        CONFIG_DIR=".gigacode"
        ENTRY_FILE="GIGACODE.md"
        SKILLS_DIR="$CONFIG_DIR/commands"
        ;;
esac

# Create directories
mkdir -p "$TARGET_PROJECT/$CONFIG_DIR"
mkdir -p "$TARGET_PROJECT/$SKILLS_DIR"

echo -e "\n${BOLD}Jimmer AI Toolkit${NC} ${DIM}→${NC} ${CYAN}$TOOL${NC} ${DIM}→${NC} $TARGET_PROJECT/$CONFIG_DIR/"

# Counters
INSTALLED=0
SKIPPED=0
UPDATED=0

# Helper: copy or link, with conflict detection
install_file() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [ -f "$dst" ]; then
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
            log_skip "already linked: $label"
            SKIPPED=$((SKIPPED + 1))
            return
        fi
        if cmp -s "$src" "$dst" 2>/dev/null; then
            log_skip "identical: $label"
            SKIPPED=$((SKIPPED + 1))
            return
        fi
        if [ "$USE_SYMLINK" = true ]; then
            ln -sf "$src" "$dst"
            log_update "updated (symlink): $label"
        else
            cp "$src" "$dst"
            log_update "updated: $label"
        fi
        UPDATED=$((UPDATED + 1))
    else
        if [ "$USE_SYMLINK" = true ]; then
            ln -sf "$src" "$dst"
            log_install "linked: $label"
        else
            cp "$src" "$dst"
            log_install "copied: $label"
        fi
        INSTALLED=$((INSTALLED + 1))
    fi
}

# Build list of optional files (not auto-imported unless flag is set)
OPTIONAL_FILES=""
[ "$INSTALL_KOTLIN" = false ] && OPTIONAL_FILES="$OPTIONAL_FILES jimmer-kotlin.md"
[ "$INSTALL_QUARKUS" = false ] && OPTIONAL_FILES="$OPTIONAL_FILES jimmer-quarkus.md"

# 1. Instruction files
log_header "Instruction files"
FILE_COUNT=0
for file in "$TOOLKIT_DIR"/instructions/*.md; do
    filename=$(basename "$file")
    if echo "$OPTIONAL_FILES" | grep -qw "$filename"; then
        install_file "$file" "$TARGET_PROJECT/$CONFIG_DIR/$filename" "${DIM}optional${NC} $filename"
    else
        install_file "$file" "$TARGET_PROJECT/$CONFIG_DIR/$filename" "$filename"
        FILE_COUNT=$((FILE_COUNT + 1))
    fi
done

# 2. Skills/commands
log_header "Skills/Commands"
for file in "$TOOLKIT_DIR"/commands/*.md; do
    filename=$(basename "$file")
    install_file "$file" "$TARGET_PROJECT/$SKILLS_DIR/$filename" "$filename"
done

# 3. MCP server
if [ "$INSTALL_MCP" = true ]; then
    log_header "MCP Server"

    MCP_DIR="$TOOLKIT_DIR/mcp/jimmer-docs-mcp"
    MCP_DIST="$MCP_DIR/dist/bundle.js"

    if [ ! -f "$MCP_DIST" ]; then
        log_error "MCP bundle not found at $MCP_DIST"
        log_error "Run: cd $MCP_DIR && npm install && npm run bundle"
        INSTALL_MCP=false
    fi

    if [ "$INSTALL_MCP" = true ]; then
        MCP_SERVER_BLOCK="\"jimmer-docs\": {
      \"type\": \"stdio\",
      \"command\": \"node\",
      \"args\": [\"$MCP_DIST\"],
      \"env\": { \"GITHUB_TOKEN\": \"\${GITHUB_TOKEN}\" }
    }"

        if [ "$TOOL" = "claude" ]; then
            # Claude Code: .mcp.json in project root
            MCP_FILE="$TARGET_PROJECT/.mcp.json"
            if [ -f "$MCP_FILE" ]; then
                if grep -q "jimmer-docs" "$MCP_FILE" 2>/dev/null; then
                    log_skip "jimmer-docs already in .mcp.json"
                else
                    log_info ".mcp.json exists. Add this to your mcpServers section:"
                    echo -e "    ${DIM}${MCP_SERVER_BLOCK}${NC}"
                fi
            else
                cat > "$MCP_FILE" << MCPEOF
{
  "mcpServers": {
    "jimmer-docs": {
      "type": "stdio",
      "command": "node",
      "args": ["$MCP_DIST"],
      "env": {
        "GITHUB_TOKEN": "\${GITHUB_TOKEN}",
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
MCPEOF
                log_install "created .mcp.json"
            fi
        else
            # Qwen/GigaCode: mcpServers in settings.json inside config dir
            MCP_FILE="$TARGET_PROJECT/$CONFIG_DIR/settings.json"
            if [ -f "$MCP_FILE" ]; then
                if grep -q "jimmer-docs" "$MCP_FILE" 2>/dev/null; then
                    log_skip "jimmer-docs already in $CONFIG_DIR/settings.json"
                else
                    log_info "$CONFIG_DIR/settings.json exists. Add this to your mcpServers section:"
                    echo -e "    ${DIM}${MCP_SERVER_BLOCK}${NC}"
                fi
            else
                cat > "$MCP_FILE" << MCPEOF
{
  "mcpServers": {
    "jimmer-docs": {
      "command": "node",
      "args": ["$MCP_DIST"],
      "env": {
        "GITHUB_TOKEN": "\${GITHUB_TOKEN}",
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
MCPEOF
                log_install "created $CONFIG_DIR/settings.json"
            fi
        fi

        echo ""
        log_info "Tools: ${CYAN}jimmer_github_search${NC}, ${CYAN}jimmer_docs_search${NC}"
        log_info "For GitHub search, set GITHUB_TOKEN (scopes: public_repo, read:discussion):"
        echo -e "    ${DIM}https://github.com/settings/tokens${NC}"
        echo -e "    ${DIM}export GITHUB_TOKEN=ghp_your_token_here${NC}"
    fi
fi

# 4. Entry file (CLAUDE.md / QWEN.md / GIGACODE.md)
IMPORTS=""
for file in "$TOOLKIT_DIR"/instructions/*.md; do
    filename=$(basename "$file")
    # Skip optional files from auto-import
    if echo "$OPTIONAL_FILES" | grep -qw "$filename"; then
        continue
    fi
    IMPORTS="${IMPORTS}@${CONFIG_DIR}/${filename}
"
done

log_header "Entry file ($ENTRY_FILE)"
ENTRY_PATH="$TARGET_PROJECT/$ENTRY_FILE"

if [ -f "$ENTRY_PATH" ]; then
    MISSING_IMPORTS=""
    MISSING_COUNT=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if ! grep -qF "$line" "$ENTRY_PATH" 2>/dev/null; then
            MISSING_IMPORTS="${MISSING_IMPORTS}${line}
"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    done <<< "$IMPORTS"

    if [ "$MISSING_COUNT" -eq 0 ]; then
        log_skip "all imports already present"
    else
        echo "" >> "$ENTRY_PATH"
        echo "# Jimmer AI Toolkit" >> "$ENTRY_PATH"
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            echo "$line" >> "$ENTRY_PATH"
        done <<< "$MISSING_IMPORTS"
        log_update "appended $MISSING_COUNT import(s)"
    fi
else
    {
        echo "# Jimmer Project"
        echo ""
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            echo "$line"
        done <<< "$IMPORTS"
        echo ""
        echo "# Extended Jimmer knowledge available via commands:"
        echo "# /jimmer-entity, /jimmer-dto, /jimmer-build-query, /jimmer-migration, /jimmer-debug"
    } > "$ENTRY_PATH"
    log_install "created $ENTRY_FILE"
fi

# Summary
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}Done!${NC}  ${GREEN}+$INSTALLED installed${NC}  ${YELLOW}~$UPDATED updated${NC}  ${DIM}-$SKIPPED skipped${NC}"
echo ""
echo -e "  Context: ${CYAN}$FILE_COUNT instruction files${NC} (~50KB always in context)"
echo -e "  Skills:  ${CYAN}/jimmer-entity${NC}  ${CYAN}/jimmer-build-query${NC}  ${CYAN}/jimmer-migration${NC}  ${CYAN}/jimmer-debug${NC}"
if [ "$INSTALL_MCP" = true ]; then
    echo -e "  MCP:     ${CYAN}jimmer_github_search${NC}  ${CYAN}jimmer_docs_search${NC}"
fi
echo ""
