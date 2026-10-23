/// Otorisasi tampilan UI. Firestore Security Rules tetap menjadi pengaman utama.
abstract final class ItemOwnership {
  static bool canModify({
    required String donorId,
    required String? currentUserId,
  }) =>
      donorId.isNotEmpty &&
      currentUserId != null &&
      currentUserId.isNotEmpty &&
      donorId == currentUserId;
}
