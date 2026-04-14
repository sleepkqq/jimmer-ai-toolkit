# Jimmer Docs MCP Server

MCP server providing Jimmer ORM documentation search and GitHub issues/discussions lookup.

## Tools

### `jimmer_docs_search`
Search Jimmer official documentation with contextual guidance.

Parameters:
- `query` (required) — search query
- `section` — `overview`, `query`, `mutation`, `cache`, `trigger`, `dto`, `spring`, or `all` (default: `all`)

### `jimmer_github_search`
Search GitHub issues and discussions in the `babyfish-ct/jimmer` repository.

Parameters:
- `query` (required) — search query
- `type` — `issues`, `discussions`, or `all` (default: `all`)
- `state` — `open`, `closed`, or `all` (default: `all`)
- `limit` — max results, 1-20 (default: 5)

## Setup

### 1. Install dependencies and build

```bash
cd mcp/jimmer-docs-mcp
npm install
npm run bundle
```

This produces `dist/bundle.js` — a single self-contained file used by the installer.

### 2. Install into your project

```bash
./install.sh --mcp /path/to/project
```

This creates `.mcp.json` (Claude Code) or the equivalent settings file for Qwen/GigaCode.

### 3. Set GitHub token (required for `jimmer_github_search`)

Create a token at https://github.com/settings/tokens with scopes:
- **`public_repo`** — read access to public repositories
- **`read:discussion`** — read access to discussions

```bash
export GITHUB_TOKEN=ghp_your_token_here
```

### 4. Verify

In Claude Code, try:
```
Search Jimmer GitHub for "NeitherIdNorKey" issues
```

## Manual `.mcp.json` configuration

If you're not using the installer:

```json
{
  "mcpServers": {
    "jimmer-docs": {
      "type": "stdio",
      "command": "node",
      "args": ["/absolute/path/to/jimmer-ai-toolkit/mcp/jimmer-docs-mcp/dist/bundle.js"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

## Development

```bash
npm run dev   # live TypeScript execution via tsx
npm run build # tsc compile to dist/index.js
npm run bundle # single bundled file → dist/bundle.js (used in production)
```
