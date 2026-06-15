#!/bin/bash

# Wake Up Sunshine - iOS Simulator Build Script
# Run from project root

set -e

echo "=========================================="
echo "  Wake Up Sunshine - iOS Simulator Build"
echo "=========================================="
echo ""

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"
PROJECT_FILE="$IOS_DIR/WakeUpSunshine.xcodeproj"
SCHEME="WakeUpSunshine"

# Default simulator
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --device)
            shift
            DESTINATION="$1"
            shift
            ;;
        --list)
            echo "Available Simulators:"
            xcrun simctl list devices available | grep -E "iPhone|iPad" | head -20
            exit 0
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --device 'DEVICE_NAME'   Specify simulator (default: 'iPhone 16 Pro')"
            echo "  --list                   List available simulators"
            echo "  --help                   Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Build for iPhone 16 Pro"
            echo "  $0 --device 'iPhone 15'               # Build for iPhone 15"
            echo "  $0 --device 'platform=iOS Simulator,name=iPad Pro'  # Build for iPad"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if project exists
if [ ! -d "$PROJECT_FILE" ]; then
    echo "Generating Xcode project..."
    cd "$IOS_DIR"
    xcodegen generate
fi

# Build
echo "Building for: $DESTINATION"
echo ""

cd "$IOS_DIR"

xcodebuild \
    -project WakeUpSunshine.xcodeproj \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    build \
    2>&1 | tee "$PROJECT_ROOT/logs/ios_build.log" | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED|\*\* BUILD)"

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "  ✅ BUILD SUCCEEDED"
    echo "=========================================="
    echo ""
    echo "To open in Xcode:"
    echo "  open $PROJECT_FILE"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "  ❌ BUILD FAILED"
    echo "=========================================="
    echo ""
    echo "Check the log for details:"
    echo "  $PROJECT_ROOT/logs/ios_build.log"
    exit 1
fi