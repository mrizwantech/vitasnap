import 'package:flutter/material.dart';
import '../../presentation/widgets/vitasnap_logo.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: true),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A4E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    color: const Color(0xFF1B8A4E),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Privacy Matters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: January 2026',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              context,
              icon: Icons.info_outline,
              title: 'Introduction',
              content:
                  'VitaSnap ("we", "our", or "us") is committed to protecting your privacy. '
                  'All your data stays on your device - we do not collect, store, or transmit '
                  'any of your personal information to external servers.',
            ),

            _buildSection(
              context,
              icon: Icons.storage_outlined,
              title: 'We Do Not Collect Your Data',
              content:
                  '''VitaSnap does NOT collect any personal information. Everything stays on your device:

• Scanned products and nutritional info - stored locally
• Your dietary preferences - stored locally
• Scan history - stored locally
• Health conditions - stored locally

We have no servers storing your data. We do not track you. We do not have access to your information.''',
            ),

            _buildSection(
              context,
              icon: Icons.analytics_outlined,
              title: 'How The App Works',
              content: '''All processing happens on your device:

• Product lookups use public food databases
• Your preferences personalize your experience locally
• Scan history is saved only on your phone
• No accounts required - no sign-up needed''',
            ),

            _buildSection(
              context,
              icon: Icons.phone_android_outlined,
              title: 'Local Storage Only',
              content:
                  'All your data is stored exclusively on your device. '
                  'There is no cloud backup, no sync, and no remote storage. '
                  'If you uninstall the app or clear app data, your information will be permanently deleted.',
            ),

            _buildSection(
              context,
              icon: Icons.block_outlined,
              title: 'No Data Sharing or Selling',
              content:
                  'We do not sell, trade, share, or rent any information - because we do not have access to it. '
                  'Your data never leaves your device. There is nothing for us to share with anyone.',
            ),

            _buildSection(
              context,
              icon: Icons.security_outlined,
              title: 'Data Security',
              content:
                  'Your data is as secure as your device. Since all information is stored locally, '
                  'your data security depends on your device\'s security settings (screen lock, encryption, etc.).',
            ),

            _buildSection(
              context,
              icon: Icons.child_care_outlined,
              title: "Children's Privacy",
              content:
                  'Our app is not intended for children under 13 years of age. '
                  'We do not knowingly collect personal information from children.',
            ),

            _buildSection(
              context,
              icon: Icons.settings_outlined,
              title: 'Your Control',
              content: '''You have complete control over your data:

• Clear your scan history anytime in Settings
• Modify your dietary preferences anytime
• Uninstall the app to delete all data permanently
• No account to manage - it's that simple''',
            ),

            _buildSection(
              context,
              icon: Icons.update_outlined,
              title: 'Changes to This Policy',
              content:
                  'We may update this Privacy Policy from time to time. '
                  'We will notify you of any changes by posting the new policy in the app.',
            ),

            _buildSection(
              context,
              icon: Icons.email_outlined,
              title: 'Contact Us',
              content:
                  'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                  'support@vitasnap.app',
            ),

            const SizedBox(height: 24),

            // Footer
            Center(
              child: Text(
                '© ${DateTime.now().year} VitaSnap. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1B8A4E), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
