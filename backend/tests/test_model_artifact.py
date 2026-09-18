"""Tests for the inference math and artifact persistence in backend/model/artifact.py.

Pure stdlib -- no numpy/scikit-learn needed, matching artifact.py's own
dependency-light design.
"""

from __future__ import annotations

import json
import math
import tempfile
import unittest
from pathlib import Path

from backend.model.artifact import (
    PREDICTIVE_FEATURES,
    ScorecardArtifact,
    compute_contributions,
    predict_default_probability,
    predict_vitality_probability,
    sigmoid,
    standardize,
)
from backend.tests.model_helpers import make_artifact, neutral_feature_values


class TestSigmoid(unittest.TestCase):
    def test_zero_is_one_half(self):
        self.assertAlmostEqual(sigmoid(0.0), 0.5)

    def test_large_positive_approaches_one(self):
        self.assertAlmostEqual(sigmoid(50.0), 1.0, places=9)

    def test_large_negative_approaches_zero(self):
        self.assertAlmostEqual(sigmoid(-50.0), 0.0, places=9)

    def test_no_overflow_on_extreme_input(self):
        # A naive exp(-x) implementation overflows around x < -709.
        self.assertEqual(sigmoid(-10000.0), 0.0)
        self.assertEqual(sigmoid(10000.0), 1.0)

    def test_matches_hand_computed_value(self):
        self.assertAlmostEqual(sigmoid(1.0), 1 / (1 + math.exp(-1)), places=12)

    def test_symmetry(self):
        for x in (0.3, 1.7, -2.4):
            self.assertAlmostEqual(sigmoid(x) + sigmoid(-x), 1.0, places=12)


class TestStandardize(unittest.TestCase):
    def test_basic(self):
        self.assertAlmostEqual(standardize(15.0, mean=10.0, scale=5.0), 1.0)

    def test_zero_scale_returns_zero_rather_than_dividing_by_zero(self):
        self.assertEqual(standardize(999.0, mean=10.0, scale=0.0), 0.0)

    def test_value_at_mean_is_zero(self):
        self.assertEqual(standardize(10.0, mean=10.0, scale=5.0), 0.0)


class TestPredictProbability(unittest.TestCase):
    def test_all_zero_coefficients_gives_sigmoid_of_intercept(self):
        artifact = make_artifact(intercept=0.5)
        p_vitality = predict_vitality_probability(artifact, neutral_feature_values())
        self.assertAlmostEqual(p_vitality, sigmoid(0.5))

    def test_hand_computed_two_feature_logit(self):
        artifact = make_artifact(
            coefficients={"pct_weeks_with_income": 2.0, "cash_buffer_days": -1.0},
            intercept=0.1,
        )
        values = neutral_feature_values()
        # scaler mean=0, scale=1 -> standardized value == raw value.
        expected_logit = 0.1 + 2.0 * values["pct_weeks_with_income"] + (-1.0) * values["cash_buffer_days"]
        p_vitality = predict_vitality_probability(artifact, values)
        self.assertAlmostEqual(p_vitality, sigmoid(expected_logit), places=10)

    def test_default_probability_is_one_minus_vitality_probability(self):
        artifact = make_artifact(coefficients={"trend_last_6_months": 1.3}, intercept=-0.4)
        values = neutral_feature_values()
        p_vitality = predict_vitality_probability(artifact, values)
        p_default = predict_default_probability(artifact, values)
        self.assertAlmostEqual(p_vitality + p_default, 1.0, places=12)

    def test_scaling_is_applied_before_the_coefficient(self):
        base = make_artifact(coefficients={"cash_buffer_days": 1.0}, intercept=0.0)
        artifact = ScorecardArtifact(
            trained_at=base.trained_at,
            train_seed=base.train_seed,
            predictive_features=base.predictive_features,
            scaler_mean={**base.scaler_mean, "cash_buffer_days": 20.0},
            scaler_scale={**base.scaler_scale, "cash_buffer_days": 10.0},
            coefficients=base.coefficients,
            intercept=base.intercept,
            band_cutoffs=base.band_cutoffs,
            train_profile_ids=base.train_profile_ids,
            test_profile_ids=base.test_profile_ids,
        )
        values = {**neutral_feature_values(), "cash_buffer_days": 30.0}  # z = (30-20)/10 = 1.0
        p_vitality = predict_vitality_probability(artifact, values)
        self.assertAlmostEqual(p_vitality, sigmoid(1.0), places=10)

    def test_missing_feature_contributes_zero_rather_than_crashing(self):
        artifact = make_artifact(coefficients={"trend_last_6_months": 5.0}, intercept=0.0)
        values = neutral_feature_values()
        values["trend_last_6_months"] = None
        p_vitality = predict_vitality_probability(artifact, values)
        self.assertAlmostEqual(p_vitality, sigmoid(0.0))


class TestFairnessExcludedFeaturesNeverMoveTheScore(unittest.TestCase):
    """The Y2 mandate, carried forward: digital_share/cash_share never score."""

    def test_digital_and_cash_share_are_not_in_predictive_features(self):
        self.assertNotIn("digital_share", PREDICTIVE_FEATURES)
        self.assertNotIn("cash_share", PREDICTIVE_FEATURES)
        self.assertEqual(len(PREDICTIVE_FEATURES), 10)

    def test_changing_channel_mix_never_changes_the_predicted_probability(self):
        artifact = make_artifact(
            coefficients={name: 1.0 for name in PREDICTIVE_FEATURES}, intercept=0.0
        )
        digital_heavy = {**neutral_feature_values(), "digital_share": 0.99, "cash_share": 0.01}
        cash_heavy = {**neutral_feature_values(), "digital_share": 0.01, "cash_share": 0.99}
        self.assertEqual(
            predict_default_probability(artifact, digital_heavy),
            predict_default_probability(artifact, cash_heavy),
        )

    def test_compute_contributions_never_includes_the_excluded_features(self):
        artifact = make_artifact(coefficients={name: 1.0 for name in PREDICTIVE_FEATURES})
        contributions = compute_contributions(artifact, neutral_feature_values())
        self.assertNotIn("digital_share", contributions)
        self.assertNotIn("cash_share", contributions)


class TestComputeContributions(unittest.TestCase):
    def test_contribution_equals_coefficient_times_standardized_value(self):
        artifact = make_artifact(coefficients={"expense_to_income_ratio": -2.0})
        values = neutral_feature_values()
        contributions = compute_contributions(artifact, values)
        self.assertAlmostEqual(
            contributions["expense_to_income_ratio"],
            -2.0 * values["expense_to_income_ratio"],
        )

    def test_zero_coefficient_gives_zero_contribution(self):
        artifact = make_artifact()  # all coefficients zero
        contributions = compute_contributions(artifact, neutral_feature_values())
        self.assertTrue(all(v == 0.0 for v in contributions.values()))

    def test_missing_raw_value_is_omitted_not_zero(self):
        artifact = make_artifact(coefficients={"trend_last_6_months": 3.0})
        values = neutral_feature_values()
        values["trend_last_6_months"] = None
        contributions = compute_contributions(artifact, values)
        self.assertNotIn("trend_last_6_months", contributions)


class TestBandCutoffs(unittest.TestCase):
    def test_boundaries_are_inclusive_toward_their_own_band(self):
        artifact = make_artifact(strong_candidate_max=0.1, high_risk_referral_min=0.5)
        self.assertEqual(artifact.band_cutoffs.band_for(0.1), "strong_candidate")
        self.assertEqual(artifact.band_cutoffs.band_for(0.5), "high_risk_referral")

    def test_between_the_cutoffs_is_manual_review(self):
        artifact = make_artifact(strong_candidate_max=0.1, high_risk_referral_min=0.5)
        self.assertEqual(artifact.band_cutoffs.band_for(0.3), "manual_review")

    def test_extremes(self):
        artifact = make_artifact(strong_candidate_max=0.1, high_risk_referral_min=0.5)
        self.assertEqual(artifact.band_cutoffs.band_for(0.0), "strong_candidate")
        self.assertEqual(artifact.band_cutoffs.band_for(1.0), "high_risk_referral")


class TestArtifactPersistence(unittest.TestCase):
    def test_round_trips_through_json(self):
        artifact = make_artifact(
            coefficients={"trend_last_6_months": 1.234, "cash_buffer_days": -0.567},
            intercept=0.089,
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "artifact.json"
            artifact.save(path)
            self.assertTrue(path.exists())
            loaded = ScorecardArtifact.load(path)

        self.assertEqual(loaded.predictive_features, artifact.predictive_features)
        self.assertAlmostEqual(loaded.coefficients["trend_last_6_months"], 1.234)
        self.assertAlmostEqual(loaded.intercept, 0.089)
        self.assertEqual(loaded.band_cutoffs.strong_candidate_max, artifact.band_cutoffs.strong_candidate_max)
        self.assertEqual(loaded.train_profile_ids, artifact.train_profile_ids)

    def test_saved_json_is_plain_and_human_readable(self):
        artifact = make_artifact()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "artifact.json"
            artifact.save(path)
            data = json.loads(path.read_text())
        self.assertIn("coefficients", data)
        self.assertIn("band_cutoffs", data)
        self.assertIsInstance(data["coefficients"], dict)

    def test_load_missing_file_raises_with_a_helpful_message(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "does_not_exist.json"
            with self.assertRaises(FileNotFoundError) as ctx:
                ScorecardArtifact.load(missing)
        self.assertIn("train_scorecard", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
