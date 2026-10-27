// La page en anglais ne doit plus contenir de francais.
//   node tests/test-anglais.js
//
// Ce test cherche ce qui NE DOIT PAS etre la, et c'est volontaire : un test qui
// verifie la presence de traductions se satisfait de la premiere, alors qu'un
// test qui refuse le francais ne passe que quand il n'en reste plus. C'est plus
// dur a tricher, et c'est la seule facon de savoir que la traduction est finie.
//
// CE QU'IL IGNORE, et pourquoi. Le contenu du profil — noms de logiciels,
// descriptions, intitules de categories venus d'un fichier etranger — n'est pas
// de l'interface : la page ne traduit pas plus une description de profil qu'elle
// ne traduit le nom d'un logiciel releve sur la machine. Ces textes sont donc
// retires avant l'examen, en les prenant dans le profil charge plutot qu'en les
// devinant.
//
// QUATRE DETECTIONS, parce qu'aucune ne suffit seule.
//   1. Les accents attrapent « Réinitialiser ».
//   2. La liste de mots attrape « Close the panel » laisse en « Fermer the
//      panel », qui n'a pas d'accent.
//   3. Les cles de la table, cherchees telles quelles : une cle qu'on lit encore
//      a l'ecran est un point d'appel qui ne passe pas par tr().
//   4. La page francaise et la page anglaise, comparees ligne a ligne : une
//      ligne identique des deux cotes n'a pas ete traduite.
//
// Les trois premieres dependent de quelque chose d'ecrit a la main, et la
// deuxieme a laisse passer « Passer » — pas d'accent, pas dans la liste. La
// quatrieme ne depend de rien et l'a trouve. Elle a aussi trouve « Site
// officiel » et « Ouvrir », deux intitules que les trois autres ignoraient.
//
// CE QU'AUCUNE DES QUATRE NE VOIT, et il faut le savoir : un intitule
// d'interface dont le texte est exactement celui d'une valeur du profil. Le
// retrait du profil l'efface des deux cotes. C'est le cas qu'a eu « Site
// officiel », intitule de lien ET valeur du champ src d'un logiciel : il a fallu
// le lire dans le code pour le voir. Le trou est etroit, mais il existe.
const {chromium}=require('playwright');
const path=require('path');

const HTML='file://'+path.join(__dirname,'..','index.html');
const lancement=process.env.CHROME?{executablePath:process.env.CHROME}:{};

let ko=0;
function ok(label,a,b){
  const bon=a===b;
  console.log((bon?'  ok  ':' FAIL ')+label+' → '+JSON.stringify(a)
    +(bon?'':' (attendu '+JSON.stringify(b)+')'));
  if(!bon)ko++;
}

// Des mots franceais qui ne sont pas des mots anglais. « Communication » et
// « Installation » s'ecrivent pareil dans les deux langues : les mettre ici
// produirait de fausses alertes.
const MOTS_FR=['le','la','les','des','une','pour','sur','dans','avec','sans',
  'tout','tous','toute','cette','cet','aucun','aucune','rien','votre','vos',
  'quand','donc','mais','ici','elle','ils','elles','est','sont','ont','fait',
  'faire','voir','lance','choisis','ce','qui','que','quoi','plus','moins',
  'encore','deja','ensuite','avant','apres','pendant','depuis','chaque',
  'autre','autres','meme','memes','peut','peuvent','doit','doivent','veut',
  'seul','seule','seulement','aussi','alors','ainsi','vers','chez','entre',
  'toujours','jamais','parfois','souvent','pourquoi','comment','ou','et',
  'fermer','annuler','effacer','cocher','decocher','ignorer','installer',
  'chercher','telecharger','importer','exporter','imprimer','reinitialiser',
  'manque','manquants','pilote','pilotes','logiciel','logiciels',
  'ordinateur','fichier','fichiers','dossier','liste','ligne','lignes',
  'onglet','onglets','releve','releves','constate','ecarte','ecartes'];
// « machine » et « scan » s'ecrivent pareil dans les deux langues, comme
// « installation » et « communication » : les mettre dans la liste produirait de
// fausses alertes a chaque passage.

function sansAccent(s){
  return s.normalize('NFD').replace(/[̀-ͯ]/g,'');
}

// Ce qui est du francais dans un texte : un accent, ou un mot de la liste
// entoure de separateurs. On rend les coupables pour pouvoir les corriger.
function francaisDans(texte){
  const trouves=[];
  // Le mot entier, pas seulement la lettre accentuee : « églages » ne dit pas
  // ou chercher, « Réglages » si.
  const accents=texte.match(/[^\s]*[éèêëàâäçùûüîïôöœæÉÈÊÀÂÇÙÛÎÏÔŒ][^\s]*/g);
  if(accents){
    const vusA={};
    accents.forEach(function(m){
      if(vusA[m])return; vusA[m]=true;
      if(Object.keys(vusA).length<=40)trouves.push('accent: '+m);
    });
  }
  // Le contexte avec le mot : « mot: la » ne dit pas ou chercher, la phrase si.
  const plat=sansAccent(texte).replace(/\s+/g,' ');
  const bas=plat.toLowerCase();
  const vus={};
  bas.split(/[^a-z0-9]+/).forEach(function(m){
    if(!m||MOTS_FR.indexOf(m)<0||vus[m])return;
    vus[m]=true;
    const mot=new RegExp('(^|[^a-z0-9])'+m+'([^a-z0-9]|$)');
    const trouve=mot.exec(bas);
    const i=trouve?trouve.index:0;
    trouves.push('mot « '+m+' » dans : …'+plat.slice(Math.max(0,i-45),i+55).trim()+'…');
  });
  return trouves;
}

(async()=>{
const b=await chromium.launch(lancement);
// Locale anglaise : la page doit s'ouvrir en anglais toute seule, sans qu'on
// clique. C'est le cas d'un anglophone qui arrive sur le lien publie.
const pg=await (await b.newContext({locale:'en-US'})).newPage();
const erreurs=[];
pg.on('pageerror',e=>erreurs.push(String(e)));
await pg.goto(HTML,{waitUntil:'networkidle'});

console.log('--- la page s\'ouvre en anglais toute seule ---');
ok('la langue suit le navigateur',await pg.evaluate(()=>LANG),'en');
ok('et le document le declare',
  await pg.evaluate(()=>document.documentElement.getAttribute('lang')),'en');
// Ces deux libelles disent l'etat et non un texte fixe : ils ne portent pas
// data-t, donc rien ne les traduit au chargement sauf l'appel du demarrage.
// Sans lui un anglophone lisait « Sombre » jusqu'a son premier changement de
// langue, et aucune autre verification ne passait par la.
ok('au demarrage, le libelle du theme est en anglais',
  await pg.evaluate(()=>document.getElementById('theme-lbl').textContent),'Dark');
ok('au demarrage, le libelle de l\'affichage est en anglais',
  await pg.evaluate(()=>document.getElementById('mode-lbl').textContent),'Compact view');

// Le profil livre est vide : sans l'exemple garni, les listes ne rendent rien et
// la moitie de l'interface ne s'affiche jamais. Un scan de cible par-dessus,
// pour faire apparaitre la comparaison, les badges, la vue « a installer » et
// l'onglet Pilotes dans son etat renseigne.
async function garnir(page){
  await page.evaluate(()=>{chargerDemo();});
  await page.waitForTimeout(300);
  await page.evaluate(()=>{
    const noms=APPS_DATA.slice(0,Math.max(1,APPS_DATA.length-2)).map(a=>a.n);
    INV_SOURCE={type:'inventaire-migration-pc',role:'source',
      machine:{nom:'PC-OLD',os:'Windows 11'},
      apps:APPS_DATA.map(a=>({nom:a.n,version:'1.0',winget:a.w||''})),
      materiel:{cm:'ASUS ROG STRIX B850-A'},pilotesTiers:[],pilotes:[]};
    INV_CIBLE={type:'inventaire-migration-pc',role:'cible',
      machine:{nom:'PC-NEW',os:'Windows 11',fabricant:'ASUS',modele:'B850-A'},
      apps:noms.map(n=>({nom:n,version:'1.0'})),
      materiel:{cm:'ASUS ROG STRIX B850-A'},
      pilotesTiers:[{classe:'Net',fournisseur:'Realtek',appareils:['Realtek Gaming GbE']}],
      pilotes:[{nom:'Card reader',probleme:'No driver',classe:'Unknown'}]};
    renderAll();updateGlobal();
  });
  await page.waitForTimeout(300);
}
await garnir(pg);

// Le texte du profil n'est pas de l'interface : on le retire avant d'examiner.
const duProfil=await pg.evaluate(()=>{
  const bouts=[];
  (APPS_DATA||[]).forEach(function(a){
    if(a.n)bouts.push(String(a.n));
    if(a.d)bouts.push(String(a.d));
    if(a.src)bouts.push(String(a.src));
  });
  (PWA_DATA||[]).forEach(function(p){
    if(p.n)bouts.push(String(p.n));
    if(p.d)bouts.push(String(p.d));
  });
  [INV_SOURCE,INV_CIBLE].forEach(function(inv){
    if(!inv)return;
    const m=inv.machine||{};
    ['nom','os','fabricant','modele','serie'].forEach(function(c){
      if(m[c])bouts.push(String(m[c]));
    });
    Object.keys(inv.materiel||{}).forEach(function(c){
      if(inv.materiel[c])bouts.push(String(inv.materiel[c]));
    });
    (inv.pilotesTiers||[]).forEach(function(p){
      if(p.fournisseur)bouts.push(String(p.fournisseur));
      if(p.classe)bouts.push(String(p.classe));
      (p.appareils||[]).forEach(function(a){bouts.push(String(a));});
    });
    (inv.pilotes||[]).forEach(function(p){
      ['nom','probleme','classe'].forEach(function(c){
        if(p[c])bouts.push(String(p[c]));
      });
    });
  });
  if(typeof PROFIL_NOM==='string'&&PROFIL_NOM)bouts.push(PROFIL_NOM);
  if(typeof PROFIL_SOUS==='string'&&PROFIL_SOUS)bouts.push(PROFIL_SOUS);
  Object.keys(CONFIG||{}).forEach(function(k){if(CONFIG[k])bouts.push(String(CONFIG[k]));});
  return bouts;
});

const aTraduire=await pg.evaluate(bouts=>bouts.filter(function(s){
  return TRADUCTIONS.en[s]!==undefined;
}),duProfil);
const sansEntree=duProfil.filter(s=>aTraduire.indexOf(s)<0);

function retirerProfil(texte){
  let t=texte;
  // Les plus longs d'abord : retirer « Firefox » avant « Mozilla Firefox »
  // laisserait « Mozilla », qui n'est pas du francais mais brouille la lecture.
  sansEntree.slice().sort((a,b)=>b.length-a.length).forEach(function(s){
    if(s.length<3)return;
    t=t.split(s).join(' ');
  });
  return t;
}

// Chaque onglet, puis chaque panneau : un texte francais cache derriere un
// bouton reste du francais a l'ecran. Le parcours est une fonction parce que le
// dernier controle le rejoue sur la page francaise, et qu'un parcours recopie
// aurait derive de celui-ci a la premiere modification.
async function parcourir(page){
  const out=[];
  for(const onglet of ['apps','pilotes','pwa']){
    await page.evaluate(o=>{switchTab(o);},onglet);
    await page.waitForTimeout(200);
    out.push(['onglet '+onglet,await page.evaluate(()=>document.body.innerText)]);
  }
  // La liste complete, derriere « Voir les N logiciels releves ».
  await page.evaluate(()=>{switchTab('apps');basculerListeComplete();});
  await page.waitForTimeout(200);
  out.push(['liste complete',await page.evaluate(()=>document.body.innerText)]);
  await page.evaluate(()=>{basculerListeComplete();});

  for(const [nom,fn] of [['configuration','basculerConfig'],
                         ['reinitialiser','basculerReglages'],
                         ['scripts','basculerOutils']]){
    await page.evaluate(f=>{window[f]();},fn);
    await page.waitForTimeout(250);
    out.push(['panneau '+nom,await page.evaluate(()=>document.body.innerText)]);
    await page.evaluate(f=>{window[f]();},fn);
  }
  // La recherche globale ne rend rien tant que le champ est vide. Deux
  // passages : une requete qui trouve, une qui ne trouve rien.
  for(const q of ['e','zzzzzz']){
    await page.evaluate(r=>{
      const c=document.getElementById('gsearch-input');
      c.value=r; globalSearch();
    },q);
    await page.waitForTimeout(200);
    out.push(['recherche globale « '+q+' »',await page.evaluate(()=>document.body.innerText)]);
  }
  await page.evaluate(()=>{
    const c=document.getElementById('gsearch-input');
    c.value=''; globalSearch();
  });

  // Le mode guide, qui a ses propres textes.
  await page.evaluate(()=>{basculerGuide();});
  await page.waitForTimeout(250);
  out.push(['mode guide',await page.evaluate(()=>document.body.innerText)]);
  await page.evaluate(()=>{basculerGuide();});
  return out;
}
const zones=await parcourir(pg);

console.log('\n--- aucun francais a l\'ecran ---');
let total=0;
for(const [nom,texte] of zones){
  const coupables=francaisDans(retirerProfil(texte));
  total+=coupables.length;
  if(coupables.length){
    console.log('   '+nom+' : '+coupables.length+' trouvaille(s)');
    coupables.slice(0,12).forEach(c=>console.log('      '+c));
  }
}
ok('rien de francais dans les zones visibles',total,0);

// Les attributs title et aria-label ne se voient pas a l'oeil mais se lisent au
// lecteur d'ecran. Ils sont examines a part pour que le message dise lequel.
console.log('\n--- ni dans les title et aria-label ---');
await pg.evaluate(()=>{switchTab('apps');});
await pg.waitForTimeout(200);
const attrs=await pg.evaluate(()=>{
  const out=[];
  document.querySelectorAll('[title],[aria-label]').forEach(function(n){
    if(n.closest('.hdr-lang'))return;
    const t=n.getAttribute('title'); const a=n.getAttribute('aria-label');
    if(t)out.push(t); if(a)out.push(a);
  });
  return out;
});
const coupablesAttrs=francaisDans(retirerProfil(attrs.join(' | ')));
if(coupablesAttrs.length)coupablesAttrs.slice(0,15).forEach(c=>console.log('      '+c));
ok('rien de francais dans les attributs',coupablesAttrs.length,0);

console.log('\n--- le profil d\'exemple est declare en entier ---');
// Les noms propres de l'exemple, nommes un par un. Un nom de logiciel ne se
// traduit pas ; le jour ou l'exemple change, cette liste le dit tout de suite
// au lieu de laisser passer un texte francais.
const NOMS_PROPRES=['7-Zip','VLC','PowerToys','HWiNFO64','CrystalDiskInfo','Git',
  'Node.js','Python','Visual Studio Code','Windows Terminal','PowerShell 7',
  'Steam','Discord','GitHub','Microsoft Store'];
const nonDeclares=await pg.evaluate(props=>{
  const manque=[];
  function voir(s){
    if(!s||typeof s!=='string')return;
    if(props.indexOf(s)>=0)return;
    if(TRADUCTIONS.en[s]!==undefined)return;
    if(manque.indexOf(s)<0)manque.push(s);
  }
  (PROFIL_DEMO.apps||[]).forEach(function(a){voir(a.n);voir(a.d);voir(a.src);});
  (PROFIL_DEMO.pwa||[]).forEach(function(p){voir(p.n);voir(p.d);});
  Object.keys(PROFIL_DEMO.cats||{}).forEach(function(k){voir(PROFIL_DEMO.cats[k]);});
  voir((PROFIL_DEMO.meta||{}).nom); voir((PROFIL_DEMO.meta||{}).soustitre);
  return manque;
},NOMS_PROPRES);
nonDeclares.slice(0,15).forEach(function(s){
  console.log('      ni traduit ni declare nom propre : '+JSON.stringify(s));
});
ok('tout le profil d\'exemple est traduit ou declare',nonDeclares.length,0);

console.log('\n--- ni aucune cle de la table, lue telle quelle ---');
const tousTextes=zones.map(function(z){return z[1];}).join('\n')+'\n'+attrs.join(' | ');
const platTextes=retirerProfil(tousTextes).replace(/\s+/g,' ');
// Les cles dont la traduction est le texte francais lui-meme sont voulues :
// « SSD », « Wi-Fi », « 💬 Communication » s'ecrivent pareil dans les deux
// langues. Les chercher signalerait chaque passage.
const cles=await pg.evaluate(()=>Object.keys(TRADUCTIONS.en)
  .filter(function(k){return TRADUCTIONS.en[k]!==k;})
  // Une cle qui porte du HTML est posee par data-t-html : innerText n'en rend
  // que le texte, la chercher telle quelle ne trouverait jamais rien. Les
  // balises sont donc retirees des deux cotes.
  .map(function(k){return [k,k.replace(/<[^>]+>/g,'')];})
  // Les trous {0} sont remplis a l'affichage : on ne cherche que le debut,
  // assez long pour ne pas se confondre avec autre chose.
  .map(function(pr){const c=pr[1].split('{')[0].trim();return [pr[0],c];})
  .filter(function(pr){return pr[1].length>=8;}));
const restees=cles.filter(function(pr){return platTextes.indexOf(pr[1])>=0;});
restees.slice(0,15).forEach(function(pr){
  console.log('      cle lue en anglais : '+JSON.stringify(pr[0]));
});
ok('aucune cle francaise ne subsiste',restees.length,0);

// ── Le controle qui ne peut pas oublier de mot ──────────────────────────
// Les trois precedents dependent tous de quelque chose d'ecrit a la main : une
// liste de mots forcement incomplete, une table qui ne se cherche qu'elle-meme.
// Celui-ci ne depend de rien : on rend la meme page dans les deux langues, et
// une ligne identique des deux cotes est une ligne qui n'a pas ete traduite.
// Il a trouve « Site officiel » et « Ouvrir » que les trois autres laissaient
// passer — le premier parce que le profil porte le meme texte, donc le retrait
// du profil effacait aussi la faute de l'interface.
console.log('\n--- la page francaise et la page anglaise ne se ressemblent pas ---');
const pgFr=await (await b.newContext({locale:'fr-FR'})).newPage();
await pgFr.goto(HTML,{waitUntil:'networkidle'});
await garnir(pgFr);
const zonesFr=await parcourir(pgFr);

// Ce qui a le droit d'etre identique, nomme un par un. Une liste de lignes
// explicites se relit et se discute, contrairement a un dictionnaire de mots.
const IDENTIQUES_VOULUES=[
  'SSD','Wi-Fi','Sections','FR','EN',          // sigles, et le selecteur de langue
  '💬 Communication',                          // s'ecrit pareil dans les deux langues
  '⬇️ winget .json',                           // un nom de format, pas une phrase
  'Migration PC.bat',                          // un nom de fichier
  '📋 winget'                                  // le nom de la commande, pas une phrase
];
function ligneNeutre(l){
  if(!l)return true;
  if(IDENTIQUES_VOULUES.indexOf(l)>=0)return true;
  if(l.indexOf('⬇️ winget .json')===0)return true;   // « (1) » derriere
  if(/^[^A-Za-z]*$/.test(l))return true;             // emoji, fleches, « 16/18 »
  if(/\.(ps1|bat|json|js|html|zip)$/.test(l))return true;
  if(l.indexOf('winget install ')===0)return true;   // une commande, pas un texte
  return false;
}
const platFr=zonesFr.map(z=>z[1]).join('\n');
const platEn=zones.map(z=>z[1]).join('\n');
function lignesDe(s){
  return retirerProfil(s).split('\n').map(x=>x.trim()).filter(x=>!ligneNeutre(x));
}
const vuesEn={}; lignesDe(platEn).forEach(function(l){vuesEn[l]=true;});
const dejaDit={}; const identiques=[];
lignesDe(platFr).forEach(function(l){
  if(!vuesEn[l]||dejaDit[l])return; dejaDit[l]=true; identiques.push(l);
});
identiques.slice(0,15).forEach(function(l){
  console.log('      identique dans les deux langues : '+JSON.stringify(l));
});
ok('aucune ligne francaise ne survit en anglais',identiques.length,0);

// ── ce que la traduction ne doit PAS toucher ────────────────────────────
// Un profil exporte depuis la page anglaise doit repartir avec son texte
// d'origine : le reecrire en anglais rendrait a son auteur un fichier dans une
// langue qu'il n'a pas choisie, et la page francaise de la machine suivante
// afficherait de l'anglais. De meme une recherche web doit porter le nom reel
// du logiciel : chercher « Web browser » ne trouve aucun programme.
console.log('\n--- la traduction ne touche ni l\'export ni les liens ---');
const garde=await pg.evaluate(()=>{
  const p=profilCourant();
  const app=(p.apps||[]).find(function(a){return a.n==='7-Zip';})||{};
  switchTab('apps'); basculerListeComplete();
  const liens=[].slice.call(document.querySelectorAll('#list-apps .lnk-btn'))
    .map(function(a){return a.getAttribute('href')||'';});
  basculerListeComplete();
  return {nom:p.meta.nom,desc:app.d||'',pwa:(p.pwa[0]||{}).n||'',
    href:liens.filter(function(h){return h.indexOf('7-zip')>=0;})[0]||liens.join(' ')};
});
ok('le nom du profil exporte reste le francais',
  garde.nom,'Migration Windows — exemple garni');
ok('la description exportee reste le francais',
  garde.desc,"Gestionnaire d'archives. À installer en premier pour ouvrir tout le reste.");
ok('le nom de raccourci exporte reste le francais',garde.pwa,'Messagerie web');
ok('le lien de recherche porte le nom reel',garde.href.indexOf('7-zip')>=0,true);

// ── ce que la page DIT ──────────────────────────────────────────────────
// LE TROU QUE LES SECTIONS D'AVANT LAISSAIENT. Elles regardent l'ecran : ce qui
// y est quand le test passe. Un message n'y est qu'au moment ou il est dit —
// « Fichier illisible », « Configuration effacee », l'etat d'un bouton apres un
// clic — et aucun scenario ne les declenchait. Dix-sept messages sont restes en
// francais dans une page declaree entierement traduite, et ce test passait.
//
// Celui-ci DECLENCHE chaque cas pour de vrai, dans les deux langues, et lit ce
// que la page a dit. Trois exigences par cas, parce qu'une seule se contourne :
//   - la page a parle, dans les deux langues. Un scenario qui ne declenche
//     rien passerait sans rien prouver, et c'est le piege de toutes les
//     assertions creuses de ce projet ;
//   - rien de francais en anglais ;
//   - le texte anglais differe du francais — ce qui attrape un message qui
//     retombe sur le francais faute de cle, meme sans accent ni mot de la liste.
// Et, pour les phrases dont la composition a change, le francais exact : une
// phrase entiere par cas ne doit pas deplacer un mot du francais d'avant.
//
// CE QUE LE CONTROLE STATIQUE DE test-langue.js FAIT A COTE : il lit le code a
// chaque endroit ou la page parle et refuse un texte brut. Il ne voit pas un
// message construit dans une variable — c'est ce que celui-ci couvre.
console.log('\n--- ce que la page dit : messages, provenance, bascules ---');
const pm=await (await b.newContext({locale:'en-US'})).newPage();
const erreursDit=[];
pm.on('pageerror',e=>erreursDit.push(String(e)));
await pm.goto(HTML,{waitUntil:'networkidle'});
await garnir(pm);

async function parler(run,zone){
  await pm.evaluate(()=>{
    masquerAnnulation();masquerPanne();
    document.getElementById('annul-txt').textContent='';
    document.getElementById('panne-detail').textContent='';
  });
  await pm.evaluate(run);
  await pm.waitForTimeout(80);
  return pm.evaluate(z=>document.getElementById(z==='p'?'panne-detail':'annul-txt').textContent,zone||'b');
}
function verdict(t){
  const pb=[];
  if(!t.fr||t.fr.indexOf('ERREUR')===0)pb.push('rien en fr : '+t.fr);
  if(!t.en||t.en.indexOf('ERREUR')===0)pb.push('rien en en : '+t.en);
  if(!pb.length&&t.en===t.fr)pb.push('identique dans les deux langues');
  if(!pb.length)francaisDans(t.en).forEach(function(f){pb.push(f);});
  return pb.join(' ; ');
}
// Des noms anglais pour les donnees de test : un nom francais serait pris pour
// du francais non traduit, alors que c'est le contenu d'un profil.
const DONNEES='const inv=function(role,apps,plus){return Object.assign({type:"inventaire-migration-pc",role:role,'
  +'apps:apps.map(function(n){return {nom:n,version:"1.0"};})},plus||{});};';
const SCENARIOS=[
  {nom:'export du profil',
   run:()=>{exportProfil();},
   fr:'Profil et progression exportés dans un seul fichier.'},
  {nom:'instantane trop gros pour la memoire du navigateur',
   run:()=>{const o=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw new Error('quota');};
     try{memoriserInstantane('mpc_source_v1',{type:'inventaire-migration-pc',apps:[]});}
     finally{Storage.prototype.setItem=o;}},
   fr:"L'instantané est trop gros pour être gardé en mémoire du navigateur. Il reste utilisable maintenant, mais il faudra le réimporter après un rechargement."},
  {nom:'export winget, un paquet',
   run:()=>{traiterDonnees({$schema:'https://aka.ms/winget-packages.schema.2.0.json',Sources:[{Packages:[{PackageIdentifier:'Git.Git'}]}]},'');},
   fr:'Export winget importé : 1 paquet. Les noms sont déduits des identifiants.'},
  {nom:'export winget, deux paquets',
   run:()=>{traiterDonnees({$schema:'https://aka.ms/winget-packages.schema.2.0.json',Sources:[{Packages:[{PackageIdentifier:'Git.Git'},{PackageIdentifier:'Mozilla.Firefox'}]}]},'');},
   fr:'Export winget importé : 2 paquets. Les noms sont déduits des identifiants.'},
  {nom:'provenance : fichier depose par le scanner',
   run:()=>{traiterDonnees({$schema:'https://aka.ms/winget-packages.schema.2.0.json',Sources:[{Packages:[{PackageIdentifier:'Git.Git'}]}]},tr('fichier déposé par le scanner'));},
   fr:'Export winget importé : 1 paquet. Les noms sont déduits des identifiants. — fichier déposé par le scanner'},
  {nom:'scan de la cible sans instantane de la source',
   run:new Function(DONNEES+'INV_SOURCE=null;traiterDonnees(inv("cible",["Alpha"]),"");'),
   fr:"Scan du PC cible reçu, mais aucun instantané du PC source à comparer. Importe d'abord celui que tu as pris avant d'effacer."},
  {nom:'scan de la cible : il en reste',
   run:new Function(DONNEES+'INV_SOURCE=inv("source",["Alpha","Beta"]);traiterDonnees(inv("cible",["Alpha"]),"");'),
   fr:'Scan du PC cible reçu : 1 sur 2 éléments sont déjà là, il en reste 1.'},
  {nom:'scan de la cible : tout y est',
   run:new Function(DONNEES+'INV_SOURCE=inv("source",["Alpha"]);traiterDonnees(inv("cible",["Alpha"]),"");'),
   fr:'Scan du PC cible reçu : 1 sur 1 éléments sont déjà là, tout y est.'},
  {nom:'scan sans application, sans materiel',
   run:new Function(DONNEES+'CONFIG={};traiterDonnees(inv("source",[]),"");'),
   fr:"Scan reçu, mais aucune application détectée. Sur une machine neuve c'est normal ; sinon, relancez avec -ToutInclure."},
  {nom:'scan sans application, un composant repris',
   run:new Function(DONNEES+'CONFIG={};traiterDonnees(inv("source",[],{materiel:{cm:"Board Alpha"}}),"");'),
   fr:"Scan reçu, mais aucune application détectée. Le matériel a été repris (1 composant). Sur une machine neuve c'est normal ; sinon, relancez avec -ToutInclure."},
  {nom:'scan sans application, deux composants repris',
   run:new Function(DONNEES+'CONFIG={};traiterDonnees(inv("source",[],{materiel:{cm:"Board Alpha",gpu:"Card Beta"}}),"");'),
   fr:"Scan reçu, mais aucune application détectée. Le matériel a été repris (2 composants). Sur une machine neuve c'est normal ; sinon, relancez avec -ToutInclure."},
  {nom:'inventaire importe, une application',
   run:new Function(DONNEES+'traiterDonnees(inv("source",["Alpha"]),"");'),
   fr:'Inventaire importé : 1 application.'},
  {nom:'inventaire importe, trois applications',
   run:new Function(DONNEES+'traiterDonnees(inv("source",["Alpha","Beta","Gamma"]),"");'),
   fr:'Inventaire importé : 3 applications.'},
  {nom:'provenance : date et machine du scan local',
   run:new Function(DONNEES+'window.MIGRATION_PC_SCAN=inv("source",["Alpha"],{genere:"2026-10-01T10:00:00",machine:{nom:"PC-X"}});'
     +'try{localStorage.removeItem(CLE_SCAN);}catch(e){}scanEnAttente=null;appliquerScanLocal();'),
   fr:'Inventaire importé : 1 application. — fichier déposé par le scanner du 2026-10-01 sur PC-X'},
  {nom:'provenance : rejouer le scan local',
   run:new Function(DONNEES+'scanEnAttente=inv("source",["Alpha"],{genere:"2026-10-01T10:00:00"});rejouerScanLocal();'),
   fr:'Inventaire importé : 1 application. — fichier déposé par le scanner du 2026-10-01'},
  {nom:'rejouer le scan local sans scan',
   run:()=>{scanEnAttente=null;rejouerScanLocal();},
   fr:'Aucun fichier de scan à côté de cette page.'},
  {nom:'profil importe',
   run:()=>{chargerDemo();traiterDonnees(profilCourant(),'');},
   frRe:/^Profil importé : \d+ éléments\.$/},
  {nom:'profil importe avec sa progression',
   run:()=>{chargerDemo();const p=profilCourant();p.state={checked:{x:true,y:true},dates:{}};traiterDonnees(p,'');},
   frRe:/^Profil importé : \d+ éléments, dont 2 cochés\.$/},
  {nom:'progression importee, une tache',
   run:()=>{traiterDonnees({state:{checked:{a1:true},dates:{}}},'');},
   fr:'Progression importée : 1 tâche cochée.'},
  {nom:'progression importee, deux taches',
   run:()=>{traiterDonnees({state:{checked:{a1:true,a2:true},dates:{}}},'');},
   fr:'Progression importée : 2 tâches cochées.'},
  {nom:'format non reconnu',
   run:()=>{traiterDonnees({x:1},'');},
   fr:'Format non reconnu. Attendu : un export winget, un inventaire de scan-pc.ps1, un profil, ou une progression exportée depuis cette page.'},
  {nom:'cocher avant son prerequis',
   run:()=>{chargerDemo();APPS_DATA[0].n='Alpha';APPS_DATA[1].n='Beta';APPS_DATA[1].dep=[APPS_DATA[0].id];
     S.checked={};toggle(APPS_DATA[1].id,'Beta');},
   fr:'« Beta » se fait normalement après : Alpha.'},
  {nom:'verification : tout est deja coche',
   run:()=>{chargerDemo();S.checked={};const id=APPS_DATA[0].id;S.checked[id]=true;
     afficherVerification({type:'verification-migration-pc',trouves:[{id:id}]});},
   fr:'Rien de nouveau à cocher : 1 élément(s) détecté(s) sont déjà cochés.'},
  {nom:'verification : inconnu du profil',
   run:()=>{chargerDemo();S.checked={};
     afficherVerification({type:'verification-migration-pc',trouves:[{id:'zz-inconnu'}]});},
   fr:'Rien de nouveau à cocher : 1 élément(s) détecté(s) ne figurent pas dans le profil chargé.'},
  {nom:'verification : deja coche et inconnu',
   run:()=>{chargerDemo();S.checked={};const id=APPS_DATA[0].id;S.checked[id]=true;
     afficherVerification({type:'verification-migration-pc',trouves:[{id:id},{id:'zz-inconnu'}]});},
   fr:'Rien de nouveau à cocher : 1 élément(s) détecté(s) sont déjà cochés. 1 élément(s) détecté(s) ne figurent pas dans le profil chargé.'},
  {nom:'verification : rien detecte',
   run:()=>{chargerDemo();S.checked={};afficherVerification({type:'verification-migration-pc',trouves:[]});},
   fr:"Aucun des éléments du profil n'a été détecté sur cette machine."},
  {nom:'verification appliquee, deux cases',
   run:()=>{chargerDemo();S.checked={};
     afficherVerification({type:'verification-migration-pc',trouves:[{id:APPS_DATA[0].id},{id:APPS_DATA[1].id}]});
     appliquerVerification();},
   fr:'2 cases cochées depuis la vérification du PC.'},
  {nom:'verification appliquee, une case',
   run:()=>{chargerDemo();S.checked={};
     afficherVerification({type:'verification-migration-pc',trouves:[{id:APPS_DATA[0].id}]});
     appliquerVerification();},
   fr:'1 case cochée depuis la vérification du PC.'},
  {nom:'verification appliquee, aucune case',
   run:()=>{chargerDemo();S.checked={};
     afficherVerification({type:'verification-migration-pc',trouves:[{id:APPS_DATA[0].id}]});
     [].slice.call(document.querySelectorAll('#verif input[type=checkbox]')).forEach(function(c){c.checked=false;});
     appliquerVerification();},
   fr:"Aucun élément sélectionné : rien n'a été coché."},
  {nom:'tout decocher, rien a decocher',
   run:()=>{S.checked={};toutDecocher();},
   fr:"Rien à décocher : aucune case n'est cochée."},
  {nom:'tout decocher, une case',
   run:()=>{S.checked={a1:true};S.dates={};toutDecocher();},
   fr:'1 case décochée sur toute la checklist. Le profil, la configuration et les lignes écartées sont conservés.'},
  {nom:'tout decocher, deux cases',
   run:()=>{S.checked={a1:true,a2:true};S.dates={};toutDecocher();},
   fr:'2 cases décochées sur toute la checklist. Le profil, la configuration et les lignes écartées sont conservés.'},
  {nom:'configuration deja vide',
   run:()=>{CONFIG={};viderConfig();},
   fr:'La configuration est déjà vide.'},
  {nom:'configuration effacee',
   run:()=>{CONFIG={cm:'Board Alpha'};viderConfig();},
   fr:'Configuration effacée.'},
  {nom:'ignorer une ligne',
   run:()=>{chargerDemo();IGNORES={};basculerIgnore(APPS_DATA[0].id,'Alpha');},
   fr:'« Alpha » ignoré : il sort des comptes et du script winget.'},
  {nom:'reprendre une ligne ignoree',
   run:()=>{chargerDemo();IGNORES={};IGNORES[APPS_DATA[0].id]=true;basculerIgnore(APPS_DATA[0].id,'Alpha');},
   fr:'« Alpha » revient dans la liste.'},
  {nom:'sauvegarde retablie',
   run:()=>{const o=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw new Error('quota');};
     try{saveState();}finally{Storage.prototype.setItem=o;}
     masquerPanne();document.getElementById('annul-txt').textContent='';saveState();},
   fr:'Sauvegarde rétablie : la progression est de nouveau enregistrée.'},
  {nom:'sauvegarde refusee (panneau de panne)', zone:'p',
   run:()=>{stockageEnPanne=false;const o=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw new Error('quota');};
     try{saveState();}finally{Storage.prototype.setItem=o;}},
   fr:"Sauvegarde : le navigateur refuse d'enregistrer (stockage plein ou bloqué). Votre travail reste à l'écran mais sera perdu au rechargement : exportez-le avec « Exporter le profil »."},
  {nom:'etiquette d\'une panne (panneau de panne)', zone:'p',
   run:()=>{proteger('Logiciels',function(){throw new Error('boom');});},
   fr:'Logiciels : boom'},
  // DEUX BRANCHES, et le test doit choisir : remiseAZero() dit une phrase quand
  // un profil etait memorise et en ecrase une autre quand il n'y en avait pas.
  // Sans choisir, le francais et l'anglais prenaient la branche qui restait
  // apres le passage precedent, et ne comparaient plus la meme phrase.
  {nom:'remise a zero du site, avec un profil memorise',
   run:()=>{chargerDemo();localStorage.setItem(CLE_PROFIL,JSON.stringify(profilCourant()));remiseAZero();},
   fr:'Site remis à zéro : progression, configuration, lignes écartées et profil importé effacés.'},
  {nom:'remise a zero du site, sans profil memorise',
   run:()=>{localStorage.removeItem(CLE_PROFIL);remiseAZero();},
   fr:'Site remis à zéro : progression, notes et clés effacées.'},
];
for(const sc of SCENARIOS){
  const t={};
  for(const l of ['fr','en']){
    await pm.evaluate(x=>setLangue(x),l);
    try{ t[l]=await parler(sc.run,sc.zone); }
    catch(e){ t[l]='ERREUR : '+String(e).slice(0,140); }
  }
  console.log('      ['+sc.nom+']  fr: '+JSON.stringify(t.fr)+'   en: '+JSON.stringify(t.en));
  ok(sc.nom+' : la page parle, en anglais sans francais',verdict(t),'');
  if(sc.fr!==undefined)ok(sc.nom+' : le francais est inchange',t.fr,sc.fr);
  if(sc.frRe)ok(sc.nom+' : le francais a la forme attendue',sc.frRe.test(t.fr),true);
}

// Ce qui s'ecrit sur un bouton apres un clic, et l'echec de la copie.
console.log('\n--- apres un clic : copie, bascules, indicateur de sauvegarde ---');
async function copie(lang){
  await pm.evaluate(x=>setLangue(x),lang);
  return pm.evaluate(async()=>{
    const faux=function(){const el={innerHTML:'avant'};return {el:el,stopPropagation(){},target:{closest(){return el;}}};};
    Object.defineProperty(navigator,'clipboard',{value:{writeText:()=>Promise.resolve()},configurable:true});
    const e1=faux();copyWinget('Git.Git',e1);
    await new Promise(function(r){setTimeout(r,50);});
    const reussi=e1.el.innerHTML;
    Object.defineProperty(navigator,'clipboard',{value:{writeText:()=>Promise.reject(new Error('refus'))},configurable:true});
    masquerAnnulation();document.getElementById('annul-txt').textContent='';
    copierCommande('winget install X',faux());
    await new Promise(function(r){setTimeout(r,50);});
    return {reussi:reussi,echec:document.getElementById('annul-txt').textContent};
  });
}
const cFr=await copie('fr'), cEn=await copie('en');
ok('copie reussie : le bouton le dit en francais',cFr.reussi,'✓ Copié !');
ok('copie reussie : et en anglais',cEn.reussi,'✓ Copied!');
ok('copie impossible : le message en francais',cFr.echec,'Copie impossible dans ce navigateur. Commande : winget install X');
ok('copie impossible : et en anglais',cEn.echec,'Copying is not possible in this browser. Command: winget install X');

// LE DEFAUT QUE CE BLOC A ATTRAPE. « Sombre » et « Affichage compact » portaient
// data-t, donc setLangue les reecrivait d'apres le texte vu au premier passage,
// sans regarder l'etat : apres un aller-retour de langue le bouton affichait
// « Dark » alors que le theme etait deja sombre. Un libelle qui ment sur l'etat
// est pire qu'un libelle dans la mauvaise langue.
const bas=await pm.evaluate(()=>{
  const lire=function(){return {theme:document.getElementById('theme-lbl').textContent,
    mode:document.getElementById('mode-lbl').textContent};};
  const r={};
  setLangue('en');isDark=false;applyTheme();setMode('normal');r.clair=lire();
  toggleTheme();setMode('compact');r.sombre=lire();
  setLangue('fr');r.sombreFr=lire();
  setLangue('en');r.sombreEn=lire();
  toggleTheme();setMode('normal');r.clairBis=lire();
  return r;
});
ok('theme clair, en anglais : le bouton propose le sombre',bas.clair.theme,'Dark');
ok('affichage normal, en anglais : le bouton propose le compact',bas.clair.mode,'Compact view');
ok('theme sombre : le bouton propose le clair',bas.sombre.theme,'Light');
ok('affichage compact : le bouton propose le normal',bas.sombre.mode,'Normal view');
ok('changer de langue ne change pas l\'etat : theme, en francais',bas.sombreFr.theme,'Clair');
ok('changer de langue ne change pas l\'etat : mode, en francais',bas.sombreFr.mode,'Affichage normal');
ok('et au retour en anglais le theme dit toujours la meme chose',bas.sombreEn.theme,'Light');
ok('et le mode aussi',bas.sombreEn.mode,'Normal view');
ok('revenir a l\'etat clair le redit',bas.clairBis.theme,'Dark');

const sauvegarde={};
for(const l of ['fr','en']){
  await pm.evaluate(x=>setLangue(x),l);
  sauvegarde[l]=await pm.evaluate(()=>{
    const el=document.getElementById('save-state');
    stockageEnPanne=false;S.lastSave=new Date(2026,9,1,14,5).getTime();updateSaveLabel();
    const bon={texte:el.textContent,titre:el.title};
    stockageEnPanne=true;updateSaveLabel();
    const ko={texte:el.textContent,titre:el.title};
    stockageEnPanne=false;S.lastSave=null;updateSaveLabel();
    return {bon:bon,ko:ko};
  });
}
ok('enregistre, en francais',sauvegarde.fr.bon.texte,'✓ enregistré 14:05');
ok('enregistre, en anglais',sauvegarde.en.bon.texte,'✓ saved 14:05');
ok('non enregistre, en francais',sauvegarde.fr.ko.texte,'⚠ non enregistré');
ok('non enregistre, en anglais',sauvegarde.en.ko.texte,'⚠ not saved');
ok('l\'info-bulle de l\'indicateur : aucun francais en anglais',
  francaisDans(sauvegarde.en.bon.titre+' '+sauvegarde.en.ko.titre).join(' ; '),'');
ok('aucune erreur JS pendant ces scenarios',erreursDit.length?erreursDit[0]:'aucune','aucune');

ok('aucune erreur JS',erreurs.length?erreurs[0]:'aucune','aucune');
await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nANGLAIS : PLUS AUCUN FRANCAIS A L\'ECRAN');
process.exit(ko?1:0);
})();
