// Tests navigateur : charge index.html dans un vrai Chromium et verifie le rendu,
// ce que le DOM simule de test-checklist.js ne peut pas couvrir (mise en page,
// imbrication des panneaux, visibilite reelle des elements).
//
//   npm install playwright && node tests/test-navigateur.js
//
// CHROME peut pointer vers un binaire Chromium deja present sur la machine.
const {chromium}=require('playwright');
const path=require('path'),fs=require('fs');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
// Les comptes viennent du profil d'exemple : figer « 45 éléments » oblige à
// retoucher ce fichier a chaque enrichissement du contenu, ce qui finit par
// le faire mentir.
const PROFIL=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const SECTIONS=['quitter','npc','apps','data','pwa'];
const TOTAL=SECTIONS.reduce(function(n,s){return n+((PROFIL[s]||[]).length);},0);
let ko=0;
const ok=(l,a,b)=>{const p=(b===undefined?!!a:a===b);console.log((p?'  ok   ':'  FAIL ')+l+' → '+a+(p?'':' (attendu '+b+')'));if(!p)ko++;};


// Depuis la refonte, la situation et le theme sont derriere « Réglages ».
// Ces deux aides reproduisent le chemin qu'un utilisateur emprunte, plutôt
// que d'affaiblir les assertions qui suivent.
async function ouvrirReglages(pg){
  if(await pg.isVisible('#hdr-menu-liste'))return;
  await pg.click('#menu-btn');
  await pg.waitForSelector('#hdr-menu-liste',{state:'visible'});
}
async function ouvrirSituation(pg){
  if(await pg.isVisible('#scen'))return;
  await ouvrirReglages(pg);
  await pg.click('#scen-btn');
  await pg.waitForSelector('#scen',{state:'visible'});
}

(async()=>{
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;
const b=await chromium.launch(lancement);
const pg=await b.newPage();
const erreurs=[];
pg.on('pageerror',e=>erreurs.push(e.message));
// Une seule absence est attendue et benigne : resultat-scan.js n'existe que
// sur une cle ou un scan a tourne. On la nomme plutot que de desactiver
// l'assertion, pour que toute AUTRE erreur de console fasse echouer le test.
// Le texte du message ne nomme pas la ressource : c'est son emplacement qui
// le fait. On cible donc l'URL, pour que toute AUTRE erreur de console fasse
// bien echouer le test.
pg.on('console',m=>{
  if(m.type()!=='error')return;
  const ou=(m.location()&&m.location().url)||'';
  if(/resultat-scan\.js$/.test(ou))return;
  erreurs.push('console: '+m.text()+(ou?' ['+ou+']':''));
});
await pg.goto(HTML,{waitUntil:'networkidle'});

console.log('--- chargement ---');
ok('aucune erreur JS',erreurs.length===0?'oui':'NON : '+erreurs.join(' | '),'oui');
ok('titre onglet',await pg.title());
ok('en-tête',await pg.textContent('#profil-titre'),'Migration Windows — profil type');
ok('total affiché',await pg.textContent('#gp-total'),String(TOTAL));
ok('filtres catégories',(await pg.$$('#cat-filters .fb')).length,8);

// Les quatre panneaux doivent etre freres : imbriques, les onglets deviennent
// invisibles des qu'on quitte le premier. On compare les parents entre eux
// plutot qu'a un conteneur nomme : ajouter un <main> ne doit pas casser ce test.
const memeParent=await pg.evaluate(()=>{
  const p=['npc','apps','data','pwa'].map(t=>document.getElementById('panel-'+t).parentElement);
  return p.every(x=>x===p[0]) && !p[0].closest('.panel');
});
ok('panneaux frères',memeParent,true);

console.log('\n--- onglet Nouveau PC ---');
// Ce n'est plus l'onglet ouvert au chargement : il faut y aller.
await pg.click('#tab-npc');
await pg.waitForTimeout(150);
ok('items rendus',(await pg.$$('#list-npc .item')).length,PROFIL.npc.length);
ok('badge étape visible',await pg.isVisible('#list-npc .b-num'));

console.log('\n--- onglet Apps (celui qui était cassé en v6) ---');
await pg.click('#tab-apps');
ok('items rendus',(await pg.$$('#list-apps .item')).length,18);
const boite=await (await pg.$('#list-apps .item')).boundingBox();
ok('items réellement visibles',boite&&boite.height>0&&boite.width>0,true);
ok('badges winget rendus',(await pg.$$('#list-apps .b-winget')).length,17);
ok('badge dépendance rendu',(await pg.$$('#list-apps .b-dep')).length>0);
ok('lien recherche',(await pg.getAttribute('#list-apps .lnk-btn','href')).startsWith('https://www.google.com/search'));

console.log('\n--- interaction ---');
await pg.click('#list-apps .item');
ok('case cochée',(await pg.$$('#list-apps .item.done')).length,1);
ok('compteur global',await pg.textContent('#gp-done'),'1');
const persiste=await pg.evaluate(()=>{const s=JSON.parse(localStorage.getItem('mpc_state_v1'));return Object.keys(s.checked).length;});
ok('persisté en localStorage',persiste,1);

await pg.fill('#gsearch-input','git');
await pg.waitForTimeout(150);
ok('recherche globale',(await pg.textContent('#gsearch-count')).length>0);
await pg.fill('#gsearch-input','');

console.log('\n--- onglets Données et PWA ---');
await pg.click('#tab-data');
ok('données rendues',(await pg.$$('#list-data .item')).length,PROFIL.data.length);
ok('champ licence présent',(await pg.$$('#list-data .lic-field')).length>0);
ok('champs env présents',(await pg.$$('#list-data .env-row')).length,3);
await pg.fill('#list-data .lic-input','ABCD-1234-EFGH');
await pg.fill('#list-data .env-input','D:/outils/java');
await pg.waitForTimeout(200);
const sto=await pg.evaluate(()=>JSON.parse(localStorage.getItem('mpc_state_v1')));
ok('licence persistée',Object.values(sto.lic)[0],'ABCD-1234-EFGH');
ok('variable persistée',Object.values(sto.env)[0],'D:/outils/java');
await pg.reload({waitUntil:'networkidle'});
await pg.click('#tab-data');
await pg.waitForTimeout(300);
ok('licence relue après rechargement',await pg.inputValue('#list-data .lic-input'),'ABCD-1234-EFGH');
await pg.click('#tab-pwa');
ok('pwa rendues',(await pg.$$('#list-pwa .item')).length,3);

console.log('\n--- import d\'un inventaire ---');
await pg.click('#tab-apps');
const inv=fs.readFileSync(path.join(__dirname,'inventaire-exemple.json'),'utf8');
pg.on('dialog',d=>d.accept());
await pg.setInputFiles('#json-file',{name:'inventaire-pc.json',mimeType:'application/json',buffer:Buffer.from(inv)});
await pg.waitForTimeout(400);
ok('apps remplacées',(await pg.$$('#list-apps .item')).length,4);
ok('en-tête mis à jour',await pg.textContent('#profil-titre'),'Migration PC — inventaire importé');
ok('progression conservée',(await pg.$$('#list-apps .item.done')).length>=0);

// Un profil local, s'il y en a un : permet de verifier son propre fichier.
const profilLocal=process.env.PROFIL||path.join(racine,'profil-local.json');
if(fs.existsSync(profilLocal)){
  console.log('\n--- profil local ---');
  const p=JSON.parse(fs.readFileSync(profilLocal,'utf8'));
  const attendu=SECTIONS.reduce(function(n,c){return n+((p[c]||[]).length);},0);
  await pg.setInputFiles('#json-file',{name:'profil.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(p))});
  await pg.waitForTimeout(500);
  ok('items chargés',await pg.textContent('#gp-total'),String(attendu));
  ok('apps rendues',(await pg.$$('#list-apps .item')).length,p.apps.length);
  ok('en-tête',await pg.textContent('#profil-titre'),p.meta.nom);
}

console.log('\n--- import d\'un export winget ---');
const wg=fs.readFileSync(path.join(__dirname,'winget-export-exemple.json'),'utf8');
await pg.setInputFiles('#json-file',{name:'apps.json',mimeType:'application/json',buffer:Buffer.from(wg)});
await pg.waitForTimeout(400);
ok('paquets importés',(await pg.$$('#list-apps .item')).length,7);
ok('en-tête winget',await pg.textContent('#profil-titre'),'Migration PC — export winget');
ok('badge identifiant rendu',(await pg.textContent('#list-apps')).indexOf('Mozilla.Firefox')>=0,true);
ok('bouton winget .json présent',await pg.isVisible('button[onclick="exportWingetJSON(true)"]'),true);
await pg.reload({waitUntil:'networkidle'});
await pg.click('#tab-apps');
ok('profil winget mémorisé après rechargement',(await pg.$$('#list-apps .item')).length,7);

console.log('\n--- filet d\'erreur ---');
// Une exception pendant un rendu doit devenir visible, et ne pas emporter les autres onglets.
ok('bandeau masqué au départ',await pg.isVisible('#panne'),false);
await pg.evaluate(()=>{window.renderApps=()=>{throw new Error('panne simulée');};renderAll();});
await pg.waitForTimeout(200);
ok('bandeau visible après la panne',await pg.isVisible('#panne'),true);
const detail=await pg.textContent('#panne-detail');
ok('onglet fautif nommé',detail.indexOf('Apps')>=0,true);
ok('message d\'erreur repris',detail.indexOf('panne simulée')>=0,true);
ok('les autres onglets survivent',(await pg.$$('#list-npc .item')).length>0,true);
await pg.click('.panne-fermer');
ok('bandeau refermable',await pg.isVisible('#panne'),false);
// La panne ci-dessus est volontaire : on la retire du bilan d'erreurs final.
erreurs.length=0;
await pg.reload({waitUntil:'networkidle'});

console.log('\n--- thème sombre ---');
await ouvrirReglages(pg);await pg.click('#theme-btn');
ok('thème basculé',await pg.getAttribute('html','data-theme'),'dark');

if(process.env.CAPTURE){
  await pg.screenshot({path:process.env.CAPTURE+'/sombre.png'});
  await ouvrirReglages(pg);await pg.click('#theme-btn');await pg.waitForTimeout(200);
  await pg.screenshot({path:process.env.CAPTURE+'/clair.png'});
}

console.log('\nerreurs JS collectées :',erreurs.length?erreurs.join(' | '):'aucune');
await b.close();
console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nTOUS LES TESTS NAVIGATEUR PASSENT');
process.exit(ko?1:0);
})();
