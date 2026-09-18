# Clover Frontend — SESSION-LOG.md
# Updated: 2026-09-18

## Agent: Antigravity (Google DeepMind Antigravity IDE)
## Conversation ID: 64555e34-8c0b-4fac-b0ee-2445efc77fcf
## Branch: praneeth/frontend
## Status: Complete (Flutter analyze: 0 issues; flutter test: 15/15 pass; ready for PR)

---

## What was built

A Flutter frontend skeleton for the Clover alternative-credit scoring app
(TechSurge 2k26, PS-F02 "Credit Invisible") under `/frontend/`.

### Architecture

```
frontend/lib/
├── main.dart                        # App shell, theme, nav, disclaimer banner
├── mock_backend.dart                # Mock API (implements CloverApiService)
├── models/
│   ├── analyze_response.dart        # POST /api/analyze contract model
│   └── portfolio_response.dart      # GET /api/portfolio contract model
├── services/
│   ├── clover_api_service.dart      # Abstract interface (swap-ready)
│   └── clover_http_service.dart     # Real HTTP implementation (not activated)
├── state/
│   └── app_state.dart               # ChangeNotifier state for lender flow + consent
├── screens/
│   ├── lender_screen.dart           # Screen 1: bureau dead-end → Clover score
│   ├── consent_screen.dart          # Screen 2: AA consent flow
│   ├── portfolio_screen.dart        # Screen 3: portfolio metrics + histogram
│   └── borrower_screen.dart         # Screen 4: plain-language borrower view
└── widgets/
    ├── disclaimer_banner.dart        # Persistent banner on all screens
    ├── score_gauge.dart              # Circular vitality gauge (percent_indicator)
    ├── cashflow_chart.dart           # Line chart (fl_chart)
    └── score_histogram_chart.dart   # Bar chart (fl_chart)
```

### Mock API profiles
- `lakshmi_vendor_001` — SCORED, vitality 71.5, strong_candidate (from spec verbatim)
- `thin_file_002` — NOT_ASSESSABLE, thin file (from spec verbatim)
- `dormancy_gap_003` — NOT_ASSESSABLE, constructed per spec requirement
- `ramesh_carpentry_004` — LOW_CONFIDENCE, manual_review

### Mock portfolio numbers are clearly marked as ILLUSTRATIVE PLACEHOLDERS
(will be replaced by live GET /api/portfolio values in a later integration task)

### Decisions made
- Used `provider` (ChangeNotifier) for state — lightweight, no overkill
- `_useMock = true` constant in main.dart is the single toggle to switch to live HTTP
- IndexedStack for tab nav keeps all 4 screens in memory so state persists across tabs
- Disclaimer banner pinned between AppBar and the page body; always visible regardless of scroll position

### Rejected alternatives
- `riverpod` — unnecessary complexity for this phase
- `dio` over `http` — `http` is sufficient and lighter

---

---

## Session 2: Mock alignment with trained model (91.0 score)

### Completed
- In `frontend/lib/mock_backend.dart`: updated `_lakshmi` vitality_score from 71.5 to 91.0 (matching real trained model for `demo_lakshmi`).
- Updated `_lakshmi` reason codes and affordability to be internally consistent with 91.0 score:
  - Strengths: `ontime_bill_payment_rate` (+0.729), `months_would_cover_emi_of_last_24` (+0.549), `trend_last_6_months` (+0.514).
  - Concerns: empty list (strong candidate, 0 concerns).
  - Affordability: `indicative_emi_low: 8989.59`, `indicative_emi_high: 13606.68`, `months_would_cover_emi_of_last_24: 24`.
- In `frontend/lib/services/clover_http_service.dart`: added TODO comment above `getAvailableProfileIds()` noting pending confirmation with backend on exact demo profile IDs in `/data`. Left IDs and `analyzeProfile()` untouched.
- In `frontend/test/clover_test.dart`: updated test assertion from 71.5 to 91.0.
- Verification: `flutter analyze` passed (0 issues), `flutter test` passed (15/15 tests).

### Rejected alternatives
- Did NOT modify `analyzeProfile()` request body or URL in `clover_http_service.dart` — waiting for backend's `GET /api/profiles/{profile_id}` endpoint to be shipped and confirmed.
- Did NOT alter demo profile IDs in `clover_http_service.dart` pending backend confirmation.

