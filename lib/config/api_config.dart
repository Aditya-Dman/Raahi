// API Configuration
// For security, API keys are loaded from environment variables or local config

class ApiConfig {
  // Google Maps and Places API Key
  static const String googleApiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue:
        'YOUR_GOOGLE_API_KEY_HERE', // Placeholder for public repository
  );

  // Supabase Configuration (from environment variables)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-id.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );

  // Validate that API keys are properly configured
  static bool get isConfigured {
    return googleApiKey != 'YOUR_GOOGLE_API_KEY_HERE' &&
        googleApiKey.isNotEmpty;
  }

  // Get API key with validation
  static String getGoogleApiKey() {
    if (!isConfigured) {
      throw Exception(
        'Google API Key not configured. Please set GOOGLE_API_KEY environment variable or update api_config.dart',
      );
    }
    return googleApiKey;
  }
}
