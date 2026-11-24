import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

// The round category buttons on Home: All, then one per cuisine.
class CuisineRow extends StatelessWidget {
  const CuisineRow({
    super.key,
    required this.cuisines,
    required this.selected,
    required this.onSelected,
  });

  static const double height = 92;

  final List<String> cuisines;

  // Null means "All".
  final String? selected;
  final ValueChanged<String?> onSelected;

  // Words to look for in a cuisine name, and the icon to show.
  static const _icons = <(List<String>, IconData)>[
    (['sri lankan', 'rice', 'kottu'], Icons.rice_bowl_rounded),
    (['chinese', 'noodle', 'asian'], Icons.ramen_dining_rounded),
    (['pizza', 'italian'], Icons.local_pizza_rounded),
    (['burger', 'fast food'], Icons.lunch_dining_rounded),
    (['indian', 'curry'], Icons.soup_kitchen_rounded),
    (['seafood', 'fish'], Icons.set_meal_rounded),
    (['bakery', 'cake', 'dessert'], Icons.cake_rounded),
    (['cafe', 'coffee'], Icons.local_cafe_rounded),
    (['drink', 'juice'], Icons.local_drink_rounded),
  ];

  static IconData iconFor(String cuisine) {
    final name = cuisine.toLowerCase();
    for (final (words, icon) in _icons) {
      if (words.any(name.contains)) return icon;
    }
    // Fork and knife for any other cuisine.
    return Icons.restaurant_menu_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...cuisines];

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final option = options[index];
          return CuisineButton(
            label: option ?? 'All',
            icon: option == null ? Icons.restaurant_rounded : iconFor(option),
            selected: option == selected,
            onTap: () => onSelected(option),
          );
        },
      ),
    );
  }
}

// One round category button with its name under it.
class CuisineButton extends StatelessWidget {
  const CuisineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const double circle = 56;
  static const Color idleBackground = Color(0xFFF4F4F4);
  static const Duration duration = Duration(milliseconds: 200);

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: reduce ? Duration.zero : duration,
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.brandOrange : idleBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected ? Colors.white : AppTheme.brandOrange,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppTheme.brandOrange : AppTheme.textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}