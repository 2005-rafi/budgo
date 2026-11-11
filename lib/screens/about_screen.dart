import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:expense/core/constants/legal_policies.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/security/brand_integrity.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/widgets/sheets/legal_document_sheet.dart';
import 'package:expense/widgets/tiles/app_settings_tile.dart';

class AboutScreen extends StatelessWidget {
  final BrandIntegrityReport? integrityOverride;

  const AboutScreen({
    super.key,
    this.integrityOverride,
  });

  Future<void> _launchUri(BuildContext context, Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          SnackbarFeedback.showError(
            context,
            'Could not open the external application.',
            operation: FeedbackOperation.openLink,
            guidance: 'Verify a mail or browser app is configured on your device.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarFeedback.showError(
          context,
          e,
          operation: FeedbackOperation.openLink,
        );
      }
    }
  }

  Future<void> _copySupportEmail(BuildContext context, String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (context.mounted) {
      SnackbarFeedback.showSuccess(
        context,
        'Support email copied to clipboard.',
      );
    }
  }

  String _safeDiagnosticTemplate() {
    return 'Please describe what happened below (no personal or financial records are included):\n\n'
        'App: ${AppBrand.appName} ${AppBrand.version} (${AppBrand.buildNumber})\n'
        'Feedback:\n';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final integrity = integrityOverride ?? AppBrand.verifyIntegrity();
    final isVerified = integrity.isValid;

    final safeDeveloper =
        isVerified ? AppBrand.developerName : 'Attribution Verification Failed';
    final safeCopyright = isVerified
        ? '${AppBrand.copyrightStatement} • ${AppBrand.rightsNotice}'
        : 'Modified Build Metadata Detected';

    return Scaffold(
      appBar: const BudgoAppBar(title: 'About & Legal'),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.base,
        ),
        children: [
          if (!isVerified) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gpp_maybe_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Build Integrity Notice',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ownership or legal metadata failed verification. Use only official, unmodified releases.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Brand Showcase Header Card
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              children: [
                const AppBrandLogo.about(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppBrand.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: AppBrand.brandFontFamily,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    AppBrand.taglineUppercase,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: AppBrand.taglineFontFamily,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppBrand.appTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _BrandStatusPill(
                      icon: Icons.tag_rounded,
                      label: '${AppBrand.versionBadge} (${AppBrand.buildNumber})',
                      background: colorScheme.primaryContainer,
                      foreground: colorScheme.onPrimaryContainer,
                    ),
                    _BrandStatusPill(
                      icon: isVerified
                          ? Icons.verified_user_outlined
                          : Icons.gpp_maybe_outlined,
                      label: isVerified ? '100% Offline • Verified' : 'Unverified',
                      background: isVerified
                          ? colorScheme.secondaryContainer
                          : colorScheme.errorContainer,
                      foreground: isVerified
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onErrorContainer,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Credits, Ownership & Privacy Architecture
          const AppSectionHeader(
            label: 'Ownership & Architecture',
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'Developer & Rights Holder',
                  subtitle: safeDeveloper,
                  leadingIcon: Icons.person_outline_rounded,
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'Copyright Notice',
                  subtitle: safeCopyright,
                  leadingIcon: Icons.copyright_rounded,
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'License Model',
                  subtitle: AppBrand.licenseModel,
                  leadingIcon: Icons.gavel_outlined,
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                const AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'Data Custody',
                  subtitle: 'Device-local storage only • Zero cloud tracking',
                  leadingIcon: Icons.shield_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Support & Communication
          const AppSectionHeader(
            label: 'Support & Feedback',
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Email Support',
                  subtitle: isVerified
                      ? AppBrand.contactEmail
                      : 'Verify build before contacting',
                  leadingIcon: Icons.support_agent_outlined,
                  onTap: isVerified
                      ? () => _launchUri(
                            context,
                            AppBrand.supportMailtoUri(subjectTag: 'Support'),
                          )
                      : null,
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.action,
                  title: 'Copy Support Email',
                  subtitle: 'Copy verified address to clipboard',
                  leadingIcon: Icons.content_copy_rounded,
                  onTap: isVerified
                      ? () => _copySupportEmail(context, AppBrand.contactEmail)
                      : null,
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Send Bug Report or Feedback',
                  subtitle: 'Opens mail draft with app version only (no user data)',
                  leadingIcon: Icons.bug_report_outlined,
                  onTap: isVerified
                      ? () => _launchUri(
                            context,
                            AppBrand.supportMailtoUri(
                              subjectTag: 'Feedback',
                              body: _safeDiagnosticTemplate(),
                            ),
                          )
                      : null,
                ),
                if (AppBrand.showSourceLinks &&
                    AppBrand.repositoryUrl.isNotEmpty) ...[
                  const Divider(height: 1, indent: AppSpacing.base),
                  AppSettingsTile(
                    type: AppSettingsTileType.navigation,
                    title: 'Project Website',
                    leadingIcon: Icons.public_outlined,
                    onTap: () =>
                        _launchUri(context, Uri.parse(AppBrand.repositoryUrl)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Legal, Compliance & Open Source Attributions
          const AppSectionHeader(
            label: 'Legal & Compliance',
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Privacy Policy',
                  subtitle: 'Zero-collection offline commitment & permissions',
                  leadingIcon: Icons.privacy_tip_outlined,
                  onTap: () => LegalDocumentSheet.show(
                    context,
                    title: 'Privacy Policy',
                    icon: Icons.privacy_tip_outlined,
                    markdownData: LegalPolicies.privacyPolicy,
                    integrityVerified: isVerified,
                    onTapLink: (href) => _launchUri(context, Uri.parse(href)),
                  ),
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Terms of Use',
                  subtitle: 'Scope, non-advisory disclaimer & usage conduct',
                  leadingIcon: Icons.description_outlined,
                  onTap: () => LegalDocumentSheet.show(
                    context,
                    title: 'Terms of Use',
                    icon: Icons.description_outlined,
                    markdownData: LegalPolicies.termsOfUse,
                    integrityVerified: isVerified,
                    onTapLink: (href) => _launchUri(context, Uri.parse(href)),
                  ),
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'End User License Agreement (EULA)',
                  subtitle: 'Proprietary rights, anti-cloning & OSS notice',
                  leadingIcon: Icons.assignment_outlined,
                  onTap: () => LegalDocumentSheet.show(
                    context,
                    title: 'End User License Agreement',
                    icon: Icons.assignment_outlined,
                    markdownData: LegalPolicies.eula,
                    integrityVerified: isVerified,
                    onTapLink: (href) => _launchUri(context, Uri.parse(href)),
                  ),
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Open Source Licenses',
                  subtitle: 'Flutter SDK, packages & bundled font attributions',
                  leadingIcon: Icons.account_tree_outlined,
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: AppBrand.appName,
                      applicationVersion: AppBrand.versionBadge,
                      applicationIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: AppBrandLogo.compact(),
                      ),
                      applicationLegalese: safeCopyright,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Footer
          Center(
            child: Column(
              children: [
                Text(
                  AppBrand.buildFooter,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your financial records stay exclusively on this device.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _BrandStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _BrandStatusPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
