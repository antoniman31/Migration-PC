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
