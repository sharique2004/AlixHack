# Simple Transfer — LLM vs Compiled Law (demo app)

Same case, two ways to answer. The same structured probate case is answered by
**Gemini reading the statute on every query** (selectable model, real
latency / token / cost metering) and by **this repository's Lean 4
formalization** — compiled once, proof-checked, answering deterministically in
milliseconds and re-running live as you drag the estate-value slider. A
head-to-head box compares time, tokens, and estimated cost per case.

Ground-truth audit of the 12 sample cases: Lean 12/12, Gemini 23/36 runs
([AUDIT.md](AUDIT.md)). The Lean half replays on demand with
`python3 tools/run_audit.py`; the Gemini half is a record of the 2026-07-28
run, not a reproducible figure — re-sampling a non-deterministic model produces
new numbers rather than confirming old ones.

## Run it

From the repository root:

```bash
# 1. Build the Lean engine (needs elan; toolchain pinned by lean-toolchain)
lake build probate-api

# 2. Backend (Python 3.12+)
cd demo/backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env   # put your GEMINI_API_KEY in .env
.venv/bin/uvicorn app.main:app --port 8000

# 3. Frontend (Node 18+), in another terminal
cd demo/frontend
npm install && npm run dev   # http://localhost:5173
```

The Lean panel works without any API key; the Gemini panel needs
`GEMINI_API_KEY` in `demo/backend/.env`.

## Disclaimer

Demo only — not legal advice; all sample cases are fictional. Sources: the
[CA Courts self-help guide](https://selfhelp.courts.ca.gov/probate/simple-transfer)
as of 2026-07-28; death dates supported through 2026-12-31. Lean proves
consequences of supplied facts, not their truth.
