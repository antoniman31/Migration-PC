// Les deux situations : migrer vers une autre machine, ou reinstaller celle
// qu'on a. Verifie que le filtre s'applique partout ou l'on compte ou l'on
// affiche — totaux, onglets, recherche, mode guide — et qu'une case cochee
// survit au changement de mode sans compter dans l'autre.
//
//   node tests/test-scenarios.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;
(async()=>{
const b=await chromium.launch(lancement);
const pg=await (await b.newContext({viewport:{width:1200,height:900},deviceScaleFactor:2})).newPage();
pg.on('pageerror',e=>console.log('ERREUR JS:',e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};
const P=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const tous=[...P.quitter,...P.npc,...P.apps,...P.data,...P.pwa];
const vis=sc=>tous.filter(e=>!e.cas||e.cas.includes(sc)).length;

console.log('--- au départ : tout ---');
ok('sélecteur présent',await pg.isVisible('.scen'),true);
ok('« Tout » actif',await pg.getAttribute('#sc-tout','aria-pressed'),'true');
ok('total complet',await pg.textContent('#gp-total'),String(tous.length));

console.log('\n--- migration ---');
await pg.click('#sc-migration');await pg.waitForTimeout(300);
ok('bouton actif',await pg.getAttribute('#sc-migration','aria-pressed'),'true');
ok('total filtré',await pg.textContent('#gp-total'),String(vis('migration')));
const npcM=(await pg.$$('#list-npc .item')).length;
console.log('   note :',await pg.textContent('#scenario-note'));
const txtM=await pg.textContent('#list-npc');
ok('le point de non-retour est masqué',txtM.indexOf('NON-RETOUR')<0,true);
ok('le sens des ventilateurs est là',txtM.indexOf('sens des ventilateurs')>=0,true);
ok('libellé « Activer TPM »',txtM.indexOf('Activer TPM 2.0')>=0,true);

console.log('\n--- réinstallation ---');
await pg.click('#sc-reinstall');await pg.waitForTimeout(300);
ok('total filtré',await pg.textContent('#gp-total'),String(vis('reinstall')));
const txtR=await pg.textContent('#list-npc');
ok('point de non-retour visible',txtR.indexOf('NON-RETOUR')>=0,true);
ok('étape pilotes sur clé visible',txtR.indexOf('Télécharger les pilotes')>=0,true);
ok('sens des ventilateurs masqué',txtR.indexOf('sens des ventilateurs')<0,true);
ok('libellé devenu « Vérifier que TPM »',txtR.indexOf('Vérifier que TPM 2.0')>=0,true);
ok('« Activer TPM » disparu',txtR.indexOf('Activer TPM 2.0')<0,true);
const q=await pg.evaluate(()=>{switchTab('quitter');return document.getElementById('list-quitter').textContent;});
await pg.waitForTimeout(200);
ok('effacement sécurisé masqué',q.indexOf('Effacer le disque')<0,true);
ok('désactivation Adobe conservée',q.indexOf('Adobe')>=0,true);

console.log('\n--- la progression survit au changement de mode ---');
await pg.click('#sc-tout');await pg.waitForTimeout(250);
await pg.evaluate(()=>{switchTab('npc');});
await pg.waitForTimeout(200);
await pg.evaluate(()=>{const e=NPC_DATA.find(x=>x.cas&&x.cas[0]==='migration');S.checked[e.id]=true;saveState();renderAll();updateGlobal();});
const avant=await pg.evaluate(()=>Object.keys(S.checked).length);
await pg.click('#sc-reinstall');await pg.waitForTimeout(250);
ok('la case cochée reste en mémoire',await pg.evaluate(()=>Object.keys(S.checked).length),avant);
ok('mais ne compte plus',await pg.textContent('#gp-done'),'0');
await pg.click('#sc-migration');await pg.waitForTimeout(250);
ok('elle recompte au retour',await pg.textContent('#gp-done'),'1');

console.log('\n--- mémorisation, recherche, guide ---');
await pg.reload({waitUntil:'networkidle'});
ok('mode retenu après rechargement',await pg.getAttribute('#sc-migration','aria-pressed'),'true');
await pg.fill('#gsearch-input','non-retour');
await pg.waitForTimeout(300);
ok('la recherche respecte le filtre',(await pg.textContent('#gsearch-results')).indexOf('NON-RETOUR')<0,true);
await pg.fill('#gsearch-input','');
await pg.click('#sc-reinstall');await pg.waitForTimeout(250);
await pg.fill('#gsearch-input','non-retour');await pg.waitForTimeout(300);
ok('et le trouve dans l\'autre mode',(await pg.textContent('#gsearch-results')).indexOf('NON-RETOUR')>=0,true);
await pg.fill('#gsearch-input','');
await pg.click('#guide-btn');await pg.waitForTimeout(300);
const g=await pg.evaluate(()=>document.querySelector('.guide-etape').textContent);
ok('le guide compte comme le filtre',g,'Tâche 1 sur '+vis('reinstall'));
await pg.click('#guide-btn');await pg.waitForTimeout(200);

console.log('\n--- un prerequis masque par le filtre ---');
// Un element peut dependre d'un autre que le scenario courant ne montre pas.
// Le badge « ↳ » nommerait alors une tache introuvable dans la liste.
const sonde=await pg.evaluate(()=>{
  // On fabrique le cas plutot que d'esperer qu'il existe dans l'exemple.
  const base=NPC_DATA[0];
  const cache={id:'zz-cache',o:998,n:'Étape réservée au montage neuf',
    src:'Test',p:'low',t:5,d:'Test.',cas:['migration']};
  const suiv={id:'zz-suite',o:999,n:'Étape qui en dépend',
    src:'Test',p:'low',t:5,d:'Test.',dep:['zz-cache',base.id]};
  NPC_DATA.push(cache,suiv);viderIndex();renderAll();updateGlobal();
  // Pas de data-id sur les lignes : on retrouve la nôtre par son intitulé.
  const ligne=()=>[...document.querySelectorAll('#list-npc .item')]
    .find(x=>x.textContent.indexOf('Étape qui en dépend')>=0);
  const lire=()=>{
    const l=ligne();const b=l&&l.querySelector('.b-dep');
    return b?b.textContent:null;
  };
  changerScenario('migration');const enMigration=lire();
  changerScenario('reinstall');const enReinstall=lire();
  // L'intitulé seulement : le badge de la ligne suivante contient le même
  // texte, et c'est précisément ce qu'on cherche à distinguer.
  const visible=[...document.querySelectorAll('#list-npc .item-name')]
    .some(x=>x.textContent.indexOf('montage neuf')>=0);
  NPC_DATA.splice(NPC_DATA.length-2,2);viderIndex();
  changerScenario('tout');renderAll();updateGlobal();
  return {enMigration:enMigration,enReinstall:enReinstall,visible:visible,
    nomBase:base.n};
});
ok('en migration le badge cite les deux prérequis',
  sonde.enMigration&&sonde.enMigration.indexOf('montage neuf')>=0,true);
ok('l\'étape masquée l\'est bien en réinstallation',sonde.visible,false);
ok('et le badge ne la cite plus',
  sonde.enReinstall&&sonde.enReinstall.indexOf('montage neuf')>=0,false);
ok('mais garde le prérequis encore visible',
  !!sonde.enReinstall,true);

await b.close();
console.log(ko?'\n'+ko+' EN ECHEC':'\nSCENARIOS OPERATIONNELS');
process.exit(ko?1:0);
})();
