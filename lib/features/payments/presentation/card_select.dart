import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

// The month or year picker, from the credit_card_ui project.
// The menu opens above the box, with a fade and a small slide.
// A tap outside closes it.

class SelectOption {
  const SelectOption(this.value, this.label);

  final String value;
  final String label;
}

class CardSelect extends StatefulWidget {
  const CardSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.placeholder,
    required this.onChanged,
    this.errorText,
    this.onOpen,
    this.onClose,
  });

  final String label;

  // Empty means nothing is picked yet.
  final String value;

  final List<SelectOption> options;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final String? errorText;

  // The card moves its focus box to the date while the menu is open.
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  State<CardSelect> createState() => _CardSelectState();
}

class _CardSelectState extends State<CardSelect>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  // Taps inside the box or inside the menu count as "inside".
  final Object _tapGroup = Object();

  late final AnimationController _menuController;
  late final Animation<double> _menuAnim;

  bool _open = false;
  double _width = 0;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _menuAnim = CurvedAnimation(parent: _menuController, curve: Curves.ease);
  }

  void _openMenu() {
    if (_open) return;
    setState(() => _open = true);
    _portal.show();
    _menuController.forward(from: 0);
    widget.onOpen?.call();
  }

  void _closeMenu() {
    if (!_open) return;
    setState(() => _open = false);
    widget.onClose?.call();

    // Play the close animation, then remove the menu.
    _menuController.reverse().whenComplete(() {
      if (mounted && !_open) _portal.hide();
    });
  }

  void _toggle() => _open ? _closeMenu() : _openMenu();

  void _select(String value) {
    widget.onChanged(value);
    _closeMenu();
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? shown;
    for (final option in widget.options) {
      if (option.value == widget.value) shown = option.label;
    }

    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (_) => _closeMenu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _portal,
              overlayChildBuilder: _buildMenu,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The menu is as wide as the box.
                  _width = constraints.maxWidth;
                  return _buildBox(shown);
                },
              ),
            ),
          ),
          if (widget.errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.errorText!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  // The box you tap.
  Widget _buildBox(String? shown) {
    final hasError = widget.errorText != null;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _open
                ? AppTheme.brandOrange
                : hasError
                    ? Colors.red.shade400
                    : const Color(0xFFE2E8F0),
          ),
          boxShadow: _open
              ? const [BoxShadow(color: Color(0x1FFF5000), spreadRadius: 4)]
              : const [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                shown ?? widget.placeholder,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  color: shown == null
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1A2B4B),
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF3B4D6B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The list that opens above the box.
  Widget _buildMenu(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -6),
        child: TapRegion(
          groupId: _tapGroup,
          child: AnimatedBuilder(
            animation: _menuAnim,
            builder: (context, child) {
              final t = _menuAnim.value;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: Transform.scale(
                    scale: 0.98 + 0.02 * t,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              );
            },
            child: SizedBox(
              width: _width,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      offset: Offset(0, 18),
                      blurRadius: 40,
                      color: Color(0x240F172A),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: widget.options.map(_buildOption).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(SelectOption option) {
    final selected = option.value == widget.value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _select(option.value),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? const Color(0xFFFFF1EA) : null,
          ),
          child: Text(
            option.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected
                  ? AppTheme.brandOrange
                  : const Color(0xFF1E3354),
            ),
          ),
        ),
      ),
    );
  }
}