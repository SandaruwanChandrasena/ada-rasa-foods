import 'package:ada_rasa_foods/features/profile/domain/settings_repository.dart';
import 'package:ada_rasa_foods/features/profile/presentation/reduce_animations_cubit.dart';
import 'package:ada_rasa_foods/features/profile/presentation/settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository repository;

  setUp(() {
    repository = MockSettingsRepository();
    when(() => repository.reduceAnimations).thenReturn(false);
    when(() => repository.setReduceAnimations(any()))
        .thenAnswer((_) async {});
  });

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<ReduceAnimationsCubit> show(WidgetTester tester) async {
    phoneSize(tester);
    final cubit = ReduceAnimationsCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<ReduceAnimationsCubit>.value(
        value: cubit,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    return cubit;
  }

  Finder theSwitch() => find.byType(Switch);

  // The page is longer than the screen. This scrolls until the widget is
  // really on the screen, so it can be found and tapped.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('SettingsScreen', () {
    testWidgets('shows every part of the page', (tester) async {
      await show(tester);

      expect(find.text('App settings'), findsOneWidget);
      expect(find.text('Reduce animations'), findsOneWidget);
      expect(find.text('Test cards (demo)'), findsOneWidget);

      await scrollTo(tester, find.text('Order notifications'));
      expect(find.text('Coming soon'), findsOneWidget);

      await scrollTo(tester, find.text('Open source licences'));
      expect(find.text('Version $appVersion'), findsOneWidget);
    });

    testWidgets('the switch starts off when nothing is saved',
        (tester) async {
      await show(tester);

      expect(tester.widget<Switch>(theSwitch()).value, isFalse);
    });

    testWidgets('the switch starts on when it was saved on',
        (tester) async {
      when(() => repository.reduceAnimations).thenReturn(true);
      await show(tester);

      expect(tester.widget<Switch>(theSwitch()).value, isTrue);
    });

    testWidgets('tapping the switch turns it on and saves it',
        (tester) async {
      final cubit = await show(tester);

      await tester.tap(find.text('Reduce animations'));
      await tester.pumpAndSettle();

      expect(cubit.state, isTrue);
      expect(tester.widget<Switch>(theSwitch()).value, isTrue);
      verify(() => repository.setReduceAnimations(true)).called(1);
    });

    testWidgets('shows the 5 test cards, and which one fails',
        (tester) async {
      await show(tester);

      expect(find.text('4242 4242 4242 4242'), findsOneWidget);
      expect(find.text('4111 1111 1111 1111'), findsOneWidget);
      expect(find.text('5555 5555 5555 4444'), findsOneWidget);
      expect(find.text('5105 1051 0510 5100'), findsOneWidget);
      expect(find.text('4000 0000 0000 0002'), findsOneWidget);
      expect(find.text('Visa, always fails'), findsOneWidget);
    });

    testWidgets('tapping a test card copies its number', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await show(tester);

      await tester.tap(find.text('5555 5555 5555 4444'));
      await tester.pumpAndSettle();

      expect(copied, '5555 5555 5555 4444');
      expect(find.text('Copied 5555 5555 5555 4444'), findsOneWidget);
    });

    testWidgets('notifications is turned off for now', (tester) async {
      await show(tester);
      await scrollTo(tester, find.text('Order notifications'));

      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Order notifications'),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('About shows the name, version, and licences button',
        (tester) async {
      await show(tester);
      await scrollTo(tester, find.text('Open source licences'));

      expect(find.text('Ada Rasa'), findsOneWidget);
      expect(find.text('Version $appVersion'), findsOneWidget);
      expect(
        find.text(
          'A food delivery app prototype. Demo only, no real payments.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the licences button opens the licences page',
        (tester) async {
      await show(tester);
      await scrollTo(tester, find.text('Open source licences'));

      await tester.tap(find.text('Open source licences'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  group('ReduceAnimationsScope', () {
    // Reads what the screens see.
    Future<bool> animationsOffInside(
      WidgetTester tester, {
      required bool appSwitch,
      required bool phoneSetting,
    }) async {
      when(() => repository.reduceAnimations).thenReturn(appSwitch);
      final cubit = ReduceAnimationsCubit(repository);
      addTearDown(cubit.close);
      var seen = false;

      await tester.pumpWidget(
        BlocProvider<ReduceAnimationsCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: phoneSetting),
                child: ReduceAnimationsScope(
                  child: Builder(
                    builder: (context) {
                      seen = MediaQuery.disableAnimationsOf(context);
                      return const SizedBox();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return seen;
    }

    testWidgets('both off: animations stay on', (tester) async {
      final off = await animationsOffInside(
        tester,
        appSwitch: false,
        phoneSetting: false,
      );
      expect(off, isFalse);
    });

    testWidgets('app switch on: animations are off', (tester) async {
      final off = await animationsOffInside(
        tester,
        appSwitch: true,
        phoneSetting: false,
      );
      expect(off, isTrue);
    });

    testWidgets('phone setting on: animations are off', (tester) async {
      final off = await animationsOffInside(
        tester,
        appSwitch: false,
        phoneSetting: true,
      );
      expect(off, isTrue);
    });

    testWidgets('turning the switch on changes it at once', (tester) async {
      when(() => repository.reduceAnimations).thenReturn(false);
      final cubit = ReduceAnimationsCubit(repository);
      addTearDown(cubit.close);
      var seen = false;

      await tester.pumpWidget(
        BlocProvider<ReduceAnimationsCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: ReduceAnimationsScope(
              child: Builder(
                builder: (context) {
                  seen = MediaQuery.disableAnimationsOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(seen, isFalse);

      await cubit.set(true);
      await tester.pump();

      expect(seen, isTrue);
    });
  });
}