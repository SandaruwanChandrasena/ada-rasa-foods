import 'package:equatable/equatable.dart';

import 'card_brand.dart';

// A saved demo card. Never the full number or the CVV (CUS-9).
class PaymentCard extends Equatable {
  const PaymentCard({
    this.id = '',
    required this.brand,
    required this.last4,
    required this.holderName,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
    this.createdAt,
  });

  // Empty until Firestore gives the card an id.
  final String id;

  final CardBrand brand;
  final String last4;
  final String holderName;

  // expMonth is 1 to 12. expYear has 4 digits, like 2028.
  final int expMonth;
  final int expYear;

  final bool isDefault;
  final DateTime? createdAt;

  // A card works until the end of its expiry month.
  bool isExpired(DateTime now) =>
      expYear < now.year || (expYear == now.year && expMonth < now.month);

  // Like "08/28".
  String get expiryText {
    final month = expMonth.toString().padLeft(2, '0');
    final year = (expYear % 100).toString().padLeft(2, '0');
    return '$month/$year';
  }

  // Like "Visa ending 4242".
  String get title => '${brand.label} ending $last4';

  // The demo card ending in 0002 always fails (CUS-10).
  bool get alwaysFails => last4 == '0002';

  // Used to stop saving the same card twice.
  bool isSameCardAs(PaymentCard other) =>
      brand == other.brand &&
      last4 == other.last4 &&
      expMonth == other.expMonth &&
      expYear == other.expYear;

  @override
  List<Object?> get props => [
        id,
        brand,
        last4,
        holderName,
        expMonth,
        expYear,
        isDefault,
        createdAt,
      ];
}