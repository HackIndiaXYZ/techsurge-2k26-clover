# Clover — Credit Invisible (TechSurge 2k26, PS-F02)

Clover is a research prototype for MSME credit scoring using alternative
data — specifically simulated Account Aggregator (AA) transaction history —
for small businesses that are "credit invisible" to traditional bureaus.
This repository currently contains the synthetic data generator, the
transaction/profile schema, the feature-extraction and labeling pipeline, and
the API contract that a future FastAPI backend will implement; no model
training or server code is included yet. All data here is 100% synthetic — no
real bank, GST, Udyam, or bureau data is used anywhere.

## 1. Generate the dataset

```bash
pip install -r backend/requirements.txt
python3 -m backend.generator.generate_dataset
```

This produces 500+ synthetic MSME borrower profiles (each a simulated AA
transaction payload spanning 30 months) as individual JSON files in
`data/generated/` (gitignored — regenerate anytime). Two reference profiles
are committed at `data/sample_profile.json` and
`data/demo_profile_lakshmi.json`.

## 2. Build the feature table

```bash
python3 -m backend.scripts.build_feature_table
```

Extracts 12 features per profile from months 1–24, runs the sufficiency gate,
and derives the held-out label from months 25–30. Writes:

- `data/feature_table.csv` — committed. The only file a model may read.
- `data/labels_holdout.csv` — gitignored. Ground truth, validation only.

## 3. Run the tests

```bash
python3 -m unittest discover -s backend/tests -t .
```

The suite includes the label-leakage guard (features must not be able to see
the held-out window) and the fairness exclusion check (no geographic,
demographic or merchant-category field may become a feature).

See `/docs/DATA_SCHEMA.md` for the full schema, business archetypes, health
tiers, noise model, the Shadow-P2M heuristic, the 12 features, the sufficiency
thresholds and their reasoning, the label definition, and the fairness
exclusion list.
