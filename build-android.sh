#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from script directory
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

REPO_URL="${REPO_URL}"
REPO_DIR="${REPO_DIR}"
PACKAGE_NAME="${ANDROID_PACKAGE_NAME}"
KEYSTORE_PATH="${ANDROID_KEYSTORE_PATH}"
KEYSTORE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD}"
KEY_ALIAS="${ANDROID_KEY_ALIAS}"
KEY_PASSWORD="${ANDROID_KEY_PASSWORD}"
SERVICE_ACCOUNT_JSON="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON}"
MIN_VERSION_CODE="${MIN_VERSION_CODE:-1}"

echo "📦 Cloning fresh repository..."
mkdir -p build
cd build
rm -rf "$REPO_DIR"
git clone "$REPO_URL"

cd "$REPO_DIR"

echo "📝 Creating .env file..."
echo "APP_ENV_VARS length: ${#APP_ENV_VARS}"
echo "$APP_ENV_VARS" > .env

echo "📦 Installing dependencies..."
rm -rf node_modules
npm install

echo "📝 Verifying .env file..."
cat .env

echo "🔨 Prebuilding Android..."
EXPO_NO_GIT_STATUS=1 npx expo prebuild --platform android

echo "📝 Creating polyfills file..."
mkdir -p app
cat > app/polyfills.ts << 'EOF'
// Polyfills for React Native
import 'react-native-get-random-values';
import 'react-native-url-polyfill/auto';
EOF

echo "🔢 Incrementing version code..."
cd android
GRADLE_FILE="app/build.gradle"
CURRENT_VERSION=$(grep -o 'versionCode [0-9]*' $GRADLE_FILE | grep -o '[0-9]*')
NEW_VERSION=$((CURRENT_VERSION + 1))
echo "Current: $CURRENT_VERSION, Incremented: $NEW_VERSION, Min: $MIN_VERSION_CODE"
if [ $NEW_VERSION -le $MIN_VERSION_CODE ]; then
  NEW_VERSION=$((MIN_VERSION_CODE + 1))
fi
sed -i '' "s/versionCode $CURRENT_VERSION/versionCode $NEW_VERSION/" $GRADLE_FILE
echo "Version code: $NEW_VERSION"
cd ..

echo "🔨 Building Android AAB..."
cd android

# Stop any existing Gradle daemons
./gradlew --stop || true

# Clean build
./gradlew clean --no-daemon

# Build with optimized settings
./gradlew bundleRelease \
  --no-daemon \
  --no-build-cache \
  --no-configuration-cache \
  --max-workers=2 \
  --stacktrace \
  -Dorg.gradle.jvmargs="-Xmx4096m -XX:MaxMetaspaceSize=1024m" \
  -Pandroid.injected.signing.store.file="$KEYSTORE_PATH" \
  -Pandroid.injected.signing.store.password="$KEYSTORE_PASSWORD" \
  -Pandroid.injected.signing.key.alias="$KEY_ALIAS" \
  -Pandroid.injected.signing.key.password="$KEY_PASSWORD" 2>&1 | tee build.log

echo "☁️ Uploading to Google Play Console..."
# Install bundletool if not present
if ! command -v bundletool &> /dev/null; then
  echo "Installing bundletool..."
  curl -L -o bundletool.jar https://github.com/google/bundletool/releases/latest/download/bundletool-all-1.15.6.jar
  alias bundletool='java -jar bundletool.jar'
fi

# Upload using Google Play Console API (requires fastlane or similar tool)
if command -v fastlane &> /dev/null; then
  echo "Using fastlane for upload..."
  fastlane supply --aab app/build/outputs/bundle/release/app-release.aab --json_key "$SERVICE_ACCOUNT_JSON" --package_name "$PACKAGE_NAME" --track internal
else
  echo "⚠️ Fastlane not installed. AAB built at: app/build/outputs/bundle/release/app-release.aab"
  echo "Manual upload required to Google Play Console"
fi

cd ..
echo "✅ Build complete!"