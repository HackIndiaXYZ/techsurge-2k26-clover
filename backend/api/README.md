# /backend/api

FastAPI server exposing Y1's `/api/analyze` and `/api/portfolio` contract
(`backend/contract/api_schema.py`) over the trained scorecard from Y3/Y4.

## Running it

```bash
pip install -r backend/requirements.txt fastapi uvicorn
python3 -m backend.model.train_scorecard   # if you haven't already
python3 -m backend.model.validate          # writes metrics.json, needed at startup
uvicorn backend.api.main:app --reload
```

The model artifact and `metrics.json` are loaded **once, at startup** — not
per request. If the model hasn't been trained yet, `uvicorn` fails to start
immediately with a clear message rather than starting "successfully" and
500ing on the first request.

CORS is open to `http://localhost:<any port>` and `http://127.0.0.1:<any port>`
(dev-only — not `*`), so a frontend running on a different local port (e.g. a
Flutter web build on `:5173` or `:3000`) can call this server directly.

## `GET /api/health`

Liveness check — not part of Y1's original contract, added for a frontend to
confirm the server is up before a demo.

```bash
curl -s http://localhost:8000/api/health
```

```json
{"status": "ok"}
```

## `POST /api/analyze`

Body is Y1's `AnalyzeRequest` exactly: `{profile_id, transactions,
months_available}`. `transactions` is the full list of `Transaction` objects
from `backend/generator/schema.py` — the same shape every profile JSON in
`/data` already uses under `transactions_seen`.

Build a request body from the committed demo profile:

```bash
python3 -c "
import json
from backend.generator.schema import Profile
p = Profile.model_validate(json.load(open('data/demo_profile_lakshmi.json')))
body = {
    'profile_id': p.meta.profile_id,
    'transactions': [t.model_dump(mode='json') for t in p.transactions_seen],
    'months_available': p.meta.months_available,
}
json.dump(body, open('/tmp/lakshmi_request.json', 'w'))
"
```

```bash
curl -s -X POST http://localhost:8000/api/analyze \
  -H "Content-Type: application/json" \
  -d @/tmp/lakshmi_request.json
```

```json
{
  "profile_id": "demo_lakshmi",
  "outcome": "SCORED",
  "vitality_score": 91.0,
  "band": "strong_candidate",
  "confidence": "high",
  "reason_codes": {
    "strengths": [
      {"feature": "ontime_bill_payment_rate", "statement": "Rent and utility bills were paid on time 100% of the time.", "contribution": 0.729},
      {"feature": "months_would_cover_emi_of_last_24", "statement": "Income would have covered an indicative loan payment in 24 of the last 24 months.", "contribution": 0.549},
      {"feature": "trend_last_6_months", "statement": "Income is up 19% versus the same period a year earlier — growing.", "contribution": 0.514}
    ],
    "concerns": []
  },
  "affordability": {"indicative_emi_low": 8989.59, "indicative_emi_high": 13606.68, "months_would_cover_emi_of_last_24": 24},
  "monthly_cashflow": [{"month": "2024-03", "inflow": 50219.58, "outflow": 19690.73, "net": 30528.85}, "... 23 more months (24 total) ..."],
  "coverage_reason": null,
  "disclaimer": "Research prototype on synthetic data. Not a lending decision system. Decision-support signal only — final lending decision rests with the lender."
}
```

**A thin-file / short-history profile** (`data/sample_profile.json`, 5 months)
returns a gated response, not an error:

```bash
python3 -c "
import json
from backend.generator.schema import Profile
p = Profile.model_validate(json.load(open('data/sample_profile.json')))
body = {
    'profile_id': p.meta.profile_id,
    'transactions': [t.model_dump(mode='json') for t in p.transactions_seen],
    'months_available': p.meta.months_available,
}
json.dump(body, open('/tmp/thin_request.json', 'w'))
"
curl -s -X POST http://localhost:8000/api/analyze \
  -H "Content-Type: application/json" \
  -d @/tmp/thin_request.json
```

```json
{
  "profile_id": "MSME0003",
  "outcome": "NOT_ASSESSABLE",
  "vitality_score": null,
  "band": null,
  "confidence": null,
  "reason_codes": {"strengths": [], "concerns": []},
  "affordability": {"indicative_emi_low": 5346.53, "indicative_emi_high": 6534.65, "months_would_cover_emi_of_last_24": 5},
  "monthly_cashflow": ["... 5 months ..."],
  "coverage_reason": "Not assessable: only 5 months of history (minimum 6 to span more than one season).",
  "disclaimer": "Research prototype on synthetic data. Not a lending decision system. Decision-support signal only — final lending decision rests with the lender."
}
```

**Malformed requests get a clean 422**, never a 500:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/api/analyze \
  -H "Content-Type: application/json" -d '{"profile_id": "bad"}'
# 422
```

## `GET /api/portfolio`

Serves the committed `backend/model/artifacts/metrics.json` (the numbers
`validate.py` computed and this repo's docs cite) — not a live recomputation
over the full 500+ profile dataset on every request.

```bash
curl -s http://localhost:8000/api/portfolio
```

```json
{
  "n_profiles": 521,
  "coverage_pct": 97.12,
  "auc": 0.9595,
  "band_distribution": {"strong_candidate": 145, "manual_review": 313, "high_risk_referral": 48},
  "score_histogram": [
    {"bucket": "0-10", "count": 48}, {"bucket": "10-20", "count": 39},
    {"bucket": "20-30", "count": 43}, {"bucket": "30-40", "count": 38},
    {"bucket": "40-50", "count": 43}, {"bucket": "50-60", "count": 54},
    {"bucket": "60-70", "count": 60}, {"bucket": "70-80", "count": 74},
    {"bucket": "80-90", "count": 46}, {"bucket": "90-100", "count": 61}
  ]
}
```

## Known integration gap — read before wiring up a frontend

**The frontend skeleton (`frontend/lib/services/clover_http_service.dart`, PR
#5) currently POSTs only `{"profile_id": "..."}` to `/api/analyze`** — it does
not send `transactions`/`months_available`. That does not match Y1's
`AnalyzeRequest` contract, which this server implements exactly (no
deviation, per this task's instructions), so as written today the frontend's
live-API call path will get a 422 from this real server, not a working
response. This is a frontend integration gap for a follow-up task, not
something fixed here — fixing it either means the frontend needs to send the
full transaction list, or a future task needs to add a separate
profile-lookup-by-id endpoint outside Y1's contract. Flagging it now so it
isn't a surprise mid-demo.

**Separately, the mock score does not match the real one.** The frontend's
mock data (`frontend/lib/mock_backend.dart`) uses `vitality_score: 71.5` for
its Lakshmi placeholder (`profile_id: "lakshmi_vendor_001"`, also a different
id than this repo's real `demo_lakshmi`). The real trained model scores the
real Lakshmi profile at **91.0**. This is expected — the mock predates the
real model — but the two numbers will visibly disagree until the frontend
integration task switches it over to this live API.
