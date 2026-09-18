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
