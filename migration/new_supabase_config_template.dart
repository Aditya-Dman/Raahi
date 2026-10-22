// NEW SUPABASE CONFIGURATION TEMPLATE
// Copy this to lib/services/supabase_config.dart and update with your new credentials

class SupabaseConfig {
  // Replace these with your NEW Supabase project credentials
  // You can find these in your Supabase dashboard under Settings > API
  
  static const String supabaseUrl = 'https://YOUR_NEW_PROJECT_ID.supabase.co';
  static const String supabaseAnonKey = 'YOUR_NEW_ANON_KEY_HERE';

  // Example format:
  // static const String supabaseUrl = 'https://abcdef123456.supabase.co';
  // static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiY2RlZjEyMzQ1NiIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjg5NTQ4NDAwLCJleHAiOjIwMDUxMjQ0MDB9.EXAMPLE_KEY_HERE';
}

// IMPORTANT REMINDERS:
// 1. Never commit real credentials to version control
// 2. Your old project credentials will stop working after account suspension
// 3. Test thoroughly after updating these values
// 4. Keep a backup of working credentials until migration is confirmed successful