// Recopie presets/exemple.json dans le PROFIL_DEFAUT embarqué d'index.html.
// Les deux doivent rester identiques : le fichier est lisible et modifiable,
// la copie embarquée permet à la page de fonctionner sans fetch, depuis une
// clé USB. tests/test-profil-sync.js échoue si elles divergent.
//
//   node scripts-sync.js
const fs=require('fs'),path=require('path');
const racine=__dirname;
const html=fs.readFileSync(path.join(racine,'index.html'),'utf8');
const json=fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8');

const MARQUE='const PROFIL_DEFAUT = ';
const debut=html.indexOf(MARQUE);
const fin=html.indexOf('const CLE_PROFIL');
if(debut<0||fin<=debut){console.error('PROFIL_DEFAUT introuvable dans index.html');process.exit(1);}

// On vérifie que le fichier source est du JSON valide avant de l'injecter.
JSON.parse(json);

const avant=html.slice(0,debut+MARQUE.length);
const apres=html.slice(fin);
fs.writeFileSync(path.join(racine,'index.html'),avant+json.trim()+';\n\n'+apres);
console.log('profil embarqué resynchronisé depuis presets/exemple.json');

// ── Nom du cache du service worker ────────────────────────────────────────
// sw.js demandait « à incrémenter à chaque publication qui change index.html ».
// Compter sur la discipline n'a pas marché : le nom est resté à v1 pendant une
// dizaine de publications. On le dérive donc de la page elle-même. Un appareil
// qui a déjà installé la checklist reçoit ainsi un cache neuf dès que la page
// change, au lieu de garder une version périmée hors ligne.
const crypto=require('crypto');
const empreinte=s=>crypto.createHash('sha256').update(s).digest('hex').slice(0,12);

const cheminSW=path.join(racine,'sw.js');
const sw=fs.readFileSync(cheminSW,'utf8');
const marque=empreinte(fs.readFileSync(path.join(racine,'index.html'),'utf8'));
const attendu='const CACHE = "migration-pc-'+marque+'";';
const remplace=sw.replace(/const CACHE = "migration-pc-[^"]*";/,attendu);
if(remplace===sw&&sw.indexOf(attendu)<0){
  console.error('ligne CACHE introuvable dans sw.js');process.exit(1);
}
if(remplace!==sw){
  fs.writeFileSync(cheminSW,remplace);
  console.log('cache du service worker : migration-pc-'+marque);
}else{
  console.log('cache du service worker déjà à jour');
}
