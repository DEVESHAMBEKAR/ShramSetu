import 'dart:convert';
import 'package:crypto/crypto.dart';

class UuidUtil {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String? id) {
    if (id == null) return false;
    return _uuidRegex.hasMatch(id.trim());
  }

  /// Converts any string (e.g. 'phone_9975811244', 'customer_9975811244', or Firebase UID)
  /// into a deterministic valid RFC4122 UUID string.
  /// If the input is already a valid UUID, returns it unchanged.
  static String toDeterministicUuid(String input) {
    final trimmed = input.trim();
    if (_uuidRegex.hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }
    final bytes = md5.convert(utf8.encode('shramsetu:$trimmed')).bytes;
    final b = List<int>.from(bytes);
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant RFC4122
    final hex = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
