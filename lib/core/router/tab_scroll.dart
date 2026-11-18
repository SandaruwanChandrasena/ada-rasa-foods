import 'package:material_ui/material_ui.dart';

// Tells the tab pages that a tab was tapped while it was already open.
class TabReselectSignal extends ChangeNotifier {
  int? _tab;

  // The tab that was tapped again last.
  int? get tab => _tab;

  void reselect(int tab) {
    _tab = tab;
    notifyListeners();
  }
}

// Gives the tab pages the shell's signal.
class TabReselectScope extends InheritedWidget {
  const TabReselectScope({
    super.key,
    required this.signal,
    required super.child,
  });

  final TabReselectSignal signal;

  static TabReselectSignal? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<TabReselectScope>()?.signal;
  }

  @override
  bool updateShouldNotify(TabReselectScope oldWidget) =>
      signal != oldWidget.signal;
}

// Scrolls a tab page's main list back to the top when its tab is tapped
// again. The list needs no changes: it uses this as its controller.
class TabScroll extends StatefulWidget {
  const TabScroll({super.key, required this.tab, required this.child});

  static const Duration duration = Duration(milliseconds: 300);

  final int tab;
  final Widget child;

  @override
  State<TabScroll> createState() => _TabScrollState();
}

class _TabScrollState extends State<TabScroll> {
  final _controller = ScrollController();
  TabReselectSignal? _signal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final signal = TabReselectScope.maybeOf(context);
    if (signal == _signal) return;
    _signal?.removeListener(_onReselect);
    _signal = signal?..addListener(_onReselect);
  }

  void _onReselect() {
    if (_signal?.tab != widget.tab) return;
    // No list yet (still loading), or already at the top.
    if (!_controller.hasClients || _controller.offset <= 0) return;

    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _controller.jumpTo(0);
    } else {
      _controller.animateTo(
        0,
        duration: TabScroll.duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _signal?.removeListener(_onReselect);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      child: widget.child,
    );
  }
}