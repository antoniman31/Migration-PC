// L'onglet « Avant de quitter » : son contenu, sa place dans les totaux, la
// recherche et le mode guide, et la retrocompatibilite — un profil qui ne
// declare pas cette section doit rester valide et afficher quatre onglets.
//
//   node tests/test-quitter.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const PROFIL=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;
(async()=>{
const b=await chromium.launch(lancement);
const pg=await (await b.newContext({viewport:{width:1200,height:900},deviceScaleFactor:2})).newPage();
pg.on('pageerror',e=>console.log('ERREUR JS:',e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};

console.log('--- le 5e onglet existe et s\'ouvre en premier ---');
ok('onglet présent',await pg.isVisible('#tab-quitter'),true);
ok('actif au chargement',await pg.getAttribute('#tab-quitter','aria-selected'),'true');
ok('panneau visible',await pg.isVisible('#panel-quitter'),true);
ok('tous les éléments rendus',(await pg.$$('#list-quitter .item')).length,PROFIL.quitter.length);
ok('groupes de priorité',(await pg.$$('#panel-quitter .sec-hdr')).length,3);
const t=await pg.textContent('#panel-quitter .sec-hdr');
console.log('   premier groupe :',t.trim().slice(0,45));
ok('libellé propre à cet onglet',t.indexOf('Irréversible')>=0,true);

console.log('\n--- totaux ---');
ok('badge onglet',await pg.textContent('#badge-quitter'),'0/'+PROFIL.quitter.length);
const total=await pg.evaluate(()=>tousLesItems().length);
ok('total global inclut la section',await pg.textContent('#gp-total'),String(total));
ok('cinq onglets',(await pg.$$('.tabs .tab')).length,5);

console.log('\n--- cocher, tout cocher, réinitialiser ---');
await pg.click('#list-quitter .item');
await pg.waitForTimeout(200);
ok('case cochée',await pg.evaluate(()=>Object.keys(S.checked).length),1);
ok('badge à jour',await pg.textContent('#badge-quitter'),'1/'+PROFIL.quitter.length);
await pg.click('#panel-quitter .chk-all');
await pg.waitForTimeout(250);
ok('groupe entier coché',await pg.evaluate(()=>QUITTER_DATA.filter(e=>e.pr==='high'&&S.checked[e.id]).length),PROFIL.quitter.filter(e=>e.pr==='high').length);
ok('les autres onglets intacts',await pg.evaluate(()=>DATA_SAVES.filter(e=>S.checked[e.id]).length),0);
await pg.evaluate(()=>resetSection('quitter'));
await pg.waitForTimeout(250);
ok('réinitialisation',await pg.evaluate(()=>Object.keys(S.checked).length),0);
ok('annulation proposée',await pg.isVisible('.annul-btn'),true);
await pg.click('.annul-btn');await pg.waitForTimeout(250);
ok('annulation restaure',await pg.evaluate(()=>Object.keys(S.checked).length)>0,true);

console.log('\n--- recherche globale et mode guidé ---');
await pg.evaluate(()=>{S.checked={};saveState();renderAll();updateGlobal();});
await pg.fill('#gsearch-input','Adobe');
await pg.waitForTimeout(300);
ok('trouvé par la recherche',(await pg.textContent('#gsearch-results')).indexOf('Adobe')>=0,true);
ok('section nommée',(await pg.textContent('#gsearch-results')).indexOf('Avant de quitter')>=0,true);
await pg.fill('#gsearch-input','');
await pg.click('#guide-btn');await pg.waitForTimeout(250);
const g=await pg.evaluate(()=>({onglet:document.querySelector('.guide-onglet').textContent,
  titre:document.querySelector('.guide-titre').textContent}));
console.log('   première tâche guidée :',JSON.stringify(g));
ok('le guide commence par l\'ancien PC',g.onglet,'Avant de quitter');
await pg.click('#guide-btn');await pg.waitForTimeout(200);

console.log('\n--- un profil sans la section reste valide ---');
await pg.evaluate(()=>{
  const p=JSON.parse(JSON.stringify(PROFIL_DEFAUT));delete p.quitter;
  appliquerProfil(p,false);});
await pg.waitForTimeout(250);
ok('aucune erreur, onglet vide',(await pg.$$('#list-quitter .item')).length,0);
ok('badge à zéro',await pg.textContent('#badge-quitter'),'0/0');
ok('les autres onglets marchent',(await pg.$$('#list-npc .item')).length,PROFIL.npc.length);

await pg.evaluate(()=>appliquerProfil(PROFIL_DEFAUT,false));
await pg.waitForTimeout(250);
await b.close();
console.log(ko?'\n'+ko+' EN ECHEC':'\nONGLET AVANT DE QUITTER OPERATIONNEL');
process.exit(ko?1:0);
})();
