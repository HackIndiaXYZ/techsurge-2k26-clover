import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/portfolio_response.dart';

class ScoreHistogramChart extends StatelessWidget {
  final List<ScoreBucket> buckets;
  const ScoreHistogramChart({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No histogram data',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    final maxCount = buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          backgroundColor: Colors.transparent,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: const Color(0xFF2D3148),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= buckets.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      buckets[idx].bucket,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 10,
                        fontFamily: 'Inter',
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          maxY: (maxCount * 1.25).ceilToDouble(),
          barGroups: buckets.asMap().entries.map((entry) {
            final idx = entry.key;
            final b = entry.value;
            // Color gradient: low scores red → high scores green
            final fraction = idx / (buckets.length - 1);
            final color = Color.lerp(
              const Color(0xFFF87171),
              const Color(0xFF4ADE80),
              fraction,
            )!;
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: b.count.toDouble(),
                  color: color,
                  width: 36,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF2D3148),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${buckets[group.x].bucket}\n${rod.toY.toInt()} profiles',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
