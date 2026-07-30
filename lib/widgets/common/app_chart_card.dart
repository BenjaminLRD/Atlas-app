import 'package:flutter/material.dart';
import 'app_card.dart';
import 'app_chip.dart';
import 'section_header.dart';

/// Reusable Chart Card container with title, subtitle, period selector chips, and chart child.
class AppChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> periods;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodSelected;
  final Widget chart;

  const AppChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.periods,
    required this.selectedPeriod,
    required this.onPeriodSelected,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SectionHeader(
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: periods.map((p) {
                  final isSelected = p == selectedPeriod;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: AppChip.selectable(
                      label: p,
                      isSelected: isSelected,
                      onTap: () => onPeriodSelected(p),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          chart,
        ],
      ),
    );
  }
}
