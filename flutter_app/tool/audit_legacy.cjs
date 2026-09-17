// Read-only by default. Credentials come from Google Application Default Credentials.
// node tool/audit_legacy.cjs --project lobos-trucking [--apply]
function audit(jobs, invoices) {
  const issues = [], links = [], grouped = new Map();
  const jobMap = new Map(jobs.map(row => [row.id, row]));
  const invoiceMap = new Map(invoices.map(row => [row.id, row]));
  for (const inv of invoices) {
    if (!jobMap.has(inv.jobId)) issues.push({ type: 'missing-job', invoiceId: inv.id, jobId: inv.jobId ?? null });
    const list = grouped.get(inv.jobId) ?? [];
    list.push(inv); grouped.set(inv.jobId, list);
    if (typeof inv.amount !== 'number' || !Number.isFinite(inv.amount) || inv.amount <= 0) issues.push({ type: 'invalid-amount', invoiceId: inv.id });
    if (inv.amountPaid != null && (typeof inv.amountPaid !== 'number' || !Number.isFinite(inv.amountPaid) || inv.amountPaid < 0 || inv.amountPaid > inv.amount)) issues.push({ type: 'invalid-paid-balance', invoiceId: inv.id });
  }
  for (const [jobId, list] of grouped) {
    if (list.length > 1) issues.push({ type: 'duplicate-invoices', jobId: jobId ?? null, invoiceIds: list.map(row => row.id) });
    else if (jobMap.has(jobId) && jobMap.get(jobId).invoiceId == null) links.push({ jobId, invoiceId: list[0].id });
  }
  for (const job of jobs) {
    if (job.invoiceId != null && invoiceMap.get(job.invoiceId)?.jobId !== job.id) issues.push({ type: 'broken-link', jobId: job.id, invoiceId: job.invoiceId });
  }
  return { issues, links };
}
module.exports = { audit };
if (require.main === module) {
  (async () => {
    const args = process.argv.slice(2);
    const project = args[args.indexOf('--project') + 1];
    if (!args.includes('--project') || !project || project.startsWith('--')) throw new Error('Supply --project PROJECT_ID.');
    const { initializeApp, applicationDefault } = require('firebase-admin/app');
    const { getFirestore } = require('firebase-admin/firestore');
    initializeApp({ projectId: project, credential: applicationDefault() });
    const db = getFirestore();
    const read = async name => (await db.collection(name).get()).docs.map(d => ({ ...d.data(), id: d.id }));
    const [jobs, invoices] = await Promise.all([read('jobs'), read('invoices')]);
    const report = audit(jobs, invoices);
    console.log(JSON.stringify({ project, mode: args.includes('--apply') ? 'apply' : 'audit', ...report }, null, 2));
    if (report.issues.length) { process.exitCode = 2; return; }
    if (!args.includes('--apply')) return;
    // Run during the documented write freeze. Each transaction rechecks the
    // referenced documents and cannot overwrite an existing invoice link.
    for (const link of report.links) {
      await db.runTransaction(async tx => {
        const jobRef = db.collection('jobs').doc(link.jobId);
        const invRef = db.collection('invoices').doc(link.invoiceId);
        const [job, inv] = await Promise.all([tx.get(jobRef), tx.get(invRef)]);
        if (!job.exists || !inv.exists || inv.data().jobId !== link.jobId) throw new Error('Records changed; stop and rerun audit.');
        if (job.data().invoiceId === link.invoiceId) return;
        if (job.data().invoiceId != null) throw new Error('Invoice link changed; stop and rerun audit.');
        tx.update(jobRef, { invoiceId: link.invoiceId });
      });
    }
    console.log(`Linked ${report.links.length} jobs. No financial amounts or invoices were changed.`);
  })().catch(error => { console.error(error.message); process.exitCode = 1; });
}
