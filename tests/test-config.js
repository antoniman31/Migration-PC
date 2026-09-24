// Le bloc « Ma configuration » et l'affichage sur grand ecran.
//
// « Pilote chipset de la carte mere » ne disait pas quelle carte mere, et le
// bouton Rechercher cherchait ces mots-la. Ce que ce bloc ne fait PAS,
// volontairement : deviner quel pilote va avec quel modele. Il faudrait une
// table que personne ne tient a jour, et on servirait des liens faux qui ont
// l'air vrais.
//
//   node tests/test-config.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

(async()=>{
const b=await chromium.launch(lancement);
const ctx=await b.newContext({viewport:{width:1400,height:900}});
const pg=await ctx.newPage();
const errs=[];pg.on('pageerror',e=>errs.push(e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
await pg.evaluate(()=>{try{localStorage.setItem('mpc_debut_v1','1');}catch(e){}});
await pg.reload({waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};
const P=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const nomsNpc=()=>pg.evaluate(()=>[...document.querySelectorAll('#list-npc .item-name')].map(x=>x.textContent));
const ouvrirConfig=async()=>{
  if(await pg.isVisible('#config'))return;
  await pg.click('#menu-btn');await pg.waitForTimeout(120);
  await pg.getByRole('menuitem',{name:/Ma configuration/}).click();
  await pg.waitForTimeout(250);
};
const lienDe=motif=>pg.evaluate(m=>{
  const l=[...document.querySelectorAll('#list-npc .item')].find(i=>new RegExp(m).test(i.textContent));
  const a=l&&l.querySelector('a.lnk-btn');
  return a?decodeURIComponent(a.getAttribute('href')):null;},motif);

console.log('--- sans configuration ---');
ok('aucun intitulé ne porte de modèle',(await nomsNpc()).some(n=>/ — [A-Z]/.test(n)),false);
ok('le bloc est fermé',await pg.isVisible('#config'),false);
const avant=await lienDe('chipset');
ok('la recherche est générique',avant.indexOf('download')>=0,true);

console.log('\n--- on le remplit ---');
await ouvrirConfig();
ok('le bloc s\'ouvre',await pg.isVisible('#config'),true);
ok('un champ par composant',(await pg.$$('.config-input')).length,5);
ok('le focus y entre',await pg.evaluate(()=>
  document.getElementById('config').contains(document.activeElement)),true);
await pg.fill('#cfg-cm','ASUS ROG STRIX B850-A');
await pg.fill('#cfg-gpu','NVIDIA RTX 5070 Ti');
await pg.waitForTimeout(400);
ok('le résumé compte',await pg.textContent('#config-resume'),'2 composants sur 5');

console.log('\n--- ce que ça change ---');
const apres=await nomsNpc();
ok('le pilote chipset porte la carte mère',
  apres.some(n=>/^Pilote chipset.*ASUS ROG STRIX B850-A$/.test(n)),true);
ok('le pilote graphique porte la carte graphique',
  apres.some(n=>/^Pilote de carte graphique.*RTX 5070 Ti$/.test(n)),true);
// Le modele n'a rien a faire la ou l'on ne cherche rien.
ok('mais pas « Désactiver le CSM »',apres.some(n=>/CSM.*B850-A/.test(n)),false);
ok('ni « Installer Windows »',apres.some(n=>/Installer Windows.*B850-A/.test(n)),false);
ok('ni un composant non renseigné',apres.some(n=>/Benchmark du SSD —/.test(n)),false);
const lien=await lienDe('chipset');
ok('la recherche vise le constructeur',lien.indexOf('ASUS ROG STRIX B850-A support pilotes')>=0,true);
ok('et pas la phrase entière',lien.indexOf('Pilote chipset de la carte')<0,true);
ok('une étape sans composant garde sa recherche',
  (await lienDe('Windows Update')).indexOf('download')>=0,true);

console.log('\n--- ça tient, et ça s\'efface ---');
await pg.reload({waitUntil:'networkidle'});
ok('la configuration survit au rechargement',
  (await nomsNpc()).some(n=>/B850-A/.test(n)),true);
// Le bloc se referme au rechargement : c'est voulu, on le rouvre.
ok('il ne se rouvre pas tout seul',await pg.isVisible('#config'),false);
await ouvrirConfig();
ok('les champs sont repeuplés',await pg.inputValue('#cfg-cm'),'ASUS ROG STRIX B850-A');
await pg.click('.config-vider');await pg.waitForTimeout(350);
ok('« Tout effacer » vide les champs',await pg.inputValue('#cfg-cm'),'');
ok('et les intitulés redeviennent nus',(await nomsNpc()).some(n=>/B850-A/.test(n)),false);
ok('on le dit',(await pg.textContent('#annul-txt')).indexOf('Configuration effacée')>=0,true);

console.log('\n--- un profil sans composant déclaré marche pareil ---');
ok('aucun intitulé cassé',await pg.evaluate(()=>{
  const p=JSON.parse(JSON.stringify(PROFIL_DEFAUT));
  p.npc.forEach(e=>{delete e.comp;});
  CONFIG={cm:'Carte X'};appliquerProfil(p,false);
  const n=[...document.querySelectorAll('#list-npc .item-name')].map(x=>x.textContent);
  CONFIG={};appliquerProfil(PROFIL_DEFAUT,false);
  return n.every(x=>x.length>0&&x.indexOf('undefined')<0);}),true);

console.log('\n--- l\'affichage selon la taille de l\'écran ---');
const mesure=async(w,h)=>{
  await pg.setViewportSize({width:w,height:h});
  await pg.waitForTimeout(200);
  return pg.evaluate(()=>({
    carte:Math.round(document.querySelector('.card').getBoundingClientRect().width),
    tache:getComputedStyle(document.querySelector('.item-name')).fontSize,
    desc:getComputedStyle(document.querySelector('.item-desc')).fontSize,
    defile:document.documentElement.scrollWidth>document.documentElement.clientWidth+1}));
};
const tel=await mesure(360,740);
ok('téléphone : la largeur ne change pas',tel.carte<=360,true);
ok('téléphone : le texte reste à 13 px',tel.tache,'13px');
ok('téléphone : pas de défilement horizontal',tel.defile,false);
const tab=await mesure(900,1200);
ok('tablette : inchangée elle aussi',tab.tache,'13px');
const pc=await mesure(1400,900);
ok('grand écran : la carte s\'élargit',pc.carte>1000,true);
ok('grand écran : les tâches passent à 15 px',pc.tache,'15px');
ok('grand écran : les descriptions à 13 px',pc.desc,'13px');
ok('grand écran : toujours pas de défilement',pc.defile,false);
ok('aucune erreur JS',errs.length?errs[0]:'aucune','aucune');

await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nCONFIGURATION ET AFFICHAGE : OPERATIONNELS');
process.exit(ko?1:0);
})();
