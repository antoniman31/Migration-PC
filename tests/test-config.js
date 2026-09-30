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
const {annoncerNavigateur}=require('./lib-tests');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;


// Le detail d'une application (description, commande, avertissement) s'ouvre
// au clic. Ces assertions le deplient d'abord au lieu de chercher dans une
// ligne repliee ce qui n'y est plus.
async function deplierApps(pg){
  await pg.evaluate(()=>{APPS_DATA.forEach(a=>{lignesOuvertes[a.id]=true;});renderApps();});
}

(async()=>{
const b=await chromium.launch(lancement);
annoncerNavigateur(b);
const ctx=await b.newContext({locale:'fr-FR',viewport:{width:1400,height:900}});
const pg=await ctx.newPage();
const errs=[];pg.on('pageerror',e=>errs.push(e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
await pg.evaluate(()=>{try{localStorage.setItem('mpc_debut_v1','1');}catch(e){}});
await pg.reload({waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};
const P=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const ouvrirConfig=async()=>{
  if(await pg.isVisible('#config'))return;
  await pg.click('#menu-btn');await pg.waitForTimeout(120);
  await pg.getByRole('menuitem',{name:/Ma configuration/}).click();
  await pg.waitForTimeout(250);
};
console.log('--- sans configuration ---');
ok('le bloc est fermé',await pg.isVisible('#config'),false);
ok('rien n\'est retenu',await pg.evaluate(()=>Object.keys(CONFIG).length),0);

console.log('\n--- on le remplit ---');
await ouvrirConfig();
ok('le bloc s\'ouvre',await pg.isVisible('#config'),true);
ok('un champ par composant',(await pg.$$('.config-input')).length,9);
ok('le focus y entre',await pg.evaluate(()=>
  document.getElementById('config').contains(document.activeElement)),true);
await pg.fill('#cfg-cm','ASUS ROG STRIX B850-A');
await pg.fill('#cfg-gpu','NVIDIA RTX 5070 Ti');
await pg.waitForTimeout(400);
// Un compte — « 2 sur 9 » — ne dit pas s'il faut remplir la suite. Le résumé
// nomme donc ce qui manque pour retrouver un pilote, qui est la seule chose
// qu'on ne peut pas se contenter d'ignorer.
const resume=await pg.textContent('#config-resume');
ok('le résumé compte',/2\/9/.test(resume),true);
ok('et nomme ce qui manque pour les pilotes',
  /r[ée]seau filaire/.test(resume)&&/wi-fi/i.test(resume),true);
// Les neuf champs sont rangés en deux groupes : cinq décrivent la machine,
// quatre servent à retrouver un pilote, et une liste plate cachait cet écart.
ok('deux groupes de champs',(await pg.$$('.config-grp')).length,2);
ok('chaque groupe porte un titre',(await pg.$$('.config-grp-t')).length,2);
ok('les neuf champs y sont tous',(await pg.$$('.config-grp .config-input')).length,9);
ok('la carte mère est retenue',await pg.evaluate(()=>CONFIG.cm),'ASUS ROG STRIX B850-A');

console.log('\n--- ça tient, et ça s\'efface ---');
await pg.reload({waitUntil:'networkidle'});
ok('la configuration survit au rechargement',
  await pg.evaluate(()=>CONFIG.cm),'ASUS ROG STRIX B850-A');
// Le bloc se referme au rechargement : c'est voulu, on le rouvre.
ok('il ne se rouvre pas tout seul',await pg.isVisible('#config'),false);
await ouvrirConfig();
ok('les champs sont repeuplés',await pg.inputValue('#cfg-cm'),'ASUS ROG STRIX B850-A');
await pg.click('.config-vider');await pg.waitForTimeout(350);
ok('« Tout effacer » vide les champs',await pg.inputValue('#cfg-cm'),'');
ok('et la mémoire avec',await pg.evaluate(()=>Object.keys(CONFIG).length),0);
ok('on le dit',(await pg.textContent('#annul-txt')).indexOf('Configuration effacée')>=0,true);

console.log('\n--- le matériel détecté remplit la configuration ---');
// Windows connaît la machine : la saisie à la main n'est qu'un repli.
await pg.click('.config-vider');await pg.waitForTimeout(300);
await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',genere:'2026-09-24T14:00:00',
  machine:{os:'Windows 11',nom:'PC'},
  apps:[{nom:'7-Zip',cat:'outils',source:'registre',winget:'7zip.7zip'}],
  variables:{},configs:[],
  materiel:{cm:'ASUSTeK ROG STRIX B850-A',cpu:'AMD Ryzen 7 9800X3D',
            gpu:'NVIDIA GeForce RTX 5070 Ti',ram:'32 Go DDR5 6000 MT/s',
            ssd:'Samsung SSD 9100 PRO 2TB',eth:'Realtek Gaming 2.5GbE',
            wifi:'Intel Wi-Fi 6E AX211',audio:'Realtek(R) Audio',
            bios:'1402 (2025-03-11)'}},''));
await pg.waitForTimeout(450);
// Le scan remplit les neuf : les cinq composants et les quatre qui servent à
// retrouver un pilote.
ok('les neuf champs sont remplis',
  await pg.evaluate(()=>COMPOSANTS.filter(c=>CONFIG[c.cle]).length),9);
ok('le sous-titre le dit',
  (await pg.textContent('#profil-sous')).indexOf('9 composants repris')>=0,true);
// Le modèle sert à fabriquer le lien du constructeur dans l'onglet Pilotes.
ok('la carte mère relevée est retenue',
  await pg.evaluate(()=>CONFIG.cm),'ASUSTeK ROG STRIX B850-A');

console.log('\n--- qui a raison sur le matériel ---');
// Un inventaire vient presque toujours de l'ANCIEN PC : c'est tout l'intérêt
// du scan. Il n'a donc pas à écraser une configuration saisie pour le neuf,
// sinon le lien du constructeur viserait la carte mère qu'on abandonne.
await pg.evaluate(()=>{CONFIG={cm:'Ma carte à moi'};saveConfig();construireConfig();});
await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{},apps:[{nom:'A',cat:'x',source:'y'}],
  variables:{},configs:[],materiel:{cm:'ASUSTeK autre chose',gpu:'RTX 4060'}},''));
await pg.waitForTimeout(400);
ok('un inventaire ne corrige pas la saisie',await pg.evaluate(()=>CONFIG.cm),'Ma carte à moi');
ok('mais remplit les champs vides',await pg.evaluate(()=>CONFIG.gpu),'RTX 4060');

console.log('\n--- la configuration voyage avec le profil ---');
// Sans cela, tout le bénéfice disparaissait au transfert : sur le PC neuf les
// intitulés redevenaient génériques et les recherches visaient dans le vide.
const profil=await pg.evaluate(()=>profilCourant());
ok('le profil exporté porte le matériel',
  profil.materiel&&profil.materiel.cm,'Ma carte à moi');
ok('les cinq clés voyagent',
  profil.materiel&&profil.materiel.gpu,'RTX 4060');

console.log('\n--- seule la vérification constate la machine qu'+"'"+'on équipe ---');
// Le scan de la cible tourne sur le PC neuf : lui seul sait de quelle machine il
// parle, donc lui seul écrase. Un profil rapporté de l'+"'"+'ancien PC, non.'
await pg.evaluate(()=>traiterDonnees({
  type:'verification-migration-pc',machine:{},trouves:[],
  materiel:{cm:'MSI MAG B650 TOMAHAWK'}},''));
await pg.waitForTimeout(350);
ok('la machine constatée gagne',await pg.evaluate(()=>CONFIG.cm),'MSI MAG B650 TOMAHAWK');

await pg.evaluate(p=>traiterDonnees(p,''),
  {meta:{nom:'Ancien'},cats:{},apps:[{id:'z',n:'Z',c:'x',src:'s',d:'d'}],
   pwa:[],materiel:{cm:'ASUSTeK ancien',ssd:'Un SSD'}});
await pg.waitForTimeout(350);
ok('un profil n\'écrase pas la machine constatée',
  await pg.evaluate(()=>CONFIG.cm),'MSI MAG B650 TOMAHAWK');
ok('mais comble ce qui manquait',await pg.evaluate(()=>CONFIG.ssd),'Un SSD');
await pg.evaluate(()=>{CONFIG={};saveConfig();construireConfig();
  appliquerProfil(PROFIL_DEFAUT,false);});
await pg.waitForTimeout(300);

console.log('\n--- les périphériques sans pilote ---');
await pg.evaluate(()=>traiterDonnees({
  type:'verification-migration-pc',machine:{nom:'NEUF'},trouves:[],
  materiel:{cm:'ASUSTeK ROG STRIX B850-A'},
  pilotes:[{nom:'Contrôleur Ethernet',classe:'',probleme:'aucun pilote installe',code:28},
           {nom:'Realtek Audio',classe:'MEDIA',probleme:'ne demarre pas',code:10}]},''));
await pg.waitForTimeout(400);
ok('le panneau s\'affiche même sans rien à cocher',await pg.isVisible('.pilotes'),true);
ok('les deux périphériques y sont',(await pg.$$('.pil-item')).length,2);
ok('le problème est nommé',
  (await pg.textContent('.pilotes')).indexOf('aucun pilote installe')>=0,true);
ok('la recherche cite la carte mère',await pg.evaluate(()=>
  /B850-A/.test(document.querySelector('.pil-item .sm-btn').getAttribute('onclick'))),true);
ok('aucun panneau de panne',await pg.isVisible('#panne'),false);
await pg.evaluate(()=>{try{fermerVerification();}catch(e){}});

console.log('\n--- un scan qui ne trouve rien n\'est pas une panne ---');
// C'est justement le cas d'une machine fraîchement installée : le scan tourne,
// ne trouve presque rien, et ouvrir la page sur un panneau rouge serait faux.
await pg.evaluate(()=>{CONFIG={};saveConfig();construireConfig();});
// On charge une liste garnie pour avoir quelque chose a preserver : ce qu'on
// verifie ici est qu'un inventaire vide n'efface pas ce qui est deja la.
await pg.evaluate(()=>{chargerDemo();});
await pg.waitForTimeout(250);
const appsAvant=await pg.evaluate(()=>APPS_DATA.length);
const vide=await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{nom:'NEUF'},apps:[],variables:{},configs:[],
  materiel:{cm:'ASUS B850-A'}},''));
await pg.waitForTimeout(350);
ok('l\'import est accepté',vide,true);
ok('aucun panneau d\'erreur',await pg.isVisible('#panne'),false);
ok('on le dit calmement',
  (await pg.textContent('#annul-txt')).indexOf('aucune application détectée')>=0,true);
ok('le matériel est repris quand même',await pg.evaluate(()=>CONFIG.cm),'ASUS B850-A');
ok('et la liste en place n\'est pas effacée',
  await pg.evaluate(()=>APPS_DATA.length),appsAvant);

console.log('\n--- une vérification sans pilote en défaut ---');
await pg.evaluate(()=>traiterDonnees({
  type:'verification-migration-pc',machine:{nom:'NEUF'},trouves:[],pilotes:[]},''));
await pg.waitForTimeout(300);
ok('rien ne s\'affiche',await pg.isVisible('.pilotes'),false);

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
// ON VERIFIE L'INTENTION, PAS LE CHIFFRE. Ces lignes exigeaient une taille
// calculee EXACTEMENT egale a 13px ou 15px. C'est la forme la plus fragile qui
// soit : un navigateur qui arrondit autrement, une densite d'ecran differente,
// et le test tombe sans qu'aucun defaut n'existe. test-mobile.js a deja coute
// deux allers-retours pour cette raison exacte.
//
// Ce qui etait reellement promis : le texte ne retrecit pas sur telephone, il
// ne change pas entre telephone et tablette, il grandit sur grand ecran, et
// rien ne descend sous le plancher. Les relations valent mieux que les valeurs.
// Elles disent la meme chose, elles survivent a un changement de navigateur, et
// « grandit » n'etait meme pas verifie avant : il n'etait qu'implique par deux
// nombres ecrits a la main.
const PLANCHER=12;   // le meme que test-mobile.js et test-plancher-texte.js
const px=v=>parseFloat(v);
ok('téléphone : la largeur ne change pas',tel.carte<=360,true);
ok('téléphone : le texte reste lisible',px(tel.tache)>=PLANCHER,true);
ok('téléphone : pas de défilement horizontal',tel.defile,false);
const tab=await mesure(900,1200);
ok('tablette : le texte ne change pas',tab.tache,tel.tache);
const pc=await mesure(1400,900);
ok('grand écran : la carte s\'élargit',pc.carte>1000,true);
ok('grand écran : les tâches grandissent',px(pc.tache)>px(tel.tache),true);
ok('grand écran : les descriptions restent lisibles',px(pc.desc)>=PLANCHER,true);
ok('grand écran : et plus petites que les tâches',px(pc.desc)<px(pc.tache),true);
ok('grand écran : toujours pas de défilement',pc.defile,false);
ok('aucune erreur JS',errs.length?errs[0]:'aucune','aucune');

await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nCONFIGURATION ET AFFICHAGE : OPERATIONNELS');
process.exit(ko?1:0);
})();
