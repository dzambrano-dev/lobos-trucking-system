# Lobos Trucking

A Flutter and Firebase workspace for a small trucking company: dispatch, customer contacts, billing, payments, and operating expenses. The older Python/SQLite CLI remains in `backend/` as a separate prototype; it does not share data with the Flutter app.

## Daily workflow

1. **Clients:** add company and contact information. Search, edit, archive, or restore customers without deleting their history.
2. **Dispatch:** add pickup/delivery locations, scheduled date, driver, truck, load reference, agreed rate, and notes. Edit a job as it moves from Scheduled to In progress to Completed.
3. **Invoices:** create an invoice from a completed job. The app links one invoice to each job and freezes the billed job. New invoices default to net 30; due dates and notes remain editable.
4. **Payments:** record a received amount and payment reference. Partial payments reduce the balance; excess payments are rejected. Correct an incorrectly recorded payment with **Reverse entry**, which retains the original receipt and correction reason. This corrects bookkeeping only and does not send a refund. Print or save an invoice as PDF.
5. **Expenses:** record fuel, maintenance, tolls, insurance, driver pay, and other costs, optionally linked to a job.
6. **Overview:** see active work, jobs ready to bill, overdue invoices, all-time collected payments, outstanding balances, and active expense totals.

Amounts are USD, entered to two decimal places. Collected is based on invoice paid balances, including legacy invoices marked paid; it is not a profit or tax report. Dates use the device's local calendar. Archived expenses are excluded from the overview expense total. Archive erroneous expense entries only when that exclusion is intended.

## Run locally

Use Flutter 3.44.8 / Dart 3.12.2 (the version used for verification), or a compatible newer stable SDK.

```sh
cd flutter_app
flutter pub get
flutter run -d chrome
```

The default entry point is the real Firebase workspace and requires an enabled staff account. To review all screens without credentials or touching company data:

```sh
flutter run -d chrome -t tool/preview.dart
```

The preview uses fictional, in-memory records. Changes disappear on reload. It is a development-only entry point: use debug mode, not release, with the fake Firestore package.

## Configure access before deploying

1. In the existing `lobos-trucking` Firebase project, enable **Authentication → Email/Password**. Create each office user's account there. Do not put passwords or service-account keys in the repository.
2. Each Authentication UID needs a `users/{uid}` document with `displayName`, `email`, `active: true`, and a `permissions` map containing five booleans: `manageUsers`, `manageClients`, `manageLoads`, `viewAllLoads`, `updateAssignedLoads`. Admins have all five enabled. Drivers have only `updateAssignedLoads` enabled. Set `active: false` to revoke application access. Existing profiles on the driver foundation branch remain compatible.
3. Back up existing Firestore data, then run the legacy audit and rollout steps in [RELEASE.md](RELEASE.md).
4. Deploy the included rules with an authorized Firebase administrator account:

   ```sh
   cd flutter_app
   npx firebase deploy --only firestore:rules --project lobos-trucking
   ```

5. Build the production app with `flutter build web`. Publish `flutter_app/build/web` through your existing hosting provider, and add its domain to Firebase Authentication's authorized domains. The default build excludes the demo entry point.
6. Enter real business and remittance details under the gear icon before printing invoices. Verify sign-in, client/job editing, invoice creation, partial payment/reversal, and PDF printing with a designated test record before daily use. Android, iOS, macOS, and Windows packaging still require platform-specific deployment verification. The checked-in Firebase configuration must correspond to the platform/application you deploy.

Rules and app changes should be rolled out together. The old unsigned app will lose access when the staff-only rules are deployed. Existing hosted app configuration and live Firebase data were not changed by this implementation.

## Existing data

The app reads existing `clients`, `jobs`, and `invoices` collections and accepts Firestore timestamps or ISO date strings. Records missing `createdAt` remain visible. Existing invoices with `status: paid` and no `amountPaid` retain a zero balance.

Legacy invoices used random document IDs. Choosing **Create invoice** for an already billed job resolves its existing invoice and stores the link instead of issuing another. Before production, inspect invoices grouped by `jobId`: resolve any pre-existing duplicates and missing-job references with the owner, and populate each uniquely billed job's `invoiceId`. Do not delete accounting records to resolve an ambiguity. This migration is needed so the rules can lock all legacy billed jobs, including writes from other clients. The app itself also checks for legacy invoices before editing a job.

Invoice totals, job references, and original payment entries cannot be edited or deleted through the app. Corrections append a reversal record and restore the outstanding balance. Refund transactions, credit notes, sales tax, multi-currency, and bank reconciliation are not implemented. This is an operations and receivables tracker, not a full accounting package.

## Verification

```sh
cd flutter_app
flutter analyze
flutter test
flutter build web
npm ci
npm run test:rules
```

The rule tests use only the local Firestore emulator and the `demo-lobos` project; they require Java 21+ and Node.js 20+. Tests cover staff authorization, transactional invoice linking, billed-job locks, immutable payment history, partial payments, duplicate retries, overpayment rejection, legacy balances, responsive navigation, and client editing.

## Driver and admin workflow

One sign-in page routes employees automatically from their saved profile. Admins land on **Dispatch** to assign loads and review progress. The work list groups attention items (including overdue pickups), today's work, deliveries ready to invoice, upcoming loads, and history. Drivers see only **My deliveries**, progress through each step, report delays, and obtain a customer name and signature before completing delivery.

For a delivered load, admins choose **Create / view invoice** and enter the agreed charge. Billing creates one stable job and invoice per load, reopens that invoice on retries, and retains the original charge. Standalone office jobs remain available through **Invoices → Standalone billing jobs**. Driver accounts cannot read jobs, invoices, payments, expenses, or company settings. User profiles, not the legacy staff collection, are the authorization source.

Deploy the supplied Firestore indexes as well as rules and hosting. Accounts and passwords are managed in Firebase Authentication; permission profiles are managed by the owner in Firestore. Disable the profile to revoke ongoing data access.

The dispatch invoice button reads **Create invoice** until the delivery is billed, then **View invoice**. Financial transaction and driver access rules are unchanged by this navigation update.

Assigned loads expose **Reschedule pickup**. Open loads expose **Cancel load** with confirmation; both retain audit history. Overdue pickup cards explain why they need attention. Once a driver has started, the office cannot reschedule over their progress. Driver screens list started trips first, followed by new assignments in pickup order.

### Expense accounts

Admins can enter vendor bills as unpaid or paid in full, record partial payments with dates and references, and reverse mistaken payment entries while retaining history. Balances cannot be increased or reduced without matching payment records. Older expenses show Needs review until their known payments are recorded or they are confirmed unpaid.

The month selector shows incurred expenses, net expense payments, customer receipts, net cash flow, and an operating profit estimate (invoiced revenue less recorded expenses). Outstanding bills span all dates. Cash figures depend on individually recorded payments; legacy paid invoices may lack these records. These operational estimates exclude taxes, depreciation, and missing costs.
