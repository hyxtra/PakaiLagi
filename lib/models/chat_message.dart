import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.fromMe,
    required this.time,
    this.text,
    this.isItemCard = false,
  });

  final bool fromMe;
  final String time;
  final String? text;

  /// Bila true, pesan ini dirender sebagai kartu "Barang yang Diminta".
  final bool isItemCard;
}
