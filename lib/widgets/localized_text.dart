import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class LocalizedText extends StatelessWidget {
  final String englishText;
  final String hindiText;
  final TextStyle? style;

  const LocalizedText({
    super.key,
    required this.englishText,
    required this.hindiText,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageNotifier>(
      builder: (context, languageNotifier, child) {
        final isHindi = languageNotifier.currentLocale.languageCode == 'hi';
        final textToShow = isHindi ? hindiText : englishText;
        print(
          '🔤 LocalizedText: locale=${languageNotifier.currentLocale.languageCode}, isHindi=$isHindi, showing: $textToShow',
        );
        return Text(textToShow, style: style);
      },
    );
  }
}

// Helper function to get localized string
String getLocalizedString(
  BuildContext context,
  String englishText,
  String hindiText,
) {
  final languageNotifier = context.read<LanguageNotifier>();
  final isHindi = languageNotifier.currentLocale.languageCode == 'hi';
  return isHindi ? hindiText : englishText;
}

// Common localized strings
class LocalizedStrings {
  static Widget appName(BuildContext context) => LocalizedText(
    englishText: 'Raahi',
    hindiText: 'राही',
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
  );

  static Widget appTagline(BuildContext context) => LocalizedText(
    englishText: 'Smart Tourist Safety System',
    hindiText: 'स्मार्ट पर्यटक सुरक्षा प्रणाली',
    style: TextStyle(
      fontSize: 16,
      color: Colors.white.withOpacity(0.8),
      letterSpacing: 1,
    ),
  );

  static Widget loading(BuildContext context) => LocalizedText(
    englishText: 'Loading...',
    hindiText: 'लोड हो रहा है...',
    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
  );

  static Widget dashboard(BuildContext context) => LocalizedText(
    englishText: 'Dashboard',
    hindiText: 'डैशबोर्ड',
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF2D3748),
    ),
  );

  static Widget profile(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    return LocalizedText(
      englishText: 'Profile Information',
      hindiText: 'प्रोफ़ाइल जानकारी',
      style: TextStyle(
        fontSize: isDesktop ? 18 : 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF2D3748),
      ),
    );
  }

  static Widget emergencyAlert(BuildContext context) => LocalizedText(
    englishText: 'Emergency Alert',
    hindiText: 'आपातकालीन अलर्ट',
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  );

  static Widget sendAlert(BuildContext context) => LocalizedText(
    englishText: 'Send Alert',
    hindiText: 'अलर्ट भेजें',
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  );

  // Navigation menu items
  static Widget overview(BuildContext context) => LocalizedText(
    englishText: 'Overview',
    hindiText: 'सिंहावलोकन',
    style: const TextStyle(fontSize: 14),
  );

  static Widget gps(BuildContext context) => LocalizedText(
    englishText: 'GPS',
    hindiText: 'जीपीएस',
    style: const TextStyle(fontSize: 14),
  );

  static Widget safetyEmergency(BuildContext context) => LocalizedText(
    englishText: 'Safety Emergency',
    hindiText: 'सुरक्षा आपातकाल',
    style: const TextStyle(fontSize: 14),
  );

  static Widget aiAssistant(BuildContext context) => LocalizedText(
    englishText: 'AI Assistant',
    hindiText: 'एआई सहायक',
    style: const TextStyle(fontSize: 14),
  );

  static Widget iot(BuildContext context) => LocalizedText(
    englishText: 'IoT',
    hindiText: 'आईओटी',
    style: const TextStyle(fontSize: 14),
  );

  static Widget digitalId(BuildContext context) => LocalizedText(
    englishText: 'ID',
    hindiText: 'पहचान',
    style: const TextStyle(fontSize: 14),
  );

  // Permission messages
  static String phonePermissionMessage(BuildContext context) {
    final languageNotifier = context.read<LanguageNotifier>();
    final isHindi = languageNotifier.currentLocale.languageCode == 'hi';
    return isHindi
        ? 'आपातकालीन कॉलिंग सुविधाओं के लिए फोन अनुमति आवश्यक है'
        : 'Phone permission is needed for emergency calling features';
  }

  static String smsPermissionMessage(BuildContext context) {
    final languageNotifier = context.read<LanguageNotifier>();
    final isHindi = languageNotifier.currentLocale.languageCode == 'hi';
    return isHindi
        ? 'स्वचालित आपातकालीन अलर्ट के लिए SMS अनुमति आवश्यक है'
        : 'SMS permission is needed for automatic emergency alerts';
  }

  static String locationPermissionMessage(BuildContext context) {
    final languageNotifier = context.read<LanguageNotifier>();
    final isHindi = languageNotifier.currentLocale.languageCode == 'hi';
    return isHindi
        ? 'GPS ट्रैकिंग और मैप्स के लिए स्थान अनुमति आवश्यक है'
        : 'Location permission is needed for GPS tracking and maps';
  }
}
