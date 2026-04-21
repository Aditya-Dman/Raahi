# Raahi App - Supabase Migration Guide

## Overview
This guide will help you migrate your Raahi app from your current Supabase account to a new one when your free account gets suspended. The entire process should take less than 30 minutes.

## What You'll Need
1. A new Supabase account
2. This migration package (all files included in this repo)
3. Your existing app data (if you want to preserve it)

## Migration Steps

### Step 1: Create New Supabase Project
1. Go to [https://supabase.com](https://supabase.com) and create a new account
2. Create a new project
3. Note down:
   - Project URL (format: `https://your-new-project-id.supabase.co`)
   - Anonymous Key (starts with `eyJhbGciOiJIUzI1NiIs...`)

### Step 2: Set Up Database Schema
Run the complete database setup script in your new Supabase SQL editor:
- Execute `migration/complete_database_setup.sql` (created by this migration guide)

### Step 3: Update App Configuration
1. Open `lib/services/supabase_config.dart`
2. Replace the old credentials with your new ones:
   ```dart
   static const String supabaseUrl = 'https://your-new-project-id.supabase.co';
   static const String supabaseAnonKey = 'your-new-anon-key';
   ```

### Step 4: Configure Authentication
1. In your new Supabase dashboard: Authentication > Settings
2. Enable Email authentication
3. Set Site URL to your domain (or `http://localhost:3000` for development)
4. Configure any additional auth providers you were using

### Step 5: Test the Migration
1. Run the app: `flutter run`
2. Test signup functionality
3. Test login functionality  
4. Verify all features work correctly

## Data Preservation (Optional)
If you want to migrate existing user data:
1. Export data from old project using the export script: `migration/export_data.sql`
2. Import using: `migration/import_data.sql`

## Rollback Plan
If something goes wrong:
1. Keep your old Supabase credentials backed up
2. Use the rollback configuration: `migration/rollback_config.dart`

## Post-Migration Checklist
- [ ] New Supabase project created
- [ ] Database schema set up
- [ ] App configuration updated
- [ ] Authentication configured
- [ ] App tested and working
- [ ] Old credentials securely removed

## Emergency Contact
If you face issues during migration:
1. Check the troubleshooting section below
2. Verify all credentials are correct
3. Ensure database schema was properly created

## Troubleshooting
- **Auth errors**: Double-check your URL and API key
- **Database errors**: Ensure all SQL scripts ran successfully
- **Connection errors**: Verify your internet connection and Supabase project status