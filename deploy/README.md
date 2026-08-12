# Deploying Atlas to atlas.shariquekhatri.com

## Why it isn't live yet

Nothing has been deployed. `atlas.shariquekhatri.com` returns
`DNS_PROBE_POSSIBLE` because the DNS record does not exist.

Verified 2026-08-12:

```
shariquekhatri.com  NS   dahlia.ns.cloudflare.com, brodie.ns.cloudflare.com   ✅ on Cloudflare
shariquekhatri.com  A    216.198.79.1, 64.29.17.1                            (apex → Vercel)
atlas.shariquekhatri.com                                                      does not exist
```

The zone is already on Cloudflare, so this is one DNS record away — once
something is running to point it at.

## Why Cloudflare alone cannot host it

The engine is a **~95 MB native binary** (`settlement-api`; `probate-api` is
another 94 MB). Cloudflare Workers and Pages Functions cap at roughly 10 MB and
execute JS/WASM only. They cannot run it. Neither can Vercel's edge runtime,
Netlify Functions, or any static host. A static-only deploy would leave the app
showing labelled sample data with no live engine, which defeats the entire
point of the project.

So the engine needs a container host, and **one container serves everything** —
the API and the frontend from the same origin. One deploy, one DNS record, no
CORS, no build-time API URL.

## 0. Revoke the leaked token first

The Cloudflare token pasted into chat on 2026-08-12 is compromised. Cloudflare
dashboard → My Profile → API Tokens → delete it. You do not need a Cloudflare
API token for anything below; the one DNS record is a 30-second click in the
dashboard.

## 1. The image is built and verified

Already done on 2026-08-12 — `docker build -f deploy/Dockerfile -t atlas .`
produced an 899 MB image, and every check below was run against a live
container:

| check | result |
|---|---|
| `GET /api/health` | `lean_engine: "binary"`, `settlement_engine: "binary"` |
| `GET /` | 200 — frontend served from the same origin |
| `GET /evidence` | 200 — SPA deep link survives a hard refresh |
| `GET /api/nope` | `{"detail":"not found"}` — JSON, not the app shell |
| Florida pair through the container | 2026-06-30 → `OTHER_FORM_REQUIRED`; 2026-07-01 → `ELIGIBLE` |
| all 11 settlement samples | 10 assessments + 1 typed error envelope, no crashes |

The Lean stage discharges every `by decide` regression, so a broken legal rule
fails the image build rather than shipping.

To re-run it locally:

```bash
cd /Users/shariquekhatri/Alix/AlixHack
docker build -f deploy/Dockerfile -t atlas .    # ~12 min cold, seconds cached
docker run --rm -p 8080:8080 atlas              # → http://localhost:8080
```

### One thing that will bite you

That local image is **linux/arm64** (Apple Silicon). Fly.io machines are
**x86_64**, and an arm64 image will not boot there. Do **not** `docker push`
this one. `fly deploy` uses a remote x86 builder by default, which is exactly
what you want — let it build from the Dockerfile rather than shipping the local
image. (Building amd64 locally works via `--platform linux/amd64` but compiles
Lean under QEMU emulation and takes far longer.)

## 2. Deploy the container

Fly.io shown; Railway and Render are equivalent.

```bash
brew install flyctl
fly auth login
fly launch --dockerfile deploy/Dockerfile --name atlas-sk --no-deploy \
           --region sjc --vm-memory 1024
fly secrets set GEMINI_API_KEY=...      # only for the /evidence LLM panel
fly deploy --remote-only                # x86 builder — see the arm64 note above
```

Give it **≥1 GB RAM**: each request forks a ~95 MB binary. Note the hostname it
prints (`atlas-sk.fly.dev`).

```bash
fly certs add atlas.shariquekhatri.com
```

## 3. One DNS record

Cloudflare dashboard → `shariquekhatri.com` → DNS → Add record:

| Type | Name | Target | Proxy |
|---|---|---|---|
| CNAME | `atlas` | `atlas-sk.fly.dev` | **DNS only** (grey cloud) until the cert issues, then proxy if you want |

Fly's cert validation needs to see the origin, so leave it unproxied until
`fly certs show atlas.shariquekhatri.com` reports the certificate is issued.

## 4. Verify before you send anyone the link

```bash
curl -s https://atlas.shariquekhatri.com/api/health
```

Then open the site and load the two Florida samples back to back:

- **died 2026-06-30** → `OTHER_FORM_REQUIRED`, summary administration ruled out
- **died 2026-07-01** → `ELIGIBLE`, summary administration qualifies

If both show the same verdict, or the page reports the engine unreachable, the
container is not actually serving the engine — check `fly logs`.

## Cost

A shared-cpu-1x with 1 GB idles around $5/month. `fly scale count 1
--auto-stop` scales to zero when idle, at the price of a few seconds of cold
start on the first request — worth mentioning to anyone you send the link to.
