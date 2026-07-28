# Simple Transfer — LLM vs Compiled Law (demo app)

Same case, two ways to answer. The same structured probate case is answered by
**Gemini reading the statute on every query** (selectable model, real
latency / token / cost metering) and by **this repository's exact Lean 4
formalization** — compiled once, proof-checked, answering deterministically in
milliseconds and re-running live as you drag the estate-value slider. The
Python service only validates the HTTP shape and forwards the raw case to the
Lean JSON adapter; it has no rule evaluator. A
head-to-head box compares time, tokens, and estimated cost per case.

Ground-truth audit of the 12 sample cases: Lean 12/12, Gemini 23/36 runs
([AUDIT.md](AUDIT.md)).

The input supports legacy `gross_value_cents` plus independent
`current_gross_value_cents` and `date_of_death_value_cents`. The exact adapter
uses each explicit fact for its corresponding valuation and falls back to the
legacy value when that explicit key is absent or `null`. See [CONTRACT.md](CONTRACT.md)
for the route projection and exact source inventory.

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
