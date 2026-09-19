"""Pydantic models for the /api/analyze and /api/portfolio API contract.

This module defines the contract only — it is consumed by a FastAPI app that
will be built in a later task. Nothing here starts a server or implements
scoring logic. Field names and nesting mirror the contract spec exactly so
the future FastAPI app can import these models directly as its
request/response types.
"""

from __future__ import annotations

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field

from backend.generator.schema import Transaction

DISCLAIMER = (
    "Research prototype on synthetic data. Not a lending decision system. "
    "Decision-support signal only — final lending decision rests with the lender."
)


class Outcome(str, Enum):
    SCORED = "SCORED"
    LOW_CONFIDENCE = "LOW_CONFIDENCE"
    NOT_ASSESSABLE = "NOT_ASSESSABLE"


class Band(str, Enum):
    STRONG_CANDIDATE = "strong_candidate"
    MANUAL_REVIEW = "manual_review"
    HIGH_RISK_REFERRAL = "high_risk_referral"


class Confidence(str, Enum):
    HIGH = "high"
    LOW = "low"


# ---------------------------------------------------------------------------
# POST /api/analyze
# ---------------------------------------------------------------------------


class AnalyzeRequest(BaseModel):
    profile_id: str
    transactions: list[Transaction]
    months_available: int


class ReasonCode(BaseModel):
    feature: str
    statement: str
    contribution: float


class ReasonCodes(BaseModel):
    strengths: list[ReasonCode] = Field(default_factory=list)
    concerns: list[ReasonCode] = Field(default_factory=list)


class ScoreBreakdown(BaseModel):
    """The exact additive decomposition behind a SCORED result.

    The model is linear, so `intercept + sum(contributions.values())` equals
    `logit` exactly -- no approximation step (unlike SHAP over a tree model).
    That additivity holds in LOG-ODDS SPACE ONLY. vitality_score is a
    percentile rank of p_default against a frozen reference cohort, which is
    monotonic but not linear, so these contributions must never be presented
    as "points added to the score".

    Optional and additive: older clients that ignore this field are unaffected.
    """

    intercept: float
    contributions: dict[str, float]
    logit: float
    p_default: float


class Affordability(BaseModel):
    indicative_emi_low: float
    indicative_emi_high: float
    months_would_cover_emi_of_last_24: int


class MonthlyCashflow(BaseModel):
    month: str
    inflow: float
    outflow: float
    net: float


class AnalyzeResponse(BaseModel):
    profile_id: str
    outcome: Outcome
    vitality_score: Optional[float] = Field(default=None, ge=0, le=100)
    band: Optional[Band] = None
    confidence: Optional[Confidence] = None
    reason_codes: ReasonCodes
    score_breakdown: Optional[ScoreBreakdown] = Field(
        default=None,
        description="Populated only for SCORED outcomes; absent when there is no score to decompose.",
    )
    affordability: Affordability
    monthly_cashflow: list[MonthlyCashflow]
    coverage_reason: Optional[str] = Field(
        default=None,
        description="Populated only for LOW_CONFIDENCE / NOT_ASSESSABLE outcomes.",
    )
    disclaimer: str = DISCLAIMER


# ---------------------------------------------------------------------------
# GET /api/portfolio
# ---------------------------------------------------------------------------


class BandDistribution(BaseModel):
    strong_candidate: int
    manual_review: int
    high_risk_referral: int


class ScoreHistogramBucket(BaseModel):
    bucket: str
    count: int


class PortfolioResponse(BaseModel):
    n_profiles: int
    coverage_pct: float
    auc: Optional[float] = None
    band_distribution: BandDistribution
    score_histogram: list[ScoreHistogramBucket]
