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
