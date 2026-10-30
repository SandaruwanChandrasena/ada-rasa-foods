// Only Visa and Mastercard (CUS-9). Firestore saves the name, like "visa".
enum CardBrand {
  visa('Visa'),
  mastercard('Mastercard');

  const CardBrand(this.label);

  // The name shown in the app.
  final String label;
}