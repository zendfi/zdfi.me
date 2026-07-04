/**
 * Vercel Edge Function — per-user metadata injection for zdfi.me.
 *
 * When a crawler or social bot visits zdfi.me/@tnxl or zdfi.me/tnxl,
 * this function fetches the user's public data from the Zend! API and
 * injects personalised <head> tags into index.html before returning it.
 *
 * Human visitors get the same response — Flutter boots normally from
 * the injected HTML. The metadata is invisible to Flutter but visible to
 * search engines, social previews (WhatsApp, iMessage, Twitter, Telegram),
 * and Google's indexer.
 *
 * Route pattern: covers /:zendtag and /:zendtag/:requestId
 */

const API_BASE = 'https://api-v2.zendfi.tech';
const SITE_BASE = 'https://zdfi.me';

// Bots that need SSR metadata injection.
// We don't restrict to bots only — everyone gets the same HTML,
// so there's no cloaking risk and no maintenance burden.
const BOT_PATTERNS = [
  'googlebot', 'bingbot', 'slurp', 'duckduckbot',
  'facebookexternalhit', 'twitterbot', 'linkedinbot',
  'whatsapp', 'telegram', 'slackbot', 'discordbot',
  'applebot', 'ia_archiver',
];

function isBot(userAgent) {
  if (!userAgent) return false;
  const ua = userAgent.toLowerCase();
  return BOT_PATTERNS.some(b => ua.includes(b));
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Build the full <head> block for a user profile page.
 *
 * Targets "Pay {name}" and "Pay @{tag}" queries by:
 * - Setting <title> to "Pay {displayName} (@{zendtag}) on Zend!"
 * - Writing <meta name="description"> that contains both the full name
 *   and the @handle in pay-intent phrasing
 * - Injecting schema.org Person structured data so Google understands
 *   this is a real person's payment page
 * - Setting og:title / og:description / twitter:* for social cards
 * - Canonical URL to zdfi.me/@{zendtag}
 */
function buildHeadTags({ zendtag, displayName, bio, avatarUrl, amountUsdc, description, requestId }) {
  const name = escapeHtml(displayName || zendtag);
  const tag = escapeHtml(zendtag);
  const safeAvatarUrl = avatarUrl ? escapeHtml(avatarUrl) : '';
  const canonicalUrl = `${SITE_BASE}/${tag}`;
  const pageUrl = requestId ? `${SITE_BASE}/${tag}/${requestId}` : canonicalUrl;

  // Title and description vary between profile and request pages
  const title = requestId && amountUsdc
    ? `Pay ${name} $${amountUsdc.toFixed(2)} on Zend!`
    : `Pay ${name} (@${tag}) on Zend!`;

  const descriptionText = requestId && description
    ? `${description} — Send money to @${tag} on Zend!, the fastest way to pay globally.`
    : bio
      ? `${escapeHtml(bio)} — Pay @${tag} on Zend! Send money instantly, no bank needed.`
      : `Send money to ${name} (@${tag}) on Zend! Pay with your local currency — NGN, GBP, EUR, USD. No app required.`;

  // Schema.org Person + PayAction structured data
  // This is the key signal for "Pay {name}" queries.
  const schema = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Person",
        "@id": canonicalUrl,
        "name": displayName || zendtag,
        "alternateName": `@${zendtag}`,
        "url": canonicalUrl,
        ...(avatarUrl ? { "image": avatarUrl } : {}),
        ...(bio ? { "description": bio } : {}),
      },
      {
        "@type": "WebPage",
        "url": pageUrl,
        "name": title,
        "description": descriptionText,
        "isPartOf": { "@type": "WebSite", "url": SITE_BASE, "name": "Zend!" },
        "potentialAction": {
          "@type": "PayAction",
          "target": pageUrl,
          "recipient": {
            "@type": "Person",
            "name": displayName || zendtag,
            "url": canonicalUrl,
          },
        },
      },
    ],
  };

  return `
  <!-- Injected by Vercel Edge Function: zdfi.me/api/meta.js -->
  <title>${title}</title>
  <meta name="description" content="${descriptionText}">
  <link rel="canonical" href="${canonicalUrl}">

  <!-- Open Graph (Facebook, WhatsApp, Telegram, iMessage) -->
  <meta property="og:type" content="profile">
  <meta property="og:url" content="${pageUrl}">
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${descriptionText}">
  <meta property="og:site_name" content="Zend!">
  ${safeAvatarUrl ? `<meta property="og:image" content="${safeAvatarUrl}">
  <meta property="og:image:alt" content="${name} on Zend!">` : `<meta property="og:image" content="${SITE_BASE}/icons/og-default.png">`}

  <!-- Twitter Card -->
  <meta name="twitter:card" content="${safeAvatarUrl ? 'summary_large_image' : 'summary'}">
  <meta name="twitter:title" content="${title}">
  <meta name="twitter:description" content="${descriptionText}">
  ${safeAvatarUrl ? `<meta name="twitter:image" content="${safeAvatarUrl}">` : ''}

  <!-- Profile meta -->
  <meta property="profile:username" content="${tag}">

  <!-- Schema.org structured data -->
  <script type="application/ld+json">${JSON.stringify(schema)}</script>
  `;
}

export const config = {
  runtime: 'edge',
};

export default async function handler(request) {
  const url = new URL(request.url);
  const pathname = url.pathname;

  // ── Sitemap ──────────────────────────────────────────────────────────────
  // Handle /sitemap.xml inline — no separate edge function needed.
  if (pathname === '/sitemap.xml' || pathname === '/sitemap.xml/') {
    return handleSitemap(url);
  }

  // Strip leading slash and split
  const segments = pathname.replace(/^\//, '').split('/').filter(Boolean);

  // Must be 1 or 2 segments (zendtag or zendtag/requestId)
  if (segments.length === 0 || segments.length > 2) {
    // Let Vercel serve index.html normally
    return;
  }

  const rawZendtag = segments[0].replace(/^@/, '').toLowerCase();
  const requestId = segments[1] || null;

  // Basic zendtag sanity check (alphanumeric + underscore, 2-20 chars)
  if (!/^[a-z0-9_]{2,20}$/.test(rawZendtag)) {
    return;
  }

  // Fetch the static index.html directly from Vercel's CDN origin
  // Using an absolute path avoids re-triggering the /(.*) rewrite rule.
  const indexUrl = `${url.protocol}//${url.host}/index.html`;
  const indexResponse = await fetch(indexUrl, {
    headers: { 'Accept': 'text/html' },
  });

  if (!indexResponse.ok) {
    return indexResponse;
  }

  let html = await indexResponse.text();

  // Fetch user data from the Zend! API
  let headTags = '';
  try {
    const apiUrl = requestId
      ? `${API_BASE}/api/v1/public/zend/${rawZendtag}/${requestId}`
      : `${API_BASE}/api/v1/public/zend/${rawZendtag}`;

    // Fetch user data and customisation in parallel
    const [dataResp, custResp] = await Promise.all([
      fetch(apiUrl, { headers: { 'Accept': 'application/json' } }),
      fetch(`${API_BASE}/api/v1/public/zend/${rawZendtag}/customisation`, {
        headers: { 'Accept': 'application/json' },
      }),
    ]);

    let displayName = rawZendtag;
    let bio = null;
    let avatarUrl = null;
    let amountUsdc = null;
    let description = null;

    if (dataResp.ok) {
      const data = await dataResp.json();

      if (requestId) {
        // Request page: { request: { amount_usdc, description }, user: { display_name } }
        const user = data.user || {};
        displayName = user.display_name || rawZendtag;
        amountUsdc = data.request?.amount_usdc ?? null;
        description = data.request?.description ?? null;
      } else {
        // Profile page: { user: { display_name, avatar_url } }
        const user = data.user || {};
        displayName = user.display_name || rawZendtag;
        avatarUrl = user.avatar_url || null;
      }
    }

    // Customisation may override display name and provide bio/avatar
    if (custResp.ok) {
      const cust = await custResp.json();
      if (cust.display_name_override) displayName = cust.display_name_override;
      if (cust.bio) bio = cust.bio;
      if (cust.avatar_url && !avatarUrl) avatarUrl = cust.avatar_url;
    }

    headTags = buildHeadTags({
      zendtag: rawZendtag,
      displayName,
      bio,
      avatarUrl,
      amountUsdc,
      description,
      requestId,
    });
  } catch (err) {
    // API error — fall back to generic metadata rather than breaking the page
    headTags = `
  <title>Pay @${escapeHtml(rawZendtag)} on Zend!</title>
  <meta name="description" content="Send money to @${escapeHtml(rawZendtag)} on Zend! Pay instantly with your local currency.">
  <link rel="canonical" href="${SITE_BASE}/${escapeHtml(rawZendtag)}">
    `;
  }

  // Inject before the closing </head> tag
  // Replace the existing generic title/meta to avoid duplicates
  html = html
    .replace(/<title>Zend!<\/title>/, '')
    .replace(/<meta name="title"[^>]*>/, '')
    .replace(/<meta name="description"[^>]*>/, '')
    .replace(/<meta property="og:type"[^>]*>/, '')
    .replace(/<meta property="og:title"[^>]*>/, '')
    .replace(/<meta property="og:description"[^>]*>/, '')
    .replace(/<meta property="twitter:card"[^>]*>/, '')
    .replace(/<meta property="twitter:title"[^>]*>/, '')
    .replace(/<meta property="twitter:description"[^>]*>/, '')
    .replace('</head>', `${headTags}\n</head>`);

  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      // Cache user pages for 60s on CDN edge — short enough to pick up
      // profile changes quickly, long enough to reduce API load.
      'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300',
      // Preserve security headers
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Referrer-Policy': 'strict-origin-when-cross-origin',
    },
  });
}

// ── Sitemap handler ───────────────────────────────────────────────────────────

async function handleSitemap(url) {
  const SITE_BASE_LOCAL = 'https://zdfi.me';
  const API_BASE_LOCAL = 'https://api-v2.zendfi.tech';

  let userZendtags = [];
  try {
    const resp = await fetch(`${API_BASE_LOCAL}/api/v1/public/sitemap/users`, {
      headers: { 'Accept': 'application/json' },
      signal: AbortSignal.timeout(8000),
    });
    if (resp.ok) {
      const data = await resp.json();
      userZendtags = data.users || [];
    }
  } catch (_) {
    // Backend unavailable — return minimal sitemap rather than failing
  }

  const today = new Date().toISOString().split('T')[0];

  const urlEntries = [
    `  <url>
    <loc>${SITE_BASE_LOCAL}/</loc>
    <lastmod>${today}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>`,
    ...userZendtags.map(({ zendtag, updated_at }) => {
      const lastmod = updated_at ? updated_at.split('T')[0] : today;
      return `  <url>
    <loc>${SITE_BASE_LOCAL}/${encodeURIComponent(zendtag)}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.6</priority>
  </url>`;
    }),
  ].join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urlEntries}
</urlset>`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
