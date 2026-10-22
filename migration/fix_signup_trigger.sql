-- HOTFIX: Resolve "Database error saving new user" during signup
-- Run this in Supabase SQL Editor for your NEW project.

DROP TRIGGER IF EXISTS create_user_profile_trigger ON auth.users;
DROP FUNCTION IF EXISTS public.create_user_profile();

CREATE OR REPLACE FUNCTION public.create_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_profiles (
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

CREATE TRIGGER create_user_profile_trigger
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.create_user_profile();

-- Optional sanity checks
-- SELECT routine_name FROM information_schema.routines WHERE routine_name = 'create_user_profile';
-- SELECT trigger_name FROM information_schema.triggers WHERE trigger_name = 'create_user_profile_trigger';