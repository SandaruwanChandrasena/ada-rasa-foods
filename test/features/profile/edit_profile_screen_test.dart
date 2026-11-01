import 'dart:async';

import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_failure.dart';
import 'package:ada_rasa_foods/features/auth/domain/auth_repository.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:ada_rasa_foods/features/profile/presentation/edit_profile_cubit.dart';
import 'package:ada_rasa_foods/features/profile/presentation/edit_profile_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

const nimal = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  phone: '0712345678',
  role: UserRole.customer,
);

const updated = AppUser(
  uid: 'u1',
  name: 'Nimal Perera',
  email: 'nimal@test.com',
  phone: '0771234567',
  role: UserRole.customer,
);

const noPhone = AppUser(
  uid: 'u1',
  name: 'Nimal',
  email: 'nimal@test.com',
  role: UserRole.customer,
);

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  late MockAuthRepository repository;
  late MockAuthCubit authCubit;
  bool? popResult;

  setUpAll(() => registerFallbackValue(nimal));

  setUp(() {
    repository = MockAuthRepository();
    authCubit = MockAuthCubit();
    popResult = null;
    when(
      () => repository.updateProfile(
        user: any(named: 'user'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer((_) async => updated);
  });

  // Opens the edit page from a home page, so we can see it close.
  Future<void> open(
    WidgetTester tester, {
    AppUser user = nimal,
    bool forCheckout = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => authCubit.state).thenReturn(AuthState.authenticated(user));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<EditProfileCubit>(
            create: (_) => EditProfileCubit(repository),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          EditProfileView(forCheckout: forCheckout),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the name, the phone in groups, and the email',
      (tester) async {
    await open(tester);

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Nimal'), findsOneWidget);
    expect(find.text('071 234 5678'), findsOneWidget);
    expect(find.text('nimal@test.com'), findsOneWidget);
    expect(find.text('Your email cannot be changed.'), findsOneWidget);
  });

  testWidgets('the email box cannot be changed', (tester) async {
    await open(tester);

    final email = tester.widget<TextField>(
      find.descendant(of: field('Email'), matching: find.byType(TextField)),
    );
    expect(email.enabled, isFalse);
  });

  testWidgets('an empty phone is refused and nothing is saved',
      (tester) async {
    await open(tester, user: noPhone);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Please enter your phone number.'), findsOneWidget);
    verifyNever(
      () => repository.updateProfile(
        user: any(named: 'user'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    );
  });

  testWidgets('a wrong phone shows why', (tester) async {
    await open(tester);

    await tester.enterText(field('Phone'), '011 234 5678');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('A mobile number starts with 07.'), findsOneWidget);
  });

  testWidgets('an empty name is refused', (tester) async {
    await open(tester);

    await tester.enterText(field('Name'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Please enter your name.'), findsOneWidget);
  });

  testWidgets('letters cannot be typed in the phone box', (tester) async {
    await open(tester, user: noPhone);

    await tester.enterText(field('Phone'), '07a1b2');

    final phone = tester.widget<TextField>(
      find.descendant(of: field('Phone'), matching: find.byType(TextField)),
    );
    expect(phone.controller!.text, '0712');
  });

  testWidgets('a good save updates the user and closes the page',
      (tester) async {
    await open(tester);

    await tester.enterText(field('Name'), 'Nimal Perera');
    await tester.enterText(field('Phone'), '077 123 4567');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateProfile(
        user: nimal,
        name: 'Nimal Perera',
        phone: '077 123 4567',
      ),
    ).called(1);
    verify(() => authCubit.updateUser(updated)).called(1);
    expect(popResult, isTrue);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('an error shows a message and stays on the page',
      (tester) async {
    when(
      () => repository.updateProfile(
        user: any(named: 'user'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).thenThrow(
      const AuthFailure('No internet connection. Please try again.'),
    );
    await open(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('No internet connection. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Edit profile'), findsOneWidget);
    verifyNever(() => authCubit.updateUser(any()));
  });

  testWidgets('while saving, the boxes and button are turned off',
      (tester) async {
    final slow = Completer<AppUser>();
    when(
      () => repository.updateProfile(
        user: any(named: 'user'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer((_) => slow.future);
    await open(tester);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final name = tester.widget<TextField>(
      find.descendant(of: field('Name'), matching: find.byType(TextField)),
    );
    expect(name.enabled, isFalse);

    slow.complete(updated);
    await tester.pumpAndSettle();
    expect(popResult, isTrue);
  });

  testWidgets('from checkout, it explains why the phone is needed',
      (tester) async {
    await open(tester, user: noPhone, forCheckout: true);

    expect(find.text('Add your phone'), findsOneWidget);
    expect(
      find.textContaining('so the restaurant can call you'),
      findsOneWidget,
    );
  });
}