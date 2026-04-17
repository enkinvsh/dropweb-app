import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'print.dart';

extension StringExtension on String {
  bool get isUrl => RegExp(r'^(http|https|ftp)://').hasMatch(this);

  dynamic get splitByMultipleSeparators {
    final parts =
        split(RegExp(r'[, ;]+')).where((part) => part.isNotEmpty).toList();

    return parts.length > 1 ? parts : this;
  }

  int compareToLower(String other) => toLowerCase().compareTo(
        other.toLowerCase(),
      );

  List<int> get encodeUtf16LeWithBom {
    final byteData = ByteData(length * 2);
    final bom = [0xFF, 0xFE];
    for (var i = 0; i < length; i++) {
      final charCode = codeUnitAt(i);
      byteData.setUint16(i * 2, charCode, Endian.little);
    }
    return bom + byteData.buffer.asUint8List();
  }

  Uint8List? get getBase64 {
    final regExp = RegExp(r'base64,(.*)');
    final match = regExp.firstMatch(this);
    final realValue = match?.group(1) ?? '';
    if (realValue.isEmpty) {
      return null;
    }
    try {
      return base64.decode(realValue);
    } catch (e) {
      return null;
    }
  }

  bool get isSvg => endsWith(".svg");

  bool get isRegex {
    try {
      RegExp(this);
      return true;
    } catch (e) {
      commonPrint.log(e.toString());
      return false;
    }
  }

  /// Stable digest of the string — used for cache-key / filename derivation
  /// from URLs. NOT used for authentication.
  ///
  /// Switched from MD5 to SHA-256 (truncated): MD5 is cryptographically
  /// broken and flagged by most static analyzers / security audits. Even
  /// though this is non-auth, avoiding it sidesteps the question in Google
  /// Play and store reviews. The returned string is the first 32 hex chars
  /// of the SHA-256 digest so existing callers that expect a 32-char MD5-
  /// style key still get a fixed-width value. NOTE: this invalidates cache
  /// files keyed by the old MD5 hash exactly once, on first upgrade.
  String toMd5() {
    final bytes = utf8.encode(this);
    return sha256.convert(bytes).toString().substring(0, 32);
  }

  /// Full SHA-256 hex digest, preferred for any new code.
  String toSha256() {
    final bytes = utf8.encode(this);
    return sha256.convert(bytes).toString();
  }

// bool containsToLower(String target) {
//   return toLowerCase().contains(target);
// }
}

extension StringExtensionSafe on String? {
  String getSafeValue(String defaultValue) {
    if (this == null || this!.isEmpty) {
      return defaultValue;
    }
    return this!;
  }
}
