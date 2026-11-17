import 'package:ada_rasa_foods/core/theme/app_theme.dart';
import 'package:ada_rasa_foods/core/widgets/round_icon_button.dart';
import 'package:ada_rasa_foods/core/widgets/sign_out_button.dart';
import 'package:ada_rasa_foods/features/auth/domain/app_user.dart';
import 'package:ada_rasa_foods/features/auth/domain/user_role.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_cubit.dart';
import 'package:ada_rasa_foods/features/auth/presentation/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

const owner = AppUser(
  uid: 'o1',
  name: 'Owner',
  email: 'owner@test.com',
  role: UserRole.restaurant,
  restaurantId: 'r1',
);

void main() {
  late MockAuthCubit authCubit;

  setUp(() {
    authCubit = MockAuthCubit();
    when(() => authCubit.state)
        .thenReturn(const AuthState.authenticated(owner));
    when(() => authCubit.signOut()).thenAnswer((_) async {});
  });

  // A top bar with the button, on a Redmi size screen (normal icons).
  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp(
          builder: (context, child) => AppThemeByWidth(child: child!),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Orders'),
              actions: const [SignOutButton()],
            ),
          ),
        ),
      ),
    );
  }

  group('SignOutButton', () {
    testWidgets('is a rounded sign out icon in a soft round circle', (
      tester,
    ) async {
      await show(tester);

      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsNothing);

      final circle = find.byType(RoundIconCircle);
      expect(tester.widget<RoundIconCircle>(circle).style,
          RoundIconStyle.soft);
      expect(tester.getSize(circle), const Size(38, 38));

      final icon = tester.widget<Icon>(find.byIcon(Icons.logout_rounded));
      expect(icon.color, AppTheme.brandOrange);
    });

    testWidgets('has the Sign out tooltip', (tester) async {
      await show(tester);

      expect(find.byTooltip('Sign out'), findsOneWidget);
    });

    testWidgets('tapping it signs out once', (tester) async {
      await show(tester);

      await tester.tap(find.byType(SignOutButton));
      await tester.pump();

      verify(() => authCubit.signOut()).called(1);
    });

    testWidgets('is not faded, because it can always be tapped', (
      tester,
    ) async {
      await show(tester);

      final fade = find.descendant(
        of: find.byType(SignOutButton),
        matching: find.byType(Opacity),
      );
      expect(fade, findsNothing);
    });
  });
}