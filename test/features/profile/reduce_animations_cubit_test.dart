import 'package:ada_rasa_foods/features/profile/domain/settings_repository.dart';
import 'package:ada_rasa_foods/features/profile/presentation/reduce_animations_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
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

  ReduceAnimationsCubit build() => ReduceAnimationsCubit(repository);

  test('starts with the saved setting (off)', () {
    expect(build().state, isFalse);
  });

  test('starts with the saved setting (on)', () {
    when(() => repository.reduceAnimations).thenReturn(true);
    expect(build().state, isTrue);
  });

  blocTest<ReduceAnimationsCubit, bool>(
    'turning it on shows at once and is saved',
    build: build,
    act: (cubit) => cubit.set(true),
    expect: () => const [true],
    verify: (_) =>
        verify(() => repository.setReduceAnimations(true)).called(1),
  );

  blocTest<ReduceAnimationsCubit, bool>(
    'turning it off again works',
    setUp: () => when(() => repository.reduceAnimations).thenReturn(true),
    build: build,
    act: (cubit) => cubit.set(false),
    expect: () => const [false],
    verify: (_) =>
        verify(() => repository.setReduceAnimations(false)).called(1),
  );

  blocTest<ReduceAnimationsCubit, bool>(
    'the same value does nothing',
    build: build,
    act: (cubit) => cubit.set(false),
    expect: () => const <bool>[],
    verify: (_) =>
        verifyNever(() => repository.setReduceAnimations(any())),
  );

  blocTest<ReduceAnimationsCubit, bool>(
    'if saving fails, the switch moves back',
    setUp: () => when(() => repository.setReduceAnimations(any()))
        .thenThrow(Exception('disk full')),
    build: build,
    act: (cubit) => cubit.set(true),
    expect: () => const [true, false],
  );
}