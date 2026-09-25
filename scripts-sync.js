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
// Le profil de demonstration — celui qui porte les dix-huit applications d'une
// autre machine — est embarque lui aussi : il se charge a la demande depuis
// les Reglages, et la page doit marcher sans reseau depuis une cle USB.
const demo=fs.readFileSync(path.join(racine,'presets','demonstration.json'),'utf8');

function injecter(html,marque,fin,contenu,quoi){
  const debut=html.indexOf(marque);
  const f=html.indexOf(fin);
  if(debut<0||f<=debut){console.error(quoi+' introuvable dans index.html');process.exit(1);}
  JSON.parse(contenu);
  return html.slice(0,debut+marque.length)+contenu.trim()+';\n\n'+html.slice(f);
}

let sortie=injecter(html,'const PROFIL_DEFAUT = ','const PROFIL_DEMO',json,'PROFIL_DEFAUT');
sortie=injecter(sortie,'const PROFIL_DEMO = ','const CLE_PROFIL',demo,'PROFIL_DEMO');
fs.writeFileSync(path.join(racine,'index.html'),sortie);
console.log('profils embarqués resynchronisés depuis presets/');

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
