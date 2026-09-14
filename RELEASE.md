# Production rollout

The supported release target for this change is **Flutter web for admins and drivers**. Passing CI produces the production web build; it does not deploy, create users, or migrate your live database.

## Before cutover

- Export/back up the current Firestore database using the Firebase/Google Cloud console. Confirm that the backup can be located and restored, and assign responsibility for recurring backups.
- Enable Firebase Authentication Email/Password. Create office accounts and `users/{uid}` profiles as described in README.md. There is no public registration. Driver accounts have only updateAssignedLoads enabled. Manage passwords and disabled accounts through Firebase Authentication.
- Pause writes from the existing app during the migration and release. Keep a copy of the previously deployed rules and web release for rollback.
- Run the audit with authorized Google Application Default Credentials (never commit credentials):

  ```sh
  cd flutter_app
  npm ci
  node tool/audit_legacy.cjs --project lobos-trucking
  ```

  Exit code 2 means records need owner review. The report identifies duplicates, orphan invoices, invalid balances, and broken links. Resolve these deliberately; the tool never deletes invoices or adjusts amounts. Once the report has no issues, link unique legacy invoices:

  ```sh
  node tool/audit_legacy.cjs --project lobos-trucking --apply
  node tool/audit_legacy.cjs --project lobos-trucking
  ```

  Apply is rerunnable and rechecks each referenced job/invoice. Maintain the write freeze until cutover finishes; a read-only scan cannot prevent another old client from creating a new duplicate concurrently.

## Release

1. Run `flutter analyze`, `flutter test`, `node --test test/audit_legacy.test.cjs`, and `npm run test:rules`.
2. Run `flutter build web --no-wasm-dry-run`. Never publish the debug demo build under `build/preview`.
3. Authenticate Firebase CLI as the project administrator. Review the selected project, then run `npx firebase deploy --only firestore:rules,firestore:indexes,hosting --project lobos-trucking` from `flutter_app`. The supplied hosting configuration publishes `build/web` only. If existing hosting uses a custom multi-site target, adapt the hosting target before deploying.
4. Ensure the production hostname is in Firebase Authentication's authorized domains. Open the site and sign in with the enabled office account.
5. Open **Company & invoice details** (the gear icon). Enter the real company name, business/remittance address, billing contact, and payment instructions.

## Acceptance check before operational use

Use clearly designated test records with the owner's knowledge, not real customer invoices. Confirm all of the following in the deployed environment:

- Anonymous/disabled accounts cannot read company data; an enabled office account can sign in and out.
- Add a customer, edit their contact information, schedule a job, assign a driver/unit, and change its status.
- Invoice the completed job twice; both actions must open the same invoice. The billed job must remain locked.
- Record a partial payment; confirm the exact remaining balance and one payment-history row. An overpayment must be rejected. Reverse an incorrect entry with a reason; the original payment and reversal must remain visible and the balance must be restored exactly once.
- Print/save the invoice and check the business address, customer, route, due date, collected total, and balance. Check individual references and reversal reasons in the app's payment history.
- Add/edit an expense, verify the overview, and check the phone layout.
- Disable a test staff account and confirm access is denied on refresh.

This release was tested against fake Firestore and the local Firestore emulator. Live Firebase permissions, authentication configuration, hosting, backups, and production acceptance require the project administrator's environment and are separate release gates. Native platform packaging is not release-verified.

## Operations and limits

Admins oversee office finances and driver dispatch. Drivers can read only their own loads, advance their delivery steps, report issues, and capture delivery signatures. Use separate user accounts and revoke access when staff leave. This version tracks dispatch and receivables; it does not calculate tax, perform bank transactions, automate regulatory compliance, or implement refunds/credit notes. Use **Reverse entry** for an incorrectly recorded payment, then enter the corrected payment. Both the original entry and reversal remain in the history. Legacy paid invoices without individual receipts require owner reconciliation; never invent a payment entry to change their balance.

Existing jobs retain a cached client name; new invoices snapshot the current client billing details. Company details on PDFs use the current company profile. Due dates use local calendar days. Reports are all-time summaries for a small company and stream the relevant collections; plan indexed, date-bounded reporting before the data grows substantially.

For rollback, pause writes first and restore the previous compatible app/rules as a pair. Keep new billing/payment documents intact; do not roll back the database blindly after payments have been recorded. Reconcile records before reopening the old app, which lacks the new billing safeguards.
