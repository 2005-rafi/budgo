import 'dart:convert';
import 'dart:io';

import 'package:expense/core/security/brand_integrity.dart';

/// Reads `tool/brand_manifest.json` and `pubspec.yaml` to deterministically
/// regenerate protected brand constants, masked legal policies, and native
/// Android/iOS launcher display labels from a single centralized source.
///
/// Run: `dart run tool/sync_brand.dart`
Future<void> main() async {
  final manifestFile = File('tool/brand_manifest.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('Error: tool/brand_manifest.json not found.');
    exitCode = 1;
    return;
  }

  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;

  final pubspecFile = File('pubspec.yaml');
  final pubspecRaw = pubspecFile.existsSync() ? pubspecFile.readAsStringSync() : '';
  final versionMatch =
      RegExp(r'^version:\s*([^\s+#]+)(?:\+([^\s#]+))?', multiLine: true)
          .firstMatch(pubspecRaw);
  final appVersion = versionMatch?.group(1) ?? '1.0.0';
  final buildNumber =
      versionMatch?.group(2) ?? (manifest['defaultBuildNumber'] as String? ?? '1');

  final appName = manifest['appName'] as String;
  final appDescriptor = manifest['appDescriptor'] as String;
  final appTagline = manifest['appTagline'] as String;
  final taglineUppercase = manifest['taglineUppercase'] as String;
  final fileSlug = manifest['fileSlug'] as String;
  final logoAsset = manifest['logoAsset'] as String;
  final pdfLogoAsset = manifest['pdfLogoAsset'] as String;
  final brandFontFamily = manifest['brandFontFamily'] as String;
  final taglineFontFamily = manifest['taglineFontFamily'] as String;
  final developerName = manifest['developerName'] as String;
  final contactEmail = manifest['contactEmail'] as String;
  final copyrightYear = manifest['copyrightYear'] as String;
  final rightsNotice = manifest['rightsNotice'] as String;
  final licenseModel = manifest['licenseModel'] as String;
  final legalEffectiveDate = manifest['legalEffectiveDate'] as String;
  final jurisdiction = manifest['jurisdiction'] as String;
  final releaseChannel = manifest['releaseChannel'] as String;
  final showSourceLinks = manifest['showSourceLinks'] as bool? ?? false;
  final repositoryUrl = manifest['repositoryUrl'] as String? ?? '';

  final copyrightStatement = '© $copyrightYear $developerName';

  // Deterministic 32-byte key derived from build-time seed (never stored raw in APK strings)
  final maskKey = <int>[
    0xA7, 0x3C, 0x91, 0x5E, 0xD4, 0x19, 0x82, 0x6F,
    0x4B, 0xE3, 0x0D, 0x7A, 0xC8, 0x25, 0x96, 0xF1,
    0x54, 0xB9, 0x38, 0xE7, 0x12, 0x6D, 0xCA, 0x45,
    0x8F, 0x20, 0xD9, 0x73, 0x3E, 0xA1, 0x5B, 0xC6,
  ];

  final privacyDoc = _buildPrivacyPolicy(
    appName: appName,
    developer: developerName,
    effectiveDate: legalEffectiveDate,
  );
  final termsDoc = _buildTermsOfUse(
    appName: appName,
    developer: developerName,
    effectiveDate: legalEffectiveDate,
    copyright: copyrightStatement,
  );
  final eulaDoc = _buildEula(
    appName: appName,
    developer: developerName,
    effectiveDate: legalEffectiveDate,
    copyright: copyrightStatement,
    rightsNotice: rightsNotice,
    jurisdiction: jurisdiction,
  );

  // Canonical payload sealed with SHA-256
  final canonicalFields = <String, String>{
    'appName': appName,
    'contactEmail': contactEmail,
    'copyrightStatement': copyrightStatement,
    'developerName': developerName,
    'eulaSha256': BrandIntegrity.sha256Hex(utf8.encode(eulaDoc)),
    'jurisdiction': jurisdiction,
    'legalEffectiveDate': legalEffectiveDate,
    'licenseModel': licenseModel,
    'privacySha256': BrandIntegrity.sha256Hex(utf8.encode(privacyDoc)),
    'rightsNotice': rightsNotice,
    'termsSha256': BrandIntegrity.sha256Hex(utf8.encode(termsDoc)),
  };

  final sortedKeys = canonicalFields.keys.toList()..sort();
  final canonicalBuffer = StringBuffer();
  for (final k in sortedKeys) {
    canonicalBuffer
      ..write(k)
      ..write('=')
      ..write(canonicalFields[k])
      ..write('\n');
  }
  final expectedSealHex =
      BrandIntegrity.sha256Hex(utf8.encode(canonicalBuffer.toString()));

  // Encode all protected fields with unique salts
  String formatBytes(String value, int salt) {
    final encoded = BrandIntegrity.encodeMaskedUtf8(value, maskKey, salt);
    final lines = <String>[];
    for (int i = 0; i < encoded.length; i += 14) {
      final end = (i + 14 < encoded.length) ? i + 14 : encoded.length;
      lines.add(encoded.sublist(i, end).join(', '));
    }
    return '<int>[\n    ${lines.join(',\n    ')},\n  ]';
  }

  final appBrandDart = '''// GENERATED FILE — DO NOT EDIT MANUALLY.
// Single centralized control point generated from `tool/brand_manifest.json` + `pubspec.yaml`.
// Re-generate after any brand/name change using: `dart run tool/sync_brand.dart`

import 'dart:convert';
import 'package:expense/core/constants/legal_policies.dart';
import 'package:expense/core/security/brand_integrity.dart';

class AppBrand {
  AppBrand._();

  // Asset & Font Paths
  static const String logoAsset = '${_escapeDart(logoAsset)}';
  static const String pdfLogoAsset = '${_escapeDart(pdfLogoAsset)}';
  static const String brandFontFamily = '${_escapeDart(brandFontFamily)}';
  static const String taglineFontFamily = '${_escapeDart(taglineFontFamily)}';

  // Synced Version & Distribution Metadata (from pubspec.yaml)
  static const String version = '${_escapeDart(appVersion)}';
  static const String buildNumber = '${_escapeDart(buildNumber)}';
  static const String releaseChannel = '${_escapeDart(releaseChannel)}';
  static const bool showSourceLinks = $showSourceLinks;

  static const List<int> _k = <int>[
    ${maskKey.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(', ')},
  ];

  // Masked byte slices (prevents plaintext string extraction & naive binary patching)
  static const List<int> _bAppName = ${formatBytes(appName, 11)};
  static const List<int> _bAppDescriptor = ${formatBytes(appDescriptor, 17)};
  static const List<int> _bAppTagline = ${formatBytes(appTagline, 23)};
  static const List<int> _bTaglineUpper = ${formatBytes(taglineUppercase, 29)};
  static const List<int> _bFileSlug = ${formatBytes(fileSlug, 31)};
  static const List<int> _bDevName = ${formatBytes(developerName, 37)};
  static const List<int> _bContactEmail = ${formatBytes(contactEmail, 41)};
  static const List<int> _bCopyright = ${formatBytes(copyrightStatement, 43)};
  static const List<int> _bRights = ${formatBytes(rightsNotice, 47)};
  static const List<int> _bLicenseModel = ${formatBytes(licenseModel, 53)};
  static const List<int> _bEffectiveDate = ${formatBytes(legalEffectiveDate, 59)};
  static const List<int> _bJurisdiction = ${formatBytes(jurisdiction, 61)};
  static const List<int> _bRepoUrl = ${formatBytes(repositoryUrl, 67)};
  static const List<int> _bSealHex = ${formatBytes(expectedSealHex, 71)};

  static String? _cAppName;
  static String? _cAppDescriptor;
  static String? _cAppTagline;
  static String? _cTaglineUpper;
  static String? _cFileSlug;
  static String? _cDevName;
  static String? _cContactEmail;
  static String? _cCopyright;
  static String? _cRights;
  static String? _cLicenseModel;
  static String? _cEffectiveDate;
  static String? _cJurisdiction;
  static String? _cRepoUrl;
  static String? _cSealHex;

  static String get appName =>
      _cAppName ??= BrandIntegrity.decodeMaskedUtf8(_bAppName, _k, 11);
  static String get appNameUpper => appName.toUpperCase();
  static String get appDescriptor =>
      _cAppDescriptor ??= BrandIntegrity.decodeMaskedUtf8(_bAppDescriptor, _k, 17);
  static String get fullProductTitle => '\$appName \$appDescriptor';
  static String get appTagline =>
      _cAppTagline ??= BrandIntegrity.decodeMaskedUtf8(_bAppTagline, _k, 23);
  static String get taglineUppercase =>
      _cTaglineUpper ??= BrandIntegrity.decodeMaskedUtf8(_bTaglineUpper, _k, 29);
  static String get fileSlug =>
      _cFileSlug ??= BrandIntegrity.decodeMaskedUtf8(_bFileSlug, _k, 31);
  static String get developerName =>
      _cDevName ??= BrandIntegrity.decodeMaskedUtf8(_bDevName, _k, 37);
  static String get contactEmail =>
      _cContactEmail ??= BrandIntegrity.decodeMaskedUtf8(_bContactEmail, _k, 41);
  static String get copyrightStatement =>
      _cCopyright ??= BrandIntegrity.decodeMaskedUtf8(_bCopyright, _k, 43);
  static String get rightsNotice =>
      _cRights ??= BrandIntegrity.decodeMaskedUtf8(_bRights, _k, 47);
  static String get licenseModel =>
      _cLicenseModel ??= BrandIntegrity.decodeMaskedUtf8(_bLicenseModel, _k, 53);
  static String get legalEffectiveDate =>
      _cEffectiveDate ??= BrandIntegrity.decodeMaskedUtf8(_bEffectiveDate, _k, 59);
  static String get jurisdiction =>
      _cJurisdiction ??= BrandIntegrity.decodeMaskedUtf8(_bJurisdiction, _k, 61);
  static String get repositoryUrl =>
      _cRepoUrl ??= BrandIntegrity.decodeMaskedUtf8(_bRepoUrl, _k, 67);
  static String get _expectedSealHex =>
      _cSealHex ??= BrandIntegrity.decodeMaskedUtf8(_bSealHex, _k, 71);

  static String get versionBadge => 'Version \$version';
  static String get buildFooter => 'Build \$buildNumber • \$releaseChannel';
  static String get exportStatementTitle => '\$appName Financial Statement';

  static Uri supportMailtoUri({
    String? subjectTag,
    String? body,
  }) {
    final subject = subjectTag != null && subjectTag.isNotEmpty
        ? '\$appName \$subjectTag (v\$version)'
        : '\$appName Support (v\$version)';
    return Uri(
      scheme: 'mailto',
      path: contactEmail,
      queryParameters: <String, String>{
        'subject': subject,
        if (body != null && body.isNotEmpty) 'body': body,
      },
    );
  }

  /// Verifies runtime cryptographic integrity across decoded brand identity
  /// and legal documents to detect binary attribution tampering.
  static BrandIntegrityReport verifyIntegrity() {
    return BrandIntegrity.verifyManifest(
      fields: <String, String>{
        'appName': appName,
        'contactEmail': contactEmail,
        'copyrightStatement': copyrightStatement,
        'developerName': developerName,
        'eulaSha256': BrandIntegrity.sha256Hex(utf8.encode(LegalPolicies.eula)),
        'jurisdiction': jurisdiction,
        'legalEffectiveDate': legalEffectiveDate,
        'licenseModel': licenseModel,
        'privacySha256':
            BrandIntegrity.sha256Hex(utf8.encode(LegalPolicies.privacyPolicy)),
        'rightsNotice': rightsNotice,
        'termsSha256':
            BrandIntegrity.sha256Hex(utf8.encode(LegalPolicies.termsOfUse)),
      },
      expectedDigestHex: _expectedSealHex,
    );
  }
}
''';

  final legalPoliciesDart = '''// GENERATED FILE — DO NOT EDIT MANUALLY.
// Masked legal policies sealed against tampering; update via `tool/sync_brand.dart`.

import 'package:expense/core/security/brand_integrity.dart';

class LegalPolicies {
  LegalPolicies._();

  static const List<int> _k = <int>[
    ${maskKey.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(', ')},
  ];

  static const List<int> _bPrivacy = ${formatBytes(privacyDoc, 73)};
  static const List<int> _bTerms = ${formatBytes(termsDoc, 79)};
  static const List<int> _bEula = ${formatBytes(eulaDoc, 83)};

  static String? _cPrivacy;
  static String? _cTerms;
  static String? _cEula;

  static String get privacyPolicy =>
      _cPrivacy ??= BrandIntegrity.decodeMaskedUtf8(_bPrivacy, _k, 73);

  static String get termsOfUse =>
      _cTerms ??= BrandIntegrity.decodeMaskedUtf8(_bTerms, _k, 79);

  static String get eula =>
      _cEula ??= BrandIntegrity.decodeMaskedUtf8(_bEula, _k, 83);
}
''';

  File('lib/core/constants/app_brand.dart').writeAsStringSync(appBrandDart);
  File('lib/core/constants/legal_policies.dart')
      .writeAsStringSync(legalPoliciesDart);

  // Sync Android strings.xml
  final androidStringsFile =
      File('android/app/src/main/res/values/strings.xml');
  androidStringsFile.parent.createSync(recursive: true);
  androidStringsFile.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">${_escapeXml(appName)}</string>
</resources>
''');

  // Sync iOS CFBundleDisplayName in Info.plist if present
  final plistFile = File('ios/Runner/Info.plist');
  if (plistFile.existsSync()) {
    final plistContent = plistFile.readAsStringSync();
    final updatedPlist = plistContent.replaceFirstMapped(
      RegExp(
          r'(<key>CFBundleDisplayName</key>\s*<string>)([^<]*)(</string>)'),
      (m) => '${m.group(1)}${_escapeXml(appName)}${m.group(3)}',
    );
    if (updatedPlist != plistContent) {
      plistFile.writeAsStringSync(updatedPlist);
    }
  }

  stdout.writeln(
    'Brand synced cleanly: $appName v$appVersion+$buildNumber | SHA-256 seal: ${expectedSealHex.substring(0, 12)}...',
  );
}

String _escapeDart(String input) =>
    input.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

String _escapeXml(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", "\\'");

String _buildPrivacyPolicy({
  required String appName,
  required String developer,
  required String effectiveDate,
}) =>
    '''# Privacy Policy

**Effective Date:** $effectiveDate

$appName is engineered from the ground up as a **100% offline-first personal finance application** created by **$developer**. Protecting your financial dignity and privacy is a foundational design rule, not an afterthought.

---

### Privacy At a Glance
- **Cloud Data Collection:** None (0%)
- **Tracking / Ad SDKs:** None
- **Account Sign-Up Required:** None
- **Where Records Live:** Exclusively in local storage on your physical device
- **Deletion Control:** Instant and irreversible local erase available anytime

---

## 1. On-Device Data Storage Only
All expenses, income entries, workspaces, savings vaults, account balances, budgets, and reminders you record in $appName remain stored exclusively on your device's internal app sandbox using local storage (Hive & system preferences). Neither the Developer nor any external party operates servers that collect, view, or back up your records.

## 2. Zero Analytics, Telemetry, or Profiling
$appName contains **no** behavioral analytics SDKs, advertising trackers, remote crash harvesters, or fingerprinting frameworks. Your spending habits, balances, and usage cadence never leave your device.

## 3. System Permissions & Explicit User Actions
To deliver core productivity features on your device, $appName only requests minimal OS capabilities:
- **Notifications & Scheduled Reminders:** Used locally by your device's operating system to alert you of upcoming bill or payment reminders you explicitly configure.
- **File Export & Sharing:** Exporting CSV or PDF financial statements writes strictly to local storage and opens your operating system's native share sheet only when you tap **Export**.

## 4. Data Ownership, Backup & Permanent Deletion
You hold complete custody over your financial records:
- Because no cloud copy exists, uninstalling the application or executing **Clear Workspace Data** / **Reset All Data** permanently removes stored local data.
- We strongly recommend exporting periodic PDF or CSV backups for your own archival records.

## 5. Privacy Inquiries
For questions regarding this Privacy Policy or data handling practices, reach the Developer directly using the verified Support Email listed on the About & Legal screen.
''';

String _buildTermsOfUse({
  required String appName,
  required String developer,
  required String effectiveDate,
  required String copyright,
}) =>
    '''# Terms of Use

**Effective Date:** $effectiveDate

Welcome to **$appName** ($copyright). By installing, accessing, or using this software application ("Application"), you agree to the following Terms of Use.

## 1. Intended Purpose
$appName is an offline personal financial ledger and budgeting organizer provided strictly for individual record-keeping and awareness.

## 2. No Financial, Tax, Investment, or Legal Advice
All metrics generated by $appName — including daily *Safe-to-Spend* estimates, charts, category breakdowns, reminders, and *Pay Yourself First* nudges — are purely mathematical calculations derived from numbers you enter. They do **not** constitute professional financial, tax, investment, legal, or accounting advice. Verify critical figures independently before making financial decisions.

## 3. Data Custody & Verification
Since $appName operates completely offline, the Developer cannot access, inspect, audit, or recover lost records resulting from hardware loss, operating system resets, device damage, or accidental erasure. Maintaining periodic exports of your financial data is solely your responsibility.

## 4. Prohibited Conduct & Integrity Protection
You agree **not** to:
- Bypass, disable, tamper with, or strip developer attribution, copyright notices, integrity seals, or legal screens embedded in the Application.
- Decompile, disassemble, reverse engineer, or extract assets/code in violation of applicable law and the accompanying End User License Agreement (EULA).
- Clone, rebrand, mirror, or redistribute modified builds on unauthorized app stores or websites.
- Use the Application for unlawful financial activity or fraud.

## 5. Disclaimer of Warranty & Limitation of Liability
The Application is furnished **"AS IS"** and **"AS AVAILABLE"** without express or implied warranties of merchantability, accuracy, continuous uptime, or fitness for a particular purpose. To the fullest extent permitted by applicable law, $developer shall not be liable for any direct, indirect, incidental, or consequential losses (including data loss or budgeting miscalculations) arising from use of or inability to use the Application.
''';

String _buildEula({
  required String appName,
  required String developer,
  required String effectiveDate,
  required String copyright,
  required String rightsNotice,
  required String jurisdiction,
}) =>
    '''# End User License Agreement (EULA)

**Effective Date:** $effectiveDate

This End User License Agreement ("Agreement") is a binding legal contract between you ("User") and **$developer** ("Developer") governing your installation and use of the **$appName** software application ("Software").

## 1. Grant of Limited License
Subject to strict compliance with this Agreement, the Developer grants you a limited, revocable, non-exclusive, non-transferable, non-sublicensable license to install and use unmodified copies of the Software strictly for lawful personal, non-commercial financial tracking on devices you own or control.

## 2. Intellectual Property & Ownership
The Software — including its original source architecture, business logic engines, visual design system, custom graphics, protected metadata, and legal documentation — constitutes proprietary intellectual property (**$copyright • $rightsNotice**). No title or ownership rights in the Software are transferred to you.

## 3. Anti-Tampering, Anti-Cloning & Redistribution Ban
**You are strictly prohibited from:**
- Selling, renting, leasing, sublicensing, or commercially exploiting the Software or derivative builds.
- Repackaging, cloning, white-labeling, or redistributing the Software on third-party stores, repositories, or file-sharing mirrors.
- Reverse engineering, disassembling, patching compiled binaries, extracting protected metadata, or altering/forging copyright, developer attribution, or legal notice screens (except solely to the narrow extent mandatory law prohibits contractual restrictions for interoperability).

Unauthorized redistribution, counterfeit cloning, or attribution removal immediately terminates this license and may be pursued under applicable copyright and intellectual property laws.

## 4. Open-Source Components Attribution
Portions of the Software incorporate open-source libraries and typography (such as the Flutter framework, packages, and bundled fonts) governed independently by their respective permissive open-source licenses (BSD, MIT, Apache 2.0, and SIL Open Font License). Nothing in this Agreement restricts your rights under those open-source licenses; full license notices are displayed in **About & Legal → Open Source Licenses**.

## 5. Termination & Governing Law
This Agreement remains active until terminated by you (by uninstalling the Software and destroying all copies) or automatically upon any breach of its terms. Except where preempted by mandatory consumer law in your country of residence, this Agreement is governed by the applicable laws of **$jurisdiction**.

By continuing to use $appName, you acknowledge that you have read, understood, and accepted this Agreement.
''';
