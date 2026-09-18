# Credify — Credit Invisible (TechSurge 2k26, PS-F02)

Credify is a research prototype for MSME credit scoring using alternative
data — specifically simulated Account Aggregator (AA) transaction history —
for small businesses that are "credit invisible" to traditional bureaus.
This repository currently contains the synthetic data generator, the
transaction/profile schema, the feature-extraction and labeling pipeline, a
trained logistic regression scorecard with plain-language reason codes, and
the API contract that a future FastAPI backend will implement; no server code
is included yet. All data here is 100% synthetic — no real bank, GST, Udyam,
or bureau data is used anywhere.

## Setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r backend/requirements.txt
```

Only `backend/model/train_scorecard.py` and `backend/model/validate.py`
need numpy/scikit-learn (they fit and evaluate the model). Every other
module — including live inference in `backend/model/scorecard.py` — is
pure-Python/pydantic, so a future API server does not need a scientific
Python stack just to serve predictions from an already-trained model.

## 1. Generate the dataset

```bash
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

## 3. Train and validate the scorecard

```bash
python3 -m backend.model.train_scorecard
python3 -m backend.model.validate
```

Fits a logistic regression on the `FULL`-gated, labeled population and
calibrates band cutoffs from the validation set's actual probability
distribution. Writes:

- `backend/model/artifacts/scorecard_model.json` — gitignored. Regenerate
  by re-running `train_scorecard.py`.
- `backend/model/artifacts/metrics.json` — committed. AUC, coverage, score
  histogram, band distribution, and a 12-vs-24-month stability check.

```python
from backend.model.scorecard import analyze_profile
response = analyze_profile(profile)  # -> AnalyzeResponse, Y1's API contract exactly
```

## 4. Run the tests

```bash
python3 -m unittest discover -s backend/tests -t .
```

Runs entirely on the standard library plus pydantic — no venv required for
the test suite itself (a couple of tests cross-check against scikit-learn
and skip gracefully if it isn't installed). The suite includes the
label-leakage guard (neither features nor the model may see the held-out
window — checked end to end through `analyze_profile()`, not just at feature
extraction) and the fairness exclusion check (no geographic, demographic or
merchant-category field may become a feature, and `digital_share`/`cash_share`
structurally cannot move a score).

See `/docs/DATA_SCHEMA.md` for the full schema, business archetypes, health
tiers, noise model, the Shadow-P2M heuristic, the 12 features, the sufficiency
thresholds and their reasoning, the label definition, the fairness exclusion
list, the score formula, band-cutoff calibration, and validation results
(AUC, coverage, and an honestly-reported stability finding).
