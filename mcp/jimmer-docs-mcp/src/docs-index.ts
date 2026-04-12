const SEARCH_INDEX_URL = "https://babyfish-ct.github.io/jimmer-doc/search-index.json";

export interface DocEntry {
	i: number;
	t: string;   // title
	u: string;   // URL path like "/jimmer-doc/docs/cache/"
	b: string[]; // breadcrumbs
}

let cachedDocs: DocEntry[] | null = null;
let loadingPromise: Promise<DocEntry[]> | null = null;

async function loadDocs(): Promise<DocEntry[]> {
	if (cachedDocs) return cachedDocs;
	if (loadingPromise) return loadingPromise;

	loadingPromise = (async () => {
		const response = await fetch(SEARCH_INDEX_URL, {
			signal: AbortSignal.timeout(15000),
		});
		const json = await response.json() as any;

		// search-index.json is an array of {documents, index} objects — merge all documents
		const docs: DocEntry[] = [];
		if (Array.isArray(json)) {
			for (const chunk of json) {
				if (chunk?.documents && Array.isArray(chunk.documents)) {
					docs.push(...chunk.documents);
				}
			}
		}
		cachedDocs = docs;
		loadingPromise = null;
		return docs;
	})();

	return loadingPromise;
}

export async function searchDocs(query: string, limit: number = 3): Promise<DocEntry[]> {
	const docs = await loadDocs();
	const tokens = query.toLowerCase().split(/\s+/).filter(t => t.length > 1);

	if (tokens.length === 0) return docs.slice(0, limit);

	const scored = docs.map(doc => {
		const title = (doc.t || "").toLowerCase();
		const breadcrumbs = (doc.b || []).join(" ").toLowerCase();
		const url = (doc.u || "").toLowerCase();
		let score = 0;

		for (const token of tokens) {
			// Title matches (highest weight)
			if (title.includes(token)) score += 3;
			if (title === token || title.startsWith(token + " ") || title.endsWith(" " + token)) score += 2; // exact word bonus

			// Breadcrumb matches
			if (breadcrumbs.includes(token)) score += 2;

			// URL matches
			if (url.includes(token)) score += 1;
		}

		// Bonus for exact query match in title
		if (title.includes(query.toLowerCase())) score += 5;

		return { doc, score };
	});

	return scored
		.filter(s => s.score > 0)
		.sort((a, b) => b.score - a.score)
		.slice(0, limit)
		.map(s => s.doc);
}
