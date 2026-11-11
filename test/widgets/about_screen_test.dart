import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense/core/security/brand_integrity.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/screens/about_screen.dart';
import 'package:expense/widgets/sheets/legal_document_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AboutScreen & LegalDocumentSheet Tests', () {
    testWidgets('Renders upgraded AppBrandLogo, centralized identity, and hides repo links', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: AboutScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBrandLogo), findsOneWidget);
      expect(find.text(AppBrand.appName), findsOneWidget);
      expect(find.text(AppBrand.taglineUppercase), findsOneWidget);
      expect(find.text('${AppBrand.versionBadge} (${AppBrand.buildNumber})'), findsOneWidget);
      expect(find.text('100% Offline • Verified'), findsOneWidget);

      // Consolidated attribution card
      expect(find.text(AppBrand.developerName), findsOneWidget);
      expect(find.text('${AppBrand.copyrightStatement} • ${AppBrand.rightsNotice}'), findsOneWidget);
      expect(find.text(AppBrand.contactEmail), findsOneWidget);

      // Proprietary stance: public GitHub repo links hidden by default
      expect(find.text('GitHub Repository'), findsNothing);
      expect(find.text('Release Notes'), findsNothing);
      expect(find.text('Build Integrity Notice'), findsNothing);
    });

    testWidgets('Opens Privacy Policy and EULA inside spacious M3 LegalDocumentSheet', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: AboutScreen()),
      );
      await tester.pumpAndSettle();

      // Open Privacy Policy sheet
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentSheet), findsOneWidget);
      expect(find.text('Sealed'), findsOneWidget);
      expect(find.textContaining('Privacy At a Glance'), findsOneWidget);

      await tester.tap(find.text('Close Document'));
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentSheet), findsNothing);

      // Open EULA sheet
      await tester.tap(find.text('End User License Agreement (EULA)'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentSheet), findsOneWidget);
      expect(find.textContaining('Open-Source Components Attribution'), findsOneWidget);
    });

    testWidgets('Tampered integrity state alerts user and shields spoofed developer attribution', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const fakeTamper = BrandIntegrityReport(
        isValid: false,
        computedDigestHex: '0000',
        expectedDigestHex: 'ffff',
        failedChecks: ['digest_mismatch'],
      );

      await tester.pumpWidget(
        const MaterialApp(home: AboutScreen(integrityOverride: fakeTamper)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Build Integrity Notice'), findsOneWidget);
      expect(find.text('Attribution Verification Failed'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text(AppBrand.developerName), findsNothing);
    });
  });
}

