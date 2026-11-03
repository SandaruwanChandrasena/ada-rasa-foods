import 'package:material_ui/material_ui.dart';

// Lets the dish photo grow from its card into the big photo on the dish
// page (CUS-14). Off when Reduce animations (in-app or phone) is on.
class DishPhotoHero extends StatelessWidget {
  const DishPhotoHero({super.key, required this.dishId, required this.child});

  final String dishId;
  final Widget child;

  // The same tag on both pages links the two photos.
  static String tagFor(String dishId) => 'dish-photo-$dishId';

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return child;

    return Hero(tag: tagFor(dishId), child: child);
  }
}