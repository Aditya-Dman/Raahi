# Migration Troubleshooting Guide

## Common Issues and Solutions

### 1. Authentication Errors

**Problem**: Users can't sign up or login after migration
**Solutions**:
- Verify your Supabase URL and API key in `supabase_config.dart`
- Check that authentication is enabled in your new Supabase project
- Ensure email authentication provider is active
- Verify your Site URL is set correctly in Supabase Auth settings

### 2. Database Connection Errors

**Problem**: App can't connect to database
**Solutions**:
- Double-check your Supabase project URL
- Verify the anonymous key is correct
- Ensure your Supabase project is not paused
- Check your internet connection

### 3. Missing Tables Error

**Problem**: Database queries fail with "table does not exist"
**Solutions**:
- Ensure you ran the complete database setup script
- Check that all tables were created successfully in Supabase dashboard
- Verify Row Level Security policies are in place
- Re-run the migration SQL script if needed

### 4. Permission Denied Errors

**Problem**: Users can't access their data
**Solutions**:
- Verify RLS policies are correctly set up
- Check that user authentication is working properly
- Ensure user profile creation trigger is active
- Test with a fresh user registration

### 5. App Crashes on Startup

**Problem**: App fails to start after migration
**Solutions**:
- Check Flutter console for specific error messages
- Verify all dependencies are properly installed (`flutter pub get`)
- Ensure Supabase initialization code is correct
- Check for any import errors in Dart files

### 6. Data Migration Issues

**Problem**: Old user data didn't transfer properly
**Solutions**:
- Verify CSV export was successful from old project
- Check file paths in import script
- Ensure user IDs match between auth.users and profile tables
- Consider manual data verification for critical records

## Emergency Recovery Steps

If migration fails completely:

1. **Rollback Configuration**:
   ```dart
   // Copy from migration/backup_supabase_config.dart
   static const String supabaseUrl = 'https://kdunsvcmgpxyqphrkzzu.supabase.co';
   static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
   ```

2. **Create Emergency Backup**:
   - Export any critical data immediately
   - Document current user base
   - Save app configuration files

3. **Fresh Setup**:
   - Create brand new Supabase project
   - Run database setup script again
   - Test with new user registration
   - Gradually migrate data if needed

## Testing Checklist

After migration, test these features:

- [ ] User registration works
- [ ] User login works
- [ ] User profiles are created automatically
- [ ] Emergency contacts can be added/edited
- [ ] Location tracking works
- [ ] Emergency alerts can be created
- [ ] All screens load without errors
- [ ] Data persistence works across app restarts
- [ ] Logout functionality works

## Getting Help

1. Check Supabase dashboard for error logs
2. Use Flutter developer console for debugging
3. Verify database schema in Supabase SQL editor
4. Test API endpoints directly if needed

## Prevention Tips

- Always backup your configuration before changes
- Test migration on a separate project first if possible
- Keep migration scripts version-controlled
- Document any custom modifications to the database
- Regularly export important data as backup