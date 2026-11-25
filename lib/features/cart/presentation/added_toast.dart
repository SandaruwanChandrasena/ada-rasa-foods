import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

// One shared pop-up, so a second dish changes the name, not adds a box.
OverlayEntry? _toastEntry;
final GlobalKey<_AddedToastState> _toastKey = GlobalKey<_AddedToastState>();

// Shows "Added to cart" and the dish name for a short time (CUS-7).
// [lift] is how high above the bottom it sits, over the page's bars.
void showAddedToast(
  BuildContext context, {
  required String dishName,
  double lift = AddedToast.aboveCartBar,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final state = _toastKey.currentState;
  if (_toastEntry != null && state != null) {
    state.show(dishName, lift);
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AddedToast(
      key: _toastKey,
      dishName: dishName,
      lift: lift,
      onDone: () {
        entry.remove();
        if (_toastEntry == entry) _toastEntry = null;
      },
    ),
  );
  _toastEntry = entry;
  overlay.insert(entry);
}

class AddedToast extends StatefulWidget {
  const AddedToast({
    super.key,
    required this.dishName,
    required this.lift,
    required this.onDone,
  });

  // Above the cart bar on the restaurant page.
  static const double aboveCartBar = 92;

  // Above the Add row and the cart bar on the dish page.
  static const double aboveAddRow = 148;

  // How long it stays on the screen.
  static const Duration showFor = Duration(milliseconds: 1500);
  static const Duration slide = Duration(milliseconds: 200);

  final String dishName;
  final double lift;
  final VoidCallback onDone;

  @override
  State<AddedToast> createState() => _AddedToastState();
}

class _AddedToastState extends State<AddedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: AddedToast.slide,
  );

  late final Animation<Offset> _slideIn = Tween(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _appear, curve: Curves.easeOutCubic));

  late String _dishName = widget.dishName;
  late double _lift = widget.lift;
  Timer? _hideTimer;
  bool _started = false;

  // Starts here, not in initState, so Reduce animations is known first.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _appear.duration = reduce ? Duration.zero : AddedToast.slide;
    if (!_started) {
      _started = true;
      _start();
    }
  }

  // A new dish while it shows: change the name and start the time again.
  void show(String dishName, double lift) {
    setState(() {
      _dishName = dishName;
      _lift = lift;
    });
    _start();
  }

  void _start() {
    _hideTimer?.cancel();
    _appear.forward();
    _hideTimer = Timer(AddedToast.showFor, () async {
      await _appear.reverse();
      if (mounted && _appear.value == 0) widget.onDone();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        Positioned(
          left: 32,
          right: 32,
          bottom: _lift + bottomSafe,
          // Taps go through to the dishes under it.
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _appear,
              child: SlideTransition(
                position: _slideIn,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Added to cart',
                                style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _dishName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}