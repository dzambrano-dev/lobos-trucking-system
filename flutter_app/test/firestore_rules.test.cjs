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
    await setDoc(doc(db, 'users/office'), { active: true, displayName: 'Office', email: 'office@example.com', permissions: {manageUsers:true,manageClients:true,manageLoads:true,viewAllLoads:true,updateAssignedLoads:true} });
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
const { writeBatch, serverTimestamp } = require('firebase/firestore');
const billData = (amountPaid = 0) => ({amount:500,category:'Fuel',vendor:'Station',expenseDate:Timestamp.now(),amountPaid,paymentReviewed:true});
async function expensePayment(db, id, amount, balance) {
  const batch=writeBatch(db);
  batch.set(doc(db, `expense_payments/${id}`),{expenseId:'bill',amount,paidAt:Timestamp.now(),reference:'Check',createdAt:serverTimestamp()});
  batch.update(doc(db,'expenses/bill'),{amountPaid:balance,paymentReviewed:true,lastPaymentId:id});
  return batch.commit();
}
test('expense balances require atomic receipts, reject overpayment and preserve history', async () => {
  const db=env.authenticatedContext('office').firestore();
  await assertFails(setDoc(doc(db,'expenses/bill'),billData(50)));
  await assertSucceeds(setDoc(doc(db,'expenses/bill'),billData()));
  await assertFails(updateDoc(doc(db,'expenses/bill'),{amountPaid:200}));
  await assertSucceeds(expensePayment(db,'partial',200,200));
  await assertFails(expensePayment(db,'excess',301,501));
  await assertFails(updateDoc(doc(db,'expenses/bill'),{amount:100}));
  await assertFails(updateDoc(doc(db,'expense_payments/partial'),{amount:10}));
  await assertFails(deleteDoc(doc(db,'expense_payments/partial')));
  const reversal={expenseId:'bill',paymentId:'partial',amount:200,reason:'Correction',createdAt:serverTimestamp()};
  await assertFails(setDoc(doc(db,'expense_reversals/partial'),reversal));
  const batch=writeBatch(db);
  batch.set(doc(db,'expense_reversals/partial'),reversal);
  batch.update(doc(db,'expenses/bill'),{amountPaid:0,lastReversalId:'partial'});
  await assertSucceeds(batch.commit());
  await assertFails(deleteDoc(doc(db,'expense_reversals/partial')));
  await assertFails(updateDoc(doc(db,'expense_reversals/partial'),{reason:'Rewrite'}));
});
test('expense paid on creation links receipt and legacy review cannot erase payments', async () => {
  const db=env.authenticatedContext('office').firestore();
  const batch=writeBatch(db);
  batch.set(doc(db,'expenses/bill'),{...billData(500),lastPaymentId:'opening'});
  batch.set(doc(db,'expense_payments/opening'),{expenseId:'bill',amount:500,paidAt:Timestamp.now(),reference:'Cash',createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(db,'expenses/bill'),{amountPaid:0,paymentReviewed:true}));
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'expenses/legacy'),{amount:50,category:'Fuel',expenseDate:Timestamp.now()}));
  await assertSucceeds(updateDoc(doc(db,'expenses/legacy'),{amountPaid:0,paymentReviewed:true}));
  const driver=env.authenticatedContext('driver').firestore();
  for (const collection of ['expenses','expense_payments','expense_reversals']) {
    await assertFails(getDoc(doc(driver,`${collection}/bill`)));
    await assertFails(setDoc(doc(driver,`${collection}/fake`),billData()));
  }
});
