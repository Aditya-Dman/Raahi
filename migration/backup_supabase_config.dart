// BACKUP OF CURRENT SUPABASE CONFIGURATION
// Keep this file safe - it contains your current working Supabase setup
// Use this to rollback if needed during migration

class SupabaseConfigBackup {
  // Current working Supabase credentials (as of December 2024)
  static const String supabaseUrl = 'https://kdunsvcmgpxyqphrkzzu.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtkdW5zdmNtZ3B4eXFwaHJrenp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgxMTQ3NDksImV4cCI6MjA3MzY5MDc0OX0.zDtkvzmbp3ngQSahohTZEVR7fC1HUb3AaoduLaPpGBQ';
}

// To rollback to this configuration:
// 1. Copy the values above
// 2. Replace them in lib/services/supabase_config.dart
// 3. Restart your app