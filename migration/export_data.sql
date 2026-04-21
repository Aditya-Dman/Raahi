-- EXPORT USER DATA FROM CURRENT SUPABASE PROJECT
-- Run this in your OLD Supabase project to backup user data before migration
-- This will help you preserve existing user accounts and data

-- Export all user profiles
COPY (
  SELECT 
    up.id,
    up.full_name,
    up.email,
    up.user_type,
    up.nationality,
    up.digital_id,
    up.created_at,
    au.email as auth_email,
    au.created_at as auth_created_at
  FROM user_profiles up
  JOIN auth.users au ON up.id = au.id
  ORDER BY up.created_at
) TO '/tmp/user_profiles_export.csv' WITH CSV HEADER;

-- Export emergency contacts
COPY (
  SELECT * FROM emergency_contacts ORDER BY created_at
) TO '/tmp/emergency_contacts_export.csv' WITH CSV HEADER;

-- Export user locations (last 30 days only to avoid huge file)
COPY (
  SELECT * FROM user_locations 
  WHERE timestamp > NOW() - INTERVAL '30 days'
  ORDER BY timestamp DESC
) TO '/tmp/user_locations_export.csv' WITH CSV HEADER;

-- Export emergency alerts (active ones only)
COPY (
  SELECT * FROM emergency_alerts 
  WHERE status = 'active' OR created_at > NOW() - INTERVAL '7 days'
  ORDER BY created_at DESC
) TO '/tmp/emergency_alerts_export.csv' WITH CSV HEADER;

-- Export tourist info (recent data only)
COPY (
  SELECT * FROM tourist_info 
  WHERE created_at > NOW() - INTERVAL '90 days'
  ORDER BY created_at DESC
) TO '/tmp/tourist_info_export.csv' WITH CSV HEADER;

-- Export digital IDs if table exists
COPY (
  SELECT * FROM digital_ids ORDER BY created_at
) TO '/tmp/digital_ids_export.csv' WITH CSV HEADER;

-- Generate summary report
SELECT 
  'user_profiles' as table_name,
  count(*) as record_count
FROM user_profiles
UNION ALL
SELECT 
  'emergency_contacts' as table_name,
  count(*) as record_count
FROM emergency_contacts
UNION ALL
SELECT 
  'user_locations' as table_name,
  count(*) as record_count
FROM user_locations
UNION ALL
SELECT 
  'emergency_alerts' as table_name,
  count(*) as record_count
FROM emergency_alerts
UNION ALL
SELECT 
  'tourist_info' as table_name,
  count(*) as record_count
FROM tourist_info;

-- Note: The CSV files will be created in your Supabase project
-- Download them from the Supabase dashboard before the account expires