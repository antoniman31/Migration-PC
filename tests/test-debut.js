// Les deux questions du premier lancement, et le cas qu'elles servent surtout
// a faire connaitre : garder l'ancienne machine. La checklist ne savait que
// transferer — elle faisait desautoriser Steam et delier les licences d'un PC
// qu'on rallume le lendemain.
//
//   node tests/test-debut.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;


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
const b=await chromium.launch(lancement);
const pg=await (await b.newContext({viewport:{width:1200,height:900}})).newPage();
const errs=[];pg.on('pageerror',e=>errs.push(e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};
const P=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const tous=[...P.quitter,...P.npc,...P.apps,...P.data,...P.pwa];
const vis=sc=>tous.filter(e=>!e.cas||e.cas.includes(sc)).length;

console.log('--- au premier lancement ---');
ok('le bandeau se propose',await pg.isVisible('#debut'),true);
// Le bandeau se pose au-dessus de la page, il ne la remplace pas : la
// checklist doit rester lisible et cliquable derriere.
ok('il ne barre pas la page',await pg.evaluate(()=>{
  const l=document.querySelector('.panel.active .item');
  if(!l)return false;
  const r=l.getBoundingClientRect();
  return r.width>0&&r.height>0;}),true);
ok('et les onglets restent atteignables',
  await pg.isVisible('#tab-apps'),true);
ok('le focus y entre',await pg.evaluate(()=>
  document.getElementById('debut').contains(document.activeElement)),true);
ok('première question',(await pg.textContent('.debut-q')).indexOf('installez')>=0,true);
ok('deux choix',(await pg.$$('.debut-choix button')).length,2);

console.log('\n--- « un PC neuf » puis « je le garde » ---');
await pg.click('.debut-choix button');await pg.waitForTimeout(250);
ok('seconde question',(await pg.textContent('.debut-q')).indexOf('ancien PC')>=0,true);
await pg.click('.debut-choix button:nth-child(2)');await pg.waitForTimeout(350);
ok('le bandeau se referme',await pg.isVisible('#debut'),false);
ok('le cas est réglé',await pg.evaluate(()=>scenario),'second');
ok('et on le dit',(await pg.textContent('#annul-txt')).indexOf('Second PC')>=0,true);

console.log('\n--- ce que « je garde l\'ancien » change ---');
const q=await pg.evaluate(()=>[...document.querySelectorAll('#list-quitter .item-name')]
  .map(x=>x.textContent));
ok('le total suit',await pg.textContent('#gp-total'),String(vis('second')));
ok('l\'onglet change de nom',await pg.evaluate(()=>
  document.getElementById('tab-quitter').textContent.indexOf("Sur l'ancien PC")>=0),true);
ok('son bandeau aussi',await pg.evaluate(()=>
  document.querySelector('#panel-quitter .tbar-info').textContent.indexOf('reste en service')>=0),true);
// Le coeur du sujet : ne pas saboter une machine encore en service.
ok('on ne désautorise plus Steam',q.some(n=>/Désautoriser Steam/.test(n)),false);
ok('ni iTunes',q.some(n=>/Désautoriser iTunes/.test(n)),false);
ok('on ne ferme plus les sessions',q.some(n=>/Se déconnecter des sessions/.test(n)),false);
ok('et on n\'efface pas le disque',q.some(n=>/Effacer le disque/.test(n)),false);
// Ce qui se retourne plutot que de disparaitre.
ok('les licences Adobe se comptent au lieu de se délier',
  q.some(n=>/combien de postes vos licences Adobe/.test(n)),true);
ok('l\'authentificateur s\'ajoute au lieu de se transférer',
  q.some(n=>/Ajouter la seconde machine/.test(n)),true);
ok('les deux clés BitLocker sont demandées',
  q.some(n=>/DEUX machines/.test(n)),true);
// Ce qui apparait, et qui n'existait nulle part.
const d=await pg.evaluate(()=>[...document.querySelectorAll('#list-data .item-name')]
  .map(x=>x.textContent));
['Décider quels dossiers','Mettre en place la synchronisation',
 'marche dans les deux sens','versions divergentes'].forEach(t=>
  ok('« '+t+' » apparaît',d.some(n=>n.indexOf(t)>=0),true));
ok('la répartition précède la synchronisation',
  d.findIndex(n=>/Décider quels dossiers/.test(n))<d.findIndex(n=>/Mettre en place la synchro/.test(n)),true);

console.log('\n--- et en migration, tout redevient comme avant ---');
await ouvrirSituation(pg);await pg.click('#sc-migration');await pg.waitForTimeout(300);
const qm=await pg.evaluate(()=>[...document.querySelectorAll('#list-quitter .item-name')]
  .map(x=>x.textContent));
ok('Steam se désautorise de nouveau',qm.some(n=>/Désautoriser Steam/.test(n)),true);
ok('Adobe se désactive de nouveau',qm.some(n=>/Désactiver les logiciels Adobe/.test(n)),true);
ok('le disque s\'efface',qm.some(n=>/Effacer le disque/.test(n)),true);
ok('la synchronisation disparaît',await pg.evaluate(()=>
  [...document.querySelectorAll('#list-data .item-name')]
    .some(x=>/synchronisation/i.test(x.textContent))),false);
ok('l\'onglet reprend son nom',await pg.evaluate(()=>
  document.getElementById('tab-quitter').textContent.indexOf('Avant de quitter')>=0),true);
ok('et le total est celui de la migration',await pg.textContent('#gp-total'),String(vis('migration')));

console.log('\n--- on ne redemande pas ---');
await pg.reload({waitUntil:'networkidle'});
ok('le bandeau ne revient pas',await pg.isVisible('#debut'),false);
ok('le cas choisi a tenu',await pg.evaluate(()=>scenario),'migration');
await pg.click('#menu-btn');await pg.waitForTimeout(150);
await pg.getByRole('menuitem',{name:/Adapter à mon cas/}).click();await pg.waitForTimeout(300);
ok('mais le menu sait le relancer',await pg.isVisible('#debut'),true);
await pg.click('.debut-passer');await pg.waitForTimeout(200);
ok('« Passer » referme sans rien changer',
  (await pg.isVisible('#debut'))===false&&await pg.evaluate(()=>scenario)==='migration',true);

console.log('\n--- une page déjà entamée ne se fait pas interroger ---');
await pg.evaluate(()=>{
  try{localStorage.removeItem('mpc_debut_v1');}catch(e){}
  const id=tousLesItems()[0].id;toggle(id,'x');
});
await pg.reload({waitUntil:'networkidle'});
ok('le bandeau reste discret',await pg.isVisible('#debut'),false);
ok('aucune erreur JS',errs.length?errs[0]:'aucune','aucune');

await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nDEUX QUESTIONS ET SECOND PC : OPERATIONNELS');
process.exit(ko?1:0);
})();
