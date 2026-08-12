# Deploying Atlas to atlas.shariquekhatri.com

Everything on Vercel: the frontend as static output, the API and the Lean
engines as a Python function on the same deployment. One origin, one domain,
no CORS.

## Status — what is already done

| | |
|---|---|
| Work committed and pushed to `sharique2004/AlixHack` | ✅ 6 commits |
| Lean CI green on x86_64 | ✅ |
| Engines built for **linux/amd64** and published | ✅ `engine-latest` prerelease, 75 MB each (stripped) |
| Engine verified to run on linux/amd64 | ✅ 2026-06-30 → `OTHER_FORM_REQUIRED`, 2026-07-01 → `ELIGIBLE` |
| Shared-library check | ✅ needs only glibc (`libc`, `libpthread`, `libdl`, `librt`, `libm`) — no libgmp, no libuv |
| `vercel.json`, `api/index.py`, `deploy/vercel-build.sh` | ✅ pushed |
| **Vercel project connected** | ❌ needs your account |
| **DNS record** | ❌ needs your account |

## Why this works on Vercel

The engine is a ~75 MB native binary. Vercel's **Python** runtime allows 500 MB
uncompressed per function (5 GB with large functions), so it fits with room to
spare. It is the *Edge* runtime that cannot do this — not the Python one.

Vercel cannot *compile* Lean, so the binaries are built by the
`engine-binaries` workflow on a native x86_64 runner and published as a rolling
prerelease. `deploy/vercel-build.sh` downloads them at build time, refuses to
continue if they are missing or truncated, and smoke-tests the engine before
building the frontend — a deployment whose frontend built but whose engine did
not would look fine and answer nothing.

## 1. Revoke the leaked tokens

The Cloudflare and Vercel tokens pasted into chat are compromised. Revoke both:

- Vercel → Account Settings → Tokens
- Cloudflare → My Profile → API Tokens

Neither is needed below.

## 2. Connect the project (2 minutes)

Vercel dashboard → **Add New → Project** → import `sharique2004/AlixHack`.

Leave every build setting alone — `vercel.json` already sets the build command,
output directory, function memory, and routing. Then **Deploy**.

Optional environment variable, only if you want the `/evidence` page's live
Gemini comparison to work:

```
GEMINI_API_KEY = ...
```

Without it that one panel reports the key is missing; everything else,
including the whole Atlas product, is unaffected.

## 3. Point the domain

Vercel → the project → **Settings → Domains** → add `atlas.shariquekhatri.com`.
Vercel will show the record it wants.

`shariquekhatri.com` is already on Cloudflare (`dahlia`/`brodie.ns.cloudflare.com`),
so add that record in the Cloudflare dashboard → DNS. Set the proxy to **DNS
only** (grey cloud) so Vercel can issue the certificate; you can enable the
proxy afterwards if you want.

## 4. Verify before sending the link to anyone

```bash
curl -s https://atlas.shariquekhatri.com/api/health
#   expect "settlement_engine":"binary"
```

Then open the site and load the two Florida samples back to back:

- **died 2026-06-30** → `OTHER_FORM_REQUIRED` — estate exceeds $75,000
- **died 2026-07-01** → `ELIGIBLE` — under $150,000

Same estate, one day apart. If both show the same verdict, or the page reports
the engine unreachable, check the Vercel build log for the `fetching engines`
step.

## Known characteristics

- **Cold start.** The first request after idle stages a 75 MB binary into
  `/tmp`, so expect a second or two. Warm requests run the engine in ~20 ms.
  Worth mentioning to anyone you send the link to.
- **Updating the law.** Editing anything under `SimpleProbate/` re-runs the
  `engine-binaries` workflow on push, which rebuilds, re-checks the Florida
  banding, and republishes. Redeploy on Vercel to pick it up.

## Alternative: one container

`deploy/Dockerfile` builds a single image with the engines, the API, and the
frontend, verified working locally (health, SPA routing, the Florida pair, all
11 samples). Use it for Fly/Railway/Render if you ever want to leave Vercel.
Note it builds `linux/arm64` on Apple Silicon; use `fly deploy --remote-only`
so the x86 builder produces the right architecture.
