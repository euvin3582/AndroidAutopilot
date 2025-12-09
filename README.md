# Android AutoPilot

Automated Android app building and deployment system for React Native/Expo apps.

## Setup

1. Copy `.env.example` to `.env` and configure:
   - Android keystore details
   - Google Play Console service account JSON
   - Repository information

2. Install dependencies:
   ```bash
   npm install
   ```

3. Make scripts executable:
   ```bash
   chmod +x build-android.sh trigger-build.sh
   ```

## Usage

### Manual Build
```bash
./trigger-build.sh
```

### Webhook Server
```bash
npm start
```

The webhook server listens on port 3001 for GitHub push events and automatically triggers Android builds.

## Requirements

- Node.js
- Android SDK
- Java 11+
- Gradle
- Fastlane (optional, for Google Play upload)

## Configuration

The system requires:
- Android keystore for signing
- Google Play Console service account JSON for uploads
- Proper environment variables in `.env` file