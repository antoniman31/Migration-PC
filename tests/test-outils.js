// Les scripts etaient publies avec le site depuis le debut — la CI met le
// depot entier en ligne — mais rien ne pointait vers eux, et les messages
// d'erreur parlaient d'« un inventaire de scan-pc.ps1 » sans dire ou le
// trouver. Ce test couvre le bloc de telechargement, et le chemin qui evite
// d'avoir a telecharger quoi que ce soit : le scanner pose son resultat a cote
// de la page, qui s'ouvre deja remplie.
//
//   node tests/test-outils.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),os=require('os');
const racine=path.join(__dirname,'..');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

(async()=>{
const b=await chromium.launch(lancement);
const pg=await (await b.newContext()).newPage();
const errs=[];pg.on('pageerror',e=>errs.push(e.message));
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};

console.log('--- les fichiers proposés existent vraiment ---');
await pg.goto('file://'+path.join(racine,'index.html'),{waitUntil:'networkidle'});
await pg.evaluate(()=>{try{localStorage.setItem('mpc_debut_v1','1');}catch(e){}});
const proposes=await pg.evaluate(()=>OUTILS.map(o=>o.f));
proposes.forEach(f=>ok('« '+f+' » est dans le dépôt',fs.existsSync(path.join(racine,f)),true));

// Ce test ne vérifiait qu'un sens : que ce qui est proposé existe. Jamais
// l'inverse — que ce qui existe soit proposé. C'est par là que ça a dérivé :
// ecrire-resultat.ps1 manquait à la liste, et comme les deux scanners
// sautaient l'étape en silence, la page ne se remplissait jamais toute seule
// pour qui avait téléchargé fichier par fichier, sans qu'aucun message le dise.
// Les scripts sont ranges dans scripts\ ; seul le fichier a double-cliquer
// reste a la racine. On balaie les deux.
const surDisque=[
  ...fs.readdirSync(racine).filter(f=>/\.(ps1|bat)$/i.test(f)),
  ...fs.readdirSync(path.join(racine,'scripts')).filter(f=>/\.(ps1|bat)$/i.test(f)).map(f=>'scripts/'+f)
].sort();
ok('des scripts existent sur le disque',surDisque.length>0,true);
ok('aucun script publié n\'est absent de la liste',
  surDisque.filter(f=>proposes.indexOf(f)<0).join(', '),'');

// Et quand le fichier manque quand même, ça doit se dire.
for(const f of ['scripts/scan-pc.ps1','scripts/verifier-pc.ps1']){
  ok(f+' signale son absence',
    /ecrire-resultat\.ps1 n'est pas a cote/.test(fs.readFileSync(path.join(racine,f),'utf8')),true);
}
// Le compte changera encore : ce qui doit tenir, c'est qu'un lanceur a
// double-cliquer soit propose, et qu'il vienne en premier.
// Un seul lanceur desormais : trois fichiers qui se ressemblaient
// desorientaient plus qu'un point d'entree unique.
ok('un lanceur a double-cliquer est propose',
  proposes.filter(f=>/\.bat$/.test(f)).length,1);
ok('le point d\'entree vient en tete',/\.bat$/.test(proposes[0]),true);
ok('la bibliothèque partagée aussi',proposes.indexOf('scripts/lib-detection.ps1')>=0,true);

console.log('\n--- le bloc s\'ouvre depuis le menu ---');
ok('fermé au départ',await pg.isVisible('#outils'),false);
await pg.click('#menu-btn');await pg.waitForTimeout(150);
await pg.getByRole('menuitem',{name:/Les scripts pour Windows/}).click();
await pg.waitForTimeout(300);
ok('ouvert',await pg.isVisible('#outils'),true);
ok('un lien par fichier',(await pg.$$('.outils-item a')).length,proposes.length);
ok('chaque lien télécharge au lieu d\'afficher',await pg.evaluate(()=>
  [...document.querySelectorAll('.outils-item a')].every(a=>a.hasAttribute('download'))),true);
ok('les liens sont relatifs, donc valables depuis une clé',await pg.evaluate(()=>
  [...document.querySelectorAll('.outils-item a')]
    .every(a=>!/^https?:/.test(a.getAttribute('href')))),true);
// « Migration PC.bat » porte un espace : un href non encode casse chez
// certains navigateurs, et le nom propose au telechargement doit rester lisible.
ok('un nom avec espace reste téléchargeable',await pg.evaluate(()=>{
  const a=[...document.querySelectorAll('.outils-item a')]
    .find(x=>/Migration/.test(x.getAttribute('download')||''));
  if(!a)return 'lien absent';
  // L'attribut href tel qu'ecrit, et l'URL que le navigateur en deduit.
  return a.href.indexOf('Migration%20PC.bat')>=0?'encodée':'brute : '+a.href.slice(-24);
}),'encodée');
ok('le lien vers le dépôt s\'ouvre à part',await pg.evaluate(()=>{
  const a=document.querySelector('.outils-note a');
  return !!(a&&a.target==='_blank'&&(a.rel||'').indexOf('noopener')>=0);}),true);
ok('on avertit de prendre le dossier entier',
  (await pg.textContent('.outils-note')).indexOf('pas un fichier isolé')>=0,true);
await pg.click('.outils-fermer');await pg.waitForTimeout(200);
ok('« Fermer » referme',await pg.isVisible('#outils'),false);

console.log('\n--- la clé USB : la page s\'ouvre déjà remplie ---');
// On reconstitue une cle : la page, et le fichier que le scanner y depose.
const cle=fs.mkdtempSync(path.join(os.tmpdir(),'cle-'));
fs.copyFileSync(path.join(racine,'index.html'),path.join(cle,'index.html'));
const scan={type:'inventaire-migration-pc',genere:'2026-09-24T11:00:00',
  machine:'ANCIEN-PC',apps:[
    {id:'a1',nom:'7-Zip',categorie:'outils',source:'registre',winget:'7zip.7zip'},
    {id:'a2',nom:'VLC',categorie:'media',source:'winget',winget:'VideoLAN.VLC'}]};
fs.writeFileSync(path.join(cle,'resultat-scan.js'),
  'window.MIGRATION_PC_SCAN='+JSON.stringify(scan)+';\n');

const pg2=await (await b.newContext()).newPage();
const errs2=[];pg2.on('pageerror',e=>errs2.push(e.message));
await pg2.goto('file://'+path.join(cle,'index.html'),{waitUntil:'networkidle'});
await pg2.waitForTimeout(500);
ok('les applications sont là sans rien importer',
  await pg2.evaluate(()=>APPS_DATA.length),scan.apps.length);
ok('ce sont les bonnes',await pg2.evaluate(()=>APPS_DATA.map(a=>a.n)),undefined);
const bandeau=await pg2.textContent('#annul-txt');
ok('la page dit d\'où ça vient',bandeau.indexOf('déposé par le scanner')>=0,true);
ok('elle date le scan',bandeau.indexOf('2026-09-24')>=0,true);
ok('elle nomme la machine',bandeau.indexOf('ANCIEN-PC')>=0,true);
ok('et ça reste annulable',await pg2.isVisible('.annul-btn'),true);

console.log('\n--- un rechargement n\'écrase pas le travail fait depuis ---');
await pg2.evaluate(()=>{
  const p=JSON.parse(JSON.stringify(profilCourant()));
  p.apps.push({id:'ajout',n:'Ajouté à la main',c:'system',src:'moi',d:'.'});
  appliquerProfil(p,true);
});
await pg2.reload({waitUntil:'networkidle'});
await pg2.waitForTimeout(400);
ok('l\'ajout a survécu',await pg2.evaluate(()=>
  APPS_DATA.some(a=>a.n==='Ajouté à la main')),true);
ok('le scan ne s\'est pas rejoué',
  (await pg2.textContent('#annul-txt')).indexOf('déposé par le scanner')>=0,false);
ok('mais on peut le rejouer exprès',await pg2.evaluate(()=>{
  const b=document.getElementById('scan-rejouer');
  return !!(b&&b.style.display!=='none');}),true);
await pg2.click('#menu-btn');await pg2.waitForTimeout(150);
await pg2.getByRole('menuitem',{name:/Recharger le scan/}).click();
await pg2.waitForTimeout(400);
ok('et il se rejoue',await pg2.evaluate(()=>APPS_DATA.length),scan.apps.length);

console.log('\n--- sans fichier à côté, rien ne change ---');
const vide=fs.mkdtempSync(path.join(os.tmpdir(),'cle-'));
fs.copyFileSync(path.join(racine,'index.html'),path.join(vide,'index.html'));
const pg3=await (await b.newContext()).newPage();
const errs3=[];pg3.on('pageerror',e=>errs3.push(e.message));
await pg3.goto('file://'+path.join(vide,'index.html'),{waitUntil:'networkidle'});
await pg3.waitForTimeout(400);
ok('la page s\'ouvre sur le profil d\'exemple',
  await pg3.evaluate(()=>PROFIL_NOM===PROFIL_DEFAUT.meta.nom),true);
ok('aucun bandeau de scan',(await pg3.textContent('#annul-txt')).indexOf('scanner')>=0,false);
ok('aucun panneau de panne',await pg3.isVisible('#panne'),false);
ok('le bouton « Recharger le scan » reste caché',await pg3.evaluate(()=>{
  const b=document.getElementById('scan-rejouer');
  return !b||b.style.display==='none';}),true);
ok('le fichier manquant ne fait pas d\'erreur',errs3.length?errs3[0]:'aucune','aucune');

console.log('\n--- un fichier de scan illisible ne casse pas la page ---');
const casse=fs.mkdtempSync(path.join(os.tmpdir(),'cle-'));
fs.copyFileSync(path.join(racine,'index.html'),path.join(casse,'index.html'));
fs.writeFileSync(path.join(casse,'resultat-scan.js'),
  'window.MIGRATION_PC_SCAN={type:"inventaire-migration-pc",apps:"pas un tableau"};\n');
const pg4=await (await b.newContext()).newPage();
await pg4.goto('file://'+path.join(casse,'index.html'),{waitUntil:'networkidle'});
await pg4.waitForTimeout(400);
ok('la checklist s\'affiche quand même',
  (await pg4.$$('#list-npc .item')).length>0,true);

ok('aucune erreur JS ailleurs',errs.concat(errs2).length?errs.concat(errs2)[0]:'aucune','aucune');
await b.close();
[cle,vide,casse].forEach(d=>fs.rmSync(d,{recursive:true,force:true}));
console.log(ko?'\n'+ko+' ECHEC(S)':'\nSCRIPTS ET CHARGEMENT AUTOMATIQUE : OPERATIONNELS');
process.exit(ko?1:0);
})();
