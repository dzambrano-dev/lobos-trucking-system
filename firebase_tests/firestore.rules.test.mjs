import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Bytes,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-lobos-trucking';
let testEnvironment;

const managerId = 'manager-1';
const driverId = 'driver-1';
const otherDriverId = 'driver-2';

const managerPermissions = {
  manageUsers: true,
  manageClients: true,
  manageLoads: true,
  viewAllLoads: true,
  updateAssignedLoads: true,
};

const driverPermissions = {
  manageUsers: false,
  manageClients: false,
  manageLoads: false,
  viewAllLoads: false,
  updateAssignedLoads: true,
};

function profile(email, permissions, active = true) {
  return {
    displayName: email.split('@')[0],
    email,
    active,
    permissions,
  };
}

function loadData(status = 'assigned', overrides = {}) {
  return {
    loadNumber: 'LD-2026-ABC123',
    clientId: 'client-1',
    clientName: 'Demo Client',
    pickupAddress: '100 Pickup Street',
    deliveryAddress: '200 Delivery Avenue',
    scheduledPickupAt: new Date('2026-08-01T16:00:00Z'),
    assignedDriverId: driverId,
    assignedDriverName: 'driver1',
    status,
    needsAttention: false,
    createdBy: managerId,
    lastEventId: 'seed-event',
    createdAt: new Date('2026-07-29T19:00:00Z'),
    updatedAt: new Date('2026-07-29T19:00:00Z'),
    ...overrides,
  };
}

function eventData(actorUid, type, status, note = null) {
  const actorName = actorUid === managerId ? 'manager' : 'driver1';
  return {
    type,
    status,
    actorUid,
    actorName,
    note,
    createdAt: serverTimestamp(),
  };
}

function proofData(bytes = new Uint8Array([137, 80, 78, 71])) {
  return {
    signaturePng: Bytes.fromUint8Array(bytes),
    contentType: 'image/png',
    byteLength: bytes.length,
    signedByName: 'Receiving Customer',
    signedAt: serverTimestamp(),
    capturedBy: driverId,
    createdAt: serverTimestamp(),
  };
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({ projectId });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();

  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const profiles = [
      [managerId, profile('manager@example.com', managerPermissions)],
      [driverId, profile('driver1@example.com', driverPermissions)],
      [otherDriverId, profile('driver2@example.com', driverPermissions)],
    ];

    for (const [uid, data] of profiles) {
      await setDoc(doc(context.firestore(), 'users', uid), data);
    }
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test('a user can read their own missing or inactive profile', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users', driverId),
      profile('driver1@example.com', driverPermissions, false),
    );
  });

  const inactiveDatabase = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const missingDatabase = testEnvironment
    .authenticatedContext('missing-user')
    .firestore();

  await assertSucceeds(getDoc(doc(inactiveDatabase, 'users', driverId)));
  await assertSucceeds(getDoc(doc(missingDatabase, 'users', 'missing-user')));
});

test('manager must create a load and its first audit event together', async () => {
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const loadRef = doc(database, 'loads', 'load-1');

  await assertFails(
    setDoc(loadRef, {
      ...loadData(),
      lastEventId: 'event-1',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  const batch = writeBatch(database);
  batch.set(loadRef, {
    ...loadData(),
    lastEventId: 'event-1',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(managerId, 'assigned', 'assigned', 'Assigned to driver1'),
  );

  await assertSucceeds(batch.commit());
});

test('manager cannot create a load with a malformed audit profile', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', managerId), {
      email: 'manager@example.com',
      active: true,
      permissions: managerPermissions,
    });
  });

  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const batch = writeBatch(database);

  batch.set(doc(database, 'loads', 'load-1'), {
    ...loadData(),
    lastEventId: 'event-1',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(managerId, 'assigned', 'assigned'),
  );

  await assertFails(batch.commit());
});

test('manager cannot assign a load to a missing driver profile', async () => {
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const batch = writeBatch(database);

  batch.set(doc(database, 'loads', 'load-1'), {
    ...loadData(),
    assignedDriverId: 'missing-driver',
    assignedDriverName: 'Missing Driver',
    lastEventId: 'event-1',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(managerId, 'assigned', 'assigned'),
  );

  await assertFails(batch.commit());
});

test('assigned driver can read but cannot update without an audit event', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const loadRef = doc(database, 'loads', 'load-1');

  await assertSucceeds(getDoc(loadRef));
  await assertFails(
    updateDoc(loadRef, {
      status: 'accepted',
      lastEventId: 'event-1',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('assigned driver can atomically accept and record the audit event', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const batch = writeBatch(database);

  batch.update(doc(database, 'loads', 'load-1'), {
    status: 'accepted',
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(driverId, 'accepted', 'accepted'),
  );

  await assertSucceeds(batch.commit());
});

test('one audit event cannot hide both a status and issue change', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const batch = writeBatch(database);

  batch.update(doc(database, 'loads', 'load-1'), {
    status: 'accepted',
    needsAttention: true,
    issueSummary: 'Waiting for a dock',
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(driverId, 'accepted', 'accepted'),
  );

  await assertFails(batch.commit());
});

test('an issue audit note must match the load summary', async () => {
  await seedLoad('load-1', 'accepted');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const batch = writeBatch(database);

  batch.update(doc(database, 'loads', 'load-1'), {
    needsAttention: true,
    issueSummary: 'Waiting for a dock',
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(driverId, 'issue_reported', 'accepted', 'Everything is fine'),
  );

  await assertFails(batch.commit());
});

test('driver issue reports and manager resolutions are both audited', async () => {
  await seedLoad('load-1', 'accepted');
  const driverDatabase = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const driverBatch = writeBatch(driverDatabase);

  driverBatch.update(doc(driverDatabase, 'loads', 'load-1'), {
    needsAttention: true,
    issueSummary: 'Waiting for a dock',
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  driverBatch.set(
    doc(driverDatabase, 'loads', 'load-1', 'events', 'event-1'),
    eventData(
      driverId,
      'issue_reported',
      'accepted',
      'Waiting for a dock',
    ),
  );
  await assertSucceeds(driverBatch.commit());

  const managerDatabase = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const managerBatch = writeBatch(managerDatabase);
  managerBatch.update(doc(managerDatabase, 'loads', 'load-1'), {
    needsAttention: false,
    issueSummary: deleteField(),
    lastEventId: 'event-2',
    updatedAt: serverTimestamp(),
  });
  managerBatch.set(
    doc(managerDatabase, 'loads', 'load-1', 'events', 'event-2'),
    eventData(managerId, 'issue_resolved', 'accepted'),
  );

  await assertSucceeds(managerBatch.commit());
});

test('unassigned driver cannot read or update a load', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(otherDriverId)
    .firestore();
  const loadRef = doc(database, 'loads', 'load-1');

  await assertFails(getDoc(loadRef));

  const batch = writeBatch(database);
  batch.update(loadRef, {
    status: 'accepted',
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(otherDriverId, 'accepted', 'accepted'),
  );
  await assertFails(batch.commit());
});

test('driver cannot skip directly from assigned to delivered', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const batch = deliveryBatch(database, 'load-1');

  await assertFails(batch.commit());
});

test('in-transit delivery requires proof, metadata, and audit event', async () => {
  await seedLoad('load-1', 'in_transit');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();

  const missingProofBatch = writeBatch(database);
  missingProofBatch.update(doc(database, 'loads', 'load-1'), {
    status: 'delivered',
    delivery: deliveryMetadata(),
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  missingProofBatch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(driverId, 'delivered', 'delivered'),
  );
  await assertFails(missingProofBatch.commit());

  await assertSucceeds(deliveryBatch(database, 'load-1').commit());
});

test('unassigned driver cannot create another driver\'s delivery proof', async () => {
  await seedLoad('load-1', 'in_transit');
  const database = testEnvironment
    .authenticatedContext(otherDriverId)
    .firestore();

  await assertFails(deliveryBatch(database, 'load-1').commit());
});

test('oversized signatures are rejected before delivery', async () => {
  await seedLoad('load-1', 'in_transit');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const tooLarge = new Uint8Array(350 * 1024 + 1);

  await assertFails(
    deliveryBatch(database, 'load-1', proofData(tooLarge)).commit(),
  );
});

test('delivery proofs are readable but never replaceable or deletable', async () => {
  await seedLoad('load-1', 'in_transit');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const proofRef = doc(
    database,
    'loads',
    'load-1',
    'proofs',
    'customerSignature',
  );

  await assertSucceeds(deliveryBatch(database, 'load-1').commit());
  await assertSucceeds(getDoc(proofRef));
  await assertFails(updateDoc(proofRef, { signedByName: 'Replacement' }));
  await assertFails(deleteDoc(proofRef));
});

test('manager cannot rewrite original load attribution', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const batch = writeBatch(database);

  batch.update(doc(database, 'loads', 'load-1'), {
    createdBy: 'rewritten-owner',
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(managerId, 'load_updated', 'assigned'),
  );

  await assertFails(batch.commit());
});

test('client records require server audit timestamps and cannot be deleted', async () => {
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const clientRef = doc(database, 'clients', 'client-1');

  await assertSucceeds(
    setDoc(clientRef, {
      name: 'Demo Client',
      contact: 'Receiving Team',
      phone: '555-0100',
      email: 'receiving@example.com',
      address: '200 Delivery Avenue',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(deleteDoc(clientRef));
});

test('loads cannot be permanently deleted', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();

  await assertFails(deleteDoc(doc(database, 'loads', 'load-1')));
});

test('delivered loads are terminal and delivery metadata is immutable', async () => {
  await seedLoad('load-1', 'delivered', {
    delivery: {
      proofId: 'customerSignature',
      signedByName: 'Receiving Customer',
      signedAt: new Date('2026-07-29T19:00:00Z'),
      capturedBy: driverId,
    },
  });
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const batch = writeBatch(database);

  batch.update(doc(database, 'loads', 'load-1'), {
    status: 'in_transit',
    'delivery.signedByName': 'Replacement',
    lastEventId: 'event-1',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', 'load-1', 'events', 'event-1'),
    eventData(managerId, 'in_transit', 'in_transit'),
  );

  await assertFails(batch.commit());
});

function deliveryMetadata() {
  return {
    proofId: 'customerSignature',
    signedByName: 'Receiving Customer',
    signedAt: serverTimestamp(),
    capturedBy: driverId,
  };
}

function deliveryBatch(database, loadId, proof = proofData()) {
  const batch = writeBatch(database);
  batch.set(
    doc(database, 'loads', loadId, 'proofs', 'customerSignature'),
    proof,
  );
  batch.update(doc(database, 'loads', loadId), {
    status: 'delivered',
    delivery: deliveryMetadata(),
    lastEventId: 'event-delivered',
    updatedAt: serverTimestamp(),
  });
  batch.set(
    doc(database, 'loads', loadId, 'events', 'event-delivered'),
    eventData(driverId, 'delivered', 'delivered', 'Customer signature captured'),
  );
  return batch;
}

async function seedLoad(loadId, status = 'assigned', overrides = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'loads', loadId),
      loadData(status, overrides),
    );
  });
}
