// Le stockage du navigateur peut refuser d'ecrire : quota plein, navigation
// privee, site bloque. saveState() avalait l'erreur dans un console.error, donc
// on continuait a cocher en croyant que c'etait garde, et tout partait au
// rechargement. updateSaveLabel() existait deja pour le dire — vide depuis le
// premier commit.
//
//   node tests/test-sauvegarde.js
const {chromium}=require('playwright');
const path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

(async()=>{
const b=await chromium.launch(lancement);
const pg=await (await b.newContext()).newPage();
const errs=[];pg.on('pageerror',e=>errs.push(e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};

console.log('--- quand tout va bien ---');
const bon=await pg.evaluate(()=>{
  const id=tousLesItems()[0].id;
  toggle(id,'test');
  // Un indicateur absent est un resultat, pas une raison de planter : c'est
  // exactement l'etat d'avant, ou updateSaveLabel() etait une fonction vide.
  const el=document.getElementById('save-state');
  const relu=JSON.parse(localStorage.getItem(CLE_ETAT));
  return {texte:el?el.textContent:'(pas d\'indicateur)',classe:el?el.className:'(absent)',
    surDisque:!!relu.checked[id],
    panne:document.getElementById('panne').classList.contains('visible')};
});
ok('la progression est écrite',bon.surDisque,true);
ok('l\'indicateur dit que c\'est enregistré',/^✓ enregistré \d\d:\d\d$/.test(bon.texte),true);
ok('sans alarme',bon.classe,'save-state');
ok('et aucun panneau de panne',bon.panne,false);

console.log('\n--- quand le navigateur refuse d\'écrire ---');
const mauvais=await pg.evaluate(()=>{
  // On sature vraiment le stockage plutot que de simuler l'echec : c'est le
  // chemin que prend un vrai navigateur.
  const vrai=localStorage.setItem.bind(localStorage);
  localStorage.setItem=function(k,v){
    if(k===CLE_ETAT){const e=new Error('quota');e.name='QuotaExceededError';throw e;}
    return vrai(k,v);
  };
  const id=tousLesItems()[1].id;
  toggle(id,'test2');
  const el=document.getElementById('save-state');
  const bloc=document.getElementById('panne');
  return {texte:el?el.textContent:'(pas d\'indicateur)',classe:el?el.className:'(absent)',
    coche:!!S.checked[id],
    panne:bloc.classList.contains('visible'),
    message:document.getElementById('panne-detail').textContent};
});
ok('la case reste cochée à l\'écran',mauvais.coche,true);
ok('mais l\'indicateur ne ment pas',mauvais.texte,'⚠ non enregistré');
ok('et se signale',mauvais.classe,'save-state save-ko');
ok('un panneau explique ce qui se passe',mauvais.panne,true);
ok('il dit que le travail sera perdu',
  mauvais.message.indexOf('perdu au rechargement')>=0,true);
ok('et vers quoi se rabattre',
  mauvais.message.indexOf('Sauvegarder')>=0,true);

console.log('\n--- on ne repete pas l\'alarme a chaque case ---');
const repete=await pg.evaluate(()=>{
  masquerPanne();
  const ids=tousLesItems().slice(2,6).map(e=>e.id);
  ids.forEach(i=>toggle(i,'x'));
  return document.getElementById('panne').classList.contains('visible');
});
ok('le panneau ne revient pas en boucle',repete,false);
ok('l\'indicateur, lui, reste alarmé',
  await pg.evaluate(()=>{const e=document.getElementById('save-state');
    return e?e.textContent:'(pas d\'indicateur)';}),'⚠ non enregistré');

console.log('\n--- quand ça remarche ---');
const retour=await pg.evaluate(()=>{
  delete localStorage.setItem;
  const id=tousLesItems()[6].id;
  toggle(id,'x');
  const el=document.getElementById('save-state');
  return {texte:el?el.textContent:'(pas d\'indicateur)',
    bandeau:document.getElementById('annul-txt').textContent,
    surDisque:!!JSON.parse(localStorage.getItem(CLE_ETAT)).checked[id]};
});
ok('la progression repart sur le disque',retour.surDisque,true);
ok('l\'indicateur redevient serein',/^✓ enregistré/.test(retour.texte),true);
ok('et on le dit',retour.bandeau.indexOf('Sauvegarde rétablie')>=0,true);

console.log('\n--- l\'indicateur ne s\'affiche pas avant la première écriture ---');
await pg.evaluate(()=>{try{localStorage.clear();}catch(e){}});
await pg.reload({waitUntil:'networkidle'});
ok('rien au chargement d\'une page vierge',
  await pg.evaluate(()=>{const e=document.getElementById('save-state');
    return e?e.textContent:'(pas d\'indicateur)';}),'');
ok('la page est saine',await pg.isVisible('#panne'),false);
ok('aucune erreur JS',errs.length?errs[0]:'aucune','aucune');

await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nSAUVEGARDE HONNETE');
process.exit(ko?1:0);
})();
