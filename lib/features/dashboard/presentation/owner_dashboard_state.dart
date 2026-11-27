import 'package:equatable/equatable.dart';

import '../domain/dash_period.dart';
import '../domain/day_summary.dart';

enum DashboardView { loading, loaded, failure }

// The owner's Home tab.
class OwnerDashboardState extends Equatable {
  const OwnerDashboardState({
    this.view = DashboardView.loading,
    this.period = DashPeriod.today,
    this.summary = const DaySummary(),
    this.weekSales = const [0, 0, 0, 0, 0, 0, 0],
    this.today,
    this.errorMessage,
  });

  final DashboardView view;

  // The picked switch: Today, 7 days or 30 days.
  final DashPeriod period;

  // The numbers for [period].
  final DaySummary summary;

  // The chart: sales of the last 7 days, today last.
  final List<int> weekSales;

  // Midnight today, so the chart can name the days. Null until loaded.
  final DateTime? today;

  // Why the numbers could not be loaded.
  final String? errorMessage;

  @override
  List<Object?> get props => [
        view,
        period,
        summary,
        weekSales,
        today,
        errorMessage,
      ];
}