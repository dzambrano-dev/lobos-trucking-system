import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteField,
  deleteDoc,
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

function profile(email, permissions) {
  return {
    displayName: email.split('@')[0],
    email,
    active: true,
    permissions,
  };
}

function loadData(status = 'assigned') {
  return {
    loadNumber: 'LD-2026-ABC123',
    clientId: 'client-1',
    clientName: 'Demo Client',
    pickupAddress: '100 Pickup Street',
    deliveryAddress: '200 Delivery Avenue',
    scheduledPickupAt: new Date('2026-08-01T16:00:00Z'),
    assignedDriverId: driverId,
    assignedDriverName: 'Driver One',
    status,
    needsAttention: false,
    createdBy: managerId,
    createdAt: new Date('2026-07-29T19:00:00Z'),
    updatedAt: new Date('2026-07-29T19:00:00Z'),
  };
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
  });
});

beforeEach(async () => {
  await Promise.all([
    testEnvironment.clearFirestore(),
    testEnvironment.clearStorage(),
  ]);

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

test('authorized manager can create a load', async () => {
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();

  await assertSucceeds(
    setDoc(doc(database, 'loads', 'load-1'), {
      ...loadData(),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('manager can atomically create a load and its audit event', async () => {
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const loadRef = doc(database, 'loads', 'load-1');
  const eventRef = doc(database, 'loads', 'load-1', 'events', 'event-1');
  const batch = writeBatch(database);

  batch.set(loadRef, {
    ...loadData(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(eventRef, {
    type: 'assigned',
    status: 'assigned',
    actorUid: managerId,
    actorName: 'manager',
    note: 'Assigned to Driver One',
    createdAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());
});

test('audit events cannot be appended without updating the load', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();

  await assertFails(
    setDoc(doc(database, 'loads', 'load-1', 'events', 'event-1'), {
      type: 'assigned',
      status: 'assigned',
      actorUid: driverId,
      actorName: 'driver1',
      note: null,
      createdAt: serverTimestamp(),
    }),
  );
});

test('manager cannot assign a load to a missing driver profile', async () => {
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();

  await assertFails(
    setDoc(doc(database, 'loads', 'load-1'), {
      ...loadData(),
      assignedDriverId: 'missing-driver',
      assignedDriverName: 'Missing Driver',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('assigned driver can read and accept a load', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const loadRef = doc(database, 'loads', 'load-1');

  await assertSucceeds(getDoc(loadRef));
  await assertSucceeds(
    updateDoc(loadRef, {
      status: 'accepted',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('assigned driver can atomically accept and record the audit event', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const loadRef = doc(database, 'loads', 'load-1');
  const eventRef = doc(database, 'loads', 'load-1', 'events', 'event-1');
  const batch = writeBatch(database);

  batch.update(loadRef, {
    status: 'accepted',
    updatedAt: serverTimestamp(),
  });
  batch.set(eventRef, {
    type: 'accepted',
    status: 'accepted',
    actorUid: driverId,
    actorName: 'driver1',
    note: null,
    createdAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());
});

test('driver issue reports and manager resolutions create valid audit events', async () => {
  await seedLoad('load-1', 'accepted');
  const driverDatabase = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const driverBatch = writeBatch(driverDatabase);

  driverBatch.update(doc(driverDatabase, 'loads', 'load-1'), {
    needsAttention: true,
    issueSummary: 'Waiting for a dock',
    updatedAt: serverTimestamp(),
  });
  driverBatch.set(
    doc(driverDatabase, 'loads', 'load-1', 'events', 'event-1'),
    {
      type: 'issue_reported',
      status: 'accepted',
      actorUid: driverId,
      actorName: 'driver1',
      note: 'Waiting for a dock',
      createdAt: serverTimestamp(),
    },
  );
  await assertSucceeds(driverBatch.commit());

  const managerDatabase = testEnvironment
    .authenticatedContext(managerId)
    .firestore();
  const managerBatch = writeBatch(managerDatabase);
  managerBatch.update(doc(managerDatabase, 'loads', 'load-1'), {
    needsAttention: false,
    issueSummary: deleteField(),
    updatedAt: serverTimestamp(),
  });
  managerBatch.set(
    doc(managerDatabase, 'loads', 'load-1', 'events', 'event-2'),
    {
      type: 'issue_resolved',
      status: 'accepted',
      actorUid: managerId,
      actorName: 'manager',
      note: null,
      createdAt: serverTimestamp(),
    },
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
  await assertFails(
    updateDoc(loadRef, {
      status: 'accepted',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('driver cannot skip directly from assigned to delivered', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();

  await assertFails(
    updateDoc(doc(database, 'loads', 'load-1'), {
      status: 'delivered',
      delivery: {
        signatureStoragePath:
          `load-signatures/load-1/${driverId}-123456.png`,
        signedAt: serverTimestamp(),
        capturedBy: driverId,
      },
      updatedAt: serverTimestamp(),
    }),
  );
});

test('in-transit load requires a correctly attributed signature', async () => {
  await seedLoad('load-1', 'in_transit');
  const database = testEnvironment
    .authenticatedContext(driverId)
    .firestore();
  const loadRef = doc(database, 'loads', 'load-1');

  await assertFails(
    updateDoc(loadRef, {
      status: 'delivered',
      updatedAt: serverTimestamp(),
    }),
  );

  await assertSucceeds(
    updateDoc(loadRef, {
      status: 'delivered',
      delivery: {
        signatureStoragePath:
          `load-signatures/load-1/${driverId}-123456.png`,
        signedAt: serverTimestamp(),
        capturedBy: driverId,
      },
      updatedAt: serverTimestamp(),
    }),
  );
});

test('loads cannot be permanently deleted', async () => {
  await seedLoad('load-1');
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();

  await assertFails(deleteDoc(doc(database, 'loads', 'load-1')));
});

test('delivered loads are terminal and their proof cannot be replaced', async () => {
  await seedLoad('load-1', 'delivered', {
    delivery: {
      signatureStoragePath:
        `load-signatures/load-1/${driverId}-123456.png`,
      signedAt: new Date('2026-07-29T19:00:00Z'),
      capturedBy: driverId,
    },
  });
  const database = testEnvironment
    .authenticatedContext(managerId)
    .firestore();

  await assertFails(
    updateDoc(doc(database, 'loads', 'load-1'), {
      status: 'in_transit',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(database, 'loads', 'load-1'), {
      'delivery.signatureStoragePath':
        `load-signatures/load-1/${driverId}-999999.png`,
      updatedAt: serverTimestamp(),
    }),
  );
});

test('signature upload is limited to the assigned in-transit driver', {
  skip: 'The Storage emulator cannot reliably resolve cross-service Firestore reads in rules-unit-testing.',
}, async () => {
  await seedLoad('load-1', 'in_transit');
  const assignedStorage = testEnvironment
    .authenticatedContext(driverId)
    .storage();
  const otherStorage = testEnvironment
    .authenticatedContext(otherDriverId)
    .storage();
  const path = `load-signatures/load-1/${driverId}-123456.png`;
  const bytes = new Uint8Array([137, 80, 78, 71]);
  const metadata = {
    contentType: 'image/png',
    customMetadata: { loadId: 'load-1', capturedBy: driverId },
  };

  await assertFails(otherStorage.ref(path).put(bytes, metadata));
  await assertSucceeds(assignedStorage.ref(path).put(bytes, metadata));
  await assertSucceeds(assignedStorage.ref(path).delete());
});

test('delivery signatures cannot be deleted after completion', {
  skip: 'The Storage emulator cannot reliably resolve cross-service Firestore reads in rules-unit-testing.',
}, async () => {
  await seedLoad('load-1', 'in_transit');
  const storage = testEnvironment
    .authenticatedContext(driverId)
    .storage();
  const path = `load-signatures/load-1/${driverId}-123456.png`;
  const fileRef = storage.ref(path);

  await assertSucceeds(
    fileRef.put(new Uint8Array([137, 80, 78, 71]), {
      contentType: 'image/png',
      customMetadata: { loadId: 'load-1', capturedBy: driverId },
    }),
  );

  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'loads', 'load-1'), {
      status: 'delivered',
      delivery: {
        signatureStoragePath: path,
        signedAt: new Date('2026-07-29T19:00:00Z'),
        capturedBy: driverId,
      },
    });
  });
  await assertFails(fileRef.delete());
});

async function seedLoad(loadId, status = 'assigned', overrides = {}) {
  const data = { ...loadData(status), ...overrides };
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'loads', loadId), data);
  });
}
