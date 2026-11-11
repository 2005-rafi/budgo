import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:expense/design/budgo_ui.dart';

/// Material 3 Expressive modal reader for legal documents (Privacy Policy, Terms, EULA)
/// replacing constrained alert dialogs with readable typography and metadata provenance.
class LegalDocumentSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final String markdownData;
  final bool integrityVerified;
  final void Function(String url)? onTapLink;

  const LegalDocumentSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.markdownData,
    this.integrityVerified = true,
    this.onTapLink,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String markdownData,
    bool integrityVerified = true,
    void Function(String url)? onTapLink,
  }) {
    return BudgoBottomSheet.show(
      context,
      builder: (_) => LegalDocumentSheet(
        title: title,
        icon: icon,
        markdownData: markdownData,
        integrityVerified: integrityVerified,
        onTapLink: onTapLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BudgoBottomSheet(
      title: title,
      subtitle: '${AppBrand.appName} • Effective ${AppBrand.legalEffectiveDate}',
      icon: icon,
      maxHeightFactor: 0.9,
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: integrityVerified
              ? colorScheme.primaryContainer.withValues(alpha: 0.6)
              : colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              integrityVerified
                  ? Icons.verified_user_outlined
                  : Icons.gpp_maybe_outlined,
              size: 14,
              color: integrityVerified
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 4),
            Text(
              integrityVerified ? 'Sealed' : 'Modified',
              style: theme.textTheme.labelSmall?.copyWith(
                color: integrityVerified
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      footer: BudgoButton(
        label: 'Close Document',
        variant: BudgoButtonVariant.tonal,
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Markdown(
          data: markdownData,
          padding: const EdgeInsets.all(AppSpacing.base),
          styleSheet: MarkdownStyleSheet(
            h1: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
            h2: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
            h3: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            p: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            strong: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            listBullet: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          onTapLink: (text, href, title) {
            if (href != null && onTapLink != null) {
              onTapLink!(href);
            }
          },
        ),
      ),
    );
  }
}

