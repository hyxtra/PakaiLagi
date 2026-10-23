/// Status dan transisi item yang diizinkan oleh MVP PakaiLagi.
abstract final class ItemStatusRules {
  static const available = 'available';
  static const reserved = 'reserved';
  static const completed = 'completed';

  static const validStatuses = {available, reserved, completed};

  static bool isValid(String status) => validStatuses.contains(status);

  static bool canTransition({required String from, required String to}) =>
      (from == available && to == reserved) ||
      (from == reserved && to == completed);
}
