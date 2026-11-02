import 'package:equatable/equatable.dart';

import '../domain/dish.dart';

enum DishFormStatus { editing, saving, deleting, saved, deleted }

// The Add dish and Edit dish page (RES-3).
class DishFormState extends Equatable {
  const DishFormState({
    this.original,
    this.name = '',
    this.description = '',
    this.price = '',
    this.category = '',
    this.available = true,
    this.showErrors = false,
    this.status = DishFormStatus.editing,
    this.notice,
    this.noticeId = 0,
  });

  // The same limits as the text fields on the page.
  static const int maxName = 60;
  static const int maxDescription = 200;
  static const int maxCategory = 30;
  static const int maxPrice = 100000;

  // Null when adding a new dish.
  final Dish? original;

  final String name;
  final String description;

  // The text in the price field. Digits only.
  final String price;

  final String category;
  final bool available;

  // Errors show only after the first Save tap.
  final bool showErrors;

  final DishFormStatus status;

  // A message for the owner. A new noticeId means "show it now".
  final String? notice;
  final int noticeId;

  bool get isEditing => original != null;

  bool get isBusy =>
      status == DishFormStatus.saving || status == DishFormStatus.deleting;

  int? get priceValue => int.tryParse(price.trim());

  // The rules need a name, a price above 0, and a category.
  String? get nameError {
    final value = name.trim();
    if (value.isEmpty) return 'Please enter the dish name.';
    if (value.length > maxName) return 'Use $maxName letters or less.';
    return null;
  }

  String? get priceError {
    if (price.trim().isEmpty) return 'Please enter the price.';
    final value = priceValue;
    if (value == null || value < 1) return 'The price must be at least 1.';
    if (value > maxPrice) return 'The price is too high.';
    return null;
  }

  String? get categoryError {
    final value = category.trim();
    if (value.isEmpty) return 'Please enter a category.';
    if (value.length > maxCategory) return 'Use $maxCategory letters or less.';
    return null;
  }

  String? get descriptionError {
    if (description.trim().length > maxDescription) {
      return 'Use $maxDescription letters or less.';
    }
    return null;
  }

  bool get isValid =>
      nameError == null &&
      priceError == null &&
      categoryError == null &&
      descriptionError == null;

  // The dish to save, with spaces trimmed. Only call when isValid.
  Dish toDish(String restaurantId) {
    return Dish(
      id: original?.id ?? '',
      restaurantId: restaurantId,
      name: name.trim(),
      description: description.trim(),
      price: priceValue ?? 0,
      category: category.trim(),
      imageUrl: original?.imageUrl ?? '',
      available: available,
    );
  }

  DishFormState copyWith({
    String? name,
    String? description,
    String? price,
    String? category,
    bool? available,
    bool? showErrors,
    DishFormStatus? status,
    String? notice,
    int? noticeId,
  }) {
    return DishFormState(
      original: original,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      available: available ?? this.available,
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
        description,
        price,
        category,
        available,
        showErrors,
        status,
        notice,
        noticeId,
      ];
}