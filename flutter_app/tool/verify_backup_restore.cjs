const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
if (!process.argv[2]) throw Error('Pass a Firestore JSON backup path');
const backup=JSON.parse(fs.readFileSync(process.argv[2]));
const host=process.env.FIRESTORE_EMULATOR_HOST;
if(!host||!/^127\.0\.0\.1:\d+$/.test(host))throw Error('Local Firestore emulator required');
const prefix='projects/demo-lobos/databases/(default)/documents/';
const base='http://'+host+'/v1/';
const normalize=v=>Array.isArray(v)?v.map(normalize):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,k==='timestampValue'?new Date(v[k]).toISOString():normalize(v[k])])):v;
(async()=>{
 const writes=backup.documents.map(d=>({update:{name:prefix+d.name.split('/documents/')[1],fields:d.fields||{}}}));
 const response=await fetch(base+'projects/demo-lobos/databases/(default)/documents:commit',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer owner'},body:JSON.stringify({writes})});
 if(!response.ok)throw Error(await response.text());
 for(const original of backup.documents){const res=await fetch(base+prefix+original.name.split('/documents/')[1],{headers:{Authorization:'Bearer owner'}});if(!res.ok)throw Error('Restore read failed');const restored=await res.json();assert.deepEqual(normalize(restored.fields||{}),normalize(original.fields||{}));}
 const result={restoredDocuments:writes.length,allFieldsMatched:true,target:'local emulator only',checkedAt:new Date().toISOString()};
 console.log(JSON.stringify(result));
})().catch(e=>{console.error(e.message);process.exitCode=1});
