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

from contextlib import asynccontextmanager
from datetime import date

from fastapi import Depends, FastAPI
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
    """
    transactions = request.transactions
    if transactions:
        history_start_date = min(t.date for t in transactions)
        history_end_date = max(t.date for t in transactions)
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
