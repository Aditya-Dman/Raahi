# Supabase Integration Setup for Raahi App

## Overview
Your Flutter app has been successfully integrated with Supabase! This integration replaces the SQLite database with a cloud-based Supabase backend for authentication and data management.

## What's Been Changed

### 1. Dependencies Added
- `supabase_flutter: ^2.5.6` - Main Supabase client
- `shared_preferences: ^2.2.2` - Local session storage

### 2. New Service Files Created
- `lib/services/supabase_config.dart` - Configuration file
- `lib/services/supabase_service.dart` - Core Supabase client wrapper
- `lib/services/supabase_auth_service.dart` - Authentication service
- `lib/services/supabase_data_service.dart` - Database operations
- `lib/services/user_session.dart` - Updated session management

### 3. Updated Files
- `lib/main.dart` - Supabase initialization
- `lib/login_page.dart` - Uses Supabase authentication
- `lib/signup_page.dart` - Uses Supabase authentication
- `lib/dashboard_page.dart` - Uses new UserSession service

## Required Setup Steps

### 1. Create a Supabase Project
1. Go to [https://supabase.com](https://supabase.com)
2. Create a new account or sign in
3. Create a new project
4. Note down your Project URL and API Keys

### 2. Configure Your App
1. Open `lib/services/supabase_config.dart`
2. Replace the placeholder values:
   ```dart
   static const String supabaseUrl = 'https://your-project-id.supabase.co';
   static const String supabaseAnonKey = 'your-anon-key-here';
   ```

### 3. Set Up Database Tables
Run these SQL commands in your Supabase SQL editor:

```sql
-- Create user profiles table
CREATE TABLE user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  user_type TEXT NOT NULL DEFAULT 'Tourist',
  nationality TEXT,
  digital_id TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user locations table
CREATE TABLE user_locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  location_name TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create emergency alerts table
CREATE TABLE emergency_alerts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL,
  message TEXT NOT NULL,
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create tourist info table
CREATE TABLE tourist_info (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  destination TEXT NOT NULL,
  check_in_date TIMESTAMP WITH TIME ZONE,
  check_out_date TIMESTAMP WITH TIME ZONE,
  hotel_info TEXT,
  emergency_contact TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE tourist_info ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view own profile" ON user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can view own locations" ON user_locations FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own alerts" ON emergency_alerts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own tourist info" ON tourist_info FOR ALL USING (auth.uid() = user_id);

-- Allow public read for emergency alerts (for safety features)
CREATE POLICY "Public can view active alerts" ON emergency_alerts FOR SELECT USING (status = 'active');
```

### 4. Set Up Authentication
1. In your Supabase dashboard, go to Authentication > Settings
2. Enable email authentication
3. Configure email templates if needed
4. Set up any additional authentication providers

## Features Now Available

### Authentication
- User registration with email/password
- User login with session management
- Secure logout with session cleanup
- User types: Tourist, Administrator, Police Officer, Tourism Officer, Emergency Responder

### Data Management
- User profiles stored in Supabase
- Location tracking capabilities
- Emergency alert system
- Tourist information management

### Security
- Row Level Security (RLS) enabled
- Users can only access their own data
- Secure authentication with Supabase Auth

## Testing the Integration

1. Update the configuration file with your Supabase credentials
2. Run the app: `flutter run`
3. Try creating a new account through the signup page
4. Verify login functionality
5. Check that user data persists across sessions

## Next Steps

- Add real-time features using Supabase realtime subscriptions
- Implement push notifications for emergency alerts
- Add file upload functionality for user avatars
- Integrate with mapping services for location features

## Troubleshooting

### Common Issues
1. **Authentication errors**: Check your Supabase URL and API key
2. **Database errors**: Ensure all tables are created with proper RLS policies
3. **Network errors**: Verify internet connection and Supabase project status

### Support
- Supabase Documentation: [https://supabase.com/docs](https://supabase.com/docs)
- Flutter Integration Guide: [https://supabase.com/docs/guides/getting-started/tutorials/with-flutter](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)