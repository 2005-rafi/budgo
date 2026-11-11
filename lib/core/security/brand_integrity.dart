import 'dart:convert';
import 'dart:typed_data';

/// Result of verifying integrity across decoded brand identity and legal policies.
class BrandIntegrityReport {
  final bool isValid;
  final String computedDigestHex;
  final String expectedDigestHex;
  final List<String> failedChecks;

  const BrandIntegrityReport({
    required this.isValid,
    required this.computedDigestHex,
    required this.expectedDigestHex,
    this.failedChecks = const [],
  });
}

/// Zero-dependency runtime cryptographic verification and masked byte decoding
/// protecting offline developer attribution, copyright, and legal terms from
/// casual string extraction and in-place binary patching.
class BrandIntegrity {
  const BrandIntegrity._();

  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) =>
      ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

  /// Pure-Dart FIPS 180-4 / RFC 6234 SHA-256 digest in lowercase hex.
  static String sha256Hex(List<int> input) {
    final bitLength = input.length * 8;
    // Pad with 0x80 then zeros until length ≡ 56 (mod 64), plus 8-byte BE bitLength
    final padLen = ((56 - (input.length + 1) % 64) + 64) % 64;
    final totalLen = input.length + 1 + padLen + 8;
    final data = Uint8List(totalLen);
    data.setAll(0, input);
    data[input.length] = 0x80;

    // Write 64-bit big-endian bit length safely across JS/VM ints
    final highBits = (bitLength ~/ 0x100000000) & 0xffffffff;
    final lowBits = bitLength & 0xffffffff;
    final lenOffset = totalLen - 8;
    data[lenOffset] = (highBits >>> 24) & 0xff;
    data[lenOffset + 1] = (highBits >>> 16) & 0xff;
    data[lenOffset + 2] = (highBits >>> 8) & 0xff;
    data[lenOffset + 3] = highBits & 0xff;
    data[lenOffset + 4] = (lowBits >>> 24) & 0xff;
    data[lenOffset + 5] = (lowBits >>> 16) & 0xff;
    data[lenOffset + 6] = (lowBits >>> 8) & 0xff;
    data[lenOffset + 7] = lowBits & 0xff;

    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final w = Uint32List(64);
    for (int chunk = 0; chunk < totalLen; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        final j = chunk + i * 4;
        w[i] = (data[j] << 24) |
            (data[j + 1] << 16) |
            (data[j + 2] << 8) |
            data[j + 3];
      }
      for (int i = 16; i < 64; i++) {
        final w15 = w[i - 15];
        final w2 = w[i - 2];
        final s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ ((w15 & 0xffffffff) >>> 3);
        final s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ ((w2 & 0xffffffff) >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    final out = StringBuffer();
    for (final v in <int>[h0, h1, h2, h3, h4, h5, h6, h7]) {
      out.write(v.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }

  /// Decodes UTF-8 string bytes protected with stride-permuted rotating XOR mask.
  static String decodeMaskedUtf8(
    List<int> masked,
    List<int> maskKey,
    int strideSalt,
  ) {
    if (masked.isEmpty) return '';
    final out = Uint8List(masked.length);
    final kLen = maskKey.length;
    for (int i = 0; i < masked.length; i++) {
      final kByte = maskKey[(i * 7 + strideSalt) % kLen];
      final iSalt = (i * 31 + strideSalt) & 0xff;
      out[i] = masked[i] ^ kByte ^ iSalt;
    }
    return utf8.decode(out);
  }

  /// Encodes UTF-8 bytes into a masked byte list for deterministic code generation.
  static List<int> encodeMaskedUtf8(
    String value,
    List<int> maskKey,
    int strideSalt,
  ) {
    final bytes = utf8.encode(value);
    final kLen = maskKey.length;
    return List<int>.generate(bytes.length, (i) {
      final kByte = maskKey[(i * 7 + strideSalt) % kLen];
      final iSalt = (i * 31 + strideSalt) & 0xff;
      return bytes[i] ^ kByte ^ iSalt;
    });
  }

  /// Constant-time string comparison avoiding short-circuit side leaks.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Validates the decoded canonical attribution + legal payload against the sealed SHA-256 digest.
  static BrandIntegrityReport verifyManifest({
    required Map<String, String> fields,
    required String expectedDigestHex,
  }) {
    final failed = <String>[];
    final sortedKeys = fields.keys.toList()..sort();
    final canonicalBuffer = StringBuffer();
    for (final key in sortedKeys) {
      final val = fields[key] ?? '';
      if (val.trim().isEmpty) {
        failed.add('empty:$key');
      }
      canonicalBuffer.write(key);
      canonicalBuffer.write('=');
      canonicalBuffer.write(val);
      canonicalBuffer.write('\n');
    }

    final computed = sha256Hex(utf8.encode(canonicalBuffer.toString()));
    final digestMatch = _constantTimeEquals(computed, expectedDigestHex);
    if (!digestMatch) {
      failed.add('digest_mismatch');
    }

    return BrandIntegrityReport(
      isValid: failed.isEmpty && digestMatch,
      computedDigestHex: computed,
      expectedDigestHex: expectedDigestHex,
      failedChecks: List.unmodifiable(failed),
    );
  }
}

