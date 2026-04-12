import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Octokit } from "@octokit/rest";
import { searchDocs } from "./docs-index.js";
import { fetchPageContent } from "./html-extractor.js";

const JIMMER_REPO = { owner: "babyfish-ct", repo: "jimmer" };
const JIMMER_DOCS_BASE = "https://babyfish-ct.github.io/jimmer-doc";

const octokit = new Octokit({
	auth: process.env.GITHUB_TOKEN,
});

const server = new McpServer({
	name: "jimmer-docs-mcp",
	version: "1.0.0",
});

// Tool 1: Search Jimmer GitHub issues and discussions
server.tool(
	"jimmer_github_search",
	{
		query: z.string().describe("Search query for Jimmer issues/discussions"),
		type: z
			.enum(["issues", "discussions", "all"])
			.default("all")
			.describe("Type of GitHub content to search"),
		state: z
			.enum(["open", "closed", "all"])
			.default("all")
			.describe("Issue state filter"),
		limit: z
			.number()
			.min(1)
			.max(20)
			.default(5)
			.describe("Maximum results to return"),
	},
	async ({ query, type, state, limit }) => {
		const results: string[] = [];

		try {
			if (type === "issues" || type === "all") {
				const stateFilter =
					state === "all" ? "" : `state:${state}`;
				const searchQuery = `${query} repo:${JIMMER_REPO.owner}/${JIMMER_REPO.repo} is:issue ${stateFilter}`.trim();

				const issueResults = await octokit.rest.search.issuesAndPullRequests(
					{
						q: searchQuery,
						per_page: limit,
						sort: "updated",
					}
				);

				for (const item of issueResults.data.items) {
					if (item.pull_request) continue; // skip PRs

					const labels = item.labels
						.map((l) => (typeof l === "string" ? l : l.name))
						.filter(Boolean)
						.join(", ");

					const bodyExcerpt = item.body
						? item.body.substring(0, 500).replace(/\n/g, " ")
						: "(no description)";

					results.push(
						[
							`## Issue #${item.number}: ${item.title}`,
							`**State:** ${item.state} | **Labels:** ${labels || "none"}`,
							`**URL:** ${item.html_url}`,
							`**Excerpt:** ${bodyExcerpt}`,
							"",
						].join("\n")
					);
				}
			}

			if (type === "discussions" || type === "all") {
				// GitHub discussions search via GraphQL
				try {
					const graphqlQuery = `
						query($searchQuery: String!) {
							search(query: $searchQuery, type: DISCUSSION, first: ${limit}) {
								nodes {
									... on Discussion {
										number
										title
										url
										body
										answer {
											body
										}
										labels(first: 5) {
											nodes {
												name
											}
										}
									}
								}
							}
						}
					`;

					const response: any = await octokit.graphql(graphqlQuery, {
						searchQuery: `${query} repo:${JIMMER_REPO.owner}/${JIMMER_REPO.repo}`,
					});

					for (const node of response.search.nodes) {
						if (!node.title) continue;

						const labels = node.labels?.nodes
							?.map((l: any) => l.name)
							.join(", ");
						const bodyExcerpt = node.body
							? node.body.substring(0, 300).replace(/\n/g, " ")
							: "(no description)";
						const answerExcerpt = node.answer?.body
							? `\n**Answer:** ${node.answer.body.substring(0, 500).replace(/\n/g, " ")}`
							: "";

						results.push(
							[
								`## Discussion #${node.number}: ${node.title}`,
								`**Labels:** ${labels || "none"}`,
								`**URL:** ${node.url}`,
								`**Excerpt:** ${bodyExcerpt}`,
								answerExcerpt,
								"",
							].join("\n")
						);
					}
				} catch (gqlError: any) {
					results.push(
						`## Discussions search failed\n**Error:** ${gqlError.message || "Unknown GraphQL error"}. Ensure your GITHUB_TOKEN has \`read:discussion\` scope.\n`
					);
				}
			}

			if (results.length === 0) {
				return {
					content: [
						{
							type: "text" as const,
							text: `No results found for "${query}" in Jimmer GitHub repository.`,
						},
					],
				};
			}

			return {
				content: [
					{
						type: "text" as const,
						text: `# Jimmer GitHub Search Results for "${query}"\n\n${results.join("\n---\n\n")}`,
					},
				],
			};
		} catch (error: any) {
			return {
				content: [
					{
						type: "text" as const,
						text: `Error searching GitHub: ${error.message}. Make sure GITHUB_TOKEN is set.`,
					},
				],
			};
		}
	}
);

// Tool 2: Search Jimmer documentation (fetches real content)
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
