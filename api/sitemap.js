/**
 * Vercel Edge Function — dynamic sitemap for zdfi.me.
 *
 * Serves GET /sitemap.xml
 *
 * Fetches all active user zendtags from the Zend! API and generates a
 * compliant XML sitemap. Google uses this to discover and crawl all user
 * payment pages.
 *
 * Sitemap spec: https://www.sitemaps.org/protocol.html
 * Includes:
 *  - Root page (zdfi.me/)
 *  - All active user pages (zdfi.me/{zendtag})
 *
 * Cache: CDN edge cache for 1 hour (new users appear within an hour without
 * needing a manual submit, as long as the sitemap ping runs on registration).
 */

const API_BASE = 'https://api-v2.zendfi.tech';
const SITE_BASE = 'https://zdfi.me';
const SITEMAP_CACHE_SECONDS = 3600; // 1 hour

export const config = {
  runtime: 'edge',
};

export default async function handler(request) {
  // Only serve on /sitemap.xml — defensive guard
  const url = new URL(request.url);
  if (!url.pathname.endsWith('/sitemap.xml') && url.pathname !== '/sitemap.xml') {
    return new Response('Not found', { status: 404 });
  }

  let userZendtags = [];

  try {
    // Fetch the public list of active user zendtags from the backend.
    // This endpoint is lightweight — just zendtags + updated_at.
    const resp = await fetch(`${API_BASE}/api/v1/public/sitemap/users`, {
      headers: { 'Accept': 'application/json' },
      // 10s timeout so the sitemap never hangs on a slow backend
      signal: AbortSignal.timeout(10_000),
    });

    if (resp.ok) {
      const data = await resp.json();
      userZendtags = data.users || [];
    }
  } catch (err) {
    // If the backend is unavailable, return a minimal sitemap with just the root.
    // This is better than a 500 — Google won't penalise a temporarily empty sitemap.
    console.error('Sitemap: failed to fetch user list:', err);
  }

  // Build the XML
  const now = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

  const urlEntries = [
    // Root page
    `  <url>
    <loc>${SITE_BASE}/</loc>
    <lastmod>${now}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>`,

    // User pages
    ...userZendtags.map(({ zendtag, updated_at }) => {
      const lastmod = updated_at
        ? updated_at.split('T')[0]
        : now;
      return `  <url>
    <loc>${SITE_BASE}/${encodeURIComponent(zendtag)}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.6</priority>
  </url>`;
    }),
  ].join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
          http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
${urlEntries}
</urlset>`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      // Cache on CDN edge for 1 hour, serve stale for up to 24h while revalidating
      'Cache-Control': `public, s-maxage=${SITEMAP_CACHE_SECONDS}, stale-while-revalidate=86400`,
    },
  });
}
