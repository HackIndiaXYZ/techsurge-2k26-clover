"""FastAPI backend serving Y1's /api/analyze and /api/portfolio contract.

    uvicorn backend.api.main:app --reload

See backend/api/README.md for example curl commands against
data/demo_profile_lakshmi.json.

Everything this module does is a thin adapter around code Y1-Y4 already
built and tested: request/response models come from backend.contract.api_schema
unchanged, scoring goes through backend.model.scorecard.analyze_profile, and
/api/portfolio serves the committed backend/model/artifacts/metrics.json --
the same file validate.py wrote and this repo's docs cite numbers from, so
the API can never quietly report different numbers than what was validated.
"""

from __future__ import annotations

import json
from contextlib import asynccontextmanager
from datetime import date
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from backend.api.dependencies import get_artifact, get_metrics, load_state
from backend.contract.api_schema import (
    AnalyzeRequest,
    AnalyzeResponse,
    BandDistribution,
    PortfolioResponse,
    ScoreHistogramBucket,
)
from backend.generator.schema import Archetype, HealthTier, Profile, ProfileMeta, SplitInfo
from backend.model.artifact import ScorecardArtifact
from backend.model.scorecard import analyze_profile

DATA_DIR = Path(__file__).resolve().parents[2] / "data"

# Frontend-facing demo profile_id -> committed profile JSON file. This map is
# what GET /api/profiles/{profile_id} exists to bridge (see that endpoint's
# docstring for the full "why"): the frontend skeleton
# (frontend/lib/services/clover_http_service.dart) hardcodes these 4 ids and
# posts only {"profile_id": ...}, not Y1's full AnalyzeRequest shape.
DEMO_PROFILES: dict[str, str] = {
    "lakshmi_vendor_001": "demo_profile_lakshmi.json",
    "thin_file_002": "sample_profile.json",
    "dormancy_gap_003": "demo_profile_dormancy_gap.json",
    "ramesh_carpentry_004": "demo_profile_ramesh_carpentry.json",
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Loads the trained model artifact and metrics.json ONCE, eagerly, before
    # the server accepts any request. If the model hasn't been trained yet
    # (backend/model/artifacts/scorecard_model.json missing), this raises and
    # uvicorn fails to start with a clear message, rather than starting
    # "successfully" and 500ing on the first real call.
    load_state()
    yield


app = FastAPI(
    title="Clover Vitality Scoring API",
    description="Research prototype on synthetic data. Not a lending decision system.",
    lifespan=lifespan,
)

# Local development CORS: a teammate's frontend (Flutter web, or anything
# else) typically runs on a different localhost port than this API. Matches
# http(s)://localhost:<any port> and http(s)://127.0.0.1:<any port> --
# intentionally NOT "*", so this stays a dev-only allowance rather than an
# open CORS policy that would also need reviewing for a real deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# A generous but hard upper bound on how much calendar time a single
# request's transactions may span. Every window helper (iter_week_keys,
# iter_month_keys, feature_engine's dry-streak scan) walks the seen window
# one day at a time, so an unbounded span is a real performance cliff -- and
# at the extreme end, a span approaching Python's full date.min..date.max
# range causes an unhandled OverflowError: the day-by-day loop increments
# one day past date.max before its own while-condition gets a chance to stop
# it. Real MSME histories in this project's domain are at most a few years;
# 10 years is comfortably above any legitimate use and still only a few
# thousand fast loop iterations, so requests beyond it are rejected with a
# clean 422 rather than allowed to hang or crash.
MAX_HISTORY_SPAN_DAYS = 3653  # ~10 years


def _request_to_profile(request: AnalyzeRequest) -> Profile:
    """Build a Profile from an AnalyzeRequest.

    AnalyzeRequest carries {profile_id, transactions, months_available} --
    it has no archetype/latent_health_tier/split metadata, which
    ProfileMeta's schema otherwise requires. Two things make filling those in
    with placeholders safe rather than a hidden assumption:

    1. archetype and latent_health_tier are never read anywhere on the scoring
       path (verified: zero references in backend/features/, backend/model/,
       backend/common/) -- they exist on the schema for the generator's own
       bookkeeping, not for scoring. A fixed placeholder here cannot influence
       a score, by construction, the same way EXCLUDED_FIELDS guarantees for
       demographic/geographic fields.
    2. The seen window used for every feature and the sufficiency gate is
       derived from the ACTUAL transaction dates (min/max below), not from the
       caller's declared `months_available` -- so a caller cannot inflate a
       score by mis-declaring history length; sufficiency.py recomputes the
       real window regardless of what this field says.

    A request with no transactions at all still produces a well-formed (if
    degenerate) Profile: assess_sufficiency correctly reads that as 0 months /
    0 transactions and returns NOT_ASSESSABLE, rather than this function
    raising on an empty min()/max().

    Raises HTTPException(422) if the transaction dates span more than
    MAX_HISTORY_SPAN_DAYS -- see that constant for why this is checked here,
    before any window helper walks the range day by day.
    """
    transactions = request.transactions
    if transactions:
        history_start_date = min(t.date for t in transactions)
        history_end_date = max(t.date for t in transactions)
        span_days = (history_end_date - history_start_date).days
        if span_days > MAX_HISTORY_SPAN_DAYS:
            raise HTTPException(
                status_code=422,
                detail=(
                    f"Transaction dates span {span_days} days "
                    f"({history_start_date} to {history_end_date}), which is more "
                    f"than the {MAX_HISTORY_SPAN_DAYS}-day maximum a single profile "
                    "may span."
                ),
            )
    else:
        history_end_date = date.today()
        history_start_date = history_end_date

    months_available = max(0, request.months_available)

    meta = ProfileMeta(
        profile_id=request.profile_id,
        archetype=Archetype.KIRANA_STORE,
        latent_health_tier=HealthTier.STABLE,
        is_cash_heavy_edge_case=False,
        is_short_history_edge_case=False,
        history_start_date=history_start_date,
        history_end_date=history_end_date,
        months_available=months_available,
        split=SplitInfo(seen_months=months_available, holdout_months=0, split_date=None),
    )
    return Profile(meta=meta, transactions_seen=transactions, transactions_holdout=[])


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/api/analyze", response_model=AnalyzeResponse)
def post_analyze(
    request: AnalyzeRequest, artifact: ScorecardArtifact = Depends(get_artifact)
) -> AnalyzeResponse:
    """Scores a profile. Malformed request bodies never reach this function --
    FastAPI validates against AnalyzeRequest first and returns 422 itself.

    A LOW_CONFIDENCE / NOT_ASSESSABLE profile is not an error: analyze_profile
    already returns the correctly-shaped response (vitality_score/band/
    confidence null, coverage_reason populated) for those, gate-first, before
    the model is ever called -- this endpoint just returns whatever it gets.
    """
    profile = _request_to_profile(request)
    return analyze_profile(profile, artifact=artifact)


@app.get("/api/portfolio", response_model=PortfolioResponse)
def get_portfolio(metrics: dict = Depends(get_metrics)) -> PortfolioResponse:
    """Serves the committed backend/model/artifacts/metrics.json, the exact
    numbers validate.py computed and this repo's docs cite -- not a live
    recomputation over the full dataset on every request.
    """
    coverage = metrics["coverage"]
    return PortfolioResponse(
        n_profiles=coverage["n_profiles"],
        coverage_pct=coverage["pct"]["SCORED"],
        auc=metrics["auc_test"],
        band_distribution=BandDistribution(**metrics["band_distribution"]),
        score_histogram=[
            ScoreHistogramBucket(**bucket) for bucket in metrics["score_histogram"]
        ],
    )


@app.get("/api/profiles/{profile_id}", response_model=AnalyzeResponse)
def get_profile_analysis(
    profile_id: str, artifact: ScorecardArtifact = Depends(get_artifact)
) -> AnalyzeResponse:
    """Server-side demo-profile lookup: resolves a known profile_id to a
    committed profile JSON file and scores it directly. NOT part of Y1's
    original contract, and does not change /api/analyze's contract at all.

    Why this exists: the frontend skeleton
    (frontend/lib/services/clover_http_service.dart) posts only
    {"profile_id": "..."} to /api/analyze, not Y1's full AnalyzeRequest
    shape ({profile_id, transactions, months_available}). /api/analyze
    implements that contract exactly, with no deviation, for every real
    integration -- relaxing it to accept a bare profile_id would be exactly
    the kind of contract drift this project has been careful to avoid
    elsewhere. Instead, this is a separate, additional endpoint outside the
    original contract that looks a known DEMO profile up server-side.

    Because the committed profile JSON already carries a complete,
    well-formed Profile (real meta/split/history dates from the generator,
    not reconstructed from a flat transaction list), this calls
    scorecard.analyze_profile() directly on it -- skipping /api/analyze's
    own AnalyzeRequest-to-Profile conversion (_request_to_profile) entirely,
    including its placeholder archetype/latent_health_tier, which aren't
    needed here since the real values are already on the file.

    Unknown ids return 404, not the 422 /api/analyze uses for malformed
    input -- this is a lookup miss (the resource ~"/api/profiles/<id>"
    doesn't exist), not a malformed request body.
    """
    filename = DEMO_PROFILES.get(profile_id)
    if filename is None:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Unknown profile_id '{profile_id}'. Known demo ids: "
                f"{sorted(DEMO_PROFILES)}"
            ),
        )

    profile = Profile.model_validate(json.loads((DATA_DIR / filename).read_text()))
    # Return the id the caller asked for, not whatever internal id the
    # committed file happens to carry (e.g. the file's own "demo_lakshmi"
    # vs. the frontend-facing "lakshmi_vendor_001") -- the caller should see
    # back the id it requested.
    profile.meta.profile_id = profile_id
    return analyze_profile(profile, artifact=artifact)
