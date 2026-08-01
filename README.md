# Lobos Trucking Operations

Private operations software for a small family trucking company. The interface
is intentionally straightforward: office staff assign loads, drivers see only
their own work, and every operational change leaves an audit event.

## Production foundation

The secured workflow on this branch supports:

1. Individual employee sign-in with no public registration.
2. Capability-based manager and driver access.
3. Client creation and editing without destructive deletion.
4. Load creation and assignment to an active driver.
5. Driver progress through assigned, accepted, pickup, transit, and delivery.
6. Delay/problem reports that alert office staff.
7. Customer name and signature capture before delivery can be completed.
8. Immutable, attributed audit events for every load mutation.

Customer signatures do **not** use Firebase Storage. Each compressed PNG is
stored as a size-limited Firestore `Blob` under the load's private `proofs`
subcollection. This works on Firebase's Spark plan and avoids downloading every
signature whenever the load list refreshes.

## Architecture

- **Flutter:** installable web/PWA and mobile codebase
- **Firebase Authentication:** private employee accounts
- **Cloud Firestore:** clients, loads, delivery proofs, and audit events
- **Firebase App Check:** app/device attestation before enforcement
- **Firebase Hosting:** initial production web deployment
- **Security Rules:** server-side permissions, workflow validation, and
  immutable proof enforcement

The FastAPI/SQLite code under `backend/` is an earlier learning prototype. It
is not connected to the Flutter application and must not be deployed beside
the Firebase runtime.

## Repository layout

```text
flutter_app/        Production Flutter and Firebase application
firebase_tests/     Firestore authorization and workflow tests
docs/               Architecture, schema, and rollout notes
backend/            Legacy learning prototype; not production runtime
.github/workflows/  Formatting, analysis, build, and rules checks
```

## Security model

Profiles receive explicit capabilities:

- `manageUsers`
- `manageClients`
- `manageLoads`
- `viewAllLoads`
- `updateAssignedLoads`

Drivers can read only their assigned loads. They cannot reassign work, change
routes, skip statuses, clear office alerts, or complete delivery without an
atomic signature-and-audit batch. Completed proof and audit documents cannot
be edited or deleted from a client application.

## Start here

- [Application setup](flutter_app/README.md)
- [Architecture walkthrough](docs/ARCHITECTURE.md)
- [Firestore schema](docs/FIRESTORE_SCHEMA.md)
- [Production checklist](docs/PRODUCTION_CHECKLIST.md)

The secure delivery workflow is a production foundation, not a finished
accounting suite. Invoice migration, exports, backup automation, and employee
administration remain separate milestones.
