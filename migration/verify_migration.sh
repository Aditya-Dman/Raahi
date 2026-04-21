#!/usr/bin/env bash

# Raahi App Migration Verification Script
# Run this script to verify that your migration was successful

echo "🔄 Raahi App Migration Verification"
echo "=================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter first: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -1)"

# Check if the project directory exists
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Not in a Flutter project directory"
    echo "Please run this script from your Raahi project root directory"
    exit 1
fi

echo "✅ Flutter project detected"

# Check if Supabase configuration exists
if [ ! -f "lib/services/supabase_config.dart" ]; then
    echo "❌ Supabase configuration file not found"
    echo "Please ensure lib/services/supabase_config.dart exists"
    exit 1
fi

echo "✅ Supabase configuration file found"

# Check if configuration has been updated
if grep -q "your-project-id" lib/services/supabase_config.dart; then
    echo "⚠️  WARNING: Supabase configuration still contains placeholder values"
    echo "Please update lib/services/supabase_config.dart with your new Supabase credentials"
else
    echo "✅ Supabase configuration appears to be updated"
fi

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to get Flutter dependencies"
    exit 1
fi

echo "✅ Dependencies fetched successfully"

# Check for Supabase dependency
if grep -q "supabase_flutter:" pubspec.yaml; then
    echo "✅ Supabase Flutter dependency found"
else
    echo "❌ Supabase Flutter dependency not found in pubspec.yaml"
    echo "Please add supabase_flutter to your dependencies"
fi

# Try to analyze the project
echo "🔍 Analyzing project..."
flutter analyze --no-fatal-infos

if [ $? -eq 0 ]; then
    echo "✅ Project analysis passed"
else
    echo "⚠️  Project has analysis issues - check the output above"
fi

echo ""
echo "🎉 Migration verification complete!"
echo ""
echo "Next steps:"
echo "1. Update your Supabase configuration if not done already"
echo "2. Run 'flutter run' to test the app"
echo "3. Test user registration and login functionality"
echo "4. Verify all app features work correctly"
echo ""
echo "If you encounter issues:"
echo "- Check your Supabase project settings"
echo "- Verify your database schema was created correctly"
echo "- Ensure your authentication settings are configured"