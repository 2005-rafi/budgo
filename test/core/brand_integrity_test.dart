import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/core/constants/legal_policies.dart';
import 'package:expense/core/security/brand_integrity.dart';

void main() {
  group('BrandIntegrity Cryptographic & Masking Primitives', () {
    test('sha256Hex matches standard FIPS 180-4 test vectors', () {
      expect(
        BrandIntegrity.sha256Hex(const <int>[]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        BrandIntegrity.sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        BrandIntegrity.sha256Hex(
          utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('Masked UTF-8 roundtrip obscures plaintext bytes including Unicode', () {
      const key = <int>[0x12, 0xA9, 0x34, 0xF0, 0x77, 0x81, 0x5C, 0x09, 0xE2, 0x4B];
      const secret = '© 2026 Developer • ₹ Privacy 🔒';
      final masked = BrandIntegrity.encodeMaskedUtf8(secret, key, 19);

      // Verify raw UTF-8 substring does not appear unmasked
      final decodedLatin = String.fromCharCodes(masked);
      expect(decodedLatin.contains('Developer'), isFalse);
      expect(decodedLatin.contains('Privacy'), isFalse);

      expect(BrandIntegrity.decodeMaskedUtf8(masked, key, 19), secret);
    });

    test('verifyManifest detects unauthorized string substitution', () {
      final baseline = <String, String>{
        'appName': 'TestLedger',
        'developerName': 'Original Author',
      };
      final canonical = 'appName=TestLedger\ndeveloperName=Original Author\n';
      final expectedHex = BrandIntegrity.sha256Hex(utf8.encode(canonical));

      final valid = BrandIntegrity.verifyManifest(
        fields: baseline,
        expectedDigestHex: expectedHex,
      );
      expect(valid.isValid, isTrue);

      final tampered = BrandIntegrity.verifyManifest(
        fields: <String, String>{
          'appName': 'TestLedger',
          'developerName': 'Spoofed Clone Author',
        },
        expectedDigestHex: expectedHex,
      );
      expect(tampered.isValid, isFalse);
      expect(tampered.failedChecks, contains('digest_mismatch'));
    });
  });

  group('Centralized AppBrand & LegalPolicies', () {
    test('AppBrand decodes clean identity synced with pubspec and passes integrity seal', () {
      final report = AppBrand.verifyIntegrity();
      expect(report.isValid, isTrue, reason: 'Failed checks: ${report.failedChecks}');
      expect(report.failedChecks, isEmpty);

      expect(AppBrand.appName, isNotEmpty);
      expect(AppBrand.version, '3.0.0');
      expect(AppBrand.buildNumber, '300');
      expect(AppBrand.developerName, 'Mohammed Rafi H');
      expect(AppBrand.contactEmail, '2005.mohammedrafi.h@gmail.com');
      expect(AppBrand.copyrightStatement, '© 2026 Mohammed Rafi H');
      expect(AppBrand.showSourceLinks, isFalse);
    });

    test('LegalPolicies interpolates centralized brand name and enforces ethics clauses', () {
      final brand = AppBrand.appName;
      expect(LegalPolicies.privacyPolicy, contains(brand));
      expect(LegalPolicies.privacyPolicy, contains('Cloud Data Collection:** None (0%)'));
      expect(LegalPolicies.termsOfUse, contains(brand));
      expect(LegalPolicies.termsOfUse, contains('No Financial, Tax, Investment, or Legal Advice'));
      expect(LegalPolicies.eula, contains(brand));
      expect(LegalPolicies.eula, contains(AppBrand.developerName));
      expect(LegalPolicies.eula, contains('Anti-Tampering, Anti-Cloning & Redistribution Ban'));
      expect(LegalPolicies.eula, contains('Open-Source Components Attribution'));
    });
  });
}

