# Firestore schema

## `users/{uid}`

| Field | Type | Purpose |
| --- | --- | --- |
| `displayName` | string | Human-readable audit attribution |
| `email` | string | Administrative account reference |
| `active` | boolean | Revokes app access without deleting history |
| `permissions` | map | Five explicit capability flags |

## `clients/{clientId}`

| Field | Type | Purpose |
| --- | --- | --- |
| `name` | string | Company name |
| `contact` | string | Primary contact |
| `phone` | string | Contact phone |
| `email` | string | Optional email |
| `address` | string | Billing/contact address |
| `createdAt`, `updatedAt` | timestamp | Server-controlled audit fields |

Clients are never deleted by the app because loads retain client references.

## `loads/{loadId}`

The load stores route, schedule, assigned-driver snapshot, current status,
attention state, creator, timestamps, and `lastEventId`. When delivered, its
small `delivery` map records the proof ID, signer name, server time, and driver
who captured it.

Allowed progress is:

```text
assigned → accepted → arrived_at_pickup → in_transit → delivered
```

`cancelled` is terminal. The manager UI does not expose cancellation yet.

## `loads/{loadId}/events/{eventId}`

Events record type, resulting status, actor UID/name, optional note, and server
timestamp. They cannot be changed or deleted. Rules link the latest event to
the load mutation through `lastEventId`.

## `loads/{loadId}/proofs/customerSignature`

| Field | Type | Purpose |
| --- | --- | --- |
| `signaturePng` | bytes | Size-limited customer signature |
| `contentType` | string | Always `image/png` |
| `byteLength` | integer | Cross-checked against the byte field |
| `signedByName` | string | Name entered beside the signature |
| `signedAt`, `createdAt` | timestamp | Server time |
| `capturedBy` | string | Assigned driver's Firebase UID |

The document can be created only during the same batch that moves an assigned
driver's in-transit load to delivered. It cannot be replaced or deleted.
