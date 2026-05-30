import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { searchDocs } from "./docs-index.js";
import { fetchPageContent } from "./html-extractor.js";

const JIMMER_DOCS_BASE = "https://babyfish-ct.github.io/jimmer-doc";

const server = new McpServer({
	name: "jimmer-docs-mcp",
	version: "1.0.0",
});

// Tool: Search Jimmer documentation (fetches real content)
server.tool(
	"jimmer_docs_search",
	{
		query: z.string().describe("Search query for Jimmer documentation (e.g., '@Formula', 'save command', 'cache invalidation')"),
		limit: z
			.number()
			.min(1)
			.max(5)
			.default(3)
			.describe("Maximum number of documentation pages to return"),
	},
	async ({ query, limit }) => {
		try {
			const rawResults = await searchDocs(query, limit * 2); // fetch extra to account for deduplication

			// Deduplicate by base URL (strip hash fragments)
			const seen = new Set<string>();
			const results = rawResults.filter(doc => {
				const baseUrl = doc.u.split("#")[0];
				if (seen.has(baseUrl)) return false;
				seen.add(baseUrl);
				return true;
			}).slice(0, limit);

			if (results.length === 0) {
				return {
					content: [
						{
							type: "text" as const,
							text: `No documentation pages found for "${query}". Try a different query or browse ${JIMMER_DOCS_BASE}`,
						},
					],
				};
			}

			// Fetch content for all matching pages in parallel
			const pages = await Promise.all(
				results.map(async (doc) => {
					const content = await fetchPageContent(doc.u);
					const fullUrl = JIMMER_DOCS_BASE + doc.u;
					const breadcrumb = doc.b?.length > 0 ? ` (${doc.b.join(" > ")})` : "";
					return [
						`## ${doc.t}${breadcrumb}`,
						`URL: ${fullUrl}`,
						"",
						content,
					].join("\n");
				})
			);

			const response = [
				`# Jimmer Documentation: "${query}"`,
				"",
				pages.join("\n\n---\n\n"),
			].join("\n");

			return {
				content: [
					{
						type: "text" as const,
						text: response,
					},
				],
			};
		} catch (error: any) {
			return {
				content: [
					{
						type: "text" as const,
						text: `Error searching documentation: ${error.message}`,
					},
				],
			};
		}
	}
);

// Start the server
async function main() {
	const transport = new StdioServerTransport();
	await server.connect(transport);
	console.error("Jimmer Docs MCP server running on stdio");
}

main().catch(console.error);
