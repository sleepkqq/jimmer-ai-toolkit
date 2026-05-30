# Jimmer Docs MCP Server

MCP server providing Jimmer ORM documentation search.

## Tools

### `jimmer_docs_search`
Search Jimmer official documentation and fetch real page content.

Parameters:
- `query` (required) — search query (e.g. `@Formula`, `save command`, `cache invalidation`)
- `limit` — max documentation pages, 1-5 (default: 3)

## Setup

### 1. Install via the toolkit installer

```bash
./install.sh --tool claude --mcp
```

The installer builds the server (`npm install && npm run bundle`) and writes the
`.mcp.json` (Claude Code / opencode) or `settings.json` (Qwen / GigaCode) entry.

### 2. Verify

In Claude Code, try:
```
Search Jimmer docs for "save command"
```

## Manual `.mcp.json` configuration

If you're not using the installer, build first:

```bash
cd mcp/jimmer-docs-mcp
npm install
npm run bundle
```

Then add:

```json
{
  "mcpServers": {
    "jimmer-docs": {
      "type": "stdio",
      "command": "node",
      "args": ["/absolute/path/to/jimmer-ai-toolkit/mcp/jimmer-docs-mcp/dist/bundle.js"]
    }
  }
}
```

## Development

```bash
npm run dev    # live TypeScript execution via tsx
npm run build  # tsc compile to dist/index.js
npm run bundle # single bundled file → dist/bundle.js (used in production)
```
