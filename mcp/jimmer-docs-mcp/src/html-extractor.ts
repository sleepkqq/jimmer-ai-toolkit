import { parse, HTMLElement } from "node-html-parser";

const DOCS_BASE = "https://babyfish-ct.github.io";
const MAX_CHARS = 4000;
const CACHE_TTL = 60 * 60 * 1000; // 1 hour
const CACHE_MAX = 50;

interface CacheEntry {
	content: string;
	timestamp: number;
}

const cache = new Map<string, CacheEntry>();

function evictStale() {
	const now = Date.now();
	for (const [key, entry] of cache) {
		if (now - entry.timestamp > CACHE_TTL) {
			cache.delete(key);
		}
	}
	// LRU-style: remove oldest if over limit
	if (cache.size > CACHE_MAX) {
		const oldest = [...cache.entries()].sort((a, b) => a[1].timestamp - b[1].timestamp);
		for (let i = 0; i < cache.size - CACHE_MAX; i++) {
			cache.delete(oldest[i][0]);
		}
	}
}

export async function fetchPageContent(urlPath: string): Promise<string> {
	const fullUrl = DOCS_BASE + urlPath;

	// Check cache
	const cached = cache.get(urlPath);
	if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
		return cached.content;
	}

	try {
		const response = await fetch(fullUrl, {
			signal: AbortSignal.timeout(10000),
		});
		if (!response.ok) {
			return `(Failed to fetch: ${response.status})`;
		}

		const html = await response.text();
		const content = extractContent(html);

		// Cache the result
		evictStale();
		cache.set(urlPath, { content, timestamp: Date.now() });

		return content;
	} catch (error: any) {
		return `(Error fetching page: ${error.message})`;
	}
}

function extractContent(html: string): string {
	const root = parse(html);

	// Find main content container
	let container = root.querySelector("article") ||
		root.querySelector(".theme-doc-markdown") ||
		root.querySelector("[class*='docMainContainer']") ||
		root.querySelector("main");

	if (!container) {
		// Fallback: try to get any meaningful content
		container = root.querySelector("body") || root;
	}

	// Remove noise elements
	const removeSelectors = [
		"nav", ".pagination-nav", ".table-of-contents", "aside",
		"script", "style", ".theme-doc-toc-mobile", ".theme-doc-breadcrumbs",
		"footer", "header",
	];
	for (const sel of removeSelectors) {
		for (const el of container.querySelectorAll(sel)) {
			el.remove();
		}
	}

	const lines: string[] = [];
	processNode(container, lines);

	// Strip any remaining HTML tags and decode entities
	const result = lines.join("\n")
		.replace(/<[^>]+>/g, "")
		.replace(/&#x27;/g, "'").replace(/&#39;/g, "'")
		.replace(/&lt;/g, "<").replace(/&gt;/g, ">")
		.replace(/&amp;/g, "&").replace(/&quot;/g, '"')
		.replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code)))
		.replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCharCode(parseInt(code, 16)))
		.replace(/\n{3,}/g, "\n\n")
		.trim();

	// Truncate at a reasonable boundary
	if (result.length <= MAX_CHARS) return result;

	const truncated = result.substring(0, MAX_CHARS);
	const lastNewline = truncated.lastIndexOf("\n");
	return (lastNewline > MAX_CHARS * 0.7 ? truncated.substring(0, lastNewline) : truncated) + "\n\n...(truncated)";
}

function processNode(node: HTMLElement, lines: string[]) {
	for (const child of node.childNodes) {
		if (child.nodeType === 3) {
			// Text node
			const text = child.text.trim();
			if (text) lines.push(text);
			continue;
		}

		if (!(child instanceof HTMLElement)) continue;

		const tag = child.tagName?.toLowerCase();

		if (!tag) {
			processNode(child, lines);
			continue;
		}

		// Headings
		if (/^h[1-6]$/.test(tag)) {
			const level = parseInt(tag[1]);
			const prefix = "#".repeat(Math.min(level, 4));
			lines.push("", `${prefix} ${child.text.trim()}`, "");
			continue;
		}

		// Code blocks
		if (tag === "pre") {
			const codeEl = child.querySelector("code");
			// Strip all HTML tags inside code to get pure text
			const rawHtml = codeEl ? codeEl.innerHTML : child.innerHTML;
			const codeText = rawHtml
				.replace(/<br\s*\/?>/gi, "\n")
				.replace(/<[^>]+>/g, "")
				.replace(/&lt;/g, "<").replace(/&gt;/g, ">")
				.replace(/&amp;/g, "&").replace(/&quot;/g, '"')
				.trim();
			const lang = codeEl?.getAttribute("class")?.match(/language-(\w+)/)?.[1] || "";
			if (codeText) {
				lines.push("", "```" + lang, codeText, "```", "");
			}
			continue;
		}

		// Skip code elements already handled inside pre
		if (tag === "code" && child.parentNode instanceof HTMLElement && child.parentNode.tagName?.toLowerCase() === "pre") {
			continue;
		}

		// Inline code — keep inline
		if (tag === "code") {
			lines.push("`" + child.text.trim() + "`");
			continue;
		}

		// Lists
		if (tag === "li") {
			lines.push("- " + child.text.trim());
			continue;
		}

		// Paragraphs
		if (tag === "p") {
			lines.push("", child.text.trim(), "");
			continue;
		}

		// Tables — simplified text extraction
		if (tag === "table") {
			const rows = child.querySelectorAll("tr");
			for (const row of rows) {
				const cells = row.querySelectorAll("th, td").map(c => c.text.trim());
				lines.push("| " + cells.join(" | ") + " |");
			}
			lines.push("");
			continue;
		}

		// Tab panels (Docusaurus Java/Kotlin tabs)
		if (tag === "div" && child.getAttribute("role") === "tabpanel") {
			const label = child.getAttribute("aria-labelledby") || "";
			if (label) lines.push(`**[${label}]**`);
			processNode(child, lines);
			continue;
		}

		// Recurse for other elements
		processNode(child, lines);
	}
}
