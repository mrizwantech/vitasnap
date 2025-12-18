import 'package:flutter/material.dart';
import '../../core/strings.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(AppStrings.privacyPolicy),
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
                          'Last updated: December 2024',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
              content: 'VitaSnap ("we", "our", or "us") is committed to protecting your privacy. '
                  'This Privacy Policy explains how we collect, use, and safeguard your information '
                  'when you use our mobile application.',
            ),

            _buildSection(
              context,
              icon: Icons.storage_outlined,
              title: 'Information We Collect',
              content: '''• Scanned product barcodes and nutritional information
• Account information (email, name) if you create an account
• Dietary preferences you set in the app
• App usage data to improve our services

We do NOT collect:
• Your location data
• Contact information
• Photos or media files
• Financial information''',
            ),

            _buildSection(
              context,
              icon: Icons.analytics_outlined,
              title: 'How We Use Your Information',
              content: '''• To provide product nutritional information
• To save your scan history for easy access
• To personalize dietary recommendations
• To improve our app and services
• To send important updates about the app''',
            ),

            _buildSection(
              context,
              icon: Icons.cloud_outlined,
              title: 'Data Storage',
              content: 'Your scan history and preferences are stored locally on your device. '
                  'If you create an account, basic account information is stored securely on our servers '
                  'using industry-standard encryption.',
            ),

            _buildSection(
              context,
              icon: Icons.share_outlined,
              title: 'Information Sharing',
              content: 'We do not sell, trade, or rent your personal information to third parties. '
                  'We may share anonymized, aggregated data for research or analytical purposes.',
            ),

            _buildSection(
              context,
              icon: Icons.security_outlined,
              title: 'Data Security',
              content: 'We implement appropriate security measures to protect your personal information. '
                  'However, no method of transmission over the internet is 100% secure.',
            ),

            _buildSection(
              context,
              icon: Icons.child_care_outlined,
              title: "Children's Privacy",
              content: 'Our app is not intended for children under 13 years of age. '
                  'We do not knowingly collect personal information from children.',
            ),

            _buildSection(
              context,
              icon: Icons.settings_outlined,
              title: 'Your Choices',
              content: '''• You can clear your scan history at any time
• You can update or delete your account
• You can modify your dietary preferences
• You can opt out of optional data collection''',
            ),

            _buildSection(
              context,
              icon: Icons.update_outlined,
              title: 'Changes to This Policy',
              content: 'We may update this Privacy Policy from time to time. '
                  'We will notify you of any changes by posting the new policy in the app.',
            ),

            _buildSection(
              context,
              icon: Icons.email_outlined,
              title: 'Contact Us',
              content: 'If you have any questions about this Privacy Policy, please contact us at:\n\n'
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
        boxShadow: isDark ? null : [
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
              Icon(
                icon,
                color: const Color(0xFF1B8A4E),
                size: 20,
              ),
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
