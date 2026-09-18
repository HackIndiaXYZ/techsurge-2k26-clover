# Data Schema

This document describes the synthetic dataset produced by
`backend/generator/generate_dataset.py`. It's written to be defensible to a
judge: every design choice below is either a documented heuristic or an
explicit "this is our own choice, not a sourced statistic."

**All data in this repository is 100% synthetic.** No real bank statement,
GST, Udyam, or credit-bureau data is used, referenced, or scraped anywhere.

## Transaction object

Each profile is a list of transaction objects shaped to resemble a simulated
Account Aggregator (AA) payload — not a flat CSV. The Pydantic model lives at
`backend/generator/schema.py::Transaction`:

| Field | Type | Notes |
|---|---|---|
| `date` | `YYYY-MM-DD` | |
| `direction` | `"in" \| "out"` | |
| `amount` | number | INR, always positive |
| `channel` | `"upi" \| "cash" \| "neft" \| "card" \| "cheque"` | |
| `counterparty_type` | `"customer" \| "supplier" \| "utility" \| "rent" \| "personal" \| "unknown"` | |
| `category` | string | e.g. `"sales"`, `"raw_material"`, `"electricity_bill"`, `"personal_transfer"` |
| `note` | string \| null | short reference-style tag, e.g. `"UPI/482913/sales"` |
| `likely_shadow_supplier` | bool \| null | only ever set (true/false) when `counterparty_type == "personal"` — see below |

## Profile JSON shape

Each profile file is one JSON object:

```
{
  "meta": {
    "profile_id": "MSME0001",
    "archetype": "street_food_vendor",
    "latent_health_tier": "thriving",
    "is_cash_heavy_edge_case": false,
    "is_short_history_edge_case": false,
    "history_start_date": "2024-03-01",
    "history_end_date": "2026-08-31",
    "months_available": 30,
    "split": { "seen_months": 24, "holdout_months": 6, "split_date": "2026-03-01" }
  },
  "transactions_seen": [ ...Transaction... ],
  "transactions_holdout": [ ...Transaction... ]
}
```

### The 24/6 split

For a full-length profile, `history_start_date` → `history_end_date` spans 30
months. `transactions_seen` holds the first 24 months (usable as model
features by a later task); `transactions_holdout` holds the last 6 months
(reserved for a different, later task to derive labels from — no labeling
logic is implemented here). `split.split_date` marks the exact boundary: every
`transactions_seen` date is `< split_date`, every `transactions_holdout` date
is `>= split_date`.

Short-history edge-case profiles (see below) have less than 12 months of
total history — there isn't enough data to hold 6 months back, so
`split.holdout_months == 0`, `split.split_date == null`, and everything lives
in `transactions_seen`.

`latent_health_tier` is generator-internal ground truth for a later labeling
task. It is **not** meant to be used as a model feature — a real credit model
would not have access to it.

## Business archetypes

Each profile is assigned exactly one archetype, which shapes its income
rhythm and expense structure:

- **street_food_vendor** — daily small inflows (cash/UPI-heavy), a weekend
  bump, a monsoon dip (Jun–Sep), and a festival spike (Oct 1 – Nov 15).
  Daily small raw-material purchases from suppliers; a small daily stall fee
  (`rent`) and shared-meter electricity bill.
- **kirana_store** — steady daily inflows with low variance, monthly lump
  supplier payments (stock restocking) rather than daily small ones, plus
  monthly shop rent and electricity.
- **tailor_salon** — a strong weekly rhythm (weekend-heavy), and strong
  seasonal peaks during Diwali and the Nov–Feb wedding season. Occasional
  (not daily) fabric/material purchases.
- **gig_worker** — irregular inflows, including a deliberately higher chance
  of zero-income days, with a gradual upward trend over the 30 months. No
  rent; a small monthly phone/data recharge stands in for a utility cost.

## Latent health tiers

Every profile is assigned exactly one of four tiers. The **target
proportions across the full 500+ dataset are this project's own design
choice for a synthetic prototype, not sourced from any external statistic**:
thriving ~30%, stable ~35%, struggling ~22%, failing ~13%. The actual
generated distribution will vary somewhat around these targets because tier
assignment is a weighted random draw per profile.

Each tier distinctly parameterizes:

| Tier | Monthly growth | Income volatility (σ) | Missed-day probability | Shock probability / month | Bill on-time rate | Cash bias |
|---|---|---|---|---|---|---|
| thriving | +1.0% | 10% | 2% | 2% | 95% | more digital |
| stable | +0.2% | 16% | 5% | 4% | 85% | neutral |
| struggling | −0.6% | 26% | 12% | 8% | 60% | more cash |
| failing | −1.5% | 36% | 25% | 15% | 35% | most cash |

- **Growth rate** compounds monthly against the archetype's base daily
  revenue.
- **Income volatility** is applied as a per-day Gaussian multiplier on top of
  the seasonal/growth-adjusted expected revenue.
- **Missed/zero-income days** are days where no income transaction is
  generated at all.
- **Shocks** are monthly events (illness, equipment failure) that suppress
  that month's income (severity drawn per-tier) and, half the time, add a
  one-off `equipment_repair` / `medical_expense` outflow.
- **Bill-payment discipline** governs whether the monthly rent/utility is paid
  on time (within 2 days of the due date) or late (6–20 days late, tagged
  `"LATE PAYMENT"` in the `note` field when no digital reference exists).
- **Cash bias** shifts the channel-selection weights toward cash (struggling/
  failing) or away from it (thriving/stable), on top of the archetype's base
  channel mix.

## Noise injection

Regardless of tier, every profile gets:

- **Failed/reversed UPI transactions** — a small sample of UPI transactions
  get a paired reversal (opposite direction, same amount, `category:
  "upi_reversal"`, `note: "REVERSED"`) 0–1 days later.
- **Midnight batch-settlement sweeps** — small aggregator-style adjustment
  entries (`category: "batch_settlement"`, `counterparty_type: "unknown"`,
  `note: "UPI SETTLEMENT BATCH"`), ~3% of days.
- **Rounding artifacts** — tiny (₹0.50–₹5) inflow entries, ~1% of days
  (`category: "rounding_adjustment"`).
- **Short gaps** — 0–2 contiguous 2–7 day windows per profile with no
  transactions at all, simulating a failed AA data pull. (Short-history
  edge-case profiles never get gaps, to keep their already-short history
  interpretable.)

## Edge cases (deliberately included, not filtered out)

- **Cash-heavy profiles** (~15 of 500+) — channel-selection weights are
  overridden so roughly 70%+ of their transactions are cash. Randomly
  assigned, independent of archetype/tier.
- **Short-history profiles** (~15 of 500+) — total history is 4–11 months
  (strictly under 12), with `split.holdout_months == 0`. These exist to test
  a later coverage/sufficiency check, not to be scored normally.

Both edge-case flags are recorded explicitly in `meta.is_cash_heavy_edge_case`
/ `meta.is_short_history_edge_case` so downstream code can find them
deliberately rather than having to infer them statistically.

## Shadow P2M tagging heuristic

For every transaction with `counterparty_type == "personal"`, the generator
adds a derived `likely_shadow_supplier: true | false`.

**Rationale:** in real AA data, a personal UPI VPA that is paid repeatedly on
a regular rhythm and in a stable amount band is more likely to actually be an
informal supplier or customer paid via a personal handle (common for small
MSMEs — e.g. a fixed weekly payment to an unregistered raw-material supplier)
than a genuine one-off personal transfer.

**Exact heuristic implemented** (`generate_dataset.py::tag_shadow_p2m`):

1. Group all `personal` transactions by `(day_of_week, amount_band)`, where
   `amount_band = round(amount / 100) * 100` (₹100-wide bucket).
2. For each group, count the number of **distinct calendar months** in which
   at least one transaction in that group occurred.
3. Every transaction in a group is flagged `likely_shadow_supplier = true` if
   that group appears in **3 or more distinct months**; otherwise `false`.

This schema has no time-of-day field (AA payloads here are daily-granularity),
so day-of-week + amount-band recurrence is used as the observable proxy for
"same rhythm, same counterparty" — a genuine one-off gift or emergency
transfer will essentially never land in the same weekday/amount bucket across
3+ separate months by chance, while a recurring informal-supplier payment
will.

This is a simple, auditable heuristic chosen for defensibility in a pitch —
not a claim of ground truth. A profile can (and does, in the generator) also
contain a deliberately-constructed recurring "shadow supplier" pattern (fixed
weekday, stable amount band, weekly cadence) so the heuristic has true
positives to catch in the synthetic data.

## Demo profile: `demo_profile_lakshmi.json`

Hand-tuned via `generate_dataset.py::build_demo_profile_lakshmi`: a
`street_food_vendor`, `thriving` tier, with volatility, missed-day
probability, and shock probability all turned down and bill-payment
discipline turned up, plus a slightly higher growth rate. This is the profile
used live in the pitch — it's tuned to visibly look like a steady, growing
business with a clear festival-season spike when its monthly totals are
printed or plotted, not just to statistically pass the generator's own
tier logic.

---

# Feature extraction, sufficiency and labels

Everything below documents the second stage of the pipeline: turning a profile
into 12 features, deciding whether it can be scored at all, and deriving the
held-out ground-truth label. No scoring or model training happens here.

## The leakage boundary

This is the rule the rest of this stage is built around:

| Months | Window | Who may read it |
|---|---|---|
| 1–24 | `transactions_seen` | `feature_engine.py` only |
| 25–30 | `transactions_holdout` | `label_engine.py` only |

A feature that can see the held-out window produces a model that validates
brilliantly and fails in production, so the boundary is **enforced, not
trusted**. `backend/common/windows.py::assert_within_window` raises
`LeakageError` if either engine is handed a transaction outside its permitted
range, and each engine calls it before computing anything.

`feature_engine` and `label_engine` never import each other. Their shared
money definitions live in `backend/common/cashflow.py`, which is a set of pure
functions with no opinion about which months it is given.

**The one value that crosses the boundary, and why it is safe.** The label
needs the indicative EMI, which is defined from months 1–24. Rather than
recomputing it, `derive_label(profile, indicative_emi)` takes it as a plain
number from the caller. This is what a lender actually has — the EMI is sized
up front from the history in hand — and it keeps the label engine from ever
reading the seen window.

Two kinds of test defend this:

- **Tripwire tests** smuggle a held-out transaction into the seen list and
  assert `LeakageError` is raised.
- **An invariance test** mutates the held-out window violently (amounts ×1000,
  window emptied, replaced with a single large cash transaction) and asserts
  that *not one of the 12 feature values moves*. This is the test that catches
  a leak which keeps its dates tidy and slips past the tripwire.

A control test asserts the label *does* change with the held-out window, so
the invariance test cannot pass trivially.

## The 12 features

All computed from months 1–24 only. Grouped by the six families in
`FEATURE_FAMILIES`, which downstream scoring reuses to populate the API
contract's `reason_codes.feature` values.

| Family | Feature | Definition |
|---|---|---|
| Regularity | `pct_weeks_with_income` | Share of calendar weeks in the window containing at least one customer inflow. |
| | `income_coefficient_of_variation` | Sample standard deviation of monthly income ÷ mean monthly income. |
| | `longest_dry_streak_days` | Longest unbroken run of days with no trading income, including leading and trailing silence. |
| Growth | `trend_last_6_months` | Last 6 months vs **the same 6 calendar months a year earlier**, as a fraction. See the seasonality note below. |
| | `year_over_year_change` | Months 13–24 income vs months 1–12, as a fraction. Needs 24 months. |
| Discipline | `expense_to_income_ratio` | Total operating outflows ÷ total business income. |
| | `ontime_bill_payment_rate` | Share of rent/utility bills paid by the 7th of the month. |
| Resilience | `cash_buffer_days` | Median monthly surplus ÷ average daily expense. Flow-derived proxy — the payload has no balance field. Negative means the typical month burns cash. |
| | `worst_monthly_dip_pct` | (median monthly income − worst month) ÷ median. 1.0 means a month earned nothing. |
| Affordability | `months_would_cover_emi_of_last_24` | **Flagship.** Count of the 24 months where income ≥ indicative EMI + that month's essential expenses. |
| Trail | `digital_share` | Share of transaction value on UPI/NEFT/card/cheque. |
| | `cash_share` | Share of transaction value in cash. |

### Why `trend_last_6_months` is season-matched

These businesses are strongly seasonal by construction — a street food vendor's
monsoon is always weaker than its festival season. A raw 6-month slope
therefore reports whichever season the window happens to end in. On this
dataset it scored the visibly-growing demo profile at **−3%**, purely because
months 19–24 end in the monsoon.

So with 18+ months of history the feature compares the last 6 months against
the same 6 calendar months a year earlier — this monsoon against last monsoon.
The demo profile then reads **+17%**, which matches what the plotted cashflow
actually does. Below 18 months that comparison is impossible and it falls back
to a normalised least-squares slope, which *is* seasonality-exposed; that
fallback affects only short-history profiles, which are already gated to
`LOW_CONFIDENCE` or `NOT_ASSESSABLE`.

### Noise and reversals

Every money calculation excludes the generator's `batch_settlement` and
`rounding_adjustment` artifacts, so a handful of rupee-scale entries can never
register as a week of trading or inflate a ratio. `upi_reversal` is **not**
excluded — a reversal is a real correction, and is netted off the transaction
it reverses (a reversed customer inflow nets business income back to zero).

### Nulls are deliberate

A feature that is genuinely undefined returns `null`, not a fabricated zero.
Across the 521 profiles:

| Feature | Nulls | Why |
|---|---|---|
| `year_over_year_change` | 15 (2.9%) | Needs 24 months; these are the 15 short-history profiles. |
| `trend_last_6_months` | 5 (1.0%) | Needs 6 months; these have 4–5. |

Every other feature, including the flagship, computes for all 521 profiles.

## Sufficiency gate

Runs **before** any scoring is attempted. A thin file must come back as "we
cannot assess this" rather than as a low score — a low score reads as *this
business is bad* when the truth is *we do not have enough of their history
yet*, and conflating the two is exactly how thin-file businesses get locked
out of credit.

| Outcome | Condition |
|---|---|
| `NOT_ASSESSABLE` | < 6 months of history **OR** < 8 transactions/month |
| `LOW_CONFIDENCE` | 6–12 months of history **OR** 8–15 transactions/month |
| `FULL` | Everything else |

Either condition alone is enough to gate: a long history cannot rescue a
sparse trail, and a dense trail cannot rescue a short history.

**These thresholds are this prototype's own design choice. They are not drawn
from any regulatory standard or published methodology.** The reasoning:

- **Why 6 months and not 3?** These businesses are strongly seasonal, and both
  the monsoon dip and the festival spike last roughly a quarter. A 3-month
  window can sit entirely inside one of them, so it measures the season rather
  than the business — a vendor assessed across a single festival looks
  exceptional, and the same vendor assessed across a single monsoon looks like
  it is failing. Six months is the shortest window that necessarily spans more
  than one seasonal regime.
- **Why 12 months for full confidence?** Twelve months closes a full seasonal
  cycle, so every month can be compared against its own counterpart. Below
  that, growth and volatility features are still measurable but are partly
  reporting where in the year the window happened to fall — hence "low
  confidence" rather than "not assessable".
- **Why ~8 transactions/month?** Below roughly two transactions a week there is
  no rhythm left to measure: regularity, dry streaks and volatility collapse
  into noise, and a single missed week swings them wildly.
- **Why 15 for full confidence?** Between 8 and 15 a month the trail is real
  but thin. Features compute, but each rests on few enough observations that a
  couple of missing entries materially move them.

Density counts **only real business transactions** — settlement sweeps and
rounding artifacts are excluded, so a trail cannot clear the density bar on
noise alone.

**Cash-heavy is not a deficiency.** All 15 planted cash-heavy profiles pass the
gate as `FULL`. They have plenty of transactions; those transactions are simply
in cash. Gating them would rebuild the exclusion this project exists to undo.

### How the gate lands on this dataset

| Outcome | Profiles |
|---|---|
| `FULL` | 506 |
| `LOW_CONFIDENCE` | 10 |
| `NOT_ASSESSABLE` | 5 |

All 15 gated profiles are exactly the 15 short-history edge cases planted in
Y1 — none reaches `FULL`. Note that on this dataset the gate is driven
**entirely by the months rule**: the sparsest profile in the whole set is 27.9
transactions/month, far above the 8/15 density thresholds, because Y1 planted
short-history and cash-heavy edge cases but no low-density ones. The density
branch is therefore covered by unit tests using synthetic sparse profiles
rather than by the generated data.

## Label definition

Derived from the held-out window (months 25–30) only, and behaviourally
grounded rather than an arbitrary cutoff.

1. **Indicative EMI** = 20% of median monthly income over months 1–24.
2. **Essential expenses** = the profile's *actual* recurring outflows —
   `utility`, `rent` and `supplier` counterparties — as they appear in the data
   for each held-out month.
3. For each of the 6 held-out months, ask the question the borrower actually
   faces: after the month's essential running costs, was there enough income
   left to service the EMI?

   ```
   covered(month)  ⟺  income(month) ≥ indicative_emi + essentials(month)
   ```

4. **Label = 1 ("default")** if that fails in **2 or more** of the 6 months,
   otherwise **0**.

**Why 2 months and not 1?** One shortfall is a normal shock for a seasonal
micro-business — an illness, a monsoon week, a broken cart. Branding that a
default would mislabel most of the healthy population. Two or more is a
pattern of being unable to carry the obligation.

The same EMI definition drives the flagship
`months_would_cover_emi_of_last_24` feature, evaluated over months 1–24 instead
of 25–30, so the feature and the label measure the same thing at two different
points in time.

**Short-history profiles cannot be labeled.** With no held-out window there is
nothing to label, so `derive_label` returns `None` and those 15 profiles are
excluded from validation rather than guessed at.

### Label distribution

| | Count | Share |
|---|---|---|
| No default (0) | 458 | 90.5% |
| Default (1) | 48 | 9.5% |
| Unlabelable | 15 | — |

The label was never shown the latent health tier, but recovers it cleanly,
which is the main evidence that it measures something real:

| Latent tier | n | Default rate |
|---|---|---|
| thriving | 181 | 0.0% |
| stable | 165 | 1.2% |
| struggling | 93 | 12.9% |
| failing | 67 | 50.7% |

The classes are imbalanced (9.5% positive), which is realistic for a lending
portfolio but means the modeling stage should use stratified splits and rank
metrics such as AUC rather than accuracy.

## Fairness by design

A credit model built on alternative data can launder a demographic proxy into
a score without anyone intending it — and once it is in the training data it is
nearly impossible to spot by looking at the score. So the prohibition is
structural: `feature_engine.py` carries an explicit `EXCLUDED_FIELDS` list, and
`backend/tests/test_fairness.py` parses the AST of every module on the feature
path and fails the build if any banned name is read as an attribute.

**Present in the schema, excluded from features:**

| Field | Why |
|---|---|
| `latent_health_tier` | Generator ground truth — using it would be self-fulfilling label leakage, not a signal a lender could observe. |
| `is_cash_heavy_edge_case` | Generator internal. |
| `is_short_history_edge_case` | Generator internal. |
| `note` | Free-text memo carrying counterparty VPA handles and personal names, which proxy for identity, community and geography. |

**Reserved — must never be introduced as features:** any geography field
(`pincode`, `postal_code`, `district`, `state`, `city`, `village`, `ward`,
`latitude`, `longitude`, `address`, `region`); any demographic field
(`gender`, `sex`, `age`, `date_of_birth`, `caste`, `religion`, `community`,
`language`, `mother_tongue`, `marital_status`, `education`, `disability`); any
identity document (`aadhaar`, `pan`, `voter_id`, `borrower_name`,
`applicant_name`); and merchant classification (`merchant_category_code`,
`mcc`, `merchant_category`, `merchant_name`, `business_name`), since MCC-style
codes proxy for the demographics of who runs and who patronises a given trade.

A test asserts the "present in schema" half really does still exist on the
models and the "reserved" half really does not, so the list cannot rot into
names that no longer mean anything.

`digital_share` and `cash_share` are computed and stored but are
**informational only and must never be used to penalize cash-heavy
businesses.** A cash-heavy street vendor is not a worse credit risk for being
cash-heavy. They exist so the product can describe the quality of a trail and
explain a `LOW_CONFIDENCE` outcome — not to move a score downward. A test
asserts that two profiles with identical cashflow and opposite channel mixes
receive the same sufficiency outcome and the same affordability result.

`build_feature_table.py` is deliberately outside the AST scan: it reads
`latent_health_tier` on purpose, to write the gitignored validation file. That
it keeps ground truth *out* of the feature table is asserted separately.

## Worked example: `demo_profile_lakshmi`

A `thriving` `street_food_vendor` with 24 months of seen history.

| Family | Feature | Value | Reading |
|---|---|---|---|
| Regularity | `pct_weeks_with_income` | 1.00 | Earned in every single week of the window. |
| | `income_coefficient_of_variation` | 0.41 | Variable, but that is the festival/monsoon cycle, not instability. |
| | `longest_dry_streak_days` | 5 | Longest silence is one short data gap. |
| Growth | `trend_last_6_months` | +0.17 | 17% up on the same 6 months a year earlier. |
| | `year_over_year_change` | +0.18 | 18% up year on year — consistent with the above. |
| Discipline | `expense_to_income_ratio` | 0.37 | Keeps ~63 paise of every rupee earned. |
| | `ontime_bill_payment_rate` | 1.00 | Every rent and utility bill paid by the 7th. |
| Resilience | `cash_buffer_days` | 46.7 | Typical monthly surplus covers ~47 days of running costs. |
| | `worst_monthly_dip_pct` | 0.47 | Worst month ran 47% below typical — the monsoon. |
| Affordability | `months_would_cover_emi_of_last_24` | **24** | Could have serviced the EMI in all 24 months. |
| Trail | `digital_share` | 0.86 | Mostly digital — informational only. |
| | `cash_share` | 0.14 | |

**Sufficiency:** `FULL` — 24 months of history at 244.2 transactions/month.

**Held-out check (not a feature):** indicative EMI ₹11,044; 0 of the 6 held-out
months fell short, so the label is **0 (no default)** — which is what the
feature profile above would lead you to expect.

## Feature table

`python3 -m backend.scripts.build_feature_table` writes two files, and the
separation between them is the point:

- **`data/feature_table.csv`** — committed, 521 rows. `profile_id`, the 12
  features, the sufficiency outcome, and the two figures the gate ran on
  (`sufficiency_months_available`, `sufficiency_transactions_per_month`).
  **This is the only file a model may read.** Nulls are written as empty cells.
- **`data/labels_holdout.csv`** — **gitignored**, 506 rows. The held-out label,
  months failed, the indicative EMI and the latent health tier. **Validation
  only; never a model input.**

The script refuses to run if any ground-truth column appears in the feature
table schema, so the two can never quietly merge.

CSV rather than Parquet: the table is ~520 rows, and CSV keeps the pipeline
dependency-free (standard library only, beyond the pydantic the generator
already required) so any teammate can run it without setting up an environment.
The feature table is small enough (~105 KB) to commit, unlike the bulk profile
data, which stays gitignored and regenerable.
