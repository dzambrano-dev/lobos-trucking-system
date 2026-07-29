# Lobos Trucking Operations

Private operations software for a small family trucking company. The production
application is designed for office staff and drivers with limited technical
experience.

## Current production milestone

This branch establishes the secure delivery workflow:

1. An authorized team member creates a load and assigns a driver.
2. The assigned driver accepts the load.
3. The driver records arrival at pickup.
4. The driver records pickup and transit.
5. The driver can report a delay or problem without losing the current
   progress state.
6. The driver completes delivery only after capturing the customer's
   signature.

Every change records the authenticated user and a server timestamp.

## Architecture

- **Flutter:** installable web and mobile interface
- **Firebase Authentication:** private, individual employee accounts
- **Cloud Firestore:** synchronized loads, users, clients, and activity events
- **Cloud Storage:** customer signature images
- **Firebase Hosting:** production web deployment
- **Firebase Security Rules:** capability and assignment-based authorization

The earlier FastAPI/SQLite proof of concept remains under `backend/` for
historical reference. It is not part of the production runtime and should not
be deployed.

## Repository layout

```text
flutter_app/        Production Flutter and Firebase application
firebase_tests/     Firestore authorization tests
backend/            Legacy proof of concept; not deployed
.github/workflows/  Flutter and Firebase rules validation
```

## Security model

Users receive explicit capabilities instead of relying on loosely defined job
titles:

- `manageUsers`
- `manageClients`
- `manageLoads`
- `viewAllLoads`
- `updateAssignedLoads`

Drivers can read only loads assigned to their account. They cannot reassign a
load, edit its client or route, skip progress states, clear an office alert, or
mark a load delivered without a customer signature. Loads and activity events
cannot be permanently deleted from client applications.

See [`flutter_app/README.md`](flutter_app/README.md) for local setup,
Firebase configuration, testing, and deployment instructions.

## Roadmap

- Secure load workflow and customer signatures
- Search, filtering, reassignment, and archival
- Invoice migration with immutable invoice numbers
- PDF/CSV exports
- Proof-of-delivery document support
- Production backups, monitoring, and staff onboarding
