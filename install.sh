#!/bin/bash
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="opencode"
USE_SYMLINK=false
INSTALL_MCP=false
TARGET_PROJECT=""

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
    echo "Installs Jimmer skills. Safe to run repeatedly."
    echo ""
    echo "Options:"
    echo -e "  ${CYAN}--tool${NC} opencode|claude|qwen|gigacode       Target CLI tool (default: opencode)"
    echo -e "  ${CYAN}--symlink${NC}                                Use symlinks instead of copies"
    echo -e "  ${CYAN}--mcp${NC}                                    Install MCP server config"
    echo ""
    echo "Examples:"
    echo -e "  ${DIM}./install.sh /path/to/project${NC}"
    echo -e "  ${DIM}./install.sh --mcp /path/to/project${NC}"
    echo -e "  ${DIM}./install.sh --tool claude /path/to/project${NC}"
    echo -e "  ${DIM}./install.sh --tool gigacode /path/to/project${NC}"
}

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

if [[ "$TOOL" != "opencode" && "$TOOL" != "claude" && "$TOOL" != "qwen" && "$TOOL" != "gigacode" ]]; then
    echo -e "${RED}Error:${NC} --tool must be 'opencode', 'claude', 'qwen', or 'gigacode'"
    exit 1
fi

case "$TOOL" in
    opencode)
        CONFIG_DIR=".opencode"
        ;;
    claude)
        CONFIG_DIR=".claude"
        ;;
    qwen)
        CONFIG_DIR=".qwen"
        ;;
    gigacode)
        CONFIG_DIR=".gigacode"
        ;;
esac

SKILLS_DIR="$CONFIG_DIR/skills"
mkdir -p "$TARGET_PROJECT/$SKILLS_DIR"

echo -e "\n${BOLD}Jimmer AI Toolkit${NC} ${DIM}→${NC} ${CYAN}$TOOL${NC} ${DIM}→${NC} $TARGET_PROJECT/$SKILLS_DIR/"

INSTALLED=0
SKIPPED=0
UPDATED=0

install_path() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [ -e "$dst" ]; then
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
            log_skip "already linked: $label"
            SKIPPED=$((SKIPPED + 1))
            return
        fi
        if [ -d "$src" ] && [ -d "$dst" ] && diff -qr "$src" "$dst" >/dev/null 2>&1; then
            log_skip "identical: $label"
            SKIPPED=$((SKIPPED + 1))
            return
        fi
        rm -rf "$dst"
        if [ "$USE_SYMLINK" = true ]; then
            ln -s "$src" "$dst"
            log_update "updated (symlink): $label"
        else
            mkdir -p "$(dirname "$dst")"
            cp -R "$src" "$dst"
            log_update "updated: $label"
        fi
        UPDATED=$((UPDATED + 1))
    else
        if [ "$USE_SYMLINK" = true ]; then
            ln -s "$src" "$dst"
            log_install "linked: $label"
        else
            mkdir -p "$(dirname "$dst")"
            cp -R "$src" "$dst"
            log_install "copied: $label"
        fi
        INSTALLED=$((INSTALLED + 1))
    fi
}

log_header "Skills"
SKILL_COUNT=0
for dir in "$TOOLKIT_DIR"/skills/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    install_path "$dir" "$TARGET_PROJECT/$SKILLS_DIR/$name" "$name"
    SKILL_COUNT=$((SKILL_COUNT + 1))
done

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

        if [ "$TOOL" = "claude" ] || [ "$TOOL" = "opencode" ]; then
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

echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}Done!${NC}  ${GREEN}+$INSTALLED installed${NC}  ${YELLOW}~$UPDATED updated${NC}  ${DIM}-$SKIPPED skipped${NC}"
echo ""
echo -e "  Skills:  ${CYAN}$SKILL_COUNT installed${NC} into ${CYAN}$SKILLS_DIR${NC}"
echo -e "  Tasks:   ${CYAN}jimmer-entity${NC} ${CYAN}jimmer-dto${NC} ${CYAN}jimmer-query${NC} ${CYAN}jimmer-migrations${NC} ${CYAN}jimmer-debug${NC}"
if [ "$INSTALL_MCP" = true ]; then
    echo -e "  MCP:     ${CYAN}jimmer_github_search${NC}  ${CYAN}jimmer_docs_search${NC}"
fi
echo ""
echo -e "Ask your agent naturally. Skills load on demand from frontmatter triggers."
