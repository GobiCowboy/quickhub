#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/RightClickX.xcodeproj"
SCHEME="RightClickX"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/QuickHub.app"
ZIP_PATH="$BUILD_DIR/QuickHub-arm64.zip"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: jin guo (4UNNXY925R)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

mkdir -p "$BUILD_DIR"
rm -rf "$DERIVED_DATA"

echo "Building Release app..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "generic/platform=macOS" -derivedDataPath "$DERIVED_DATA" build

if [ ! -d "$APP_PATH" ]; then
  echo "Expected app not found at: $APP_PATH" >&2
  exit 1
fi

echo "Signing exported app..."
codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Creating zip..."
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

if [ -n "$NOTARY_PROFILE" ]; then
  echo "Submitting for notarization..."
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "Stapling ticket to app and zip..."
  xcrun stapler staple "$APP_PATH"
fi

echo "Release artifact ready:"
echo "$ZIP_PATH"
