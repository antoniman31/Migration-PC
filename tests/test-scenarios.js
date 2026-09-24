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

console.log('\n--- les libelles alternatifs, sur les cinq onglets ---');
// Le profil d'exemple ne pose des « alt » que sur « Nouveau PC ». Le rendu des
// quatre autres onglets a donc pu ignorer libelleDe() sans qu'aucun test ne le
// voie. On en pose un par onglet et on verifie qu'il s'affiche vraiment.
const parOnglet=await pg.evaluate(()=>{
  const cibles={quitter:QUITTER_DATA,npc:NPC_DATA,apps:APPS_DATA,
    data:DATA_SAVES,pwa:PWA_DATA};
  const avant={},resultat={};
  Object.keys(cibles).forEach(k=>{
    const e=cibles[k][0];
    avant[k]={id:e.id,alt:e.alt};
    e.alt={n:'LIBELLE-'+k.toUpperCase(),d:'DESCRIPTION-'+k.toUpperCase()};
  });
  viderIndex();
  changerScenario('reinstall');
  Object.keys(cibles).forEach(k=>{
    const l=document.getElementById('list-'+k);
    const t=l?l.textContent:'';
    resultat[k]={nom:t.indexOf('LIBELLE-'+k.toUpperCase())>=0,
      // Seuls npc, apps et pwa affichent une description dans la liste.
      desc:t.indexOf('DESCRIPTION-'+k.toUpperCase())>=0};
  });
  // Le libelle memorise dans l'historique doit suivre lui aussi. On clique la
  // ligne pour de vrai : c'est l'attribut onclick qu'on veut verifier, pas un
  // appel a toggle() qu'on aurait ecrit correctement nous-memes.
  const q=cibles.quitter[0];
  const ligneQ=[...document.querySelectorAll('#list-quitter .item')]
    .find(x=>x.textContent.indexOf('LIBELLE-QUITTER')>=0);
  if(ligneQ)ligneQ.click();
  resultat.historique=journal.length>0&&journal[0].name==='LIBELLE-QUITTER';
  if(ligneQ){
    const encore=[...document.querySelectorAll('#list-quitter .item')]
      .find(x=>x.textContent.indexOf('LIBELLE-QUITTER')>=0);
    if(encore)encore.click();
  }
  journal.length=0;
  // Et le mode guide.
  basculerGuide();
  const g=document.getElementById('guide').textContent;
  resultat.guide=/LIBELLE-(QUITTER|NPC|APPS|DATA|PWA)/.test(g);
  basculerGuide();
  Object.keys(cibles).forEach(k=>{
    const e=cibles[k][0];
    if(avant[k].alt)e.alt=avant[k].alt;else delete e.alt;
  });
  viderIndex();changerScenario('tout');renderAll();updateGlobal();
  return resultat;
});
['quitter','npc','apps','data','pwa'].forEach(k=>
  ok('l\'intitulé alternatif s\'affiche dans « '+k+' »',parOnglet[k].nom,true));
['npc','apps','pwa'].forEach(k=>
  ok('la description alternative aussi dans « '+k+' »',parOnglet[k].desc,true));
ok('l\'historique retient l\'intitulé affiché',parOnglet.historique,true);
ok('le mode guidé aussi',parOnglet.guide,true);

console.log('\n--- « Tout cocher » ne deborde pas du filtre ---');
const groupe=await pg.evaluate(()=>{
  const cache={id:'zz-hors',pr:'high',n:'Hors scénario',p:'C:\\zz',
    d:'Test.',cas:['migration']};
  QUITTER_DATA.push(cache);viderIndex();
  changerScenario('reinstall');
  const btn=[...document.querySelectorAll('#list-quitter .chk-all')][0];
  if(btn)btn.click();
  const coche=!!S.checked['zz-hors'];
  // Le compteur affiche doit coller a ce qui est reellement dans le groupe.
  const ent=document.querySelector('#list-quitter .sec-hdr-cnt');
  const paire=ent?ent.textContent.split('/'):['0','0'];
  const lignes=[...document.querySelectorAll('#list-quitter .item')].length;
  const visibles=visiblesDe('quitter').length;
  // On repart propre.
  S.checked={};S.dates={};
  QUITTER_DATA.splice(QUITTER_DATA.indexOf(cache),1);viderIndex();
  changerScenario('tout');saveState();renderAll();updateGlobal();
  return {coche:coche,denominateurCredible:Number(paire[1])<=visibles,
    lignes:lignes,visibles:visibles};
});
ok('l\'élément masqué n\'est pas coché',groupe.coche,false);
ok('le compteur du groupe ne compte pas les masqués',groupe.denominateurCredible,true);
ok('autant de lignes que d\'éléments visibles',groupe.lignes,groupe.visibles);

console.log('\n--- les compteurs PWA ---');
const pwa=await pg.evaluate(()=>{
  const cache={id:'zz-pwa',n:'PWA hors scénario',u:'https://exemple.test',
    d:'Test.',cas:['migration']};
  PWA_DATA.push(cache);viderIndex();changerScenario('reinstall');
  const ent=document.querySelector('#list-pwa .sec-hdr-cnt').textContent;
  const btn=document.querySelector('#list-pwa .chk-all');
  btn.click();
  const coche=!!S.checked['zz-pwa'];
  S.checked={};S.dates={};
  PWA_DATA.splice(PWA_DATA.indexOf(cache),1);viderIndex();
  changerScenario('tout');saveState();renderAll();updateGlobal();
  return {entete:ent,coche:coche,attendu:String(visiblesDe('pwa').length)};
});
ok('le dénominateur suit le filtre',pwa.entete.split('/')[1],pwa.attendu);
ok('« Tout cocher » ne touche pas la PWA masquée',pwa.coche,false);

console.log('\n--- le troisieme cas : juste mes affaires ---');
// Celui-ci marche a l'envers des deux autres : il part de rien et ne garde que
// ce qu'il reclame. Sans cette inversion, les reglages BIOS — qui ne portent
// aucune mention — s'y retrouveraient aussi.
await pg.click('#sc-affaires');await pg.waitForTimeout(350);
const pilotes=P.npc.filter(e=>e.pilote).length;
const attendu=pilotes+P.apps.length+P.data.length+P.pwa.length;
ok('bouton actif',await pg.getAttribute('#sc-affaires','aria-pressed'),'true');
ok('le total ne compte que les affaires',await pg.textContent('#gp-total'),String(attendu));
ok('le profil declare bien des pilotes',pilotes>0,true);
const npcVus=await pg.evaluate(()=>
  [...document.querySelectorAll('#list-npc .item-name')].map(x=>x.textContent));
ok('l\'onglet Nouveau PC ne garde que les pilotes',npcVus.length,pilotes);
ok('et ce sont bien eux',npcVus.every(n=>/ilote/.test(n)),true);
ok('aucun reglage BIOS',npcVus.some(n=>/BIOS|Secure Boot|CSM|XMP|EXPO/.test(n)),false);
ok('ni l\'installation de Windows',npcVus.some(n=>/Installer Windows|NON-RETOUR/.test(n)),false);
ok('les applications sont toutes la',
  (await pg.$$('#list-apps .item')).length,P.apps.length);
ok('les donnees aussi',(await pg.$$('#list-data .item')).length,P.data.length);
ok('les PWA aussi',(await pg.$$('#list-pwa .item')).length,P.pwa.length);

console.log('\n--- un onglet vide dit pourquoi ---');
const vide=await pg.textContent('#list-quitter');
ok('« Avant de quitter » n\'est pas muet',vide.trim().length>0,true);
ok('il nomme le cas en cours',vide.indexOf('Mes affaires')>=0,true);
ok('et dit combien d\'elements existent ailleurs',
  vide.indexOf(String(P.quitter.length)+' élément')>=0,true);
ok('le mode guidé compte comme le filtre',await pg.evaluate(()=>{
  basculerGuide();
  const t=document.querySelector('.guide-etape').textContent;
  basculerGuide();return t;}),'Tâche 1 sur '+attendu);

console.log('\n--- les trois autres cas n\'ont pas bouge ---');
for(const [cle,att] of [['tout',tous.length],['migration',vis('migration')],
                        ['reinstall',vis('reinstall')]]){
  await pg.click('#sc-'+cle);await pg.waitForTimeout(250);
  ok('« '+cle+' » compte toujours pareil',await pg.textContent('#gp-total'),String(att));
}
await pg.click('#sc-tout');await pg.waitForTimeout(250);

await b.close();
console.log(ko?'\n'+ko+' EN ECHEC':'\nSCENARIOS OPERATIONNELS');
process.exit(ko?1:0);
})();
