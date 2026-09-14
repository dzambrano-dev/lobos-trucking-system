const { before, after, beforeEach, test } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc, runTransaction, Timestamp } = require('firebase/firestore');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-lobos', firestore: {
    host: '127.0.0.1', port: 8085, rules: fs.readFileSync('firestore.rules', 'utf8')
  }});
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'staff/office'), { active: true });
    await setDoc(doc(db, 'clients/client'), { name: 'Acme' });
    await setDoc(doc(db, 'jobs/job'), { clientId: 'client', clientName: 'Acme', pickup: 'Yard', dropoff: 'Site', price: 100.30, status: 'completed' });
  });
});
test('only enabled staff can read company data or edit customers', async () => {
  const staff = env.authenticatedContext('office').firestore();
  const outsider = env.authenticatedContext('outsider').firestore();
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'clients/client')));
  await assertFails(getDoc(doc(outsider, 'clients/client')));
  await assertFails(setDoc(doc(outsider, 'staff/outsider'), { active: true }));
  await assertSucceeds(getDoc(doc(staff, 'clients/client')));
  await assertSucceeds(updateDoc(doc(staff, 'clients/client'), { name: 'Updated' }));
  await assertFails(deleteDoc(doc(staff, 'clients/client')));
});
async function invoice(db) {
  await runTransaction(db, async tx => {
    const job = await tx.get(doc(db, 'jobs/job'));
    tx.set(doc(db, 'invoices/job'), { jobId: 'job', amount: job.data().price, amountPaid: 0,
      status: 'pending', dueDate: Timestamp.now(), notes: '' });
    tx.update(doc(db, 'jobs/job'), { invoiceId: 'job' });
  });
}
test('invoicing requires an atomic job link and then locks job pricing', async () => {
  const db = env.authenticatedContext('office').firestore();
  await assertFails(setDoc(doc(db, 'invoices/job'), { jobId: 'job', amount: 100.30, amountPaid: 0, status: 'pending' }));
  await assertSucceeds(invoice(db));
  await assertFails(updateDoc(doc(db, 'jobs/job'), { price: 10 }));
  await assertSucceeds(updateDoc(doc(db, 'jobs/job'), { archived: true }));
  await assertFails(updateDoc(doc(db, 'invoices/job'), { amount: 200 }));
  await assertSucceeds(updateDoc(doc(db, 'invoices/job'), { dueDate: Timestamp.now(), notes: 'Net 30' }));
});
test('payment ledger and invoice balance must change together; history is immutable', async () => {
  const db = env.authenticatedContext('office').firestore();
  await invoice(db);
  await assertFails(updateDoc(doc(db, 'invoices/job'), { amountPaid: 30.10, status: 'partial', lastPaymentId: 'missing' }));
  await assertSucceeds(runTransaction(db, async tx => {
    await tx.get(doc(db, 'invoices/job'));
    tx.set(doc(db, 'payments/p1'), { invoiceId: 'job', amount: 30.10, reference: 'Check' });
    tx.update(doc(db, 'invoices/job'), { amountPaid: 30.10, status: 'partial', lastPaymentId: 'p1' });
  }));
  await assertFails(updateDoc(doc(db, 'payments/p1'), { amount: 1 }));
  await assertFails(deleteDoc(doc(db, 'payments/p1')));
  await assertFails(runTransaction(db, async tx => {
    await tx.get(doc(db, 'invoices/job'));
    tx.set(doc(db, 'payments/p2'), { invoiceId: 'job', amount: 100, reference: 'Too much' });
    tx.update(doc(db, 'invoices/job'), { amountPaid: 130.10, status: 'paid', lastPaymentId: 'p2' });
  }));
});
test('sub-cent amounts are denied, payment reversal must be atomic and immutable', async () => {
  const db = env.authenticatedContext('office').firestore();
  await assertFails(updateDoc(doc(db, 'jobs/job'), { price: 10.001 }));
  await invoice(db);
  await runTransaction(db, async tx => {
    await tx.get(doc(db, 'invoices/job'));
    tx.set(doc(db, 'payments/p1'), { invoiceId: 'job', amount: 100.30, reference: 'Check' });
    tx.update(doc(db, 'invoices/job'), { amountPaid: 100.30, status: 'paid', lastPaymentId: 'p1' });
  });
  await assertFails(setDoc(doc(db, 'payment_reversals/p1'), { invoiceId: 'job', paymentId: 'p1', amount: 100.30, reason: 'Correction' }));
  await assertSucceeds(runTransaction(db, async tx => {
    await tx.get(doc(db, 'invoices/job'));
    tx.set(doc(db, 'payment_reversals/p1'), { invoiceId: 'job', paymentId: 'p1', amount: 100.30, reason: 'Correction' });
    tx.update(doc(db, 'invoices/job'), { amountPaid: 0, status: 'pending', lastReversalId: 'p1' });
  }));
  await assertFails(updateDoc(doc(db, 'payment_reversals/p1'), { reason: 'Rewritten' }));
  await assertFails(deleteDoc(doc(db, 'payment_reversals/p1')));
});
