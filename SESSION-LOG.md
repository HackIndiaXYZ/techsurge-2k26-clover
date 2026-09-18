# Clover Frontend — SESSION-LOG.md
# Updated: 2026-09-18

## Agent: Antigravity (Google DeepMind Antigravity IDE)
## Conversation ID: 64555e34-8c0b-4fac-b0ee-2445efc77fcf
## Branch: praneeth/frontend
## Status: In progress (Flutter app built, running flutter analyze + tests before PR)

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

## Previous sessions

None — this is the first agent session on this repo.
(Teammate `yash/backend` branch: feature extraction, sufficiency gates, held-out labels — merged to main via PR#2)
