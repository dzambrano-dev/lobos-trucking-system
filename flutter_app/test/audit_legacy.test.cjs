const { test } = require('node:test');
const assert = require('node:assert/strict');
const { audit } = require('../tool/audit_legacy.cjs');
test('legacy audit plans unique missing links without changing inputs', () => {
  const jobs = [{ id: 'j' }], invoices = [{ id: 'i', jobId: 'j', amount: 10 }];
  assert.deepEqual(audit(jobs, invoices), { issues: [], links: [{ jobId: 'j', invoiceId: 'i' }] });
  assert.deepEqual(jobs, [{ id: 'j' }]);
});
test('duplicate, orphaned and broken invoice links are reported', () => {
  const result = audit([{ id: 'j', invoiceId: 'missing' }], [
    { id: 'i', jobId: 'j', amount: 10 }, { id: 'i2', jobId: 'j', amount: 10 },
    { id: 'orphan', jobId: 'gone', amount: -1, amountPaid: 3 }
  ]);
  assert.deepEqual(new Set(result.issues.map(i => i.type)), new Set(['duplicate-invoices', 'missing-job', 'invalid-amount', 'invalid-paid-balance', 'broken-link']));
  assert.equal(result.links.length, 0);
});
