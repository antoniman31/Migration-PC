// Verifie l'installabilite et le fonctionnement hors ligne, en servant le
// depot en HTTP local — un service worker ne s'enregistre pas en file://.
//
//   node tests/test-pwa.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),http=require('http');
const racine=path.join(__dirname,'..');

const TYPES={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8',
  '.json':'application/json; charset=utf-8','.png':'image/png','.svg':'image/svg+xml',
  '.css':'text/css; charset=utf-8'};

let ko=0;
const ok=(l,a,b)=>{const p=(b===undefined?!!a:a===b);console.log((p?'  ok  ':' FAIL ')+l+' → '+a+(p?'':' (attendu '+b+')'));if(!p)ko++;};

// Serveur minimal, confine a la racine du depot.
const serveur=http.createServer((req,res)=>{
  let rel=decodeURIComponent(req.url.split('?')[0]);
  if(rel==='/')rel='/index.html';
  const abs=path.join(racine,path.normalize(rel));
  if(!abs.startsWith(racine)){res.writeHead(403);res.end();return;}
  fs.readFile(abs,(e,buf)=>{
    if(e){res.writeHead(404);res.end('introuvable');return;}
    res.writeHead(200,{'Content-Type':TYPES[path.extname(abs)]||'application/octet-stream'});
    res.end(buf);
  });
});

(async()=>{
await new Promise(r=>serveur.listen(0,'127.0.0.1',r));
const base='http://127.0.0.1:'+serveur.address().port;

const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;
const b=await chromium.launch(lancement);
const ctx=await b.newContext();
const pg=await ctx.newPage();

console.log('--- manifeste ---');
const man=JSON.parse(fs.readFileSync(path.join(racine,'manifest.json'),'utf8'));
ok('nom court sous 12 caractères',man.short_name.length<=12,true);
ok('start_url relatif',man.start_url.startsWith('./'),true);
ok('affichage autonome',man.display,'standalone');
const tailles=man.icons.map(i=>i.sizes);
ok('icône 192 présente',tailles.includes('192x192'),true);
ok('icône 512 présente',tailles.includes('512x512'),true);
ok('au moins une maskable',man.icons.some(i=>i.purpose==='maskable'),true);
for(const i of man.icons){
  ok('fichier '+i.src+' présent',fs.existsSync(path.join(racine,i.src)),true);
}

console.log('\n--- service worker ---');
await pg.goto(base+'/index.html',{waitUntil:'networkidle'});
ok('lien manifeste dans la page',await pg.getAttribute('link[rel=manifest]','href'),'manifest.json');
ok('couleur de thème déclarée',await pg.getAttribute('meta[name=theme-color]','content'),'#5493FF');

const enregistre=await pg.evaluate(async()=>{
  const r=await navigator.serviceWorker.ready.catch(()=>null);
  return !!(r&&r.active);
});
ok('service worker actif',enregistre,true);

// Laisse le temps au cache de se remplir avant de couper le reseau.
await pg.waitForTimeout(700);
const enCache=await pg.evaluate(async()=>{
  const noms=await caches.keys();
  if(!noms.length)return 0;
  const c=await caches.open(noms[0]);
  return (await c.keys()).length;
});
ok('squelette mis en cache',enCache>0,true);

console.log('\n--- hors ligne ---');
await ctx.setOffline(true);
await pg.reload({waitUntil:'domcontentloaded'});
await pg.waitForTimeout(500);
ok('page servie sans réseau',(await pg.$$('#list-npc .item')).length>0,true);
ok('titre présent hors ligne',(await pg.textContent('#profil-titre')).length>0,true);
await ctx.setOffline(false);

console.log('\n--- file:// : la page reste autonome ---');
const pg2=await (await b.newContext()).newPage();
const erreurs=[];
pg2.on('pageerror',e=>erreurs.push(e.message));
await pg2.goto('file://'+path.join(racine,'index.html'),{waitUntil:'networkidle'});
ok('aucune erreur JS en file://',erreurs.length===0?'oui':erreurs.join(' | '),'oui');
ok('checklist rendue en file://',(await pg2.$$('#list-npc .item')).length>0,true);

console.log('\n--- le nom du cache suit la page ---');
// Le commentaire de sw.js demandait d'incrementer CACHE a chaque publication
// qui change index.html. Personne ne l'a fait pendant dix publications, donc
// `npm run sync` le derive maintenant de la page. Ce test constate que c'est
// fait : sans lui, on reviendrait au meme oubli silencieux.
const crypto=require('crypto');
const empreinte=crypto.createHash('sha256')
  .update(fs.readFileSync(path.join(racine,'index.html'),'utf8'))
  .digest('hex').slice(0,12);
const sw=fs.readFileSync(path.join(racine,'sw.js'),'utf8');
const nomCache=(sw.match(/const CACHE = "([^"]+)";/)||[])[1];
ok('le cache porte l\'empreinte d\'index.html',nomCache,'migration-pc-'+empreinte);
if(nomCache!=='migration-pc-'+empreinte)
  console.log('   → lancer `npm run sync` pour le remettre à jour');

await b.close();
serveur.close();
console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nPWA OPERATIONNELLE');
process.exit(ko?1:0);
})();
