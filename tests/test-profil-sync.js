// Le profil d'exemple existe en deux endroits : embarque dans index.html (pour
// que la page fonctionne hors ligne, sans fetch) et dans presets/exemple.json
// (pour etre lisible et modifiable). Rien dans le code ne garantit qu'ils
// restent identiques : ce test le garantit.
//
//   node tests/test-profil-sync.js
const fs=require('fs'),path=require('path');
const racine=path.join(__dirname,'..');

let ko=0;
const ok=(l,vrai,detail)=>{console.log((vrai?'  ok  ':' FAIL ')+l+(vrai||!detail?'':' → '+detail));if(!vrai)ko++;};

const html=fs.readFileSync(path.join(racine,'index.html'),'utf8');
// Deux profils sont embarques : celui qui s'affiche au demarrage, universel,
// et celui de demonstration qu'on charge a la demande. Les deux doivent rester
// identiques a leur fichier source.
function lireEmbarque(marque,fin,quoi){
  const debut=html.indexOf(marque);
  const f=html.indexOf(fin);
  ok(quoi+' trouvé dans index.html',debut>=0&&f>debut);
  if(debut<0||f<=debut){console.log('\n1 TEST EN ECHEC');process.exit(1);}
  const brut=html.slice(debut+marque.length,f).trim().replace(/;$/,'');
  try{return JSON.parse(brut);}
  catch(e){
    // Un objet JS n'est pas forcement du JSON : si ce parse echoue, le profil
    // embarque a ete edite a la main dans un style que ce test ne sait pas relire.
    console.log(' FAIL '+quoi+' n\'est pas du JSON strict → '+e.message);
    console.log('\n1 TEST EN ECHEC');process.exit(1);
  }
}
const embarque=lireEmbarque('const PROFIL_DEFAUT = ','const PROFIL_DEMO','PROFIL_DEFAUT');
const embarqueDemo=lireEmbarque('const PROFIL_DEMO = ','const CLE_PROFIL','PROFIL_DEMO');
const fichier=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const fichierDemo=JSON.parse(fs.readFileSync(path.join(racine,'presets','demonstration.json'),'utf8'));

ok('démonstration embarquée identique à presets/demonstration.json',
  JSON.stringify(embarqueDemo)===JSON.stringify(fichierDemo));
// Le profil livre ne porte aucune application : celles d'une autre machine
// feraient croire a l'arrivant que c'est sa liste. Elles vivent dans la
// demonstration, qu'on charge en le sachant.
ok('le profil livré ne contient aucune application',(embarque.apps||[]).length===0);
ok('ni aucun raccourci web',(embarque.pwa||[]).length===0);
ok('la démonstration, elle, en contient',(embarqueDemo.apps||[]).length>0);

ok('profil embarqué identique à presets/exemple.json',
   JSON.stringify(embarque)===JSON.stringify(fichier),
   'les deux ont divergé — recopier presets/exemple.json dans index.html');

// Invariants du profil lui-meme : un id en double fait porter une case a deux
// elements, et la progression devient fausse sans que rien ne le signale.
// « quitter » est facultatif : un profil qui ne la déclare pas reste valide.
const tous=[].concat(fichier.quitter||[],fichier.npc||[],fichier.apps||[],
                     fichier.data||[],fichier.pwa||[]);
const vus=new Set(),doublons=[];
tous.forEach(function(e){if(vus.has(e.id))doublons.push(e.id);vus.add(e.id);});
ok('identifiants uniques sur les quatre onglets',doublons.length===0,doublons.join(', '));

const sansId=tous.filter(function(e){return !e.id;});
ok('tous les éléments ont un identifiant',sansId.length===0,sansId.length+' sans id');

const prioValides=['high','med','ok'];
const mauvaisePrio=(fichier.apps||[]).concat(fichier.npc||[]).filter(function(e){return e.p&&prioValides.indexOf(e.p)<0;});
ok('priorités valides',mauvaisePrio.length===0,mauvaisePrio.map(e=>e.id+'='+e.p).join(', '));

const mauvaisePr=(fichier.data||[]).concat(fichier.quitter||[])
  .filter(function(e){return prioValides.indexOf(e.pr)<0;});
ok('priorités de sauvegarde valides',mauvaisePr.length===0,mauvaisePr.map(e=>e.id+'='+e.pr).join(', '));

// Types des champs : une description qui serait un tableau et une dependance
// qui serait une phrase signalent une inversion des deux, ce qui s'est
// reellement produit en generant ce profil. Rien ne plante, mais la page
// affiche « n13 » a la place du texte.
const mauvaiseDesc=tous.filter(function(e){return e.d!==undefined&&typeof e.d!=='string';});
ok('les descriptions sont du texte',mauvaiseDesc.length===0,
   mauvaiseDesc.map(function(e){return e.id;}).join(', '));

const mauvaiseDep=tous.filter(function(e){
  if(e.dep===undefined)return false;
  if(typeof e.dep==='string')return false;          // ancien format, toléré
  if(!Array.isArray(e.dep))return true;
  return e.dep.some(function(d){return typeof d!=='string';});
});
ok('les dépendances sont des identifiants',mauvaiseDep.length===0,
   mauvaiseDep.map(function(e){return e.id;}).join(', '));

const depInconnue=[];
tous.forEach(function(e){
  if(!Array.isArray(e.dep))return;
  e.dep.forEach(function(d){if(!vus.has(d))depInconnue.push(e.id+'→'+d);});
});
ok('les dépendances désignent des éléments existants',depInconnue.length===0,depInconnue.join(', '));

// Dans l'onglet « Nouveau PC », un prerequis doit aussi venir avant dans la
// numerotation : sinon la liste conseille un ordre que ses propres liens
// contredisent.
const rang={};
(fichier.npc||[]).forEach(function(e){rang[e.id]=e.o;});
const ordreIncoherent=[];
(fichier.npc||[]).forEach(function(e){
  if(!Array.isArray(e.dep))return;
  e.dep.forEach(function(d){
    if(rang[d]!==undefined&&rang[d]>rang[e.id])ordreIncoherent.push(e.id+' avant '+d);
  });
});
ok("l'ordre des étapes respecte les prérequis",ordreIncoherent.length===0,ordreIncoherent.join(', '));

// Le contenu, pas seulement la structure. « Préparer la clé » se trouvait apres
// le POINT DE NON-RETOUR : on validait le dernier controle avant d'effacer,
// puis on preparait la cle sans laquelle on n'installe rien.
(function(){
  const npc=fichier.npc||[];
  const par=function(motif){return npc.filter(function(e){return motif.test(e.n);})[0];};
  const nonRetour=par(/NON-RETOUR/);
  const cle=par(/Préparer la clé/);
  const installer=par(/^Installer Windows/);
  const pilotes=par(/Télécharger les pilotes/);
  const bios=par(/Entrer dans le BIOS/);
  if(!nonRetour||!cle||!installer){
    ok('les étapes de préparation sont identifiables',false,'introuvables');
    return;
  }
  ok('la clé est prête avant le point de non-retour',cle.o<nonRetour.o,true);
  ok('le point de non-retour est le dernier avant l\'installation',
    nonRetour.o<installer.o&&!npc.some(function(e){
      return e.o>nonRetour.o&&e.o<installer.o;}),true);
  ok('le point de non-retour dépend de la clé',
    (nonRetour.dep||[]).indexOf(cle.id)>=0,true);
  if(pilotes&&bios){
    // Les pilotes se telechargent depuis le Windows qu'on va remplacer, donc
    // avant d'entrer dans le BIOS, pas au milieu de ses reglages.
    ok('les pilotes se récupèrent avant d\'entrer dans le BIOS',pilotes.o<bios.o,true);
  }
})();

const numeros=(fichier.npc||[]).map(function(e){return e.o;});
ok('numéros d\'étape uniques',new Set(numeros).size===numeros.length);

const catsInconnues=(fichier.apps||[]).filter(function(a){return a.c&&!fichier.cats[a.c];});
ok('catégories déclarées',catsInconnues.length===0,catsInconnues.map(a=>a.id+'→'+a.c).join(', '));

const ids=new Set(tous.map(e=>e.id));
const ordreInconnu=(fichier.ordre||[]).filter(function(id){return !ids.has(id);});
// ── Ce que le scanner couvre, et ce qu'il ne couvre pas ──────────────────
// La checklist a été écrite à la main d'abord ; le scanner est arrivé après et
// n'en couvre qu'une partie. Rien ne disait « cette ligne prétend être
// vérifiable, mais aucun détecteur ne la regarde » — le même sens manquant qui
// avait laissé `ecrire-resultat.ps1` hors de la liste de téléchargement.
//
// Chaque ligne de Données déclare donc l'une de trois choses :
//   une couverture qui existe  — un détecteur la remplit aujourd'hui
//   « attendu:xxx »            — c'est scannable, le détecteur reste à écrire
//   « manuel »                 — personne ne scannera ça, et c'est assumé
const lib=fs.readFileSync(path.join(racine,'scripts','lib-detection.ps1'),'utf8');
const blocCouv=(lib.match(/\$CouverturesScan\s*=\s*\[ordered\]@\{([\s\S]*?)\n\}/)||[,''])[1];
const couvertures=(blocCouv.match(/^\s*([a-z]+)\s*=/gm)||[]).map(m=>m.trim().replace(/\s*=$/,''));
ok('les couvertures sont déclarées dans lib-detection.ps1',couvertures.length>0,true);

const sansDeclaration=[],couvInconnue=[],attendus=[];
fichier.data.forEach(e=>{
  const c=e.scan;
  if(!c){sansDeclaration.push(e.id);return;}
  if(c==='manuel')return;
  if(String(c).startsWith('attendu:')){attendus.push(e.id);return;}
  if(couvertures.indexOf(c)<0)couvInconnue.push(e.id+'→'+c);
});
ok('chaque ligne de Données déclare ce qui la couvre',
  sansDeclaration.length===0,sansDeclaration.join(', '));
ok('et aucune ne cite une couverture qui n\'existe pas',
  couvInconnue.length===0,couvInconnue.join(', '));

// Une ligne qui porte un vrai chemin ne peut pas se dire « manuelle » : si le
// chemin est là, quelque chose peut aller le voir. C'est ce mélange qui faisait
// proposer des dossiers que le scan savait déjà trouver.
const manuelAvecChemin=fichier.data.filter(e=>
  e.scan==='manuel'&&/%[^%]+%|^[A-Za-z]:\\/.test(String(e.p||''))).map(e=>e.id);
ok('aucune ligne « manuelle » ne porte un chemin scannable',
  manuelAvecChemin.length===0,manuelAvecChemin.join(', '));

// Le compte est affiché pour qu'il se voie bouger quand un détecteur arrive.
console.log('   → '+fichier.data.filter(e=>e.scan==="manuel").length+" manuelles, "
  +attendus.length+' détecteurs attendus, '
  +fichier.data.filter(e=>e.scan&&e.scan!=="manuel"&&!String(e.scan).startsWith("attendu:")).length
  +' couvertes aujourd\'hui');

ok("l'ordre conseillé ne cite que des éléments existants",ordreInconnu.length===0,ordreInconnu.join(', '));

// Les fichiers dont les tests dependent doivent etre versionnes. Une regle de
// .gitignore trop large en a deja avale un : tout passait en local, et la CI
// echouait sur un fichier absent du depot. Ce controle le dit avant le push.
const {execFileSync}=require('child_process');
const requis=['tests/inventaire-exemple.json','tests/inventaire-etendu.json',
  'tests/winget-export-exemple.json','presets/exemple.json',
  'presets/demonstration.json','index.html','Migration PC.bat',
  'scripts/scan-pc.ps1','manifest.json','sw.js'];
requis.forEach(function(f){
  const chemin=path.join(racine,f);
  if(!fs.existsSync(chemin)){ok('fichier requis présent : '+f,false,'absent du disque');return;}
  let ignore=false;
  try{
    execFileSync('git',['check-ignore','-q',f],{cwd:racine,stdio:'ignore'});
    ignore=true;                       // code 0 : le fichier est ignoré
  }catch(e){
    // code 1 : non ignoré, ce qu'on veut. Tout autre code (pas de dépôt git,
    // git absent) ne doit pas faire échouer la suite.
    if(e.status!==1)return;
  }
  ok('versionné (non ignoré) : '+f,!ignore,'exclu par .gitignore');
});

// L'inverse, et il compte davantage : ces fichiers-là décrivent la machine de
// celui qui a lancé le scan. resultat-scan.js est en plus chargé par la page à
// l'ouverture — versionné, il partirait en ligne et s'appliquerait chez tous
// les visiteurs. Un de mes propres essais en avait laissé un dans le dossier.
['resultat-scan.js','inventaire-pc.json','verification-pc.json',
 'verification-sauvegardes.json','profil-local.json'].forEach(function(f){
  let ignore=false;
  try{
    execFileSync('git',['check-ignore','-q',f],{cwd:racine,stdio:'ignore'});
    ignore=true;
  }catch(e){
    if(e.status!==1)return;
  }
  ok('jamais versionné : '+f,ignore,'MANQUE dans .gitignore');
  // Et pas seulement ignoré : absent de l'index, au cas où il y aurait été
  // ajouté avant que la règle existe.
  let suivi=false;
  try{
    const sortie=execFileSync('git',['ls-files','--error-unmatch',f],
      {cwd:racine,stdio:['ignore','pipe','ignore']});
    suivi=String(sortie).trim().length>0;
  }catch(e){ /* absent de l'index : c'est ce qu'on veut */ }
  ok('ni suivi par git : '+f,!suivi,'présent dans l\'index git');
});

// Une fonction definie deux fois : la seconde ecrase silencieusement la
// premiere par hoisting, et le code qu'on vient d'ecrire n'est jamais execute.
// Ce piege s'est produit trois fois dans ce fichier (mkLicField, mkEnvFields,
// mkDepBadge), chaque fois sans le moindre message.
// index.html porte plusieurs blocs <script> : un tres court en tete, qui ne
// charge le resultat d'un scan qu'en file://, et le gros bloc de la page. Une
// regex gloutonne les avalait tous les deux avec le HTML entre eux. On prend
// le plus long.
function blocJS(html){
  const blocs=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
  if(!blocs.length)throw new Error('aucun bloc <script> inline dans index.html');
  return blocs.reduce((a,b)=>b.length>a.length?b:a);
}
const script=[null,blocJS(html)];
if(script){
  const noms={},doubles=[];
  const re=/^function\s+([A-Za-z_$][\w$]*)\s*\(/gm;
  let m;
  while((m=re.exec(script[1]))!==null){
    if(noms[m[1]])doubles.push(m[1]);
    noms[m[1]]=true;
  }
  ok('aucune fonction définie deux fois',doubles.length===0,doubles.join(', '));
}

console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nPROFIL SYNCHRONISE ET COHERENT');
process.exit(ko?1:0);
