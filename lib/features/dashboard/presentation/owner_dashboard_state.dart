import 'package:equatable/equatable.dart';

import '../domain/day_summary.dart';

enum DashboardView { loading, loaded, failure }

// The owner's Home tab.
class OwnerDashboardState extends Equatable {
  const OwnerDashboardState({
    this.view = DashboardView.loading,
    this.summary = const DaySummary(),
    this.errorMessage,
  });

  final DashboardView view;
  final DaySummary summary;

  // Why the numbers could not be loaded.
  final String? errorMessage;

  @override
  List<Object?> get props => [view, summary, errorMessage];
}