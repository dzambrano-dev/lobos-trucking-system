# Lobos Trucking Flutter App

## Prerequisites

- Flutter stable
- Firebase CLI
- Java 21 for the Firebase Emulator Suite
- Separate Firebase projects for development and production

## Local setup

```bash
flutter pub get
flutter run -d chrome
```

The app has no registration screen. In Firebase Authentication, enable the
Email/Password provider and create each employee account administratively.

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

The document ID must be copied from **Authentication → Users → User UID**. Do
not click Firestore's automatic document-ID button, and do not use an email
address as the document ID. Enter string values without surrounding quotation
marks; the Firebase console adds its own visual quotes after saving.

The profile must contain exactly the four top-level fields shown above and all
five boolean permission fields. Never store a password in Firestore—Firebase
Authentication owns passwords. If one was added there, delete that field and
change the exposed password in Authentication.

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

Do not share logins. The audit trail is useful only when each person uses their
own account.

### Profile and permission troubleshooting

If the app shows an email instead of the expected display name, or Firestore
returns `permission-denied` while creating a load:

1. Sign out and copy the signed-in employee's UID from Firebase Authentication.
2. Confirm there is exactly one matching document at `users/{that exact UID}`.
3. Remove orphan documents created with automatic Firestore IDs.
4. Confirm `displayName` has no typed quotation marks or leading/trailing spaces.
5. Confirm every permission is a Firestore boolean, not the string `"true"`.
6. Repeat the UID and profile checks for the driver selected on the load.
7. Deploy `firestore:rules,firestore:indexes`, then sign in again.

Changing a different `users` document cannot update the signed-in profile. The
app listens only to the document whose ID equals the Authentication UID.

## Firestore-only signatures

Firebase Storage requires the Blaze plan. Lobos Trucking instead writes a
small PNG as a Firestore `Blob` at:

```text
loads/{loadId}/proofs/customerSignature
```

The client and security rules both enforce a 350 KiB ceiling. The load document
stores only the signer name, timestamp, and proof ID, so live load queries do
not repeatedly download signature images. The signature is fetched on demand
when a manager or assigned driver opens proof of delivery.

## Firebase resources

Deploy the database rules and indexes before using real data:

```bash
firebase deploy \
  --project YOUR_PRODUCTION_PROJECT_ID \
  --only firestore:rules,firestore:indexes
```

Run the authorization tests from the repository root:

```bash
cd firebase_tests
npm ci
npm test
```

The emulator suite verifies permissions, allowed status transitions, required
audit events, proof size, and delivery-proof immutability.

## App Check

Debug builds leave App Check off unless requested. Configure the providers in
the Firebase console, then build production with:

```bash
flutter build web \
  --dart-define=ENABLE_APP_CHECK=true \
  --dart-define=APP_CHECK_WEB_KEY=YOUR_RECAPTCHA_V3_SITE_KEY
```

Monitor verified traffic first. Then enforce App Check for Authentication and
Firestore so a configuration mistake does not lock out the whole family on
launch day.

## Hosting

Build and deploy the installable web app:

```bash
flutter build web \
  --dart-define=ENABLE_APP_CHECK=true \
  --dart-define=APP_CHECK_WEB_KEY=YOUR_RECAPTCHA_V3_SITE_KEY
firebase deploy \
  --project YOUR_PRODUCTION_PROJECT_ID \
  --only hosting
```

The repository intentionally has no default Firebase project alias, which
makes an accidental deployment to the wrong environment less likely.

The web/PWA release is the simplest first production target: employees open
one URL and can install it from their phone browser without app-store rollout.

## Before onboarding employees

Work through [the production checklist](../docs/PRODUCTION_CHECKLIST.md). In
particular, verify the Firebase API-key restrictions, test App Check on the
actual phones, choose a backup/export plan, and run a staging delivery from
assignment through signature.
