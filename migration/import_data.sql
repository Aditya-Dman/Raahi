-- IMPORT USER DATA INTO NEW SUPABASE PROJECT
-- Run this AFTER setting up the database schema in your new Supabase project
-- Make sure you've uploaded the CSV files from your data export

-- Import user profiles
-- Note: You'll need to create users in auth.users first, then import profiles
-- This is a template - adjust file paths as needed

-- IMPORTANT: Before running this, you need to:
-- 1. Upload your CSV files to the new Supabase project
-- 2. Create corresponding auth.users entries for each user
-- 3. Adjust the file paths in the COPY commands below

-- Import emergency contacts
COPY emergency_contacts (user_id, name, phone_number, relationship, email, is_primary, created_at, updated_at)
FROM '/path/to/emergency_contacts_export.csv'
WITH CSV HEADER;

-- Import user locations
COPY user_locations (user_id, latitude, longitude, location_name, timestamp)
FROM '/path/to/user_locations_export.csv'
WITH CSV HEADER;

-- Import emergency alerts
COPY emergency_alerts (user_id, alert_type, message, latitude, longitude, status, created_at)
FROM '/path/to/emergency_alerts_export.csv'
WITH CSV HEADER;

-- Import tourist info
COPY tourist_info (user_id, destination, check_in_date, check_out_date, hotel_info, emergency_contact, created_at)
FROM '/path/to/tourist_info_export.csv'
WITH CSV HEADER;

-- Import digital IDs (if applicable)
COPY digital_ids (user_id, digital_id_number, id_type, issuing_country, issue_date, expiry_date, verification_status, created_at, updated_at)
FROM '/path/to/digital_ids_export.csv'
WITH CSV HEADER;

-- Update user profiles (match with imported auth users)
-- You'll need to manually handle this part based on your specific user data

-- Verify import
SELECT 
  'emergency_contacts' as table_name,
  count(*) as imported_records
FROM emergency_contacts
UNION ALL
SELECT 
  'user_locations' as table_name,
  count(*) as imported_records
FROM user_locations
UNION ALL
SELECT 
  'emergency_alerts' as table_name,
  count(*) as imported_records
FROM emergency_alerts
UNION ALL
SELECT 
  'tourist_info' as table_name,
  count(*) as imported_records
FROM tourist_info;

-- Note: User authentication data cannot be easily migrated between Supabase projects
-- Users will need to re-register, but their profile data can be preserved
-- Consider implementing a "data recovery" feature in your app for existing users