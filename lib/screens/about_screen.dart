import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/widgets/common/app_card.dart';
import 'package:expense/widgets/common/app_settings_tile.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About & Legal'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.base),
        children: [
          // App Header Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Budgo',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your Personal Finance Companion',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Version 1.0.0',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Developer Information
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'Developer',
                  subtitle: 'Mohammed Rafi H',
                  leadingIcon: Icons.person_outline,
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'Contact Email',
                  subtitle: '2005.mohammedrafi.h@gmail.com',
                  leadingIcon: Icons.email_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Ownership Information
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'Copyright',
                  subtitle: '© 2026 Mohammed Rafi H',
                  leadingIcon: Icons.copyright,
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.info,
                  title: 'Rights',
                  subtitle: 'All Rights Reserved',
                  leadingIcon: Icons.gavel_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Support & Contact
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Email Support',
                  leadingIcon: Icons.support_agent_outlined,
                  onTap: () {},
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Report Issue',
                  leadingIcon: Icons.bug_report_outlined,
                  onTap: () {},
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Feature Request',
                  leadingIcon: Icons.lightbulb_outline,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Project Resources
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'GitHub Repository',
                  leadingIcon: Icons.code,
                  onTap: () {},
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Release Notes',
                  leadingIcon: Icons.article_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Legal Documents
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Privacy Policy',
                  leadingIcon: Icons.privacy_tip_outlined,
                  onTap: () {},
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Terms of Use',
                  leadingIcon: Icons.description_outlined,
                  onTap: () {},
                ),
                const Divider(height: 1, indent: AppSpacing.base),
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'End User License Agreement',
                  leadingIcon: Icons.assignment_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Open Source Attribution
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingsTile(
                  type: AppSettingsTileType.navigation,
                  title: 'Open Source Licenses',
                  subtitle: 'Flutter, Packages, and Fonts',
                  leadingIcon: Icons.account_tree_outlined,
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Budgo',
                      applicationVersion: '1.0.0',
                      applicationIcon: Icon(
                        Icons.account_balance_wallet,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      applicationLegalese: '© 2026 Mohammed Rafi H',
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
                  'Designed and Developed by Mohammed Rafi H',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Build 100 • Stable Channel',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
