import 'package:ada_rasa_foods/features/menu/domain/dish.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_cubit.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_screen.dart';
import 'package:ada_rasa_foods/features/menu/presentation/menu_manage_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuManageCubit extends MockCubit<MenuManageState>
    implements MenuManageCubit {}

Dish dish(
  String id, {
  String name = 'Chicken Kottu',
  String category = 'Kottu',
  bool available = true,
}) {
  return Dish(
    id: id,
    restaurantId: 'r1',
    name: name,
    price: 1200,
    category: category,
    available: available,
  );
}

MenuManageState loaded(List<Dish> dishes, {Set<String> busyIds = const {}}) {
  return MenuManageState(
    view: MenuView.loaded,
    dishes: dishes,
    busyIds: busyIds,
  );
}

void main() {
  late MockMenuManageCubit cubit;
  late int addTaps;
  late List<Dish> edited;

  setUpAll(() => registerFallbackValue(dish('fallback')));

  setUp(() {
    cubit = MockMenuManageCubit();
    addTaps = 0;
    edited = [];
    when(
      () => cubit.setAvailable(any(), available: any(named: 'available')),
    ).thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester,
    MenuManageState state, {
    Stream<MenuManageState>? changes,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (changes != null) {
      whenListen(cubit, changes, initialState: state);
    } else {
      when(() => cubit.state).thenReturn(state);
    }

    await tester.pumpWidget(
      BlocProvider<MenuManageCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: MenuManageView(
            onAdd: () => addTaps++,
            onEdit: edited.add,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('shows a spinner while loading', (tester) async {
    await show(tester, const MenuManageState(), settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a load error shows Retry', (tester) async {
    await show(
      tester,
      const MenuManageState(
        view: MenuView.failure,
        errorMessage: 'No internet connection.',
      ),
    );

    await tester.tap(find.text('Retry'));

    expect(find.text('No internet connection.'), findsOneWidget);
    verify(() => cubit.retry()).called(1);
  });

  testWidgets('an empty menu invites the first dish', (tester) async {
    await show(tester, loaded(const []));

    await tester.tap(find.text('Add your first dish'));

    expect(find.text('No dishes yet.'), findsOneWidget);
    expect(addTaps, 1);
  });

  testWidgets('dishes show under their category', (tester) async {
    await show(
      tester,
      loaded([
        dish('d2', name: 'Iced Milo', category: 'Drinks'),
        dish('d1'),
      ]),
    );

    expect(find.text('Drinks'), findsOneWidget);
    expect(find.text('Kottu'), findsOneWidget);
    expect(find.text('Iced Milo'), findsOneWidget);
    expect(find.text('Chicken Kottu'), findsOneWidget);
    expect(find.text('Rs. 1,200'), findsNWidgets(2));
  });

  testWidgets('Add dish calls onAdd', (tester) async {
    await show(tester, loaded([dish('d1')]));

    await tester.tap(find.text('Add dish'));

    expect(addTaps, 1);
  });

  testWidgets('tapping a dish opens it for editing', (tester) async {
    final kottu = dish('d1');
    await show(tester, loaded([kottu]));

    await tester.tap(find.text('Chicken Kottu'));

    expect(edited, [kottu]);
  });

  testWidgets('the switch hides an available dish', (tester) async {
    final kottu = dish('d1');
    await show(tester, loaded([kottu]));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    verify(() => cubit.setAvailable(kottu, available: false)).called(1);
  });

  testWidgets('a hidden dish shows Not available and an off switch',
      (tester) async {
    await show(tester, loaded([dish('d1', available: false)]));

    expect(find.text('Not available'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('a saving dish shows a spinner, not the switch',
      (tester) async {
    await show(
      tester,
      loaded([dish('d1')], busyIds: {'d1'}),
      settle: false,
    );

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a message shows in a bar', (tester) async {
    final first = loaded([dish('d1')]);
    final second = MenuManageState(
      view: MenuView.loaded,
      dishes: first.dishes,
      notice: 'Chicken Kottu is hidden from customers.',
      noticeId: 1,
    );

    await show(tester, first, changes: Stream.value(second));

    expect(
      find.text('Chicken Kottu is hidden from customers.'),
      findsOneWidget,
    );
  });
}