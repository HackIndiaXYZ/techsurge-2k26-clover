import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analyze_response.dart';
import '../state/app_state.dart';
import '../widgets/score_gauge.dart';
import '../widgets/cashflow_chart.dart';

class LenderScreen extends StatelessWidget {
  const LenderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Lender Assessment Panel'),
              const SizedBox(height: 4),
              Text(
                'Profile: ${state.selectedProfileId}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 20),

              // ── Step 1: Traditional bureau check ────────────────────────
              _StepCard(
                stepNumber: '1',
                title: 'Traditional Bureau Check',
                child: state.lenderStep == LenderStep.idle
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: state.consentApproved
                              ? () => state.runBureauCheck()
                              : null,
                          icon: const Icon(Icons.search),
                          label: const Text('Run Bureau Check'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      )
                    : _BureauDeadEndCard(),
              ),

              if (!state.consentApproved && state.lenderStep == LenderStep.idle)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 6),
                      const Text(
                        'Awaiting borrower consent — go to Consent tab first.',
                        style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── Step 2: Clover alternative-data check ────────────────────
              if (state.lenderStep == LenderStep.bureauChecked ||
                  state.lenderStep == LenderStep.clovering ||
                  state.lenderStep == LenderStep.done)
                _StepCard(
                  stepNumber: '2',
                  title: 'Clover Alternative-Data Check',
                  child: state.lenderStep == LenderStep.bureauChecked
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => state.runCloverAnalysis(),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Run Clover Alternative-Data Check'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        )
                      : state.analyzeLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            )
                          : state.analyzeError != null
                              ? _ErrorCard(message: state.analyzeError!)
                              : state.analyzeResult != null
                                  ? _CloverResultView(result: state.analyzeResult!)
                                  : const SizedBox(),
                ),

              if (state.lenderStep == LenderStep.done)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton.icon(
                    onPressed: () => state.resetLenderFlow(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Run Another Check'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Bureau dead-end card (the core storytelling beat) ─────────────────────
class _BureauDeadEndCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No credit history found',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to score with a traditional bureau check.',
            style: TextStyle(
              color: Color(0xFFFCA5A5),
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This borrower is "credit invisible" — no bureau record exists. '
            'Traditional scoring cannot proceed.',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              height: 1.5,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clover result view ───────────────────────────────────────────────────
class _CloverResultView extends StatelessWidget {
  final AnalyzeResponse result;
  const _CloverResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.isNotAssessable || result.isLowConfidence) {
      return _NotAssessableCard(result: result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score gauge
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ScoreGauge(
              score: result.vitalityScore!,
              band: result.band,
              confidence: result.confidence,
            ),
          ),
        ),
        const Divider(color: Color(0xFF2D3148), height: 32),

        // Affordability
        _subHeader('Indicative EMI Affordability'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AffordabilityTile(
                label: 'EMI Range',
                value:
                    '₹${_fmt(result.affordability.indicativeEmiLow)} – ₹${_fmt(result.affordability.indicativeEmiHigh)}',
                icon: Icons.currency_rupee,
                color: const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AffordabilityTile(
                label: 'Months covered (last 24)',
                value: '${result.affordability.monthsWouldCoverEmiOfLast24} / 24',
                icon: Icons.calendar_month,
                color: const Color(0xFF4ADE80),
              ),
            ),
          ],
        ),
        const Divider(color: Color(0xFF2D3148), height: 32),

        // Strengths
        if (result.reasonCodes.strengths.isNotEmpty) ...[
          _subHeader('Signal Strengths'),
          const SizedBox(height: 8),
          ...result.reasonCodes.strengths.map((s) => _ReasonTile(
                item: s,
                isStrength: true,
              )),
        ],

        // Concerns
        if (result.reasonCodes.concerns.isNotEmpty) ...[
          const SizedBox(height: 12),
          _subHeader('Areas of Concern'),
          const SizedBox(height: 8),
          ...result.reasonCodes.concerns.map((c) => _ReasonTile(
                item: c,
                isStrength: false,
              )),
        ],

        const Divider(color: Color(0xFF2D3148), height: 32),

        // Cashflow chart
        _subHeader('24-Month Cashflow Trend'),
        const SizedBox(height: 12),
        CashflowChart(data: result.monthlyCashflow),
      ],
    );
  }

  Widget _subHeader(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE5E7EB),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      );

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

// ── NOT_ASSESSABLE / LOW_CONFIDENCE honest explanation card ──────────────
class _NotAssessableCard extends StatelessWidget {
  final AnalyzeResponse result;
  const _NotAssessableCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isLow = result.isLowConfidence;
    final color = isLow ? const Color(0xFFFBBF24) : const Color(0xFF6B7280);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFF292519) : const Color(0xFF1E2030),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLow ? Icons.info_outline : Icons.block,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isLow
                      ? 'Low-Confidence Signal — Manual Review Required'
                      : 'Signal Not Assessable',
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.coverageReason ?? 'Insufficient data to generate a reliable signal.',
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 13,
              height: 1.6,
              fontFamily: 'Inter',
            ),
          ),
          if (isLow && result.vitalityScore != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.show_chart, color: Color(0xFFFBBF24), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Indicative signal (low confidence):',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${result.vitalityScore!.toStringAsFixed(1)} / 100  ·  Band: ${_bandLabel(result.band)}',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Next step: refer to manual underwriting. Do not make a lending '
            'decision based solely on this signal.',
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
    );
  }

  String _bandLabel(String? b) {
    switch (b) {
      case 'strong_candidate':
        return 'Strong Candidate';
      case 'manual_review':
        return 'Manual Review';
      case 'high_risk_referral':
        return 'High-Risk Referral';
      default:
        return '—';
    }
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final Widget child;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D3148), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AffordabilityTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AffordabilityTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final ReasonItem item;
  final bool isStrength;

  const _ReasonTile({required this.item, required this.isStrength});

  @override
  Widget build(BuildContext context) {
    final color = isStrength ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24);
    final icon = isStrength ? Icons.trending_up : Icons.warning_amber_outlined;
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
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.statement,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 13,
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Feature: ${item.feature}  ·  Weight: ${(item.contribution * 100).abs().toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1515),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Text(
        'Error: $message',
        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
      ),
    );
  }
}

Widget _sectionHeader(String text) => Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    );
