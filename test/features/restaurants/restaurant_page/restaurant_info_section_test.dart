import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/open_status_chip.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/restaurant_page/restaurant_info_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Restaurant shop({
  String phone = '',
  String description = '',
  bool isOpen = true,
  String address = '112 Galle Road, Colombo 04',
}) {
  return Restaurant(
    id: 'r1',
    name: 'Kottu Corner',
    cuisine: 'Sri Lankan',
    ownerId: 'o1',
    address: address,
    latitude: 6.9,
    longitude: 79.8,
    phone: phone,
    description: description,
    isOpen: isOpen,
  );
}

void main() {
  late List<String> calls;
  late bool callWorks;

  setUp(() {
    calls = [];
    callWorks = true;
  });

  Future<void> show(WidgetTester tester, Restaurant restaurant) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RestaurantInfoSection(
              restaurant: restaurant,
              callPhone: (phone) async {
                calls.add(phone);
                return callWorks;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder callButton() => find.byKey(const Key('call-shop-button'));

  testWidgets('shows the name, open chip, cuisine and address',
      (tester) async {
    await show(tester, shop());

    expect(find.text('Kottu Corner'), findsOneWidget);
    expect(find.byType(OpenStatusChip), findsOneWidget);
    expect(find.text('Sri Lankan'), findsOneWidget);
    expect(find.text('112 Galle Road, Colombo 04'), findsOneWidget);
  });

  testWidgets('an old shop: no description, no phone, no Call',
      (tester) async {
    await show(tester, shop());

    expect(find.byIcon(Icons.phone_rounded), findsNothing);
    expect(callButton(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the description under the name', (tester) async {
    await show(tester, shop(description: 'Best kottu in town.'));

    final description = find.text('Best kottu in town.');
    expect(description, findsOneWidget);
    expect(
      tester.getRect(description).top,
      greaterThan(tester.getRect(find.text('Kottu Corner')).bottom),
    );
    expect(
      tester.getRect(description).bottom,
      lessThan(tester.getRect(find.text('Sri Lankan')).top),
    );
  });

  testWidgets('shows the phone in groups with a soft orange Call pill',
      (tester) async {
    await show(tester, shop(phone: '0714265830'));

    expect(find.text('071 426 5830'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(
      tester.widget<Material>(callButton()).color,
      AppTheme.softOrange,
    );
  });

  testWidgets('Call opens the phone app with the digits', (tester) async {
    await show(tester, shop(phone: '0714265830'));

    await tester.tap(callButton());
    await tester.pumpAndSettle();

    expect(calls, ['0714265830']);
    expect(find.text('Could not open the phone app.'), findsNothing);
  });

  testWidgets('if the phone app does not open, it says so', (tester) async {
    callWorks = false;
    await show(tester, shop(phone: '0714265830'));

    await tester.tap(callButton());
    await tester.pumpAndSettle();

    expect(find.text('Could not open the phone app.'), findsOneWidget);
  });

  testWidgets('a closed shop still shows the phone and Call',
      (tester) async {
    await show(tester, shop(phone: '0714265830', isOpen: false));

    expect(find.text(RestaurantInfoSection.closedText), findsOneWidget);
    expect(callButton(), findsOneWidget);
  });

  testWidgets('long text with Call does not overflow', (tester) async {
    await show(
      tester,
      shop(
        phone: '0714265830',
        description: 'd' * 150,
        address: 'No. 123, A Very Long Street Name, Bambalapitiya, '
            'Colombo 04, Western Province',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('071 426 5830'), findsOneWidget);
  });
}