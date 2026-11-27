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

const pickedPath = '/cache/shop.jpg';

void main() {
  late MockMyRestaurantCubit myRestaurant;
  late MockRestaurantPhotoCubit photo;

  // any() needs a sample value for the confirm function type.
  setUpAll(() {
    Future<PhotoChoice> fallback(String path) async => PhotoChoice.cancel;
    registerFallbackValue(fallback);
  });

  setUp(() {
    myRestaurant = MockMyRestaurantCubit();
    photo = MockRestaurantPhotoCubit();
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
        child: const MaterialApp(
          home: Scaffold(body: RestaurantPhotoCard()),
        ),
      ),
    );
    await tester.pump();
  }

  Finder photoBox() => find.byKey(const Key('restaurant-photo-box'));
  Finder removeButton() => find.byKey(const Key('remove-photo-button'));
  Finder changeButton() => find.byKey(const Key('change-photo-button'));

  testWidgets('shows nothing until the restaurant loads', (tester) async {
    await show(tester);

    expect(photoBox(), findsNothing);
    expect(find.text('Add a photo'), findsNothing);
    expect(find.text('Kottu Corner'), findsNothing);
  });

  testWidgets('no photo: Add a photo, and no round buttons',
      (tester) async {
    await show(tester, restaurant: noPhoto);

    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
    expect(removeButton(), findsNothing);
    expect(changeButton(), findsNothing);
  });

  testWidgets('a photo: camera and bin buttons on it', (tester) async {
    await show(tester, restaurant: withPhoto);

    expect(find.text('Add a photo'), findsNothing);
    expect(changeButton(), findsOneWidget);
    expect(removeButton(), findsOneWidget);
  });

  testWidgets('the bin is red and the camera orange, on white',
      (tester) async {
    await show(tester, restaurant: withPhoto);

    final bin = tester.widget<Icon>(
      find.descendant(of: removeButton(), matching: find.byType(Icon)),
    );
    final camera = tester.widget<Icon>(
      find.descendant(of: changeButton(), matching: find.byType(Icon)),
    );
    expect(bin.color, AppTheme.dangerRed);
    expect(camera.color, AppTheme.brandOrange);
    final circle = tester.widget<Material>(
      find.descendant(of: removeButton(), matching: find.byType(Material)),
    );
    expect(circle.color, Colors.white);
  });

  testWidgets('the cover is 180 high', (tester) async {
    await show(tester, restaurant: withPhoto);

    expect(tester.getSize(photoBox()).height, 180);
  });

  testWidgets('shows the name, cuisine and address', (tester) async {
    await show(tester, restaurant: noPhoto);

    expect(find.text('Kottu Corner'), findsOneWidget);
    expect(find.text('Sri Lankan · Colombo'), findsOneWidget);
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
    expect(changeButton(), findsNothing);
    expect(removeButton(), findsNothing);
  });

  testWidgets('saving shows Saving and blocks the photo tap',
      (tester) async {
    when(() => photo.state).thenReturn(
      const RestaurantPhotoState(status: RestaurantPhotoStatus.saving),
    );
    await show(tester, restaurant: withPhoto);

    expect(find.text('Saving...'), findsOneWidget);
    expect(changeButton(), findsNothing);

    await tester.tap(photoBox(), warnIfMissed: false);
    await tester.pump();

    verifyNever(() => photo.pickAndUpload(confirm: any(named: 'confirm')));
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