// Run from flutter_app after Firebase CLI login. Backups contain private business data.
const fs = require('node:fs');
const path = require('node:path');
const auth = require('firebase-tools/lib/auth');

async function main() {
  const destination = process.argv[2];
  if (!destination) throw Error('Usage: node tool/backup_firestore.cjs <new-output-directory>');
  const directory = path.resolve(destination);
  if (fs.existsSync(directory)) throw Error('Choose a new output directory; existing backups are never overwritten.');
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw Error('Sign in with the Firebase CLI first.');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']);
  let serverTime;
  async function request(url, body) {
    const response = await fetch(url, {method: body ? 'POST' : 'GET', headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type':'application/json'}, body: body ? JSON.stringify(body) : undefined});
    if (!response.ok) throw Error(`Backup request failed (${response.status}): ${(await response.json()).error?.message}. No completed backup was written.`);
    serverTime = response.headers.get('date');
    return response.json();
  }
  const project = 'lobos-trucking';
  await request(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)`);
  if (!serverTime) throw Error('Could not determine server time for a consistent backup.');
  const readTime = new Date(Date.parse(serverTime) - 1000).toISOString();
  const documents = [];
  async function walk(parent) {
    let pageToken;
    do {
      const collections = await request(`${parent}:listCollectionIds`, {pageSize:1000,readTime,...(pageToken ? {pageToken} : {})});
      for (const id of collections.collectionIds || []) {
        let next;
        do {
          const page = await request(`${parent}/${encodeURIComponent(id)}?pageSize=1000&showMissing=true&readTime=${encodeURIComponent(readTime)}${next ? '&pageToken='+encodeURIComponent(next) : ''}`);
          for (const document of page.documents || []) {
            if (document.fields || document.createTime) documents.push(document);
            await walk('https://firestore.googleapis.com/v1/'+document.name);
          }
          next = page.nextPageToken;
        } while(next);
      }
      pageToken = collections.nextPageToken;
    } while(pageToken);
  }
  await walk(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`);
  const releases = await request(`https://firebaserules.googleapis.com/v1/projects/${project}/releases`);
  const rules = [];
  for (const release of releases.releases || []) {
    rules.push({release, ruleset: await request('https://firebaserules.googleapis.com/v1/'+release.rulesetName)});
  }
  fs.mkdirSync(directory, {recursive:true});
  fs.writeFileSync(path.join(directory,'firestore.json'), JSON.stringify({project,readTime,exportedAt:new Date().toISOString(),documents}, null, 2), {flag:'wx'});
  fs.writeFileSync(path.join(directory,'rules.json'),JSON.stringify(rules,null,2),{flag:'wx'});
  console.log(JSON.stringify({directory,documents:documents.length,readTime,includes:'Firestore documents and rules only; excludes Firebase Auth credentials'}));
}
main().catch(error => {console.error(error.message);process.exitCode=1;});
