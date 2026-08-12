# Atlas — one container: compiled Lean engines, the FastAPI service, and the
# built frontend served from the same origin.
#
# One origin means one deploy, one DNS record, no CORS, and no build-time API
# URL to keep in sync. This exists as a container because the engine is a ~95 MB
# native executable: it cannot run on Cloudflare Workers/Pages Functions
# (≈10 MB, JS/WASM only), on Vercel's edge runtime, or on any static host.
#
#   docker build -f deploy/Dockerfile -t atlas .
#   docker run --rm -p 8080:8080 atlas     # → http://localhost:8080

# ---------- stage 1: compile the Lean engines ----------
FROM ubuntu:24.04 AS lean

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh \
      -o /tmp/elan-init.sh \
 && sh /tmp/elan-init.sh -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

WORKDIR /src
# lean-toolchain pins the compiler; copying it first keeps this layer cached.
COPY lean-toolchain lakefile.toml lake-manifest.json ./
RUN lake --version

# SimpleProbate.lean is the library ROOT module (it imports every submodule
# including FL/, Fed/ and Router/). Without it `lake build` fails with
# "Main.lean: bad import 'SimpleProbate'".
COPY SimpleProbate.lean ./
COPY SimpleProbate ./SimpleProbate
COPY Main.lean ApiMain.lean SettlementMain.lean ./

# `lake build` discharges every `by decide` regression in these modules, so a
# broken legal rule fails the image build rather than shipping.
RUN lake build && lake build probate-api && lake build settlement-api

# ---------- stage 2: build the frontend ----------
FROM node:22-slim AS web

WORKDIR /web
COPY demo/frontend/package.json demo/frontend/package-lock.json ./
RUN npm ci

COPY demo/frontend/ ./
# No VITE_API_BASE: same origin as the API, so relative /api paths are correct.
RUN npm run build

# ---------- stage 3: the service ----------
FROM python:3.12-slim AS app

RUN useradd --create-home --uid 10001 atlas

# The image mirrors the repo layout on purpose. main.py and the runners locate
# content/ and SimpleProbate/ by walking up from __file__, so /srv/demo/backend
# makes every one of those paths resolve exactly as it does in a checkout —
# no path branching for "in a container" anywhere in the source.
WORKDIR /srv/demo/backend

COPY demo/backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY demo/backend/app ./app
COPY demo/content /srv/demo/content
# /api/lean-source reads these at request time.
COPY SimpleProbate /srv/SimpleProbate
COPY ApiMain.lean /srv/ApiMain.lean

COPY --from=lean /src/.lake/build/bin/probate-api    /srv/bin/probate-api
COPY --from=lean /src/.lake/build/bin/settlement-api /srv/bin/settlement-api
COPY --from=web  /web/dist                           /srv/static

RUN chmod +x /srv/bin/* && chown -R atlas:atlas /srv
USER atlas

ENV LEAN_BIN_DIR=/srv/bin \
    STATIC_DIR=/srv/static \
    PYTHONUNBUFFERED=1 \
    PORT=8080

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/api/health',timeout=4).status==200 else 1)"

CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
