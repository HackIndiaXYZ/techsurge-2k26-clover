"""Tests for backend/api/main.py.

Needs fastapi + httpx (TestClient), which live only in the training venv
(.venv/bin/python3 -m unittest ...) -- the same dependency boundary as
train_scorecard.py/validate.py. Skips gracefully under the system Python
used for the rest of the leakage/fairness/feature suite.

Dependencies are overridden with a hand-built artifact (backend.tests.
model_helpers.make_artifact) rather than requiring a real trained model on
disk, so these tests are deterministic and runnable without a training run.
"""

from __future__ import annotations

import unittest

try:
    from fastapi.testclient import TestClient

    HAS_FASTAPI = True
except ImportError:
    HAS_FASTAPI = False

if HAS_FASTAPI:
    from backend.api.dependencies import get_artifact, get_metrics
    from backend.api.main import app
    from backend.tests.model_helpers import make_artifact
    from backend.tests.test_scorecard import dense_profile


def _transaction_json(tx) -> dict:
    return tx.model_dump(mode="json")


def _profile_to_analyze_request_body(profile) -> dict:
    return {
        "profile_id": profile.meta.profile_id,
        "transactions": [_transaction_json(t) for t in profile.transactions_seen],
        "months_available": profile.meta.months_available,
    }


FIXTURE_METRICS = {
    "auc_test": 0.9123,
    "coverage": {
        "n_profiles": 521,
        "counts": {"SCORED": 506, "LOW_CONFIDENCE": 10, "NOT_ASSESSABLE": 5},
        "pct": {"SCORED": 97.12, "LOW_CONFIDENCE": 1.92, "NOT_ASSESSABLE": 0.96},
    },
    "band_distribution": {
        "strong_candidate": 145,
        "manual_review": 313,
        "high_risk_referral": 48,
    },
    "score_histogram": [
        {"bucket": "0-10", "count": 48},
        {"bucket": "90-100", "count": 61},
    ],
}


@unittest.skipUnless(HAS_FASTAPI, "fastapi/httpx not installed (system Python) -- run under .venv")
class TestHealth(unittest.TestCase):
    def test_health_returns_200(self):
        with TestClient(app) as client:
            response = client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})


@unittest.skipUnless(HAS_FASTAPI, "fastapi/httpx not installed (system Python) -- run under .venv")
class TestAnalyzeEndpoint(unittest.TestCase):
    def setUp(self):
        self.artifact = make_artifact(
            coefficients={
                "months_would_cover_emi_of_last_24": 1.2,
                "ontime_bill_payment_rate": 0.7,
            },
            intercept=2.0,  # comfortably safe by default, for a clean SCORED case
        )
        app.dependency_overrides[get_artifact] = lambda: self.artifact
        app.dependency_overrides[get_metrics] = lambda: FIXTURE_METRICS

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_full_profile_returns_scored_response_matching_the_contract(self):
        profile = dense_profile(24)
        body = _profile_to_analyze_request_body(profile)

        with TestClient(app) as client:
            response = client.post("/api/analyze", json=body)

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["profile_id"], profile.meta.profile_id)
        self.assertEqual(data["outcome"], "SCORED")
        self.assertIsNotNone(data["vitality_score"])
        self.assertIsNotNone(data["band"])
        self.assertEqual(data["confidence"], "high")
        self.assertIsNone(data["coverage_reason"])
        self.assertIn("strengths", data["reason_codes"])
        self.assertIn("concerns", data["reason_codes"])
        self.assertIn("indicative_emi_low", data["affordability"])
        self.assertTrue(len(data["monthly_cashflow"]) > 0)
        self.assertIn("disclaimer", data)

    def test_short_history_profile_returns_gated_response_not_an_error(self):
        profile = dense_profile(3)  # NOT_ASSESSABLE
        body = _profile_to_analyze_request_body(profile)

        with TestClient(app) as client:
            response = client.post("/api/analyze", json=body)

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["outcome"], "NOT_ASSESSABLE")
        self.assertIsNone(data["vitality_score"])
        self.assertIsNone(data["band"])
        self.assertIsNone(data["confidence"])
        self.assertIsNotNone(data["coverage_reason"])
        self.assertEqual(data["reason_codes"]["strengths"], [])
        self.assertEqual(data["reason_codes"]["concerns"], [])

    def test_low_confidence_profile_returns_gated_response_not_an_error(self):
        profile = dense_profile(9)  # LOW_CONFIDENCE (months rule, dense enough)
        body = _profile_to_analyze_request_body(profile)

        with TestClient(app) as client:
            response = client.post("/api/analyze", json=body)

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["outcome"], "LOW_CONFIDENCE")
        self.assertIsNone(data["vitality_score"])
        self.assertIsNotNone(data["coverage_reason"])

    def test_empty_transactions_is_not_assessable_not_an_error(self):
        body = {"profile_id": "EMPTY0001", "transactions": [], "months_available": 0}
        with TestClient(app) as client:
            response = client.post("/api/analyze", json=body)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["outcome"], "NOT_ASSESSABLE")


@unittest.skipUnless(HAS_FASTAPI, "fastapi/httpx not installed (system Python) -- run under .venv")
class TestMalformedRequests(unittest.TestCase):
    def setUp(self):
        app.dependency_overrides[get_artifact] = lambda: make_artifact()
        app.dependency_overrides[get_metrics] = lambda: FIXTURE_METRICS

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_missing_required_field_is_422_not_500(self):
        with TestClient(app) as client:
            response = client.post("/api/analyze", json={"profile_id": "X"})
        self.assertEqual(response.status_code, 422)

    def test_wrong_type_is_422_not_500(self):
        with TestClient(app) as client:
            response = client.post(
                "/api/analyze",
                json={
                    "profile_id": "X",
                    "transactions": "not-a-list",
                    "months_available": "not-an-int",
                },
            )
        self.assertEqual(response.status_code, 422)

    def test_malformed_transaction_is_422_not_500(self):
        with TestClient(app) as client:
            response = client.post(
                "/api/analyze",
                json={
                    "profile_id": "X",
                    "transactions": [{"date": "2024-01-01", "amount": -5}],  # negative, missing fields
                    "months_available": 1,
                },
            )
        self.assertEqual(response.status_code, 422)

    def test_completely_empty_body_is_422_not_500(self):
        with TestClient(app) as client:
            response = client.post("/api/analyze", json={})
        self.assertEqual(response.status_code, 422)

    def test_non_json_body_is_422_not_500(self):
        with TestClient(app) as client:
            response = client.post(
                "/api/analyze",
                content=b"not json at all",
                headers={"Content-Type": "application/json"},
            )
        self.assertEqual(response.status_code, 422)


@unittest.skipUnless(HAS_FASTAPI, "fastapi/httpx not installed (system Python) -- run under .venv")
class TestPortfolioEndpoint(unittest.TestCase):
    def setUp(self):
        app.dependency_overrides[get_metrics] = lambda: FIXTURE_METRICS
        app.dependency_overrides[get_artifact] = lambda: make_artifact()

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_portfolio_maps_metrics_json_exactly(self):
        with TestClient(app) as client:
            response = client.get("/api/portfolio")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["n_profiles"], 521)
        self.assertEqual(data["coverage_pct"], 97.12)
        self.assertEqual(data["auc"], 0.9123)
        self.assertEqual(
            data["band_distribution"],
            {"strong_candidate": 145, "manual_review": 313, "high_risk_referral": 48},
        )
        self.assertEqual(
            data["score_histogram"],
            [{"bucket": "0-10", "count": 48}, {"bucket": "90-100", "count": 61}],
        )


@unittest.skipUnless(HAS_FASTAPI, "fastapi/httpx not installed (system Python) -- run under .venv")
class TestCors(unittest.TestCase):
    def setUp(self):
        app.dependency_overrides[get_metrics] = lambda: FIXTURE_METRICS

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_localhost_origin_is_allowed(self):
        with TestClient(app) as client:
            response = client.get(
                "/api/portfolio", headers={"Origin": "http://localhost:54231"}
            )
        self.assertEqual(
            response.headers.get("access-control-allow-origin"),
            "http://localhost:54231",
        )

    def test_preflight_request_is_allowed_for_localhost(self):
        with TestClient(app) as client:
            response = client.options(
                "/api/analyze",
                headers={
                    "Origin": "http://localhost:3000",
                    "Access-Control-Request-Method": "POST",
                },
            )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers.get("access-control-allow-origin"), "http://localhost:3000"
        )

    def test_non_localhost_origin_is_not_reflected(self):
        with TestClient(app) as client:
            response = client.get(
                "/api/portfolio", headers={"Origin": "http://evil.example.com"}
            )
        self.assertNotEqual(
            response.headers.get("access-control-allow-origin"), "http://evil.example.com"
        )


if __name__ == "__main__":
    unittest.main()
