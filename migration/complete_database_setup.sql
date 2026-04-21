-- COMPLETE DATABASE SETUP FOR NEW SUPABASE PROJECT
-- Run this entire script in your new Supabase SQL Editor
-- This will set up all tables, indexes, policies, and functions needed for Raahi app

-- =============================================================================
-- 1. CORE TABLES SETUP
-- =============================================================================

-- User profiles table (extends Supabase auth.users)
CREATE TABLE user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  user_type TEXT NOT NULL DEFAULT 'Tourist',
  nationality TEXT,
  digital_id TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User locations table
CREATE TABLE user_locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  location_name TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Emergency alerts table
CREATE TABLE emergency_alerts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL,
  message TEXT NOT NULL,
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tourist info table
CREATE TABLE tourist_info (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  destination TEXT NOT NULL,
  check_in_date TIMESTAMP WITH TIME ZONE,
  check_out_date TIMESTAMP WITH TIME ZONE,
  hotel_info TEXT,
  emergency_contact TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Emergency contacts table
CREATE TABLE emergency_contacts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  relationship VARCHAR(100) NOT NULL,
  email VARCHAR(255),
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Digital IDs table (additional table from your docs)
CREATE TABLE digital_ids (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  digital_id_number TEXT UNIQUE NOT NULL,
  id_type TEXT NOT NULL, -- 'passport', 'national_id', 'driver_license', etc.
  issuing_country TEXT NOT NULL,
  issue_date DATE,
  expiry_date DATE,
  verification_status TEXT DEFAULT 'pending', -- 'pending', 'verified', 'rejected'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 2. INDEXES FOR PERFORMANCE
-- =============================================================================

-- User profiles indexes
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_digital_id ON user_profiles(digital_id);
CREATE INDEX idx_user_profiles_user_type ON user_profiles(user_type);

-- User locations indexes
CREATE INDEX idx_user_locations_user_id ON user_locations(user_id);
CREATE INDEX idx_user_locations_timestamp ON user_locations(timestamp);

-- Emergency alerts indexes
CREATE INDEX idx_emergency_alerts_user_id ON emergency_alerts(user_id);
CREATE INDEX idx_emergency_alerts_status ON emergency_alerts(status);
CREATE INDEX idx_emergency_alerts_created_at ON emergency_alerts(created_at);

-- Tourist info indexes
CREATE INDEX idx_tourist_info_user_id ON tourist_info(user_id);

-- Emergency contacts indexes
CREATE INDEX idx_emergency_contacts_user_id ON emergency_contacts(user_id);
CREATE INDEX idx_emergency_contacts_is_primary ON emergency_contacts(is_primary);

-- Digital IDs indexes
CREATE INDEX idx_digital_ids_user_id ON digital_ids(user_id);
CREATE INDEX idx_digital_ids_digital_id_number ON digital_ids(digital_id_number);
CREATE INDEX idx_digital_ids_verification_status ON digital_ids(verification_status);

-- =============================================================================
-- 3. ROW LEVEL SECURITY (RLS) SETUP
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE tourist_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE digital_ids ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 4. RLS POLICIES
-- =============================================================================

-- User profiles policies
CREATE POLICY "Users can view own profile" ON user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON user_profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- User locations policies
CREATE POLICY "Users can view own locations" ON user_locations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own locations" ON user_locations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own locations" ON user_locations FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own locations" ON user_locations FOR DELETE USING (auth.uid() = user_id);

-- Emergency alerts policies
CREATE POLICY "Users can view own alerts" ON emergency_alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own alerts" ON emergency_alerts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own alerts" ON emergency_alerts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own alerts" ON emergency_alerts FOR DELETE USING (auth.uid() = user_id);
-- Allow public read for emergency alerts (for safety features)
CREATE POLICY "Public can view active alerts" ON emergency_alerts FOR SELECT USING (status = 'active');

-- Tourist info policies
CREATE POLICY "Users can view own tourist info" ON tourist_info FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own tourist info" ON tourist_info FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own tourist info" ON tourist_info FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own tourist info" ON tourist_info FOR DELETE USING (auth.uid() = user_id);

-- Emergency contacts policies
CREATE POLICY "Users can view their own emergency contacts" ON emergency_contacts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own emergency contacts" ON emergency_contacts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own emergency contacts" ON emergency_contacts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own emergency contacts" ON emergency_contacts FOR DELETE USING (auth.uid() = user_id);

-- Digital IDs policies
CREATE POLICY "Users can view own digital IDs" ON digital_ids FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own digital IDs" ON digital_ids FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own digital IDs" ON digital_ids FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own digital IDs" ON digital_ids FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 5. FUNCTIONS AND TRIGGERS
-- =============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at columns
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_emergency_contacts_updated_at BEFORE UPDATE ON emergency_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_digital_ids_updated_at BEFORE UPDATE ON digital_ids FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create user profile automatically when user signs up
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_profiles (
    id,
    full_name,
    email,
    user_type,
    nationality,
    digital_id
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'user_type', 'Tourist'),
    COALESCE(NEW.raw_user_meta_data->>'nationality', 'Unknown'),
    COALESCE(NEW.raw_user_meta_data->>'digital_id', NULL)
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Trigger to create user profile on signup
CREATE TRIGGER create_user_profile_trigger
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION create_user_profile();

-- =============================================================================
-- 6. SETUP VERIFICATION
-- =============================================================================

-- Insert some sample data to verify setup (optional)
-- You can delete this after confirming everything works
DO $$
BEGIN
    -- This will only work after a user signs up
    RAISE NOTICE 'Database setup completed successfully!';
    RAISE NOTICE 'Tables created: user_profiles, user_locations, emergency_alerts, tourist_info, emergency_contacts, digital_ids';
    RAISE NOTICE 'Indexes created for optimal performance';
    RAISE NOTICE 'Row Level Security enabled with appropriate policies';
    RAISE NOTICE 'Functions and triggers set up for automatic profile creation';
END $$;

-- =============================================================================
-- MIGRATION COMPLETE!
-- =============================================================================
-- Your new Supabase database is now ready for the Raahi app
-- Next steps:
-- 1. Update your app's Supabase configuration with new credentials
-- 2. Test user registration and login
-- 3. Verify all app features work correctly
-- =============================================================================