#!/bin/bash
set -e

SCHEME="Agentic Graph"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE_PATH="/tmp/AgenticGraph.xcarchive"
EXPORT_DIR="$PROJECT_DIR/built"
APP_NAME="Agentic Graph.app"
ZIP_NAME="AgenticGraph.zip"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
DEPLOY=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --deploy) DEPLOY=true ;;
        --help|-h)
            echo "Usage: ./build-export.sh [--deploy]"
            echo ""
            echo "  --deploy    Build, zip, and install to /Applications"
            echo "  (default)   Build and zip only"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: ./build-export.sh [--deploy]"
            exit 1
            ;;
    esac
done

echo "=== Building Agentic Graph ==="
echo "Project: $PROJECT_DIR"
echo "Output:  $EXPORT_DIR/$ZIP_NAME"
if $DEPLOY; then
    echo "Deploy:  /Applications/$APP_NAME"
fi
echo ""

# Clean previous archive
rm -rf "$ARCHIVE_PATH"

# 1. Archive
echo "→ Archiving (Release)..."
"$XCODEBUILD" \
  -project "$PROJECT_DIR/Agentic Graph.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -quiet

echo "✓ Archive complete"

# 2. Copy .app out of archive
echo "→ Exporting .app..."
rm -rf "$EXPORT_DIR/$APP_NAME"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME" "$EXPORT_DIR/$APP_NAME"
echo "✓ Exported to $EXPORT_DIR/$APP_NAME"

# 3. Zip for sharing
echo "→ Creating zip..."
rm -f "$EXPORT_DIR/$ZIP_NAME"
cd "$EXPORT_DIR"
zip -r -q "$ZIP_NAME" "$APP_NAME"
echo "✓ Created $EXPORT_DIR/$ZIP_NAME"

# 4. Deploy to /Applications if requested
if $DEPLOY; then
    echo "→ Deploying to /Applications..."
    # Quit the app if running
    osascript -e 'tell application "Agentic Graph" to quit' 2>/dev/null || true
    sleep 1
    rm -rf "/Applications/$APP_NAME"
    cp -R "$EXPORT_DIR/$APP_NAME" "/Applications/$APP_NAME"
    echo "✓ Installed to /Applications/$APP_NAME"
fi

# 5. Clean up
rm -rf "$ARCHIVE_PATH"
rm -rf "$EXPORT_DIR/$APP_NAME"

echo ""
echo "=== Done ==="
echo "Share: $EXPORT_DIR/$ZIP_NAME"
if $DEPLOY; then
    echo "Installed: /Applications/$APP_NAME"
fi
echo ""
echo "Recipients: Right-click → Open on first launch"
