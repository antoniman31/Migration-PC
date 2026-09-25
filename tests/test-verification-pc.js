// Import d'une verification produite par verifier-pc.ps1 : le script propose,
// la page montre la liste avec la raison de chaque rapprochement, et rien
// n'est coche sans validation. Un rapprochement par nom peut confondre deux
// logiciels voisins, et une case cochee a tort fait sauter une installation.
//
//   node tests/test-verification-pc.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
const HTML='file://'+path.join(__dirname,'..','index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

// Le profil livré ne contient aucune application : celles d'une autre machine
// feraient croire à l'arrivant que c'est sa liste. Les suites qui exercent
// l'onglet Apps chargent donc la démonstration, comme le ferait quelqu'un qui
// clique « Voir un exemple garni ».
async function chargerExemple(pg){
  await pg.evaluate(()=>{chargerDemo();});
  await pg.waitForTimeout(250);
}

(async()=>{
const b=await chromium.launch(lancement);
const pg=await (await b.newContext({viewport:{width:1200,height:900},deviceScaleFactor:2})).newPage();
pg.on('pageerror',e=>console.log('ERREUR JS:',e.message));
const dialogues=[];pg.on('dialog',d=>{dialogues.push(d.type());d.accept();});
await pg.goto(HTML,{waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};
const fichier=fs.readFileSync(path.join(__dirname,'verification-exemple.json'));

// La vérification rapproche ce qui est installé sur la machine neuve des
// éléments du profil chargé. Sans applications dans le profil, il n'y a rien
// à rapprocher : on charge la démonstration, comme quelqu'un qui aurait
// d'abord scanné son ancien PC.
await chargerExemple(pg);

console.log('--- import : rien n\'est coché sans validation ---');
await pg.setInputFiles('#json-file',{name:'v.json',mimeType:'application/json',buffer:fichier});
await pg.waitForTimeout(400);
ok('aucune alerte bloquante',dialogues.length,0);
ok('panneau affiché',await pg.isVisible('#verif'),true);
ok('rien n\'est coché pour l\'instant',await pg.evaluate(()=>Object.keys(S.checked).length),0);

const l=await pg.evaluate(()=>({
  lignes:document.querySelectorAll('.verif-ligne').length,
  cochees:[...document.querySelectorAll('#verif input')].filter(c=>c.checked).length,
  tete:document.querySelector('.verif-tete').textContent.trim(),
  sures:document.querySelectorAll('.verif-sure').length,
  approx:document.querySelectorAll('.verif-approx').length}));
console.log('   ',JSON.stringify(l));
ok('l\'élément absent du profil est écarté',l.lignes,3);
ok('tout est pré-sélectionné',l.cochees,3);
ok('2 correspondances sûres',l.sures,2);
ok('1 approximative signalée',l.approx,1);

console.log('\n--- on décoche ce qu\'on ne veut pas ---');
await pg.evaluate(()=>{
  const c=[...document.querySelectorAll('#verif input')].find(x=>x.getAttribute('aria-label').indexOf('Steam')>=0);
  c.checked=false;});
await pg.click('.verif-ok');
await pg.waitForTimeout(300);
ok('2 cases cochées, pas 3',await pg.evaluate(()=>Object.keys(S.checked).length),2);
ok('Steam non coché',await pg.evaluate(()=>!S.checked.a13),true);
ok('7-Zip coché',await pg.evaluate(()=>!!S.checked.a1),true);
ok('panneau refermé',await pg.isVisible('#verif'),false);
ok('annulation proposée',await pg.isVisible('.annul-btn'),true);

console.log('\n--- annulation ---');
await pg.click('.annul-btn');
await pg.waitForTimeout(300);
ok('les cases repartent',await pg.evaluate(()=>Object.keys(S.checked).length),0);

console.log('\n--- boutons tout sélectionner / désélectionner ---');
await pg.setInputFiles('#json-file',{name:'v.json',mimeType:'application/json',buffer:fichier});
await pg.waitForTimeout(350);
await pg.click('.verif-actions button:nth-child(3)');
ok('tout désélectionné',await pg.evaluate(()=>[...document.querySelectorAll('#verif input')].filter(c=>c.checked).length),0);
await pg.click('.verif-ok');
await pg.waitForTimeout(250);
ok('rien coché, message informatif',await pg.evaluate(()=>Object.keys(S.checked).length),0);
ok('bandeau sans bouton Annuler',await pg.isVisible('.annul-btn'),false);

console.log('\n--- deuxième passage : ce qui est déjà coché n\'est pas reproposé ---');
await pg.evaluate(()=>{S.checked={a1:true,a3:true};saveState();renderAll();updateGlobal();});
await pg.setInputFiles('#json-file',{name:'v.json',mimeType:'application/json',buffer:fichier});
await pg.waitForTimeout(350);
const reste=await pg.evaluate(()=>document.querySelectorAll('.verif-ligne').length);
ok('seul Steam reste à proposer',reste,1);

console.log('\n--- tout est déjà coché ---');
await pg.evaluate(()=>{S.checked={a1:true,a3:true,a13:true};saveState();renderAll();updateGlobal();});
await pg.setInputFiles('#json-file',{name:'v.json',mimeType:'application/json',buffer:fichier});
await pg.waitForTimeout(350);
ok('pas de panneau vide',await pg.isVisible('#verif'),false);
ok('un message explique',await pg.isVisible('#annul'),true);
console.log('   ',await pg.textContent('#annul-txt'));

await b.close();
console.log(ko?'\n'+ko+' EN ECHEC':'\nVERIFICATION DU PC OPERATIONNELLE');
process.exit(ko?1:0);
})();
