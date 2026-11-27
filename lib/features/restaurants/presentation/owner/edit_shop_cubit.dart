import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/data_failure.dart';
import '../../../auth/domain/phone_checks.dart';
import '../../domain/restaurant.dart';
import '../../domain/restaurant_repository.dart';

enum EditShopStatus { editing, saving, saved }

// The Edit shop page: name, cuisine, phone and description.
// The address stays with the admin, because it goes with the map point.
class EditShopState extends Equatable {
  const EditShopState({
    required this.original,
    required this.name,
    required this.cuisine,
    required this.phone,
    required this.description,
    this.showErrors = false,
    this.status = EditShopStatus.editing,
    this.notice,
    this.noticeId = 0,
  });

  // The page starts with the shop as it is now.
  factory EditShopState.from(Restaurant restaurant) {
    return EditShopState(
      original: restaurant,
      name: restaurant.name,
      cuisine: restaurant.cuisine,
      phone: restaurant.hasPhone ? PhoneChecks.format(restaurant.phone) : '',
      description: restaurant.description,
    );
  }

  // The same limits as the Firestore rules.
  static const int maxName = 40;
  static const int maxCuisine = 20;
  static const int maxDescription = 150;

  final Restaurant original;
  final String name;
  final String cuisine;

  // As typed, like "071 234 5678". Saved as digits only.
  final String phone;
  final String description;

  // Errors show only after the first Save tap.
  final bool showErrors;
  final EditShopStatus status;

  // A message for the owner. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  bool get isSaving => status == EditShopStatus.saving;

  // Like the rules, the length is checked only when the value changed,
  // so an old shop with a long name can still save its phone.
  String? get nameError {
    final value = name.trim();
    if (value.isEmpty) return 'Please enter the shop name.';
    if (value != original.name && value.length > maxName) {
      return 'Use $maxName letters or fewer.';
    }
    return null;
  }

  String? get cuisineError {
    final value = cuisine.trim();
    if (value.isEmpty) return 'Please enter the cuisine.';
    if (value != original.cuisine && value.length > maxCuisine) {
      return 'Use $maxCuisine letters or fewer.';
    }
    return null;
  }

  // The phone is optional. An empty box is fine.
  String? get phoneError {
    if (phone.trim().isEmpty) return null;
    return PhoneChecks.error(phone);
  }

  String? get descriptionError {
    if (description.trim().length > maxDescription) {
      return 'Use $maxDescription letters or fewer.';
    }
    return null;
  }

  bool get isValid =>
      nameError == null &&
      cuisineError == null &&
      phoneError == null &&
      descriptionError == null;

  String get phoneDigits => PhoneChecks.digitsOnly(phone);

  // False when the owner changed nothing, so Save needs no write.
  bool get hasChanges =>
      name.trim() != original.name ||
      cuisine.trim() != original.cuisine ||
      phoneDigits != original.phone ||
      description.trim() != original.description;

  EditShopState copyWith({
    String? name,
    String? cuisine,
    String? phone,
    String? description,
    bool? showErrors,
    EditShopStatus? status,
    String? notice,
    int? noticeId,
  }) {
    return EditShopState(
      original: original,
      name: name ?? this.name,
      cuisine: cuisine ?? this.cuisine,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      showErrors: showErrors ?? this.showErrors,
      status: status ?? this.status,
      notice: notice ?? this.notice,
      noticeId: noticeId ?? this.noticeId,
    );
  }

  @override
  List<Object?> get props => [
        original,
        name,
        cuisine,
        phone,
        description,
        showErrors,
        status,
        notice,
        noticeId,
      ];
}

// Kept in one file with its state, like MyRestaurantCubit.
class EditShopCubit extends Cubit<EditShopState> {
  EditShopCubit(this._repository, Restaurant restaurant)
      : super(EditShopState.from(restaurant));

  final RestaurantRepository _repository;

  void nameChanged(String value) => emit(state.copyWith(name: value));

  void cuisineChanged(String value) => emit(state.copyWith(cuisine: value));

  void phoneChanged(String value) => emit(state.copyWith(phone: value));

  void descriptionChanged(String value) =>
      emit(state.copyWith(description: value));

  Future<void> save() async {
    if (state.isSaving || state.status == EditShopStatus.saved) return;

    if (!state.isValid) {
      emit(state.copyWith(showErrors: true));
      return;
    }

    // Nothing changed, so the page just closes.
    if (!state.hasChanges) {
      emit(state.copyWith(status: EditShopStatus.saved));
      return;
    }

    emit(state.copyWith(status: EditShopStatus.saving));

    try {
      await _repository.updateDetails(
        state.original.id,
        name: state.name,
        cuisine: state.cuisine,
        phone: state.phoneDigits,
        description: state.description,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EditShopStatus.saved,
          notice: 'Shop details are saved.',
          noticeId: state.noticeId + 1,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EditShopStatus.editing,
          notice: error is DataFailure
              ? error.message
              : 'Something went wrong. Please try again.',
          noticeId: state.noticeId + 1,
        ),
      );
    }
  }
}