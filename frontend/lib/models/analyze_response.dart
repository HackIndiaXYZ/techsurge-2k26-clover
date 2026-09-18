class ReasonItem {
  final String feature;
  final String statement;
  final double contribution;

  const ReasonItem({
    required this.feature,
    required this.statement,
    required this.contribution,
  });

  factory ReasonItem.fromJson(Map<String, dynamic> json) {
    return ReasonItem(
      feature: json['feature'] as String? ?? '',
      statement: json['statement'] as String? ?? '',
      contribution: (json['contribution'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'statement': statement,
        'contribution': contribution,
      };
}

class ReasonCodes {
  final List<ReasonItem> strengths;
  final List<ReasonItem> concerns;

  const ReasonCodes({
    required this.strengths,
    required this.concerns,
  });

  factory ReasonCodes.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ReasonCodes(strengths: [], concerns: []);
    }
    final rawStrengths = json['strengths'] as List<dynamic>? ?? [];
    final rawConcerns = json['concerns'] as List<dynamic>? ?? [];
    return ReasonCodes(
      strengths: rawStrengths
          .map((e) => ReasonItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      concerns: rawConcerns
          .map((e) => ReasonItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'strengths': strengths.map((e) => e.toJson()).toList(),
        'concerns': concerns.map((e) => e.toJson()).toList(),
      };
}

class Affordability {
  final double indicativeEmiLow;
  final double indicativeEmiHigh;
  final int monthsWouldCoverEmiOfLast24;

  const Affordability({
    required this.indicativeEmiLow,
    required this.indicativeEmiHigh,
    required this.monthsWouldCoverEmiOfLast24,
  });

  factory Affordability.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const Affordability(
        indicativeEmiLow: 0.0,
        indicativeEmiHigh: 0.0,
        monthsWouldCoverEmiOfLast24: 0,
      );
    }
    return Affordability(
      indicativeEmiLow: (json['indicative_emi_low'] as num?)?.toDouble() ?? 0.0,
      indicativeEmiHigh: (json['indicative_emi_high'] as num?)?.toDouble() ?? 0.0,
      monthsWouldCoverEmiOfLast24:
          (json['months_would_cover_emi_of_last_24'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'indicative_emi_low': indicativeEmiLow,
        'indicative_emi_high': indicativeEmiHigh,
        'months_would_cover_emi_of_last_24': monthsWouldCoverEmiOfLast24,
      };
}

class MonthlyCashflow {
  final String month;
  final double inflow;
  final double outflow;
  final double net;

  const MonthlyCashflow({
    required this.month,
    required this.inflow,
    required this.outflow,
    required this.net,
  });

  factory MonthlyCashflow.fromJson(Map<String, dynamic> json) {
    return MonthlyCashflow(
      month: json['month'] as String? ?? '',
      inflow: (json['inflow'] as num?)?.toDouble() ?? 0.0,
      outflow: (json['outflow'] as num?)?.toDouble() ?? 0.0,
      net: (json['net'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'inflow': inflow,
        'outflow': outflow,
        'net': net,
      };
}

class AnalyzeResponse {
  final String profileId;
  final String outcome; // "SCORED" | "LOW_CONFIDENCE" | "NOT_ASSESSABLE"
  final double? vitalityScore; // 0-100 or null
  final String? band; // "strong_candidate" | "manual_review" | "high_risk_referral" | null
  final String? confidence; // "high" | "low" | null
  final ReasonCodes reasonCodes;
  final Affordability affordability;
  final List<MonthlyCashflow> monthlyCashflow;
  final String? coverageReason;
  final String disclaimer;

  const AnalyzeResponse({
    required this.profileId,
    required this.outcome,
    this.vitalityScore,
    this.band,
    this.confidence,
    required this.reasonCodes,
    required this.affordability,
    required this.monthlyCashflow,
    this.coverageReason,
    required this.disclaimer,
  });

  bool get isScored => outcome == 'SCORED';
  bool get isNotAssessable => outcome == 'NOT_ASSESSABLE';
  bool get isLowConfidence => outcome == 'LOW_CONFIDENCE';

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    final rawCashflow = json['monthly_cashflow'] as List<dynamic>? ?? [];
    return AnalyzeResponse(
      profileId: json['profile_id'] as String? ?? '',
      outcome: json['outcome'] as String? ?? 'NOT_ASSESSABLE',
      vitalityScore: (json['vitality_score'] as num?)?.toDouble(),
      band: json['band'] as String?,
      confidence: json['confidence'] as String?,
      reasonCodes: ReasonCodes.fromJson(
        json['reason_codes'] as Map<String, dynamic>?,
      ),
      affordability: Affordability.fromJson(
        json['affordability'] as Map<String, dynamic>?,
      ),
      monthlyCashflow: rawCashflow
          .map((e) => MonthlyCashflow.fromJson(e as Map<String, dynamic>))
          .toList(),
      coverageReason: json['coverage_reason'] as String?,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'outcome': outcome,
        'vitality_score': vitalityScore,
        'band': band,
        'confidence': confidence,
        'reason_codes': reasonCodes.toJson(),
        'affordability': affordability.toJson(),
        'monthly_cashflow': monthlyCashflow.map((e) => e.toJson()).toList(),
        'coverage_reason': coverageReason,
        'disclaimer': disclaimer,
      };
}
