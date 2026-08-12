#!/usr/bin/env bash
# Vercel build: fetch the compiled engines, then build the frontend.
#
# The engines are ~95 MB native linux/amd64 binaries. Vercel's Python runtime
# can *run* one (500 MB uncompressed per function) but cannot compile Lean, so
# they are built by the engine-binaries workflow on a native x86_64 runner and
# published as the `engine-latest` prerelease. This script pulls them in.
#
# Fail loudly. A deployment whose frontend built but whose engine is missing
# would come up looking fine and answer nothing — the single worst outcome for
# a project whose entire claim is that it actually runs the law.

set -euo pipefail

REPO="${ENGINE_REPO:-sharique2004/AlixHack}"
TAG="${ENGINE_TAG:-engine-latest}"
BASE="https://github.com/${REPO}/releases/download/${TAG}"

echo "==> fetching engines from ${REPO}@${TAG}"
mkdir -p bin
for engine in probate-api settlement-api; do
  curl -fsSL --retry 3 --retry-delay 2 -o "bin/${engine}" "${BASE}/${engine}"
  chmod +x "bin/${engine}"
  size=$(wc -c < "bin/${engine}")
  if [ "${size}" -lt 1000000 ]; then
    echo "ERROR: bin/${engine} is only ${size} bytes — that is not the engine." >&2
    echo "       Has the engine-binaries workflow run and published ${TAG}?" >&2
    exit 1
  fi
  echo "    bin/${engine}  $(( size / 1024 / 1024 )) MB"
done

# Prove the engine answers before we ship a frontend that depends on it.
echo "==> smoke-testing the settlement engine"
probe='{"as_of_date":{"year":2026,"month":8,"day":12}}'
if ! out=$(printf '%s' "${probe}" | ./bin/settlement-api 2>&1); then
  echo "ERROR: settlement-api did not run on this platform:" >&2
  echo "${out}" >&2
  exit 1
fi
case "${out}" in
  *jurisdictions*|*error*) echo "    engine responded with contract-shaped JSON" ;;
  *) echo "ERROR: unexpected engine output: ${out:0:200}" >&2; exit 1 ;;
esac

echo "==> building the frontend"
cd demo/frontend
npm ci
# No VITE_API_BASE: the API is served from this same deployment under /api.
npm run build

echo "==> done"
