import 'package:flutter/services.dart';

/// Automatic discovery of book files already on the device.
/// Uses the native "kun/scan" channel: MediaStore query always,
/// plus a folder walk (Downloads/Documents/Books) when the user
/// grants All-files access. No file is uploaded anywhere.
class DeviceScanner {
  static const _channel = MethodChannel('kun/scan');

  static Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestAllFilesAccess() async {
    try {
      await _channel.invokeMethod('requestAllFilesAccess');
    } on PlatformException {
      // Settings screen unavailable; MediaStore scan still works.
    }
  }

  /// Returns found files as maps: path, name, size, modified (ms epoch).
  static Future<List<Map<String, Object?>>> scan() async {
    final raw = await _channel.invokeMethod<List<Object?>>('scan') ?? const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
}
