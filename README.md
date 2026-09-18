# Clover — Credit Invisible (TechSurge 2k26, PS-F02)

Clover is a research prototype for MSME credit scoring using alternative
data — specifically simulated Account Aggregator (AA) transaction history —
for small businesses that are "credit invisible" to traditional bureaus.
This repository currently contains the synthetic data generator, the
transaction/profile schema, and the API contract that a future FastAPI
backend will implement; no scoring, feature engineering, or server code is
included yet. All data here is 100% synthetic — no real bank, GST, Udyam, or
bureau data is used anywhere.

## Running the data generator

```bash
pip install -r backend/requirements.txt
python3 -m backend.generator.generate_dataset
```

This produces 500+ synthetic MSME borrower profiles (each a simulated AA
transaction payload spanning 30 months) as individual JSON files in
`data/generated/` (gitignored — regenerate anytime). Two reference profiles
are committed at `data/sample_profile.json` and
`data/demo_profile_lakshmi.json`.

See `/docs/DATA_SCHEMA.md` for the full schema, business archetypes, health
tiers, noise model, and the Shadow-P2M heuristic.
