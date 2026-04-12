# Jimmer Docs MCP Server

MCP server providing Jimmer ORM documentation search and GitHub issues/discussions lookup.

## Tools

### `jimmer_github_search`
Search GitHub issues and discussions in the `babyfish-ct/jimmer` repository.

Parameters:
- `query` (required) — search query
- `type` — `issues`, `discussions`, or `all` (default: `all`)
- `state` — `open`, `closed`, or `all` (default: `all`)
- `limit` — max results, 1-20 (default: 5)

### `jimmer_docs_search`
Search Jimmer official documentation with contextual guidance.

Parameters:
- `query` (required) — search query
- `section` — `overview`, `query`, `mutation`, `cache`, `trigger`, `dto`, `spring`, or `all` (default: `all`)

## Setup

### 1. Install dependencies

```bash
cd mcp/jimmer-docs-mcp
npm install
npm run build
```

### 2. Set GitHub token (required for `jimmer_github_search`)

Create a token at https://github.com/settings/tokens with these scopes:
- **`public_repo`** — read access to public repositories (for issue/PR search)
- **`read:discussion`** — read access to discussions (for discussion search)

```bash
export GITHUB_TOKEN=ghp_your_token_here
```

### 3. Add to your project

Add to `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "jimmer-docs": {
      "type": "stdio",
      "command": "node",
      "args": ["/absolute/path/to/jimmer-ai-toolkit/mcp/jimmer-docs-mcp/dist/index.js"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

Or add via Claude Code CLI:

```bash
claude mcp add --transport stdio jimmer-docs -- \
  node /path/to/jimmer-ai-toolkit/mcp/jimmer-docs-mcp/dist/index.js
```

### 4. Verify

In Claude Code, try:
```
Search Jimmer GitHub for "NeitherIdNorKey" issues
```

## Development

```bash
npm run dev  # uses tsx for live TypeScript execution
```
