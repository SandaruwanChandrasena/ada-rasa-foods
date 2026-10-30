import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/card_brand.dart';
import '../domain/payment_card.dart';

// Turns a users/{uid}/cards/{id} document into a PaymentCard, and back.
class CardModel {
  const CardModel._();

  // Only these fields are saved. Never the full number or the CVV.
  static Map<String, dynamic> toNewMap(PaymentCard card) {
    return {
      'brand': card.brand.name,
      'last4': card.last4,
      'holderName': card.holderName.trim(),
      'expMonth': card.expMonth,
      'expYear': card.expYear,
      'isDefault': card.isDefault,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Missing fields get safe defaults.
  static PaymentCard fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];

    return PaymentCard(
      id: id,
      brand: CardBrand.values.asNameMap()[map['brand']] ?? CardBrand.visa,
      last4: map['last4'] as String? ?? '',
      holderName: map['holderName'] as String? ?? '',
      expMonth: (map['expMonth'] as num?)?.toInt() ?? 1,
      expYear: (map['expYear'] as num?)?.toInt() ?? 2000,
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}