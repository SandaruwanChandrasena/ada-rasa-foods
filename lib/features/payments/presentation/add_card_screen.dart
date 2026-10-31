import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/card_checks.dart';
import 'card_input_formatters.dart';
import 'card_preview.dart';
import 'card_select.dart';
import 'cards_cubit.dart';
import 'cards_state.dart';

// Add card: the live card on top, the form under it (CUS-9).
// From the credit_card_ui project, in Ada Rasa colors.
class AddCardScreen extends StatelessWidget {
  const AddCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthCubit>().state.user?.uid ?? '';

    return BlocProvider<CardsCubit>(
      create: (_) => sl<CardsCubit>()..start(userId),
      child: const AddCardView(),
    );
  }
}

// Public so widget tests can give it a CardsCubit of their own.
class AddCardView extends StatefulWidget {
  const AddCardView({super.key});

  @override
  State<AddCardView> createState() => _AddCardViewState();
}

class _AddCardViewState extends State<AddCardView>
    with SingleTickerProviderStateMixin {
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _cvvController = TextEditingController();

  final _numberFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _cvvFocus = FocusNode();

  String _cardMonth = '';
  String _cardYear = '';
  bool _isFlipped = false;
  CardFocusTarget? _focusTarget;

  // True while the month or year menu is open.
  bool _dateOpen = false;

  // Field errors show only after the first Save tap.
  bool _submitted = false;

  // Waits 200 ms before hiding the focus box.
  Timer? _blurTimer;

  bool _started = false;

  // The page slide-in. Our animation waits until it ends.
  ModalRoute<Object?>? _route;
  Animation<double>? _routeAnimation;

  // The page load animation: 1.5 seconds in total.
  static const int _totalMs = 1500;
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );

  // A soft ease out, gentler than before.
  static const Curve _enterCurve = Cubic(0.25, 1, 0.5, 1);

  late final Animation<double> _cardAnim = _part(0, 700);
  late final Animation<double> _formMove = _part(300, 1300);
  late final Animation<double> _formFade = _part(300, 620);
  late final List<Animation<double>> _itemAnims = [
    for (var i = 0; i < 4; i++) _part(720 + 90 * i, 1200 + 90 * i),
  ];

  @override
  void initState() {
    super.initState();
    _numberController.addListener(_refresh);
    _nameController.addListener(_refresh);
    _cvvController.addListener(_refresh);

    _numberFocus.addListener(_onFocusChange);
    _nameFocus.addListener(_onFocusChange);
    // The card flips while the CVV box has focus.
    _cvvFocus.addListener(() {
      setState(() => _isFlipped = _cvvFocus.hasFocus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again when the page goes on stage. Then check if we can start.
    if (_started) {
      _startIfSlideInDone();
      return;
    }
    _started = true;

    // Phone setting "remove animations": skip the page animation.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _enter.value = 1;
      return;
    }

    // Two animations at once look rushed, so wait for the page slide-in.
    // In its first frame a new page is "offstage" and its animation says
    // "completed" too early, so we also wait until it is on stage.
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (route == null || animation == null || _slideInDone(route)) {
      _enter.forward();
    } else {
      _route = route;
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
    }
  }

  bool _slideInDone(ModalRoute<Object?> route) =>
      !route.offstage && (route.animation?.isCompleted ?? true);

  void _onRouteStatus(AnimationStatus status) => _startIfSlideInDone();

  void _startIfSlideInDone() {
    final route = _route;
    if (route == null || !_slideInDone(route)) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _route = null;
    if (mounted) _enter.forward();
  }

  void _refresh() => setState(() {});

  // ------------------------------------------------------------ FOCUS BOX

  CardFocusTarget? _currentTarget() {
    if (_numberFocus.hasFocus) return CardFocusTarget.number;
    if (_nameFocus.hasFocus) return CardFocusTarget.name;
    if (_dateOpen) return CardFocusTarget.date;
    return null;
  }

  void _onFocusChange() {
    if (_numberFocus.hasFocus || _nameFocus.hasFocus) {
      _showBox();
    } else {
      _hideBoxLater();
    }
  }

  void _showBox() {
    _blurTimer?.cancel();
    setState(() => _focusTarget = _currentTarget());
  }

  // If the user moves to another field within 200 ms, the box just moves.
  void _hideBoxLater() {
    _blurTimer?.cancel();
    _blurTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _focusTarget = _currentTarget());
    });
  }

  void _onDateOpen() {
    _dateOpen = true;
    // Leaves the text box and hides the keyboard.
    FocusManager.instance.primaryFocus?.unfocus();
    _showBox();
  }

  void _onDateClose() {
    _dateOpen = false;
    _hideBoxLater();
  }

  // ------------------------------------------------------------ DATE LISTS

  int get _minYear => DateTime.now().year;

  // No months in the past for this year.
  int get _minMonth {
    if (int.tryParse(_cardYear) == _minYear) return DateTime.now().month;
    return 1;
  }

  List<SelectOption> get _monthOptions => [
        for (var n = _minMonth; n <= 12; n++)
          SelectOption(
            n.toString().padLeft(2, '0'),
            n.toString().padLeft(2, '0'),
          ),
      ];

  List<SelectOption> get _yearOptions => [
        for (var i = 0; i < 12; i++)
          SelectOption('${_minYear + i}', '${_minYear + i}'),
      ];

  void _onYearChanged(String year) {
    setState(() {
      _cardYear = year;
      // A month in the past is not allowed for this year, so clear it.
      if (_cardMonth.isNotEmpty && int.parse(_cardMonth) < _minMonth) {
        _cardMonth = '';
      }
    });
  }

  // ------------------------------------------------------------ ERRORS

  String? get _numberError =>
      _submitted ? CardChecks.numberError(_numberController.text) : null;

  String? get _nameError =>
      _submitted ? CardChecks.nameError(_nameController.text) : null;

  String? get _dateError {
    if (!_submitted) return null;
    if (_cardMonth.isEmpty || _cardYear.isEmpty) {
      return 'Choose the month and year.';
    }
    return CardChecks.expiryError(_expiryText, DateTime.now());
  }

  String? get _cvvError =>
      _submitted ? CardChecks.cvvError(_cvvController.text) : null;

  // Like "08/28", for the card checks.
  String get _expiryText =>
      _cardYear.length == 4 ? '$_cardMonth/${_cardYear.substring(2)}' : '';

  // ------------------------------------------------------------ SAVE

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);

    final hasError = _numberError != null ||
        _nameError != null ||
        _dateError != null ||
        _cvvError != null;
    if (hasError) return;

    final saved = await context.read<CardsCubit>().addCard(
          number: _numberController.text,
          name: _nameController.text,
          expiry: _expiryText,
          cvv: _cvvController.text,
        );
    // Goes back to My cards (or checkout) after a good save.
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _blurTimer?.cancel();
    _enter.dispose();
    _numberController.dispose();
    _nameController.dispose();
    _cvvController.dispose();
    _numberFocus.dispose();
    _nameFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ ANIMATION

  Animation<double> _part(int startMs, int endMs) {
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(startMs / _totalMs, endMs / _totalMs, curve: _enterCurve),
    );
  }

  // 1. The card fades in and grows a little.
  Widget _cardEnter(Widget child) {
    return AnimatedBuilder(
      animation: _cardAnim,
      child: child,
      builder: (context, child) {
        final t = _cardAnim.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
          ),
        );
      },
    );
  }

  // 2. The white form slides down from under the card.
  Widget _formEnter(Widget child) {
    return AnimatedBuilder(
      animation: _enter,
      child: child,
      builder: (context, child) => Opacity(
        opacity: _formFade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -140 * (1 - _formMove.value)),
          child: child,
        ),
      ),
    );
  }

  // 3. The inputs and the button fade up, one after another.
  Widget _itemEnter(int index, Widget child) {
    final a = _itemAnims[index];
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - a.value)),
          child: child,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ BUILD

  @override
  Widget build(BuildContext context) {
    return BlocListener<CardsCubit, CardsState>(
      listenWhen: (previous, current) => previous.noticeId != current.noticeId,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Add card'),
          backgroundColor: const Color(0xFFFFF4EE),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF4EE), Colors.white],
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              // Swipe the page down to close the keyboard.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 32),
              child: LayoutBuilder(builder: _buildLayout),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final cardWidth = constraints.maxWidth * 0.92;
    final cardHeight = cardWidth * 270 / 430;

    // How much the card covers the top of the white form.
    final overlap = cardHeight * 0.48;

    return Stack(
      children: [
        // The white form, behind the card.
        Padding(
          padding: EdgeInsets.only(top: cardHeight - overlap),
          child: _formEnter(_buildPanel(topSpace: overlap + 40)),
        ),

        // The card, on top.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _cardEnter(
              // Drawn once and reused, so the keyboard does not redraw it.
              RepaintBoundary(
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: CardPreview(
                    cardNumber: _numberController.text,
                    cardName: _nameController.text,
                    cardMonth: _cardMonth,
                    cardYear: _cardYear,
                    cardCvv: _cvvController.text,
                    isFlipped: _isFlipped,
                    focusTarget: _focusTarget,
                    onTapNumber: _numberFocus.requestFocus,
                    onTapName: _nameFocus.requestFocus,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel({required double topSpace}) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topSpace, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F1F1)),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 20),
            blurRadius: 50,
            color: Color(0x1A1F2937),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _itemEnter(
            0,
            _CardInput(
              label: 'Card Number',
              hint: '1234 5678 9012 3456',
              controller: _numberController,
              focusNode: _numberFocus,
              keyboardType: TextInputType.number,
              formatters: [CardNumberFormatter()],
              errorText: _numberError,
            ),
          ),
          const SizedBox(height: 20),
          _itemEnter(
            1,
            _CardInput(
              label: 'Card Holder',
              hint: 'NIMAL PERERA',
              controller: _nameController,
              focusNode: _nameFocus,
              keyboardType: TextInputType.name,
              capitalization: TextCapitalization.characters,
              formatters: [CardNameFormatter()],
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 20),
          _itemEnter(2, _buildDateAndCvv()),
          const SizedBox(height: 24),
          _itemEnter(3, _buildSaveArea()),
        ],
      ),
    );
  }

  Widget _buildDateAndCvv() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CardSelect(
                label: 'Expiration Date',
                value: _cardMonth,
                options: _monthOptions,
                placeholder: 'Month',
                onChanged: (month) => setState(() => _cardMonth = month),
                onOpen: _onDateOpen,
                onClose: _onDateClose,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CardSelect(
                label: ' ',
                value: _cardYear,
                options: _yearOptions,
                placeholder: 'Year',
                onChanged: _onYearChanged,
                onOpen: _onDateOpen,
                onClose: _onDateClose,
              ),
            ),
          ],
        ),
        if (_dateError != null) ...[
          const SizedBox(height: 6),
          Text(
            _dateError!,
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
        ],
        const SizedBox(height: 20),
        _CardInput(
          label: 'CVV',
          hint: '123',
          controller: _cvvController,
          focusNode: _cvvFocus,
          keyboardType: TextInputType.number,
          formatters: [CvvFormatter()],
          errorText: _cvvError,
          // Dots, like a password box. The card back shows "***".
          obscure: true,
        ),
      ],
    );
  }

  Widget _buildSaveArea() {
    return BlocBuilder<CardsCubit, CardsState>(
      buildWhen: (previous, current) =>
          previous.isWorking != current.isWorking,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SaveButton(isSaving: state.isWorking, onPressed: _onSave),
            const SizedBox(height: 14),
            // Tells the customer what is (and is not) saved.
            Text(
              'Demo only. No real money is charged. '
              'Only the card type, last 4 digits, name, and expiry are '
              'saved. Never the full number or the CVV.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------ INPUT BOX

// A label and a text box with an orange glow on focus.
class _CardInput extends StatelessWidget {
  const _CardInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.formatters,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.errorText,
    this.obscure = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<TextInputFormatter> formatters;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final String? errorText;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: focusNode,
          builder: (context, child) {
            final focused = focusNode.hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused
                      ? AppTheme.brandOrange
                      : hasError
                          ? Colors.red.shade400
                          : const Color(0xFFE2E8F0),
                ),
                boxShadow: focused
                    ? const [
                        BoxShadow(color: Color(0x1FFF5000), spreadRadius: 4),
                      ]
                    : const [],
              ),
              alignment: Alignment.centerLeft,
              child: child,
            );
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            inputFormatters: formatters,
            obscureText: obscure,
            obscuringCharacter: '•',
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 17, color: Color(0xFF1A2B4B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 17,
                color: Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------ SAVE BUTTON

// Orange gradient button. It sinks a little when pressed.
class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.isSaving, required this.onPressed});

  final bool isSaving;
  final VoidCallback onPressed;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.isSaving ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6A26), AppTheme.brandOrange],
            ),
            boxShadow: const [
              BoxShadow(
                offset: Offset(0, 15),
                blurRadius: 30,
                color: Color(0x40FF5000),
              ),
            ],
          ),
          child: widget.isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Save card',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}