import 'package:flutter/material.dart';
import '../mock_backend.dart';
import '../models/portfolio_response.dart';
import '../services/credify_api_service.dart';
import '../widgets/score_histogram_chart.dart';

class PortfolioScreen extends StatefulWidget {
  final CredifyApiService service;
  const PortfolioScreen({super.key, required this.service});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  PortfolioResponse? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.getPortfolio();
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.service is MockBackend
                ? 'Aggregate signal metrics — ILLUSTRATIVE PLACEHOLDER data (mock backend).'
                : 'Aggregate signal metrics — live from the Credify backend.',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!)
          else if (_data != null)
            _PortfolioBody(data: _data!, onRefresh: _load),
        ],
      ),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  final PortfolioResponse data;
  final VoidCallback onRefresh;

  const _PortfolioBody({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Key metrics row
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Profiles Assessed',
                value: data.nProfiles.toString(),
                icon: Icons.people_outline,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Coverage',
                value: '${data.coveragePct.toStringAsFixed(1)}%',
                icon: Icons.verified_outlined,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Model AUC',
                value: data.auc != null ? data.auc!.toStringAsFixed(3) : '—',
                icon: Icons.show_chart,
                color: const Color(0xFF60A5FA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Band distribution
        _Card(
          title: 'Band Distribution',
          icon: Icons.donut_small_outlined,
          child: Column(
            children: [
              _BandBar(
                label: 'Strong Candidate',
                count: data.bandDistribution.strongCandidate,
                total: data.nProfiles,
                color: const Color(0xFF4ADE80),
              ),
              const SizedBox(height: 10),
              _BandBar(
                label: 'Refer for Manual Review',
                count: data.bandDistribution.manualReview,
                total: data.nProfiles,
                color: const Color(0xFFFBBF24),
              ),
              const SizedBox(height: 10),
              _BandBar(
                label: 'High-Risk Referral',
                count: data.bandDistribution.highRiskReferral,
                total: data.nProfiles,
                color: const Color(0xFFF87171),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Score histogram
        _Card(
          title: 'Score Distribution (0–100)',
          icon: Icons.bar_chart,
          child: ScoreHistogramChart(buckets: data.scoreHistogram),
        ),
        const SizedBox(height: 16),

        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF9CA3AF)),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
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

class _BandBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BandBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
            Text(
              '$count (${(pct * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.toDouble(),
            backgroundColor: const Color(0xFF2D3148),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: const Color(0xFF6366F1), size: 18),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          child,
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
        'Error loading portfolio: $message',
        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
      ),
    );
  }
}
