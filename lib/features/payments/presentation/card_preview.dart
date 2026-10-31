import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../domain/card_checks.dart';
import 'card_art.dart';
import 'enter_animation.dart';

// Which part of the card has the white focus box on it.
enum CardFocusTarget { number, name, date }

// The live card picture for Add card (CUS-9), from the credit_card_ui project.
// It flips for the CVV, and the focus box moves to the part being typed.
// It is drawn at 430 x 270 and scaled to fit, so it looks the same on
// every phone.
class CardPreview extends StatefulWidget {
  const CardPreview({
    super.key,
    required this.cardNumber,
    required this.cardName,
    required this.cardMonth,
    required this.cardYear,
    required this.cardCvv,
    required this.isFlipped,
    this.focusTarget,
    this.onTapNumber,
    this.onTapName,
  });

  // The number with spaces, like "4242 4242 4242 4242".
  final String cardNumber;
  final String cardName;

  // "08" and "2028". Empty shows "MM" and "YY".
  final String cardMonth;
  final String cardYear;

  final String cardCvv;
  final bool isFlipped;
  final CardFocusTarget? focusTarget;
  final VoidCallback? onTapNumber;
  final VoidCallback? onTapName;

  static const double designWidth = 430;
  static const double designHeight = 270;

  // Every Visa and Mastercard number has 16 digits.
  static const String numberMask = '#### #### #### ####';

  @override
  State<CardPreview> createState() => _CardPreviewState();
}

class _CardPreviewState extends State<CardPreview>
    with SingleTickerProviderStateMixin {
  // The flip takes 0.9 seconds.
  late final AnimationController _flipController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.isFlipped ? 1 : 0,
  );
  late final Animation<double> _flip = CurvedAnimation(
    parent: _flipController,
    curve: smoothCurve,
    reverseCurve: smoothCurve.flipped,
  );

  // Keys to find where each part is on the card, for the focus box.
  final _frontKey = GlobalKey();
  final _numberKey = GlobalKey();
  final _nameKey = GlobalKey();
  final _dateKey = GlobalKey();
  Rect? _focusRect;

  static const double _cardRadius = 26;

  static const _textShadow = [
    Shadow(offset: Offset(7, 6), blurRadius: 10, color: Color(0xCC0E0F18)),
  ];

  // The phone's own monospace font, so no download is needed.
  static const _cardFont = TextStyle(
    fontFamily: 'monospace',
    color: Colors.white,
    fontWeight: FontWeight.w500,
    height: 1,
    shadows: _textShadow,
  );

  @override
  void initState() {
    super.initState();
    if (widget.focusTarget != null) _scheduleMeasure();
  }

  @override
  void didUpdateWidget(CardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isFlipped != widget.isFlipped) {
      widget.isFlipped ? _flipController.forward() : _flipController.reverse();
    }

    if (widget.focusTarget == null) {
      // The box goes back to full card size and fades out.
      _focusRect = null;
    } else {
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = switch (widget.focusTarget) {
        CardFocusTarget.number => _numberKey,
        CardFocusTarget.name => _nameKey,
        CardFocusTarget.date => _dateKey,
        null => null,
      };
      if (key == null) return;
      final rect = _rectOf(key);
      if (rect != null && rect != _focusRect) {
        setState(() => _focusRect = rect);
      }
    });
  }

  // Where a part is, inside the front of the card.
  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final front = _frontKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || front == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero, ancestor: front);
    return offset & box.size;
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: CardPreview.designWidth,
        height: CardPreview.designHeight,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = _flip.value * math.pi;
            final showFront = angle <= math.pi / 2;

            final transform = Matrix4.identity()
              ..setEntry(3, 2, 1 / 1200) // perspective
              ..rotateY(angle);

            // Both sides stay built, so the digits don't animate again.
            return Transform(
              alignment: Alignment.center,
              transform: transform,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Visibility(
                    visible: showFront,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: _side(_buildFront()),
                  ),
                  Visibility(
                    visible: !showFront,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    // A half turn more, so the back text is not mirrored.
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _side(_buildBack()),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Shadow and smooth (superellipse) corners, for both sides.
  Widget _side(Widget child) {
    final radius = BorderRadius.circular(_cardRadius);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: radius),
        shadows: const [
          BoxShadow(
            offset: Offset(0, 25),
            blurRadius: 50,
            color: Color(0x470F172A),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: radius,
        // The softest edge while the card turns in 3D.
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: child,
      ),
    );
  }

  // A new key when the type changes, so the logo fades in again.
  Widget _logo() {
    final brand = CardChecks.brandOf(widget.cardNumber);
    return SizedBox(
      width: 100,
      height: 45,
      child: Align(
        alignment: Alignment.topRight,
        child: EnterAnimation(
          key: ValueKey(brand),
          from: const Offset(0, -8),
          scaleFrom: 0.85,
          duration: const Duration(milliseconds: 400),
          child: CardBrandLogo(brand: brand),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- FRONT

  Widget _buildFront() {
    final fullCard = Offset.zero &
        const Size(CardPreview.designWidth, CardPreview.designHeight);
    final rect = _focusRect ?? fullCard;
    final focusVisible = widget.focusTarget != null && _focusRect != null;

    return Stack(
      key: _frontKey,
      children: [
        const Positioned.fill(child: CardBackground()),

        // The focus box moves and resizes to the part being typed.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: smoothCurve,
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              curve: smoothCurve,
              opacity: focusVisible ? 1 : 0,
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: ShapeDecoration(
                      color: const Color(0x14FFFFFF),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Color(0x8CFFFFFF),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        DefaultTextStyle(
          style: _cardFont,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chip and logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const CardChip(), const Spacer(), _logo()],
                  ),
                ),
                const SizedBox(height: 36),

                // Card number
                GestureDetector(
                  onTap: widget.onTapNumber,
                  child: Container(
                    key: _numberKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildNumberSlots(),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Name and date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildName()),
                    _buildDate(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNumberSlots() {
    const mask = CardPreview.numberMask;
    final number = widget.cardNumber;

    return List.generate(mask.length, (index) {
      final maskChar = mask[index];
      final isSpace = maskChar == ' ';
      final current = index < number.length ? number[index] : null;

      // The middle 8 digits are hidden with "*".
      final shouldMask =
          index > 4 && index < 15 && current != null && !isSpace;
      final shown = shouldMask ? '*' : (current ?? maskChar);

      return SizedBox(
        key: ValueKey('slot-$index'),
        width: isSpace ? 30 : 16,
        child: Center(
          // A new key when the text changes, so it slides up again.
          child: EnterAnimation(
            key: ValueKey('$index-$shown'),
            from: const Offset(0, 12),
            child: Text(
              shown,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 27, letterSpacing: 1),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildName() {
    final name = widget.cardName.replaceAll(RegExp(r'\s\s+'), ' ');

    final List<Widget> letters;
    if (name.isEmpty) {
      letters = const [
        EnterAnimation(
          key: ValueKey('placeholder'),
          from: Offset(10, 0),
          child: Text('FULL NAME'),
        ),
      ];
    } else {
      // One widget per letter, so each new letter slides in.
      letters = List.generate(name.length, (index) {
        final letter = name[index];
        return EnterAnimation(
          key: ValueKey('$index-$letter'),
          from: const Offset(10, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 8),
            child: Text(letter),
          ),
        );
      });
    }

    return GestureDetector(
      onTap: widget.onTapName,
      child: Container(
        key: _nameKey,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Opacity(
              opacity: 0.8,
              child: Text(
                'Card Holder',
                style: TextStyle(fontSize: 13, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            // Long names shrink to fit the card.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 18),
                child: Row(mainAxisSize: MainAxisSize.min, children: letters),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDate() {
    final month = widget.cardMonth.isEmpty ? 'MM' : widget.cardMonth;
    final year = widget.cardYear.length == 4
        ? widget.cardYear.substring(2, 4)
        : 'YY';

    Widget part(String text) => SizedBox(
          width: 22,
          // A new key when the value changes, so it slides up.
          child: EnterAnimation(
            key: ValueKey(text),
            from: const Offset(0, 12),
            child: Text(text, softWrap: false),
          ),
        );

    return Container(
      key: _dateKey,
      width: 80,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Opacity(
            opacity: 0.8,
            child: Text(
              'Expires',
              softWrap: false,
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [part(month), const Text('/'), part(year)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- BACK

  Widget _buildBack() {
    return Stack(
      children: [
        const Positioned.fill(child: CardBackground()),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            // The black magnetic band.
            Container(height: 50, color: const Color(0xCC000013)),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(
                      'CVV',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // The white CVV band.
                  Container(
                    height: 45,
                    padding: const EdgeInsets.only(right: 10),
                    alignment: Alignment.centerRight,
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.cardCvv.length, (index) {
                        // Each star pops in.
                        return EnterAnimation(
                          key: ValueKey('cvv-$index'),
                          scaleFrom: 0.4,
                          duration: const Duration(milliseconds: 250),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 3),
                            child: Text(
                              '*',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF1A2B4B),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Opacity(opacity: 0.8, child: _logo()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}