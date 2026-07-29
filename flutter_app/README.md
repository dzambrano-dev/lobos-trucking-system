# Lobos Trucking Flutter App

## Prerequisites

- Flutter stable
- Firebase CLI
- Java 21 for the Firebase Emulator Suite
- A Firebase development project separate from production

## Local setup

```bash
flutter pub get
flutter run -d chrome
```

The application has no public registration screen. Enable the Email/Password
provider in Firebase Authentication and create employees through the Firebase
console or a future administrator workflow.

## Bootstrap the first administrator

After creating the first Authentication account, create
`users/{firebaseAuthUid}` in Firestore:

```json
{
  "displayName": "Office Administrator",
  "email": "admin@example.com",
  "active": true,
  "permissions": {
    "manageUsers": true,
    "manageClients": true,
    "manageLoads": true,
    "viewAllLoads": true,
    "updateAssignedLoads": true
  }
}
```

An ordinary driver should receive:

```json
{
  "displayName": "Driver Name",
  "email": "driver@example.com",
  "active": true,
  "permissions": {
    "manageUsers": false,
    "manageClients": false,
    "manageLoads": false,
    "viewAllLoads": false,
    "updateAssignedLoads": true
  }
}
```

Do not share employee logins. Activity attribution and security depend on each
person using an individual account.

## Firebase resources

Deploy database indexes and security rules before using real data:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Test Firebase rules from the repository root:

```bash
cd firebase_tests
npm ci
npm test
```

The test command starts both the Firestore and Storage emulators, so both rule
files must compile. Two cross-service Storage cases are skipped because the
current rules test library cannot reliably seed Firestore data for
`firestore.get()` calls from Storage rules. Verify signature upload and cleanup
on a staging Firebase project before enabling production enforcement.

## App Check

Debug builds do not enable App Check unless requested. Configure the Firebase
App Check providers in the console, then build production with:

```bash
flutter build web \
  --dart-define=ENABLE_APP_CHECK=true \
  --dart-define=APP_CHECK_WEB_KEY=YOUR_RECAPTCHA_V3_SITE_KEY
```

After validating production traffic, enable App Check enforcement for
Firestore, Authentication, and Storage in the Firebase console.

## Hosting

Build and deploy the single-page web app:

```bash
flutter build web \
  --dart-define=ENABLE_APP_CHECK=true \
  --dart-define=APP_CHECK_WEB_KEY=YOUR_RECAPTCHA_V3_SITE_KEY
firebase deploy --only hosting
```

Do not use GitHub Pages for the operational application. Firebase Hosting
supports the application routes, Firebase configuration, and preview
deployments cleanly.

## Required production configuration

Before onboarding employees:

- Use separate Firebase projects for development and production.
- Disable public account creation in the product interface.
- Deploy and test Firestore and Storage rules.
- Register App Check providers and enable enforcement.
- Configure budget alerts.
- Enable scheduled Firestore backups.
- Verify restoration procedures.
- Test on the phones and browsers the drivers actually use.
