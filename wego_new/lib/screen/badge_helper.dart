import 'dart:convert';
import 'dart:typed_data';

Uint8List? safeBase64Decode(String b64) {
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}