import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/analyze_response.dart';

class CashflowChart extends StatelessWidget {
  final List<MonthlyCashflow> data;
  const CashflowChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No cashflow data available',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ),
      );
    }

    final spots = <String, List<FlSpot>>{
      'inflow': [],
      'outflow': [],
      'net': [],
    };

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      spots['inflow']!.add(FlSpot(i.toDouble(), d.inflow / 1000));
      spots['outflow']!.add(FlSpot(i.toDouble(), d.outflow / 1000));
      spots['net']!.add(FlSpot(i.toDouble(), d.net / 1000));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Cashflow (₹ thousands)',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _legend(const Color(0xFF4ADE80), 'Inflow'),
            const SizedBox(width: 16),
            _legend(const Color(0xFFF87171), 'Outflow'),
            const SizedBox(width: 16),
            _legend(const Color(0xFF60A5FA), 'Net'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              backgroundColor: const Color(0xFF1A1D2E),
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
                    reservedSize: 36,
                    getTitlesWidget: (val, meta) => Text(
                      '${val.toInt()}k',
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
                    reservedSize: 28,
                    interval: data.length > 6 ? 2 : 1,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      final parts = data[idx].month.split('-');
                      final label = parts.length == 2 ? '${parts[1]}/${parts[0].substring(2)}' : data[idx].month;
                      return Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 9,
                          fontFamily: 'Inter',
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                _line(spots['inflow']!, const Color(0xFF4ADE80)),
                _line(spots['outflow']!, const Color(0xFFF87171)),
                _line(spots['net']!, const Color(0xFF60A5FA), isDashed: true),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF2D3148),
                  getTooltipItems: (spots) => spots.map((s) {
                    final labels = ['Inflow', 'Outflow', 'Net'];
                    final colors = [
                      const Color(0xFF4ADE80),
                      const Color(0xFFF87171),
                      const Color(0xFF60A5FA),
                    ];
                    return LineTooltipItem(
                      '${labels[s.barIndex]}: ₹${(s.y * 1000).toStringAsFixed(0)}',
                      TextStyle(
                        color: colors[s.barIndex],
                        fontSize: 11,
                        fontFamily: 'Inter',
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, {bool isDashed = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dashArray: isDashed ? [6, 4] : null,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 11,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
