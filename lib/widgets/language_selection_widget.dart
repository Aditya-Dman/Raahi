import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../app_theme.dart';

class LanguageSelectionDialog extends StatelessWidget {
  const LanguageSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.language, color: AppColors.teal),
          SizedBox(width: 8),
          Expanded(
            child: Text('Select Language', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: LanguageService.getAvailableLanguages().map((language) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.teal.withValues(alpha: 0.1),
              child: Text(
                language['code']!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              language['nativeName']!,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(language['name']!),
            onTap: () async {
              await context.read<LanguageNotifier>().changeLanguage(
                language['code']!,
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();

              // Show confirmation snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    language['code'] == 'hi'
                        ? 'भाषा हिंदी में बदल दी गई'
                        : 'Language changed to English',
                  ),
                  backgroundColor: AppColors.teal,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.teal)),
        ),
      ],
    );
  }
}

class LanguageSelectionButton extends StatelessWidget {
  const LanguageSelectionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageNotifier>(
      builder: (context, languageNotifier, child) {
        final currentLanguageCode = languageNotifier.currentLocale.languageCode;
        final currentLanguage = LanguageService.getAvailableLanguages()
            .firstWhere((lang) => lang['code'] == currentLanguageCode);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const LanguageSelectionDialog(),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.language,
                      color: AppColors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentLanguageCode == 'hi' ? 'भाषा' : 'Language',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentLanguage['nativeName']!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.teal,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
