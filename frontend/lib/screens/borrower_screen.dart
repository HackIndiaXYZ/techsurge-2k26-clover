import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analyze_response.dart';
import '../state/app_state.dart';
import '../widgets/score_gauge.dart';

class BorrowerScreen extends StatelessWidget {
  const BorrowerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final result = state.analyzeResult;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Clover Vitality Signal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Plain-language explanation — just for you',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),

              if (!state.consentApproved)
                _InfoCard(
                  icon: Icons.lock_outline,
                  color: const Color(0xFFFBBF24),
                  title: 'Consent not yet given',
                  body: 'Go to the Consent tab and approve data sharing, '
                      'then ask the lender to run the Clover check. '
                      'Your results will appear here.',
                )
              else if (result == null)
                _InfoCard(
                  icon: Icons.hourglass_empty_outlined,
                  color: const Color(0xFF60A5FA),
                  title: 'Awaiting assessment',
                  body: 'Your data has been shared. '
                      'The lender needs to run the Clover alternative-data check. '
                      'Results will appear here once it\'s done.',
                )
              else
                _BorrowerResultView(result: result),
            ],
          ),
        );
      },
    );
  }
}

class _BorrowerResultView extends StatelessWidget {
  final AnalyzeResponse result;
  const _BorrowerResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.isNotAssessable) {
      return _NotAssessableView(result: result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Friendly intro
        _InfoCard(
          icon: Icons.waving_hand_outlined,
          color: const Color(0xFF10B981),
          title: 'Your financial record has been assessed',
          body: 'Clover looked at your transaction history to understand '
              'your income patterns and financial behaviour — without a '
              'traditional credit score.',
        ),
        const SizedBox(height: 20),

        // Score gauge — centred
        Center(
          child: ScoreGauge(
            score: result.vitalityScore ?? 0,
            band: result.band,
            confidence: result.confidence,
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Higher is better  ·  Scale: 0 to 100',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 24),

        // What's helping you
        if (result.reasonCodes.strengths.isNotEmpty) ...[
          _SectionHeader(icon: Icons.thumb_up_alt_outlined, label: "What's helping you"),
          const SizedBox(height: 10),
          ...result.reasonCodes.strengths.map(
            (s) => _PlainReasonTile(
              text: s.statement,
              isPositive: true,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Areas to watch
        if (result.reasonCodes.concerns.isNotEmpty) ...[
          _SectionHeader(icon: Icons.lightbulb_outline, label: 'Areas to watch'),
          const SizedBox(height: 10),
          ...result.reasonCodes.concerns.map(
            (c) => _PlainReasonTile(
              text: c.statement,
              isPositive: false,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Actionable tip
        _ActionableTip(result: result),
        const SizedBox(height: 20),

        // EMI range plain English
        if (result.isScored)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D3148)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About your loan affordability',
                  style: TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Based on your income pattern, a monthly instalment (EMI) '
                  'of roughly ₹${_fmt(result.affordability.indicativeEmiLow)} to '
                  '₹${_fmt(result.affordability.indicativeEmiHigh)} appears manageable. '
                  'In ${result.affordability.monthsWouldCoverEmiOfLast24} out of '
                  'the last 24 months, your income would have comfortably covered '
                  'an EMI in that range.',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    height: 1.6,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'These are indicative estimates only. A lender will make '
                  'the final assessment.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)},000';
    return v.toStringAsFixed(0);
  }
}

class _NotAssessableView extends StatelessWidget {
  final AnalyzeResponse result;
  const _NotAssessableView({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          icon: Icons.info_outline,
          color: const Color(0xFF60A5FA),
          title: 'We were not able to assess your signal yet',
          body: result.coverageReason ??
              'There was not enough transaction history to produce a reliable signal.',
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2D3148)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💡 What you can do',
                style: TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Continue using a bank account or UPI for your business '
                'transactions. The more months of digital transaction history '
                'you have, the stronger the signal that Clover can generate. '
                'Try again after building a few more months of digital records.',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  height: 1.6,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionableTip extends StatelessWidget {
  final AnalyzeResponse result;
  const _ActionableTip({required this.result});

  String _tipText() {
    // Pick the most relevant actionable suggestion based on concern features
    final features =
        result.reasonCodes.concerns.map((c) => c.feature).toList();

    if (features.contains('buffer_days')) {
      return 'Try to maintain a cash buffer of at least 15 days of business expenses '
          'in your account. This strengthens the signal and shows lenders you can '
          'handle unexpected slow months.';
    }
    if (features.contains('income_volatility')) {
      return 'Smoothing out your income — for example by diversifying to smaller '
          'orders during off-peak months — can significantly improve your signal '
          'over the next 6 months.';
    }
    if (features.contains('cash_share')) {
      return 'Routing more of your sales through UPI or bank transfer (rather than '
          'cash) gives Clover a clearer digital picture of your income and can '
          'improve your next assessment.';
    }
    return 'Keep your business account active and consistent. Regular digital '
        'transactions over the next 6–12 months will build a stronger financial '
        'track record for future assessments.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2618),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.rocket_launch_outlined, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'One thing you can do to improve',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _tipText(),
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 13,
              height: 1.6,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE5E7EB),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _PlainReasonTile extends StatelessWidget {
  final String text;
  final bool isPositive;
  const _PlainReasonTile({required this.text, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isPositive ? '✓ ' : '• ', style: TextStyle(color: color, fontSize: 14)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 13,
                height: 1.4,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              height: 1.5,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
