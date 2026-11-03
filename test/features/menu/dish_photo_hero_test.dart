import 'package:ada_rasa_foods/features/menu/presentation/dish_photo_hero.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> show(WidgetTester tester, {bool reduceMotion = false}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Builder(
          // Like the app's Reduce animations switch does.
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: const Scaffold(
              body: DishPhotoHero(
                dishId: 'd1',
                child: SizedBox(key: Key('photo'), width: 84, height: 84),
              ),
            ),
          ),
        ),
      ),
    );
  }

  test('the tag is made from the dish id', () {
    expect(DishPhotoHero.tagFor('d1'), 'dish-photo-d1');
    expect(DishPhotoHero.tagFor('d1'), isNot(DishPhotoHero.tagFor('d2')));
  });

  testWidgets('normally the photo is a Hero with the dish tag',
      (tester) async {
    await show(tester);

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'dish-photo-d1');
    expect(find.byKey(const Key('photo')), findsOneWidget);
  });

  testWidgets('Reduce animations: no Hero, just the photo', (tester) async {
    await show(tester, reduceMotion: true);

    expect(find.byType(Hero), findsNothing);
    expect(find.byKey(const Key('photo')), findsOneWidget);
  });
}