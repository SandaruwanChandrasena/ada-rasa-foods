import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import 'cart_cubit.dart';
import 'cart_state.dart';
import 'fly_to_cart.dart';

// Cart icon for the top bar, with the number of items on a badge.
// The food photo flies here, then the icon bounces (CUS-7).
class CartIconButton extends StatefulWidget {
  const CartIconButton({super.key});

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton>
    with SingleTickerProviderStateMixin
    implements CartFlyTarget {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  // Grows, shrinks a little, then goes back to normal size.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1), weight: 30),
  ]).animate(_bounce);

  // The page this icon is on.
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    registerCartTarget(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    unregisterCartTarget(this);
    _bounce.dispose();
    super.dispose();
  }

  @override
  Offset? get centerOnScreen {
    if (!mounted) return null;
    // Only the icon on the page the customer sees now.
    final isTopPage = _route?.isCurrent ?? true;
    final box = context.findRenderObject();
    if (!isTopPage || box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  void bounce() {
    if (mounted) _bounce.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      // Counts only dishes that can be ordered now.
      buildWhen: (previous, current) =>
          previous.itemCount != current.itemCount ||
          previous.hasProblem != current.hasProblem,
      builder: (context, state) {
        final count = state.itemCount;
        final problem = state.hasProblem;

        return IconButton(
          tooltip: problem ? 'Cart needs your attention' : 'Cart',
          onPressed: () => context.push(AppRoutes.cart),
          icon: ScaleTransition(
            scale: _scale,
            child: Badge(
              // A problem shows a red "!" in place of the number.
              isLabelVisible: problem || count > 0,
              backgroundColor:
                  problem ? Colors.red.shade700 : AppTheme.brandOrange,
              textColor: Colors.white,
              label: problem
                  ? const Text(
                      '!',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    )
                  : Text(count > 99 ? '99+' : '$count'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        );
      },
    );
  }
}