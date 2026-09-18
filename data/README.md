# /data

- `sample_profile.json` — one small, committed example profile (a
  short-history edge case, so it's compact) for reference. Shows the full
  profile JSON shape without needing to run the generator.
- `demo_profile_lakshmi.json` — the hand-tuned demo profile used live in the
  pitch: a thriving `street_food_vendor` with a clean growth curve and a
  clear festival-season spike.
- `generated/` — **not committed.** Bulk generated data (500+ profiles) is
  gitignored (see `/.gitignore`: `/data/generated/`) because it's large and
  fully reproducible. Regenerate it with:

  ```bash
  pip install -r backend/requirements.txt
  python3 -m backend.generator.generate_dataset
  ```

  This writes one JSON file per profile to `data/generated/`, plus refreshes
  `sample_profile.json` and `demo_profile_lakshmi.json` in this directory.
  See `/docs/DATA_SCHEMA.md` for the full schema, archetype, and health-tier
  documentation.
- `feature_table.csv` — **committed** (it's small, ~105 KB). One row per
  profile: `profile_id`, the 12 features, and the sufficiency-gate outcome.
  **This is the only file a model may read.** Rebuild with:

  ```bash
  python3 -m backend.scripts.build_feature_table
  ```

- `labels_holdout.csv` — **not committed**, gitignored. The held-out
  ground-truth label derived from months 25–30, alongside the generator's
  latent health tier. **Validation only — never a model input.** It is written
  by the same command above, deliberately as a separate file so it cannot be
  joined into the feature table by accident.
