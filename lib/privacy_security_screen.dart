import 'package:flutter/material.dart';

import 'app_theme.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  static const _sections = [
    (
      'What Raahi stores',
      'Raahi may store your account details, emergency contacts, digital tourist ID, '
          'saved route points, and emergency event history so safety tools continue to work.',
    ),
    (
      'Why it is used',
      'Data is used to provide GPS tracking, emergency communication, identity display, '
          'and personalized safety guidance. It is not collected for advertising.',
    ),
    (
      'Who can access it',
      'Your personal data is restricted to your account and authorized safety workflows. '
          'Location sharing is only initiated through an explicit action in the app.',
    ),
    (
      'Location and images',
      'You can stop tracking or location sharing at any time. Images are uploaded for AI '
          'analysis only after you select or capture a photo and are not required for text chat.',
    ),
    (
      'Retention and deletion',
      'Saved safety records should be reviewed and removed according to the project’s '
          'retention policy. Contact the administrator to request account or data deletion.',
    ),
    (
      'API key protection',
      'Provider API keys are kept in the secured server-side Edge Function environment. '
          'They are not embedded in the mobile application.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.tealSoft,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.teal, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Raahi is designed around consent, minimum necessary access, and clear safety communication.',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._sections.map(
            (section) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.teal,
                ),
                title: Text(
                  section.$1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Text(section.$2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
