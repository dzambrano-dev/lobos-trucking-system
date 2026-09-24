// Refuse to publish a cached web build without the URL launcher implementation.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const release = path.join(root, 'build/web/main.dart.js');
const cache = path.join(root, '.dart_tool/flutter_build');
try {
  const releaseHash = digest(release);
  const candidates = fs.readdirSync(cache, {withFileTypes:true}).filter(e=>e.isDirectory()).map(e=>path.join(cache,e.name));
  const matching = candidates.find(dir => fs.existsSync(path.join(dir,'main.dart.js')) && digest(path.join(dir,'main.dart.js')) === releaseHash);
  if (!matching) throw Error('No matching Flutter build cache found.');
  const registrant = fs.readFileSync(path.join(matching,'web_plugin_registrant.dart'),'utf8');
  const deps = fs.readFileSync(path.join(matching,'main.dart.js.deps'),'utf8');
  if (!registrant.includes('UrlLauncherPlugin.registerWith(') || !deps.includes('/url_launcher_web-')) {
    throw Error('URL launcher web registration is missing from the compiled release.');
  }
  console.log('Verified release: URL launcher web plugin is registered and compiled.');
} catch (error) {
  console.error(`${error.message}\nRun flutter clean, flutter pub get, then flutter build web before deploying.`);
  process.exitCode = 1;
}
