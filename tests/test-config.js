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


// Le detail d'une application (description, commande, avertissement) s'ouvre
// au clic. Ces assertions le deplient d'abord au lieu de chercher dans une
// ligne repliee ce qui n'y est plus.
async function deplierApps(pg){
  await pg.evaluate(()=>{APPS_DATA.forEach(a=>{lignesOuvertes[a.id]=true;});renderApps();});
}

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
// Une etape qui n'est ni un telechargement ni un composant n'a rien a
// chercher : « download Windows Update official » ne mene nulle part, et un
// bouton qui deçoit a chaque clic coute plus que son absence.
ok('une étape sans composant n\'a pas de bouton',
  await lienDe('Windows Update'),null);

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
            ssd:'Samsung SSD 9100 PRO 2TB'}},''));
await pg.waitForTimeout(450);
ok('les cinq champs sont remplis',
  await pg.evaluate(()=>COMPOSANTS.filter(c=>CONFIG[c.cle]).length),5);
ok('le sous-titre le dit',
  (await pg.textContent('#profil-sous')).indexOf('5 composants repris')>=0,true);
ok('et les intitulés en profitent aussitôt',
  (await nomsNpc()).some(n=>/^Pilote chipset.*B850-A$/.test(n)),true);

console.log('\n--- qui a raison sur le matériel ---');
// Un inventaire vient presque toujours de l'ANCIEN PC : c'est tout l'intérêt
// du scan. Il n'a donc pas à écraser une configuration saisie pour le neuf,
// sinon les intitulés des pilotes porteraient la carte mère qu'on abandonne.
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
// verifier-pc.ps1 tourne sur le PC neuf : lui seul sait de quelle machine il
// parle, donc lui seul écrase. Un profil rapporté de l'+"'"+'ancien PC, non.'
await pg.evaluate(()=>traiterDonnees({
  type:'verification-migration-pc',machine:{},trouves:[],
  materiel:{cm:'MSI MAG B650 TOMAHAWK'}},''));
await pg.waitForTimeout(350);
ok('la machine constatée gagne',await pg.evaluate(()=>CONFIG.cm),'MSI MAG B650 TOMAHAWK');
// Et les intitulés suivent tout de suite, sans attendre un autre rendu.
ok('les intitulés se rafraîchissent aussitôt',
  (await nomsNpc()).some(n=>/^Pilote chipset.*TOMAHAWK$/.test(n)),true);
await pg.evaluate(p=>traiterDonnees(p,''),
  {meta:{nom:'Ancien'},cats:{},npc:[],apps:[{id:'z',n:'Z',c:'x',src:'s',d:'d'}],
   data:[],pwa:[],quitter:[],materiel:{cm:'ASUSTeK ancien',ssd:'Un SSD'}});
await pg.waitForTimeout(350);
ok('un profil n\'écrase pas la machine constatée',
  await pg.evaluate(()=>CONFIG.cm),'MSI MAG B650 TOMAHAWK');
ok('mais comble ce qui manquait',await pg.evaluate(()=>CONFIG.ssd),'Un SSD');
await pg.evaluate(()=>{CONFIG={};saveConfig();construireConfig();
  appliquerProfil(PROFIL_DEFAUT,false);});

console.log('\n--- ce qu\'il faut prévoir sur la clé ---');
// Le scan connaissait la taille de tout ce qu'il propose d'emporter et ne
// faisait jamais la somme.
for(const [mo,attendu] of [[62000,'prévoir 60,5 Go sur la clé'],[350,'prévoir 350 Mo sur la clé']]){
  await pg.evaluate(v=>traiterDonnees({type:'inventaire-migration-pc',machine:{},
    apps:[{nom:'A',cat:'system',source:'registre'}],variables:{},configs:[],
    materiel:{},outils:[],dossiers:[],precieux:[],portables:[],aPrevoirMo:v},''),mo);
  await pg.waitForTimeout(250);
  ok(mo+' Mo annoncés',(await pg.textContent('#profil-sous')).indexOf(attendu)>=0,true);
}
// Rien de mesuré : on n'annonce pas « 0 Go », on se tait.
for(const v of [0,undefined,'beaucoup']){
  await pg.evaluate(x=>traiterDonnees({type:'inventaire-migration-pc',machine:{},
    apps:[{nom:'A',cat:'system',source:'registre'}],variables:{},configs:[],
    materiel:{},outils:[],dossiers:[],precieux:[],portables:[],aPrevoirMo:x},''),v);
  await pg.waitForTimeout(250);
  ok(JSON.stringify(v)+' : on se tait',
    (await pg.textContent('#profil-sous')).indexOf('prévoir')>=0,false);
}
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
await pg.waitForTimeout(300);

console.log('\n--- les logiciels portables ---');
// Le mot « ressemble » compte : rien ne permet de distinguer à coup sûr un
// logiciel posé sans installateur d'un dossier qui contient un .exe. La page
// doit le dire, au lieu de présenter une supposition comme un constat.
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{},
  apps:[{nom:'A',cat:'system',source:'registre'}],
  variables:{},configs:[],materiel:{},outils:[],dossiers:[],precieux:[],
  portables:[{nom:'ffmpeg',chemin:'D:\\Outils\\ffmpeg',exes:['ffmpeg.exe','ffplay.exe']},
             {nom:'SumatraPDF',chemin:'D:\\Outils\\sumatra',exes:['SumatraPDF.exe']},
             {chemin:'  '},null]},''));
await pg.waitForTimeout(400);
const ports=await pg.evaluate(()=>DATA_SAVES.filter(d=>String(d.id).indexOf('port')===0));
ok('les deux candidats remontent',ports.length,2);
ok('les entrées vides ne comptent pas',
  (await pg.textContent('#profil-sous')).indexOf('2 portables à relire')>=0,true);
ok('les exécutables sont nommés',(ports[0].note||'').indexOf('ffmpeg.exe')>=0,true);
// C'est une copie, pas une réinstallation : rien ne les remettra en place.
ok('on dit que ça se copie',(ports[0].note||'').indexOf('à copier')>=0,true);
ok('et que c\'est une supposition',
  (ports[0].warn||'').indexOf('Supposition')>=0,true);
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
await pg.waitForTimeout(300);

console.log('\n--- les clés de signature ---');
// Quelques kilo-octets, et les seuls fichiers de la liste qu'aucune
// réinstallation ne rattrape : un keystore de release perdu oblige à passer
// par la procédure de réinitialisation de clé chez l'éditeur.
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{},
  apps:[{nom:'A',cat:'system',source:'registre'}],
  variables:{},configs:[],materiel:{},outils:[],dossiers:[],
  precieux:[{nom:'release.jks',chemin:'C:\\dev\\app\\release.jks',tailleKo:2.3},
            {nom:'debug.keystore',chemin:'C:\\Users\\a\\.android\\debug.keystore',tailleKo:2.2},
            {chemin:'  '},null]},''));
await pg.waitForTimeout(400);
ok('elles passent devant tout le reste',
  await pg.evaluate(()=>DATA_SAVES[0].n),'release.jks');
ok('en priorité haute',await pg.evaluate(()=>DATA_SAVES[0].pr),'high');
ok('avec un avertissement qui dit pourquoi',
  await pg.evaluate(()=>(DATA_SAVES[0].warn||'').indexOf('recrée')>=0),true);
ok('les entrées vides ne comptent pas',
  await pg.evaluate(()=>DATA_SAVES.filter(d=>String(d.id).indexOf('cle')===0).length),2);
ok('et le sous-titre les annonce',
  (await pg.textContent('#profil-sous')).indexOf('2 clés de signature')>=0,true);
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
await pg.waitForTimeout(300);

console.log('\n--- les gros dossiers qu\'on oublie ---');
// Le projet ne détectait aucun fichier personnel : l'onglet Données est une
// liste écrite à la main, et ce qui n'y figure pas n'est rappelé par rien.
// Le script mesure, la page décide : elle seule connaît la checklist.
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{},
  apps:[{nom:'7-Zip',cat:'system',source:'registre'}],
  variables:{},configs:[],materiel:{},outils:[],
  dossiers:[
    {nom:'Projets',chemin:'D:\\Projets',tailleMo:82000,complet:true},
    // Déjà réclamés par la checklist : ils ne doivent pas doubler.
    {nom:'Documents',chemin:'C:\\Users\\a\\Documents',tailleMo:3000,complet:true},
    {nom:'Pictures',chemin:'C:\\Users\\a\\Pictures',tailleMo:5200,complet:true},
    {nom:'Downloads',chemin:'C:\\Users\\a\\Downloads',tailleMo:9000,complet:true},
    // Mesure interrompue par le budget : elle ne doit pas se faire passer
    // pour une mesure complète.
    {nom:'Jeux',chemin:'E:\\Jeux',tailleMo:140000,complet:false},
    {chemin:'   '},null]},''));
await pg.waitForTimeout(400);
const gros=await pg.evaluate(()=>DATA_SAVES.filter(d=>String(d.id).indexOf('gros')===0));
ok('seuls les dossiers hors liste remontent',gros.map(d=>d.n).join(','),'Projets,Jeux');
// « %USERPROFILE%\Documents, Pictures, Videos » désigne trois dossiers : sans
// les séparer, la comparaison portait sur la chaîne entière et n'en
// reconnaissait aucun.
ok('un champ à plusieurs chemins les couvre tous',
  gros.some(d=>/Pictures|Documents|Downloads/.test(d.n)),false);
ok('la taille est dite',(gros[0].note||'').indexOf('Go')>=0,true);
ok('une mesure partielle le dit',
  (gros[1].note||'').indexOf('mesure partielle')>=0,true);
ok('les entrées vides ne comptent pas',
  (await pg.textContent('#profil-sous')).indexOf('2 gros dossiers hors liste')>=0,true);
ok('et ils sont cochables comme le reste',
  await pg.evaluate(()=>{
    const av=Object.keys(S.checked).length;
    toggle('gros1','Projets');
    const ap=Object.keys(S.checked).length;
    toggle('gros1','Projets');
    return ap-av;}),1);
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
await pg.waitForTimeout(300);

console.log('\n--- les chaînes d\'outils ---');
// Ni le registre, ni winget, ni le Store ne savent quoi que ce soit du SDK
// Android, de WSL ou des paquets globaux de npm : ils n'apparaissaient nulle
// part. Ils arrivent avec leur commande deja ecrite — on ne la devine pas.
await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{os:'Windows 11',nom:'PC'},
  apps:[{nom:'7-Zip',cat:'system',source:'registre',winget:'7zip.7zip'}],
  variables:{},configs:[],materiel:{},
  outils:[{famille:'SDK Android',id:'platforms;android-34',commande:'sdkmanager "platforms;android-34"'},
          {famille:'WSL',id:'Ubuntu-22.04',nom:'Ubuntu-22.04 (par défaut)',commande:'wsl --install -d Ubuntu-22.04'},
          {famille:'npm (global)',id:'typescript',version:'5.6.2',commande:'npm install -g typescript'},
          // Ce qu'un fichier reçu peut porter et qui ne doit rien produire.
          {id:'   ',commande:'rien'},null,'pas un objet']},''));
await pg.waitForTimeout(400);
ok('les trois outils sont là',
  await pg.evaluate(()=>APPS_DATA.filter(a=>a.c==='outils').length),3);
ok('les entrées vides ne comptent pas',
  (await pg.textContent('#profil-sous')).indexOf('3 outils de développement')>=0,true);
ok('ils ont leur catégorie à eux',
  await pg.evaluate(()=>!!CATS.outils),true);
// La commande est recopiee telle quelle : deviner celle d'un paquet scoop ou
// du SDK servirait un ordre faux qui a l'air vrai.
await deplierApps(pg);
ok('la commande est celle du scanner',await pg.evaluate(()=>{
  const b=[...document.querySelectorAll('#list-apps .b-winget')]
    .find(x=>x.textContent.indexOf('sdkmanager')>=0);
  return b?b.getAttribute('onclick'):'(aucun bouton)';
}).then(a=>a.indexOf('sdkmanager')>=0),true);
// Un inventaire sans outils ne doit pas ouvrir une categorie vide.
await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{},apps:[{nom:'A',cat:'x',source:'y'}],
  variables:{},configs:[],materiel:{},outils:[]},''));
await pg.waitForTimeout(350);
ok('aucun outil, aucune catégorie',await pg.evaluate(()=>!!CATS.outils),false);
ok('et le sous-titre n\'en parle pas',
  (await pg.textContent('#profil-sous')).indexOf('outil')>=0,false);
await pg.evaluate(()=>{appliquerProfil(PROFIL_DEFAUT,false);});
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
const vide=await pg.evaluate(()=>traiterDonnees({
  type:'inventaire-migration-pc',machine:{nom:'NEUF'},apps:[],variables:{},configs:[],
  materiel:{cm:'ASUS B850-A'}},''));
await pg.waitForTimeout(350);
ok('l\'import est accepté',vide,true);
ok('aucun panneau d\'erreur',await pg.isVisible('#panne'),false);
ok('on le dit calmement',
  (await pg.textContent('#annul-txt')).indexOf('aucune application détectée')>=0,true);
ok('le matériel est repris quand même',await pg.evaluate(()=>CONFIG.cm),'ASUS B850-A');
ok('et le profil d\'exemple reste en place',
  await pg.evaluate(()=>APPS_DATA.length>0),true);

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
