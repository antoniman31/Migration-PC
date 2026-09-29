// L'archive proposee au telechargement : ce qu'elle contient, et ce qu'elle
// ne contient pas.
//
//   node tests/test-archive.js
//
// Le bouton de la page ne propose plus les fichiers un par un — un script pris
// isolement s'arrete faute de lib-detection.ps1 a cote de lui. Il n'y a donc
// qu'une archive, et elle doit etre exacte dans les deux sens : rien ne
// manque, et rien de superflu n'est embarque.
const {execFileSync}=require('child_process');
const fs=require('fs'),os=require('os'),path=require('path');
const racine=path.join(__dirname,'..');

let ko=0;
const ok=(l,a,b)=>{const p=(b===undefined?!!a:a===b);
  console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(b)+')'));
  if(!p)ko++;};

const bac=fs.mkdtempSync(path.join(os.tmpdir(),'zip-'));
execFileSync(path.join(racine,'construire-zip.sh'),[bac],{cwd:racine});
const dedans=execFileSync('unzip',['-Z1',path.join(bac,'migration-pc.zip')])
  .toString().trim().split('\n').sort();

console.log('--- ce qui doit y etre ---');
// Sans l'un de ces trois, rien ne se lance : la page, le point d'entree, et
// la bibliotheque dont tous les scripts dependent.
['index.html','Migration PC.bat','scripts/lib-detection.ps1'].forEach(f=>
  ok('« '+f+' » est dans l\'archive',dedans.indexOf(f)>=0,true));

// Tous les scripts du depot, sans exception : c'est le lanceur qui decide
// lequel tourne, et il les cherche tous a cote de lui.
const scripts=fs.readdirSync(path.join(racine,'scripts'))
  .filter(f=>/\.ps1$/i.test(f)).map(f=>'scripts/'+f).sort();
ok('des scripts existent',scripts.length>0,true);
ok('aucun script ne manque',scripts.filter(f=>dedans.indexOf(f)<0).join(', '),'');

// L'AGPL oblige a joindre la licence a toute redistribution. Ce n'est pas du
// superflu : c'est la condition pour avoir le droit de distribuer le reste.
ok('la licence est jointe',dedans.indexOf('LICENSE')>=0,true);

console.log('\n--- ce qui ne doit PAS y etre ---');
// « Uniquement ce qui est necessaire pour executer le programme. » Les tests
// ne se lancent pas, les captures illustrent le README, et manifest/sw/icons
// ne servent qu'en ligne : depuis une cle USB la page s'ouvre en file://, ou
// un navigateur refuse d'enregistrer un service worker.
const interdits=[/^tests\//,/^captures\//,/^node_modules\//,/^\.github\//,
  /^presets\//,/^icons\//,/^manifest\.json$/,/^sw\.js$/,/^README\.md$/,
  /^package(-lock)?\.json$/,/\.sh$/];
const superflus=dedans.filter(f=>interdits.some(r=>r.test(f)));
ok('rien de superflu',superflus.join(', '),'');

console.log('\n--- l\'archive est petite ---');
// Une archive qui gonfle est le signe qu'on y a remis le depot entier.
const ko2=Math.round(fs.statSync(path.join(bac,'migration-pc.zip')).size/1024);
console.log('   → '+ko2+' Ko, '+dedans.length+' fichiers');
ok('moins d\'un mega-octet',ko2<1024,true);

// La page pointe vers cette archive, et vers elle seule.
const html=fs.readFileSync(path.join(racine,'index.html'),'utf8');
ok('la page pointe vers l\'archive',html.indexOf('href="migration-pc.zip"')>=0,true);
// Le lien vers l'archive automatique de GitHub emportait tout le depot.
ok('et plus vers l\'archive du dépôt',/archive\/refs\/heads/.test(html),false);

fs.rmSync(bac,{recursive:true,force:true});
console.log(ko?'\n'+ko+' EN ECHEC':'\nARCHIVE CONFORME');
process.exit(ko?1:0);
