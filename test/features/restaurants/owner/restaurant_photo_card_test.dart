import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/photo_confirm_sheet.dart';
import 'package:ada_rasa_foods/features/menu/domain/photo_picker.dart';
import 'package:ada_rasa_foods/features/restaurants/domain/restaurant.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/my_restaurant_cubit.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/restaurant_photo_card.dart';
import 'package:ada_rasa_foods/features/restaurants/presentation/owner/restaurant_photo_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockMyRestaurantCubit extends MockCubit<MyRestaurantState>
    implements MyRestaurantCubit {}

class MockRestaurantPhotoCubit extends MockCubit<RestaurantPhotoState>
    implements RestaurantPhotoCubit {}

const noPhoto = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
);

const withPhoto = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
  imageUrl: 'https://example.com/shop.jpg',
);

const withDetails = Restaurant(
  id: 'r1',
  name: 'Kottu Corner',
  cuisine: 'Sri Lankan',
  ownerId: 'o1',
  address: 'Colombo',
  latitude: 6.9,
  longitude: 79.8,
  phone: '0712345678',
  description: 'Best kottu in town.',
);

const pickedPath = '/cache/shop.jpg';

void main() {
  late MockMyRestaurantCubit myRestaurant;
  late MockRestaurantPhotoCubit photo;
  late List<Restaurant> editOpened;

  // any() needs a sample value for the confirm function type.
  setUpAll(() {
    Future<PhotoChoice> fallback(String path) async => PhotoChoice.cancel;
    registerFallbackValue(fallback);
  });

  setUp(() {
    myRestaurant = MockMyRestaurantCubit();
    photo = MockRestaurantPhotoCubit();
    editOpened = [];
    when(() => photo.state).thenReturn(const RestaurantPhotoState());
    when(
      () => photo.pickAndUpload(confirm: any(named: 'confirm')),
    ).thenAnswer((_) async {});
    when(() => photo.removePhoto()).thenAnswer((_) async {});
  });

  void showRestaurant(Restaurant? restaurant) {
    when(() => myRestaurant.state).thenReturn(
      restaurant == null
          ? const MyRestaurantState()
          : MyRestaurantState(
              view: MyRestaurantView.loaded,
              restaurant: restaurant,
            ),
    );
  }

  Future<void> show(WidgetTester tester, {Restaurant? restaurant}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    showRestaurant(restaurant);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<MyRestaurantCubit>.value(value: myRestaurant),
          BlocProvider<RestaurantPhotoCubit>.value(value: photo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RestaurantPhotoCard(
                onEditShop: (_, restaurant) => editOpened.add(restaurant),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder photoBox() => find.byKey(const Key('restaurant-photo-box'));
  Finder removeButton() => find.byKey(const Key('remove-photo-button'));
  Finder changeButton() => find.byKey(const Key('change-photo-button'));
  Finder editButton() => find.byKey(const Key('edit-shop-button'));

  InkWell tapArea(WidgetTester tester, Finder button) => tester.widget<InkWell>(
        find.descendant(of: button, matching: find.byType(InkWell)),
      );

  testWidgets('shows nothing until the restaurant loads', (tester) async {
    await show(tester);

    expect(photoBox(), findsNothing);
    expect(find.text('Add a photo'), findsNothing);
    expect(find.text('Kottu Corner'), findsNothing);
  });

  testWidgets('no photo: Add a photo, and no photo buttons',
      (tester) async {
    await show(tester, restaurant: noPhoto);

    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
    expect(removeButton(), findsNothing);
    expect(changeButton(), findsNothing);
  });

  testWidgets('a photo: Remove and Change photo sit under it',
      (tester) async {
    await show(tester, restaurant: withPhoto);

    expect(find.text('Add a photo'), findsNothing);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);
    final photoBottom = tester.getRect(photoBox()).bottom;
    expect(tester.getRect(changeButton()).top, greaterThan(photoBottom));
    expect(tester.getRect(removeButton()).top, greaterThan(photoBottom));
  });

  testWidgets('Remove is soft red and Change photo soft orange',
      (tester) async {
    await show(tester, restaurant: withPhoto);

    Color? background(Finder button) => tester
        .widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)).first,
        )
        .color;
    Color? iconColor(Finder button) => tester
        .widget<Icon>(
          find.descendant(of: button, matching: find.byType(Icon)),
        )
        .color;

    expect(background(removeButton()), AppTheme.dangerBg);
    expect(iconColor(removeButton()), AppTheme.dangerRed);
    expect(background(changeButton()), AppTheme.softOrange);
    expect(iconColor(changeButton()), AppTheme.deepOrange);
  });

  testWidgets('the cover is 180 high', (tester) async {
    await show(tester, restaurant: withPhoto);

    expect(tester.getSize(photoBox()).height, 180);
  });

  Finder row(String name) => find.byKey(Key('shop-row-$name'));

  Finder textIn(String name, String text) =>
      find.descendant(of: row(name), matching: find.text(text));

  testWidgets('Shop details shows each detail in its own row',
      (tester) async {
    await show(tester, restaurant: noPhoto);

    expect(find.text('Shop details'), findsOneWidget);
    expect(textIn('name', 'Shop name'), findsOneWidget);
    expect(textIn('name', 'Kottu Corner'), findsOneWidget);
    expect(textIn('cuisine', 'Cuisine'), findsOneWidget);
    expect(textIn('cuisine', 'Sri Lankan'), findsOneWidget);
    expect(textIn('address', 'Address'), findsOneWidget);
    expect(textIn('address', 'Colombo'), findsOneWidget);
  });

  testWidgets('the rows go down in order, under the photo', (tester) async {
    await show(tester, restaurant: noPhoto);

    final tops = [
      for (final name in ['name', 'cuisine', 'phone', 'description'])
        tester.getRect(row(name)).top,
      tester.getRect(row('address')).top,
    ];
    expect(tops.first, greaterThan(tester.getRect(photoBox()).bottom));
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]));
    }
  });

  testWidgets('an empty phone and description say Not set',
      (tester) async {
    await show(tester, restaurant: noPhoto);

    expect(textIn('phone', 'Not set'), findsOneWidget);
    expect(textIn('description', 'Not set'), findsOneWidget);
  });

  testWidgets('shows the phone in groups and the description',
      (tester) async {
    await show(tester, restaurant: withDetails);

    expect(textIn('phone', '071 234 5678'), findsOneWidget);
    expect(textIn('description', 'Best kottu in town.'), findsOneWidget);
    expect(find.text('Not set'), findsNothing);
  });

  testWidgets('the Edit pill opens Edit shop for this shop', (tester) async {
    await show(tester, restaurant: noPhoto);

    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(editButton());
    await tester.pump();

    expect(editOpened, [noPhoto]);
  });

  testWidgets('tapping a detail row opens Edit shop too', (tester) async {
    await show(tester, restaurant: noPhoto);

    for (final name in ['name', 'cuisine', 'phone', 'description']) {
      await tester.ensureVisible(row(name));
      await tester.tap(row(name));
      await tester.pump();
    }

    expect(editOpened, hasLength(4));
    expect(
      find.descendant(
        of: row('name'),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the address is grey with a lock and does not open',
      (tester) async {
    await show(tester, restaurant: noPhoto);

    expect(
      find.descendant(
        of: row('address'),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );
    final pin = tester.widget<Icon>(
      find.descendant(
        of: row('address'),
        matching: find.byIcon(Icons.location_on_rounded),
      ),
    );
    expect(pin.color, AppTheme.textMuted);

    await tester.ensureVisible(row('address'));
    await tester.tap(row('address'));
    await tester.pump();

    expect(editOpened, isEmpty);
  });

  testWidgets('a very long name does not overflow', (tester) async {
    const longName = Restaurant(
      id: 'r1',
      name: 'The Very Long Named Kottu And Rice Corner Of Colombo Fort',
      cuisine: 'Sri Lankan',
      ownerId: 'o1',
      address: 'No. 123, A Very Long Street Name, Colombo 03',
      latitude: 6.9,
      longitude: 79.8,
    );

    await show(tester, restaurant: longName);

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the empty box starts the pick', (tester) async {
    await show(tester, restaurant: noPhoto);

    await tester.tap(find.text('Add a photo'));
    await tester.pump();

    verify(() => photo.pickAndUpload(confirm: any(named: 'confirm'))).called(1);
  });

  testWidgets('tapping the photo also starts the pick', (tester) async {
    await show(tester, restaurant: withPhoto);

    await tester.tap(photoBox());
    await tester.pump();

    verify(() => photo.pickAndUpload(confirm: any(named: 'confirm'))).called(1);
  });

  testWidgets('the camera button starts the pick', (tester) async {
    await show(tester, restaurant: withPhoto);

    await tester.tap(changeButton());
    await tester.pump();

    verify(() => photo.pickAndUpload(confirm: any(named: 'confirm'))).called(1);
  });

  testWidgets('the pick shows the Use this photo sheet', (tester) async {
    await show(tester, restaurant: noPhoto);
    await tester.tap(photoBox());
    await tester.pump();
    final confirm = verify(
      () => photo.pickAndUpload(confirm: captureAny(named: 'confirm')),
    ).captured.single as ConfirmPhoto;

    final choice = confirm(pickedPath);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoConfirmSheet), findsOneWidget);
    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();

    expect(await choice, PhotoChoice.use);
    expect(find.byType(PhotoConfirmSheet), findsNothing);
  });

  testWidgets('uploading shows the picked photo and the progress',
      (tester) async {
    when(() => photo.state).thenReturn(
      const RestaurantPhotoState(
        status: RestaurantPhotoStatus.uploading,
        photoPath: pickedPath,
        uploadProgress: 0.45,
      ),
    );
    await show(tester, restaurant: withPhoto);

    expect(find.byKey(const Key('restaurant-picked-photo')), findsOneWidget);
    expect(find.text('Uploading 45%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // The pills stay, so nothing jumps, but they can't be tapped.
    expect(tapArea(tester, changeButton()).onTap, isNull);
    expect(tapArea(tester, removeButton()).onTap, isNull);
  });

  testWidgets('saving shows Saving and blocks the photo tap',
      (tester) async {
    when(() => photo.state).thenReturn(
      const RestaurantPhotoState(status: RestaurantPhotoStatus.saving),
    );
    await show(tester, restaurant: withPhoto);

    expect(find.text('Saving...'), findsOneWidget);

    await tester.tap(photoBox(), warnIfMissed: false);
    await tester.tap(changeButton());
    await tester.tap(removeButton());
    // The Saving spinner never settles, so we pump a fixed time.
    await tester.pump(const Duration(milliseconds: 500));

    verifyNever(() => photo.pickAndUpload(confirm: any(named: 'confirm')));
    expect(find.text('Remove the restaurant photo?'), findsNothing);
  });

  testWidgets('the bin asks first, and Cancel keeps the photo',
      (tester) async {
    await show(tester, restaurant: withPhoto);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    expect(find.text('Remove the restaurant photo?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => photo.removePhoto());
    expect(find.text('Remove the restaurant photo?'), findsNothing);
  });

  testWidgets('Remove in the question removes the photo', (tester) async {
    await show(tester, restaurant: withPhoto);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    verify(() => photo.removePhoto()).called(1);
  });

  testWidgets('a new message shows in a bar', (tester) async {
    whenListen(
      photo,
      Stream.fromIterable([
        const RestaurantPhotoState(
          notice: 'Restaurant photo is saved.',
          noticeId: 1,
        ),
      ]),
      initialState: const RestaurantPhotoState(),
    );
    await show(tester, restaurant: noPhoto);
    await tester.pumpAndSettle();

    expect(find.text('Restaurant photo is saved.'), findsOneWidget);
  });
}