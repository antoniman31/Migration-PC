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
const debut=html.indexOf('const PROFIL_DEFAUT = ');
const fin=html.indexOf('const CLE_PROFIL');
ok('PROFIL_DEFAUT trouvé dans index.html',debut>=0&&fin>debut);
if(debut<0||fin<=debut){console.log('\n1 TEST EN ECHEC');process.exit(1);}

const brut=html.slice(debut+'const PROFIL_DEFAUT = '.length,fin).trim().replace(/;$/,'');
let embarque;
try{embarque=JSON.parse(brut);}
catch(e){
  // Un objet JS n'est pas forcement du JSON : si ce parse echoue, le profil
  // embarque a ete edite a la main dans un style que ce test ne sait pas relire.
  console.log(' FAIL le profil embarqué n\'est pas du JSON strict → '+e.message);
  console.log('\n1 TEST EN ECHEC');process.exit(1);
}
const fichier=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));

ok('profil embarqué identique à presets/exemple.json',
   JSON.stringify(embarque)===JSON.stringify(fichier),
   'les deux ont divergé — recopier presets/exemple.json dans index.html');

// Invariants du profil lui-meme : un id en double fait porter une case a deux
// elements, et la progression devient fausse sans que rien ne le signale.
const tous=[].concat(fichier.npc||[],fichier.apps||[],fichier.data||[],fichier.pwa||[]);
const vus=new Set(),doublons=[];
tous.forEach(function(e){if(vus.has(e.id))doublons.push(e.id);vus.add(e.id);});
ok('identifiants uniques sur les quatre onglets',doublons.length===0,doublons.join(', '));

const sansId=tous.filter(function(e){return !e.id;});
ok('tous les éléments ont un identifiant',sansId.length===0,sansId.length+' sans id');

const prioValides=['high','med','ok'];
const mauvaisePrio=(fichier.apps||[]).concat(fichier.npc||[]).filter(function(e){return e.p&&prioValides.indexOf(e.p)<0;});
ok('priorités valides',mauvaisePrio.length===0,mauvaisePrio.map(e=>e.id+'='+e.p).join(', '));

const mauvaisePr=(fichier.data||[]).filter(function(e){return prioValides.indexOf(e.pr)<0;});
ok('priorités de sauvegarde valides',mauvaisePr.length===0,mauvaisePr.map(e=>e.id+'='+e.pr).join(', '));

const catsInconnues=(fichier.apps||[]).filter(function(a){return a.c&&!fichier.cats[a.c];});
ok('catégories déclarées',catsInconnues.length===0,catsInconnues.map(a=>a.id+'→'+a.c).join(', '));

const ids=new Set(tous.map(e=>e.id));
const ordreInconnu=(fichier.ordre||[]).filter(function(id){return !ids.has(id);});
ok("l'ordre conseillé ne cite que des éléments existants",ordreInconnu.length===0,ordreInconnu.join(', '));

console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nPROFIL SYNCHRONISE ET COHERENT');
process.exit(ko?1:0);
