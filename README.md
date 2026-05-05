# ZendPay — Consumer Payment Pages

Flutter Web project serving `zdfi.me/@{zendtag}` payment pages.

## Build

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api-v2.zendfi.tech
```

Output is in `build/web/`.

## Deploy to Vercel

```bash
# Install Vercel CLI if needed
npm i -g vercel

# From the zdfi.me/ directory
cd zdfi.me
flutter build web --release --dart-define=API_BASE_URL=https://api-v2.zendfi.tech
cd build/web
vercel --prod
```

Set the custom domain to `zdfi.me` in the Vercel dashboard.

## Deploy to Netlify

```bash
cd zdfi.me
flutter build web --release --dart-define=API_BASE_URL=https://api-v2.zendfi.tech
netlify deploy --prod --dir=build/web
```

## DNS setup for zdfi.me

After deploying, point `zdfi.me` to your hosting provider:

**Vercel:**
- Add `A` record: `76.76.21.21`
- Add `AAAA` record: `2606:4700:3108::ac42:2a0a` (or use Vercel's nameservers)

**Netlify:**
- Add `A` record: `75.2.60.5`
- Or use Netlify DNS nameservers for automatic SSL

## URL routing

The app handles:
- `/@{zendtag}` → PWYW payment page
- `/@{zendtag}/{request_id}` → Fixed-amount payment request

All other paths fall through to `index.html` (SPA routing via `vercel.json` / `netlify.toml`).

## Environment variables

| Variable | Description |
|---|---|
| `API_BASE_URL` | Backend API base URL (default: `https://api-v2.zendfi.tech`) |
