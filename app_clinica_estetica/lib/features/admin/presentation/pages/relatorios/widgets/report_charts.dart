
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_clinica_estetica/core/theme/app_colors.dart';
import 'package:app_clinica_estetica/features/admin/data/models/report_models.dart';

class RevenueLineChart extends StatelessWidget {
  final List<TimeSeriesData> data;
  final Color primaryColor;

  const RevenueLineChart({
    super.key,
    required this.data,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Sem dados no período', style: TextStyle(fontFamily: 'Inter', color: AppColors.textLight)));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  if (value.toInt() % (data.length > 5 ? (data.length / 5).ceil() : 1) == 0) {
                    return Text(
                      DateFormat('dd/MM').format(data[value.toInt()].date),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10, 
                        color: AppColors.textLight,
                      ),
                    );
                  }
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class DistributionPieChart extends StatelessWidget {
  final Map<String, double> data;
  final List<Color> colors;

  const DistributionPieChart({
    super.key,
    required this.data,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Sem dados', style: TextStyle(fontFamily: 'Inter', color: AppColors.textLight)));

    int i = 0;
    final sections = data.entries.map((e) {
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        value: e.value,
        title: e.value.toStringAsFixed(0),
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12, 
          fontWeight: FontWeight.bold, 
          color: AppColors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }
}

class GrowthIndicator extends StatelessWidget {
  final double growth;
  final String label;

  const GrowthIndicator({super.key, required this.growth, required this.label});

  @override
  Widget build(BuildContext context) {
    final bool isPositive = growth >= 0;
    return Row(
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          size: 16,
          color: isPositive ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? "+" : ""}${growth.toStringAsFixed(1)}% $label',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isPositive ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }
}

class CashFlowBarChart extends StatelessWidget {
  final List<CashFlowData> data;
  final Color incomeColor;
  final Color expenseColor;

  const CashFlowBarChart({
    super.key,
    required this.data,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Sem dados', style: TextStyle(fontFamily: 'Inter', color: AppColors.textLight)));

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  if (value.toInt() % (data.length > 5 ? (data.length / 5).ceil() : 1) == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('dd/MM').format(data[value.toInt()].date),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10, 
                          color: AppColors.textLight,
                        ),
                      ),
                    );
                  }
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(toY: e.value.income, color: incomeColor, width: 8, borderRadius: BorderRadius.circular(2)),
              BarChartRodData(toY: e.value.expenses, color: expenseColor, width: 8, borderRadius: BorderRadius.circular(2)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  final List<LegendItem> items;

  const ChartLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12, 
                color: AppColors.textLight,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class LegendItem {
  final String label;
  final Color color;
  LegendItem(this.label, this.color);
}

class PeakBarChart extends StatelessWidget {
  final List<PeakTimeData> data;
  final Color color;

  const PeakBarChart({super.key, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Sem dados', style: TextStyle(fontFamily: 'Inter', color: AppColors.textLight)));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  // Mostrar apenas alguns labels se tiver muitos para evitar sobreposição
                  bool showLabel = true;
                  if (data.length > 12) {
                    showLabel = value.toInt() % 4 == 0;
                  }
                  
                  if (!showLabel) return const SizedBox();

                  String txt = data[value.toInt()].label;
                  // Se for dia da semana, pega apenas os 3 primeiros caracteres
                  if (txt.length > 5) txt = txt.substring(0, 3);

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      txt,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10, 
                        color: AppColors.textLight, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.appointmentsCount.toDouble(),
                color: color,
                width: data.length > 10 ? 12 : 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: data.map((d) => d.appointmentsCount).reduce((a, b) => a > b ? a : b).toDouble(),
                  color: color.withOpacity(0.05),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}


class CommissionBarChart extends StatelessWidget {
  final Map<String, double> data;
  final Color color;

  const CommissionBarChart({super.key, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Sem dados', style: TextStyle(fontFamily: 'Inter', color: AppColors.textLight)));

    final entries = data.entries.toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < entries.length) {
                  String name = entries[value.toInt()].key;
                  if (name.length > 8) name = '${name.substring(0, 7)}...';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10, 
                        color: AppColors.textLight, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        barGroups: entries.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: color,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
