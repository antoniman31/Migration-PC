// Les tailles de texte DECLAREES, lues dans le CSS.
//
//   node tests/test-plancher-texte.js
//
// POURQUOI UN SECOND CONTROLE, alors que test-mobile.js mesure deja des pixels
// rendus. Parce qu'il ne mesure que ce qui est a l'ecran au moment ou il passe :
// les trois onglets, profil d'exemple charge, panneaux fermes. Tout ce qui vit
// derriere un bouton, dans un etat qu'il ne visite pas, ou dont la largeur est
// nulle a cet instant, lui echappe. Et son verdict depend du navigateur qui le
// lance : le meme fichier a ete vert en integration et rouge en local pendant
// des semaines, sur un <code> de 104 x 13 px reellement affiche dans le bandeau
// de comparaison. Un navigateur le voyait, l'autre non.
//
// Celui-ci ne rend rien et ne mesure rien : il lit les declarations. Il ne
// remplace pas l'autre — une regle correcte peut donner un texte minuscule par
// heritage, et seule la mesure le dit — mais il attrape ce que la mesure ne
// visite pas, et il donne le meme resultat partout.
//
// CE QU'IL FAIT DES EXCEPTIONS. Le projet s'est fixe 12 px comme plancher, et
// son CSS descend plus bas en une vingtaine d'endroits : compteurs, badges,
// pastilles. Les effacer serait redessiner l'interface, ce qui n'est pas le
// travail d'un test. Il les demande donc nommees une par une, avec la raison.
// Deux effets : la liste se relit et se discute, et une regle NOUVELLE sous le
// plancher fait echouer le test au lieu de s'ajouter en silence.
const fs=require('fs');
const path=require('path');

const PLANCHER=12;   // le meme seuil que test-mobile.js

// Les exceptions, nommees et justifiees. Une entree ici est une decision, pas
// un oubli : c'est la difference entre une dette qu'on porte et une dette qu'on
// ignore. Le jour ou l'une de ces regles remonte a 12 px, son entree devient
// inutile et le test le dit.
const TOLEREES={
  // Compteurs et pastilles : un nombre a deux chiffres, jamais une phrase. Les
  // lire n'est pas lire, c'est reconnaitre une forme.
  '.tab-badge':'pastille de compte sur un onglet, deux chiffres au plus',
  '.sec-hdr-cnt':'compteur « fait / total » d\'une categorie',
  '.gsearch-count':'compteur de resultats de la recherche globale',
  '.gp-label':'etiquette de la barre de progression, sous le pourcentage',
  '.sec-prog-txt':'pourcentage d\'avancement d\'une section',
  '.badge':'badge d\'etat : un mot, souvent une icone',
  '.b-dep':'badge de dependance : « apres X »',
  '.warn-badge':'badge d\'avertissement sur une ligne',
  '.item-date':'date de cochage, affichee en second plan',
  // Boutons compacts : leur cible tactile est verifiee par test-mobile.js, qui
  // impose 44 x 24 px. Le texte y est court et l'icone porte le sens.
  '.sm-btn':'bouton compact de barre d\'actions, cible tactile verifiee ailleurs',
  '.chk-all':'bouton « tout cocher » d\'une categorie',
  '.cat-winget':'bouton « copier winget » d\'une categorie',
  '.lnk-btn':'lien d\'une ligne vers le site ou la recherche',
  '.chkbox':'la coche elle-meme : un signe, pas un texte',
  '.gsr-tab':'intitule de section dans les resultats de recherche',
  // Textes secondaires : ils accompagnent un texte principal lisible, et les
  // remonter changerait la hierarchie visuelle de la page.
  '.item-desc':'description d\'une ligne, sous son nom',
  '.save-path':'chemin de fichier, affiche en second plan',
  '.save-note':'note sous un chemin de fichier',
  '.outils-dedans':'intitule « dans l\'archive : », en capitales',
  '.outils-f':'nom de fichier dans la liste de l\'archive',
  '.config-grp-s':'sous-titre d\'un groupe du panneau de configuration',
  '.verif-raison':'raison d\'un element non detecte',
  '#panne-detail':'detail technique d\'une panne, replie par defaut',
  '.panne-aide':'aide sous un message de panne'
};

let ko=0;
function ok(label,a,b){
  const bon=JSON.stringify(a)===JSON.stringify(b);
  console.log((bon?'  ok  ':' FAIL ')+label+' → '+JSON.stringify(a)
    +(bon?'':' (attendu '+JSON.stringify(b)+')'));
  if(!bon)ko++;
}

const html=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const d=html.indexOf('<style>'), f=html.indexOf('</style>');
if(d<0||f<0)throw new Error('bloc <style> introuvable');
const css=html.slice(d,f);

// Le selecteur nu : sans les commentaires qui le precedent, et sans les
// pseudo-classes, pour qu'une entree de la liste couvre « .badge » et
// « .badge:hover » sans etre ecrite deux fois.
function selecteurs(brut){
  return brut.replace(/\/\*[\s\S]*?\*\//g,' ')
    .split(',')
    .map(s=>s.trim().replace(/::?[a-z-]+(\([^)]*\))?/g,'').trim())
    .filter(Boolean);
}

console.log('--- les tailles declarees sous le plancher ---');
const sous=[];
const regle=/([^{}]+)\{([^}]*)\}/g;
let m;
while((m=regle.exec(css))){
  const corps=m[2];
  // Une declaration en max(12px, …) porte son plancher avec elle : c'est la
  // forme retenue pour « code », justement pour que 0.9em ne descende plus
  // sous le seuil quel que soit le parent.
  if(/font-size:\s*max\(\s*12px/.test(corps))continue;
  const taille=/font-size:\s*([0-9.]+)(px|r?em)/.exec(corps);
  if(!taille)continue;
  const v=parseFloat(taille[1]), u=taille[2];
  // 0.75em de 16px fait 12px : en dessous, la regle ne peut donner 12px que
  // dans un parent plus grand que le corps du document, ce qui n'arrive pas ici.
  const souslePlancher = (u==='px') ? v<PLANCHER : v<0.75;
  if(!souslePlancher)continue;
  for(const s of selecteurs(m[1]))sous.push({sel:s,taille:taille[1]+u});
}

const parSel={};
sous.forEach(function(r){ if(!parSel[r.sel])parSel[r.sel]=r.taille; });
const noms=Object.keys(parSel).sort();
console.log('   '+noms.length+' selecteur(s) declarent moins de '+PLANCHER+'px');

// Une regle sous le plancher qui n'est pas dans la liste : soit elle vient
// d'etre ajoutee, soit personne ne l'avait vue. Les deux demandent une decision.
const nonDeclarees=noms.filter(s=>!(s in TOLEREES));
nonDeclarees.forEach(s=>console.log('      sous le plancher, non declaree : '+s+' ('+parSel[s]+')'));
ok('aucune regle sous le plancher qui ne soit declaree',nonDeclarees,[]);

// Et l'inverse, qui compte autant : une exception devenue inutile doit partir,
// sinon la liste finit par decrire un CSS qui n'existe plus — c'est exactement
// ce qui est arrive aux captures d'ecran de ce projet.
const inutiles=Object.keys(TOLEREES).filter(s=>!(s in parSel)).sort();
inutiles.forEach(s=>console.log('      exception devenue inutile : '+s));
ok('aucune exception perimee',inutiles,[]);

console.log('\n--- ce que le plancher couvre vraiment ---');
// Le nombre d'exceptions est en soi un constat : vingt-cinq veut dire que le
// plancher decrit une intention plus qu'une regle. Le test ne tranche pas cette
// question de conception, il refuse qu'elle grossisse sans qu'on le sache.
console.log('   '+Object.keys(TOLEREES).length+' exception(s) assumee(s), '
  +'chacune avec sa raison dans ce fichier.');
ok('le plancher est le meme que celui de test-mobile.js',PLANCHER,12);

console.log(ko?'\n'+ko+' ECHEC(S)':'\nPLANCHER DE TEXTE : TOUT EST DECLARE');
process.exit(ko?1:0);
