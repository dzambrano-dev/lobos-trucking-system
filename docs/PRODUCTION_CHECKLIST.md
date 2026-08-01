# Production checklist

Code can enforce workflow rules, but several production controls live in the
Firebase and hosting consoles. Complete these before real customer data enters
the system.

## Firebase projects and access

- [ ] Create separate development and production Firebase projects.
- [ ] Enable Email/Password Authentication; keep public registration out of
      the app.
- [ ] Create one account per employee and the matching `users/{uid}` profile.
- [ ] Give each person only the capabilities they need.
- [ ] Remove access immediately when an employee leaves; never delete their
      historical profile.

## API keys and abuse protection

- [ ] In Google Cloud Credentials, confirm every checked-in Firebase key is
      restricted to the required Firebase APIs.
- [ ] Confirm no public Firebase key can call unrelated billable APIs,
      especially the Generative Language API.
- [ ] Add web referrer, Android application, and Apple bundle restrictions
      where appropriate.
- [ ] Review Authentication quotas for a 4–7 person private app.
- [ ] Register App Check providers, monitor metrics in staging, then enforce
      Authentication and Firestore.

Firebase client keys identify the project; Security Rules and App Check protect
the data. Moving the same key into an environment variable would not make a web
key secret.

## Data and rules

- [ ] Run `npm test` under `firebase_tests/`.
- [ ] Deploy Firestore rules and indexes from version control.
- [ ] Confirm the production database is not using temporary/test-mode rules.
- [ ] Complete a staged load as a driver and verify the manager can open the
      signature afterward.
- [ ] Verify an unassigned driver cannot read that load in the Rules simulator.
- [ ] Choose a backup/export plan. Managed Firestore backups require billing;
      remaining on Spark means the business needs a separate routine export
      before this becomes the only copy of operational records.

## Release

- [ ] Build the web app with App Check enabled.
- [ ] Deploy to Firebase Hosting and test the installable PWA on every phone
      model drivers actually use.
- [ ] Confirm dates and times render correctly in the operating timezone.
- [ ] Train staff with one fake load before entering customer data.
- [ ] Keep the legacy `backend/` service offline.

## Native mobile follow-up

- [ ] Replace the template Android/iOS bundle identifiers and re-register the
      apps in Firebase.
- [ ] Create and protect release signing keys; never use the Android debug key
      for distribution.
- [ ] Add store privacy disclosures and a retention policy for signatures.

Until the backup decision, key restrictions, App Check rollout, and staged
end-to-end test are complete, call this a production candidate—not production.
