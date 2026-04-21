# New Supabase Project Setup Guide

## Step 1: Create New Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Click "New project" 
3. Fill in the details:
   - **Project Name**: raahi-v2 (or your preferred name)
   - **Database Password**: Create a strong password (save it)
   - **Region**: Choose the closest to your users
   - **Pricing Plan**: Select Free or Pro as needed

4. Wait for the project to initialize (2-3 minutes)

## Step 2: Get Your Credentials

Once the project is created:
1. Go to **Settings > API** in the Supabase dashboard
2. Copy the **Project URL** (looks like: `https://xxxxx.supabase.co`)
3. Copy the **anon key** (under Project API Keys)
4. **SAVE THESE** - you'll need them for the app config

## Step 3: Set Up Database (Apply RLS & Tables)

1. In your Supabase dashboard, go to **SQL Editor**
2. Click **New Query**
3. Paste the entire content from: `migration/complete_database_setup.sql`
4. Click **RUN** (this creates all tables, indexes, RLS policies, and functions)
5. Wait for it to complete (should see success message)

## Step 4: Restore Your Backup Data

1. In Supabase dashboard, go to **Settings > Database > Backups**
2. Click **Restore from backup**
3. Upload your backup file: `db_cluster-15-10-2025@20-12-44.backup`
4. Wait for restoration to complete

> ⚠️ **Note**: After restore, re-run the complete_database_setup.sql to ensure all RLS policies are in place (backup won't restore policies)

## Step 5: Update App Configuration

1. Open: `lib/services/supabase_config.dart`
2. Replace the old values with your new credentials:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'YOUR_NEW_PROJECT_URL_HERE';
  static const String supabaseAnonKey = 'YOUR_NEW_ANON_KEY_HERE';
}
```

Example:
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://abcdef123456.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

## Step 6: Test the App

1. Run the app:
   ```bash
   flutter clean && flutter pub get && flutter run
   ```

2. Test these features:
   - ✅ Sign up with new account
   - ✅ Login with that account
   - ✅ Check if you can see your previous data (from backup)
   - ✅ Try adding new data

## Troubleshooting

### Database restore failed?
- Download your data from the paused project first
- Manually insert critical data using SQL INSERT statements
- Backup file location: `db_cluster-15-10-2025@20-12-44.backup`

### Auth not working?
- Verify Project URL and Anon Key are correct
- Check that email auth is enabled in Supabase Settings
- Ensure your device/emulator has internet connection

### RLS policy errors?
- Re-run the `complete_database_setup.sql` file
- Check that all policies are created: `SELECT * FROM pg_policies;`

### Tables not showing?
- Check SQL Editor output for errors
- Refresh the browser tab
- Verify complete_database_setup.sql ran completely

## Files Involved

- **Configuration**: `lib/services/supabase_config.dart` ← Update this with new credentials
- **Setup SQL**: `migration/complete_database_setup.sql` ← Run in Supabase SQL Editor
- **Backup**: `db_cluster-15-10-2025@20-12-44.backup` ← Restore in Supabase
- **Auth Service**: `lib/services/supabase_auth_service.dart`
- **Data Service**: `lib/services/supabase_data_service.dart`

## RLS Policies Applied

Your new project will have these security rules:
- Users can only view/edit their own data
- Emergency alerts with status='active' are publicly readable (for safety)
- All personal data (locations, contacts, digital IDs) are private to user
- Automatic profile creation on signup

Good luck! 🚀
