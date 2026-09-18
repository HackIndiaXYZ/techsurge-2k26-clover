"""Startup-loaded state: the trained model artifact and the committed portfolio metrics.

Both are loaded ONCE, eagerly, when the FastAPI app starts -- not lazily on
the first request, and never re-read per request. Two reasons this matters:

1. A cold load on the first real request would make that request silently
   slower than every one after it, which is exactly the kind of thing a demo
   trips over at the worst moment.
2. If the model hasn't been trained (`scorecard_model.json` missing), we want
   `uvicorn` to fail immediately at startup with a clear message, not start
   "successfully" and then 500 on the first call to /api/analyze.

`get_artifact()` and `get_metrics()` are plain FastAPI dependencies -- inject
them with `Depends(...)` rather than importing the module-level singletons
directly, so tests can override them (see backend/tests/test_api.py) without
needing a real trained model on disk.
"""

from __future__ import annotations

import json
from pathlib import Path

from backend.model.artifact import METRICS_PATH, ScorecardArtifact

_artifact: ScorecardArtifact | None = None
_metrics: dict | None = None


def load_state() -> None:
    """Eagerly load the model artifact and metrics.json. Call once at startup.

    Raises FileNotFoundError with a clear message (via ScorecardArtifact.load)
    if the model hasn't been trained yet, or if metrics.json is missing.
    """
    global _artifact, _metrics
    _artifact = ScorecardArtifact.load()
    _metrics = _load_metrics(METRICS_PATH)


def _load_metrics(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. Validate the trained model first:\n"
            "    python3 -m backend.model.validate"
        )
    return json.loads(path.read_text())


def get_artifact() -> ScorecardArtifact:
    if _artifact is None:
        raise RuntimeError(
            "Model artifact not loaded. load_state() must run at app startup "
            "before any request is served (see main.py's lifespan handler)."
        )
    return _artifact


def get_metrics() -> dict:
    if _metrics is None:
        raise RuntimeError(
            "metrics.json not loaded. load_state() must run at app startup "
            "before any request is served (see main.py's lifespan handler)."
        )
    return _metrics
