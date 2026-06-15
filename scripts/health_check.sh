#!/bin/bash

# Wake Up Sunshine - Health Check Script
# Run from project root

set -e

echo "=========================================="
echo "  Wake Up Sunshine - Health Check"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Git Status
echo "--- Git ---"
if [ -d ".git" ]; then
    pass "Git repository found"
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    echo "  Branch: $BRANCH"
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        pass "Working tree clean"
    else
        warn "Uncommitted changes present"
    fi
else
    fail "Not a git repository"
fi
echo ""

# Xcode
echo "--- Xcode ---"
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    pass "Xcode: $XCODE_VERSION"
else
    fail "Xcode not found"
fi

if command -v xcodegen &> /dev/null; then
    XGEN_VERSION=$(xcodegen --version 2>&1 | head -1)
    pass "XcodeGen: $XGEN_VERSION"
else
    fail "XcodeGen not installed"
fi
echo ""

# iOS Project
echo "--- iOS Project ---"
if [ -d "ios/WakeUpSunshine.xcodeproj" ]; then
    pass "iOS Xcode project exists"
else
    fail "iOS Xcode project not found"
fi

if [ -f "ios/project.yml" ]; then
    pass "project.yml exists"
else
    fail "project.yml not found"
fi

if [ -f "ios/WakeUpSunshine/Resources/WakeUpSunshine.entitlements" ]; then
    pass "Entitlements file exists"
else
    warn "Entitlements file not found"
fi
echo ""

# Node.js
echo "--- Node.js ---"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    pass "Node.js: $NODE_VERSION"
else
    fail "Node.js not found"
fi
echo ""

# Supabase CLI
echo "--- Supabase ---"
if command -v supabase &> /dev/null; then
    SUPABASE_VERSION=$(supabase --version 2>&1 | head -1)
    pass "Supabase CLI: $SUPABASE_VERSION"
    
    # Check login status
    if supabase projects list &> /dev/null; then
        pass "Supabase logged in"
    else
        warn "Supabase not logged in (run: supabase login)"
    fi
else
    fail "Supabase CLI not installed"
fi
echo ""

# Android
echo "--- Android ---"
if [ -d "$HOME/Library/Android/sdk" ]; then
    pass "Android SDK found"
else
    warn "Android SDK not found (install Android Studio)"
fi

if [ -f "android/app/google-services.json" ]; then
    # Check if it's a placeholder
    if grep -q "YOUR_PROJECT_NUMBER" android/app/google-services.json 2>/dev/null; then
        warn "google-services.json is a placeholder"
    else
        pass "google-services.json configured"
    fi
else
    fail "google-services.json not found"
fi

if [ -f "android/gradlew" ]; then
    pass "Gradle wrapper exists"
else
    warn "Gradle wrapper not found (will be created by Android Studio)"
fi

if [ -f "android/settings.gradle" ] || [ -f "android/settings.gradle.kts" ]; then
    pass "settings.gradle exists"
else
    fail "settings.gradle not found"
fi
echo ""

# Backend
echo "--- Backend ---"
if [ -d "backend/supabase" ]; then
    pass "Backend folder exists"
else
    fail "Backend folder not found"
fi

if [ -d "backend/supabase/migrations" ] && [ "$(ls -A backend/supabase/migrations 2>/dev/null)" ]; then
    pass "Migrations exist"
else
    warn "No migrations found"
fi

if [ -d "backend/supabase/functions" ] && [ "$(ls -A backend/supabase/functions 2>/dev/null)" ]; then
    pass "Edge functions exist"
else
    warn "No edge functions found"
fi
echo ""

# Summary
echo "=========================================="
echo "  Health Check Complete"
echo "=========================================="