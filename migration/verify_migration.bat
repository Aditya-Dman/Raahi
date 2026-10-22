@echo off
REM Raahi App Migration Verification Script for Windows
REM Run this script to verify that your migration was successful

echo 🔄 Raahi App Migration Verification
echo ==================================

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed or not in PATH
    echo Please install Flutter first: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo ✅ Flutter found
flutter --version | findstr /C:"Flutter"

REM Check if the project directory exists
if not exist "pubspec.yaml" (
    echo ❌ Not in a Flutter project directory
    echo Please run this script from your Raahi project root directory
    pause
    exit /b 1
)

echo ✅ Flutter project detected

REM Check if Supabase configuration exists
if not exist "lib\services\supabase_config.dart" (
    echo ❌ Supabase configuration file not found
    echo Please ensure lib\services\supabase_config.dart exists
    pause
    exit /b 1
)

echo ✅ Supabase configuration file found

REM Check if configuration has been updated
findstr /C:"your-project-id" "lib\services\supabase_config.dart" >nul 2>&1
if %errorlevel% equ 0 (
    echo ⚠️  WARNING: Supabase configuration still contains placeholder values
    echo Please update lib\services\supabase_config.dart with your new Supabase credentials
) else (
    echo ✅ Supabase configuration appears to be updated
)

REM Get dependencies
echo 📦 Getting Flutter dependencies...
flutter pub get

if %errorlevel% neq 0 (
    echo ❌ Failed to get Flutter dependencies
    pause
    exit /b 1
)

echo ✅ Dependencies fetched successfully

REM Check for Supabase dependency
findstr /C:"supabase_flutter:" pubspec.yaml >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Supabase Flutter dependency found
) else (
    echo ❌ Supabase Flutter dependency not found in pubspec.yaml
    echo Please add supabase_flutter to your dependencies
)

REM Try to analyze the project
echo 🔍 Analyzing project...
flutter analyze --no-fatal-infos

if %errorlevel% equ 0 (
    echo ✅ Project analysis passed
) else (
    echo ⚠️  Project has analysis issues - check the output above
)

echo.
echo 🎉 Migration verification complete!
echo.
echo Next steps:
echo 1. Update your Supabase configuration if not done already
echo 2. Run 'flutter run' to test the app
echo 3. Test user registration and login functionality
echo 4. Verify all app features work correctly
echo.
echo If you encounter issues:
echo - Check your Supabase project settings
echo - Verify your database schema was created correctly
echo - Ensure your authentication settings are configured

pause