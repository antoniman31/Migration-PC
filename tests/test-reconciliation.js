// La comparaison entre l'instantané du PC source et le scan du PC cible.
//   node tests/test-reconciliation.js
//
// Ces tests-là valent plus que les autres, et il faut dire pourquoi. Les
// détecteurs PowerShell sont testés contre ce que J'IMAGINE que Windows
// répond : une sortie de netsh inventée, une classe WMI simulée. Plusieurs
// défauts n'ont été trouvés qu'en confrontant le code à de vraies sorties.
// La comparaison, elle, porte sur deux fichiers JSON et rien d'autre. Elle ne
// dépend d'aucune machine. Ce qui passe ici passera à l'identique sur un vrai
// PC.
const fs=require('fs'),vm=require('vm'),path=require('path');
const racine=path.join(__dirname,'..');
const html=fs.readFileSync(path.join(racine,'index.html'),'utf8');
const blocs=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
const js=blocs.reduce((a,b)=>b.length>a.length?b:a);

const store={};
function mkEl(id){
  return {id,textContent:'',innerHTML:'',value:'',style:{},dataset:{},children:[],
    classList:{_s:new Set(),add(c){this._s.add(c)},remove(c){this._s.delete(c)},
      toggle(c,v){v===undefined?(this._s.has(c)?this._s.delete(c):this._s.add(c)):(v?this._s.add(c):this._s.delete(c))},
      contains(c){return this._s.has(c)}},
    setAttribute(){},getAttribute(){return null},appendChild(){},removeChild(){},
    click(){},focus(){},querySelector(){return null},querySelectorAll(){return []},
    addEventListener(){},getContext(){return null}};
}
const els={};
const document={documentElement:mkEl('html'),body:mkEl('body'),
  getElementById(id){if(!els[id])els[id]=mkEl(id);return els[id];},
  querySelectorAll(){return []},querySelector(){return null},
  createElement(t){return mkEl(t)},addEventListener(){},
  get title(){return this._t||''},set title(v){this._t=v}};
const ctx={document,console,
  window:{addEventListener(e,f){if(e==='DOMContentLoaded')ctx.__init=f;},matchMedia:()=>({matches:false}),print(){}},
  localStorage:{getItem:k=>store[k]===undefined?null:store[k],setItem:(k,v)=>{store[k]=String(v)},removeItem:k=>{delete store[k]}},
  setInterval:()=>0,clearInterval(){},setTimeout(f){},alert(){},confirm:()=>true,
  Blob:function(p){this.p=p},URL:{createObjectURL:()=>'blob:x'},FileReader:function(){},
  requestAnimationFrame(){},navigator:{clipboard:{writeText:()=>Promise.resolve()}}};
ctx.window.document=document;ctx.globalThis=ctx;
vm.createContext(ctx);vm.runInContext(js,ctx,{filename:'app.js'});
ctx.__init();
const G=expr=>vm.runInContext(expr,ctx);

let ko=0;
function ok(label,a,b){
  const bon=a===b;
  console.log((bon?'  ok  ':' FAIL ')+label+' → '+JSON.stringify(a)+(bon?'':' (attendu '+JSON.stringify(b)+')'));
  if(!bon)ko++;
}
const comparer=G('comparerInstantanes');
const famille=(r,cle)=>r.familles.filter(f=>f.cle===cle)[0];

console.log('\n--- normalisation des noms ---');
const cleNom=G('cleNom');
// Le cas qui décide de tout : le registre écrit « Mozilla Firefox (x64 fr) »,
// winget écrit « Mozilla Firefox ». Sans normalisation commune, la page
// annonce manquant un logiciel qui est installé.
ok('la parenthèse disparaît',cleNom('Mozilla Firefox (x64 fr)'),cleNom('Mozilla Firefox'));
ok('la version aussi',cleNom('7-Zip 24.09'),cleNom('7-Zip'));
ok('« Update 401 » aussi',cleNom('Java 8 Update 401'),cleNom('Java 8 Update 411'));
// Mais deux logiciels voisins ne doivent pas fusionner, sinon l'un des deux
// disparaît de la réconciliation sans que personne ne le voie.
ok('Notepad++ n\'est pas Notepad',cleNom('Notepad++')===cleNom('Notepad'),false);
ok('un nom vide',cleNom(''),'');
ok('un null',cleNom(null),'');

// Le contrat partagé avec PowerShell. La liste des manquants est calculée deux
// fois — ici par la page, et par le scan de la cible qui écrit le fichier
// « winget import » que le lanceur joue. Deux normalisations différentes
// rapprocheraient des logiciels différents de chaque côté, et personne ne
// verrait pourquoi. Ce fichier est la référence : tests/test-scan.ps1 le rejoue
// à l'identique, donc une divergence fait tomber l'un des deux.
const casCles=require('./cles-normalisation.json');
const divergents=casCles.filter(function(c){return cleNom(c.nom)!==c.cle;});
ok('les '+casCles.length+' clés du contrat partagé',
  divergents.map(function(c){return c.nom+'→'+cleNom(c.nom);}).join(', '),'');

console.log('\n--- comparaison de versions ---');
const cv=G('comparerVersions');
// Le piège classique : en texte, « 1.2.9 » est plus grand que « 1.2.10 ».
ok('1.2.10 est plus récent que 1.2.9',cv('1.2.10','1.2.9'),1);
ok('et l\'inverse',cv('1.2.9','1.2.10'),-1);
ok('identiques',cv('3.0.1','3.0.1'),0);
ok('longueurs différentes',cv('2.0','2.0.0'),0);
ok('illisible d\'un côté',cv('beta','1.0'),null);
ok('vide',cv('','1.0'),null);

console.log('\n--- rien à comparer ---');
ok('sans source',comparer(null,{}).ok,false);
ok('et on dit pourquoi',/instantané du PC source/.test(comparer(null,{}).raison),true);
ok('sans cible',comparer({},null).ok,false);
ok('et on dit quoi faire',/lance le même script/i.test(comparer({},null).raison),true);
ok('deux instantanés vides',comparer({},{}).total.attendu,0);

console.log('\n--- une migration à moitié faite ---');
const source={type:'inventaire-migration-pc',genere:'2026-09-26T09:00:00Z',
  machine:{os:'Windows 11 Pro',nom:'PC-SOURCE'},
  apps:[
    {nom:'Mozilla Firefox (x64 fr)',version:'142.0.1'},
    {nom:'7-Zip 24.09',version:'24.09'},
    {nom:'Visual Studio Code',version:'1.98.2'},
    {nom:'Krita',version:'5.2.6'}],
  outils:[{id:'npm:pnpm',nom:'pnpm',version:'10.4.1'},
          {id:'wsl:Ubuntu-24.04',nom:'Ubuntu 24.04',version:'2'}],
  configs:[{nom:'Clés SSH',chemin:'C:\\Users\\antoni\\.ssh',modele:'%USERPROFILE%\\.ssh'},
           {nom:'Visual Studio Code',chemin:'C:\\Users\\antoni\\AppData\\Roaming\\Code\\User',
            modele:'%APPDATA%\\Code\\User'}],
  mail:[{nom:'archive.pst',chemin:'C:\\a\\archive.pst',modele:'%USERPROFILE%\\Documents\\archive.pst',cache:false},
        {nom:'compte.ost',chemin:'C:\\a\\compte.ost',modele:'%LOCALAPPDATA%\\Microsoft\\Outlook\\compte.ost',cache:true}],
  wifi:[{nom:'Livebox-1234'},{nom:'Bureau-5G'}],
  variables:{JAVA_HOME:'C:\\Java',ANDROID_HOME:'C:\\Sdk'},
  // Familles d'état : elles décrivent la machine, pas ce qu'on transporte.
  materiel:{cm:'ASUS B850',cpu:'Ryzen 7'},
  licences:[{nom:'Windows',canal:'OEM'}]};

const cible={type:'inventaire-migration-pc',genere:'2026-09-27T14:00:00Z',
  machine:{os:'Windows 11 Pro',nom:'PC-CIBLE'},
  apps:[
    {nom:'Mozilla Firefox',version:'143.0'},
    {nom:'7-Zip',version:'24.09'},
    // Présent, mais dans une version PLUS ANCIENNE qu'avant : le seul écart
    // de version qui mérite d'être signalé.
    {nom:'Visual Studio Code',version:'1.90.0'}],
  outils:[{id:'npm:pnpm',nom:'pnpm',version:'10.4.1'}],
  configs:[{nom:'Clés SSH',chemin:'D:\\Users\\Antoni\\.ssh',modele:'%USERPROFILE%\\.ssh'}],
  mail:[],
  wifi:[{nom:'Livebox-1234'}],
  variables:{JAVA_HOME:'C:\\Java'},
  materiel:{cm:'MSI X870',cpu:'Ryzen 9'},
  licences:[{nom:'Windows',canal:'Retail'}]};

const r=comparer(source,cible);
ok('la comparaison aboutit',r.ok,true);
ok('les deux machines sont nommées',r.source.nom+'→'+r.cible.nom,'PC-SOURCE→PC-CIBLE');
ok('et datées',r.source.date+'→'+r.cible.date,'2026-09-26→2026-09-27');

const apps=famille(r,'apps');
ok('quatre applications attendues',apps.total,4);
// Firefox et 7-Zip se retrouvent malgré les parenthèses et le numéro de
// version collés au nom.
ok('trois sont arrivées',apps.arrives,3);
ok('une manque',apps.manquants.length,1);
ok('la bonne',apps.manquants[0].libelle,'Krita');
ok('une a régressé',apps.differents.length,1);
ok('la bonne',apps.differents[0].libelle,'Visual Studio Code');
ok('avec les deux versions',apps.differents[0].avant+'→'+apps.differents[0].apres,'1.98.2→1.90.0');
// Firefox est passé de 142 à 143 : plus récent, donc rien à signaler.
ok('une version plus récente ne dit rien',
  apps.differents.filter(d=>/Firefox/.test(d.libelle)).length,0);

// Personne n'attend que le PC neuf ait la même carte mère ni la même licence.
ok('le matériel n\'est pas comparé',famille(r,'materiel'),undefined);
ok('les licences non plus',famille(r,'licences'),undefined);
// Les familles retirées du projet ne doivent plus apparaître, même si un
// vieil instantané en porte encore.
ok('les réglages ne sont plus comparés',famille(r,'configs'),undefined);
ok('les archives mail non plus',famille(r,'mail'),undefined);
ok('le Wi-Fi non plus',famille(r,'wifi'),undefined);
ok('une seule famille en tout',r.familles.length,1);

console.log('\n--- le compte global ---');
// 4 apps, et rien d'autre : c'est tout ce que le projet compare.
ok('total attendu',r.total.attendu,4);
// Firefox, 7-Zip et VS Code sont là ; Krita manque.
ok('total arrivé',r.total.arrive,3);

console.log('\n--- une migration terminée ---');
const fini=comparer(source,Object.assign({},source,{genere:'2026-09-28T10:00:00Z'}));
ok('tout est arrivé',fini.total.arrive,fini.total.attendu);
ok('aucun manquant',fini.familles.every(f=>f.manquants.length===0),true);
ok('aucune régression',fini.familles.every(f=>f.differents.length===0),true);

console.log('\n--- entrées hostiles ---');
// Un instantané vient d'un fichier qu'on n'a pas écrit : il peut porter
// n'importe quoi. La comparaison ne doit pas tomber.
const hostile=comparer(
  {apps:[null,'x',{},{nom:'Krita'}]},
  {apps:'pas un tableau'});
ok('rien ne tombe',hostile.ok,true);
ok('les entrées vides sont ignorées',famille(hostile,'apps').total,1);
// Le compte doit toujours boucler : ce qui est attendu se retrouve soit
// arrivé, soit manquant, jamais nulle part.
const boucle=r.familles.every(f=>f.arrives+f.manquants.length===f.total);
ok('arrivés + manquants = attendus, partout',boucle,true);
ok('et sur le total global',
  r.familles.reduce((n,f)=>n+f.total,0),r.total.attendu);
ok('une famille non-tableau est ignorée',famille(hostile,'jeux'),undefined);

console.log('\n--- la liste des logiciels, avant le scan de la cible ---');
// Rien à comparer : la machine d'arrivée n'existe pas encore. La liste doit
// dire ce qu'elle deviendra, pas rester muette.
G('INV_SOURCE=null;INV_CIBLE=null;');
ok('sans rien, on n\'est pas sur la cible',G('surLaCible()'),false);
ok('et il n\'y a aucun état à afficher',G('etatsLogiciels()'),null);
vm.runInContext('INV_SOURCE='+JSON.stringify(source)+';INV_CIBLE=null;',ctx);
const tete=G('banniereComparaison()');
ok('le bandeau annonce la suite',/Scanne le PC receveur/.test(tete),true);
ok('et ne prétend comparer rien',/à installer/.test(tete),false);

console.log('\n--- la liste des logiciels, après le scan de la cible ---');
vm.runInContext('INV_SOURCE='+JSON.stringify(source)
  +';INV_CIBLE='+JSON.stringify(cible)+';',ctx);
ok('le scan de la cible fait basculer la vue',G('surLaCible()'),true);
const e=G('etatsLogiciels()');
ok('quatre logiciels attendus',e.total,4);
ok('trois sont arrivés',e.arrives,3);
ok('un manque',e.manquants,1);
ok('et un a régressé',e.differents,1);
const vue=G('banniereComparaison()');
ok('le compte est annoncé',/1 logiciel à installer/.test(vue),true);
ok('avec les deux machines',/PC-SOURCE/.test(vue)&&/PC-CIBLE/.test(vue),true);
ok('la régression est signalée',/version plus ancienne/.test(vue),true);

// Le badge que porte chaque ligne. C'est lui qui remplace l'onglet séparé.
ok('un logiciel présent est marqué « là »',
  /b-arrive/.test(G('badgeComparaison')({n:'7-Zip'},e)),true);
ok('un logiciel absent est marqué « manque »',
  /b-manque/.test(G('badgeComparaison')({n:'Krita'},e)),true);
ok('une version plus ancienne se voit',
  /b-vieux/.test(G('badgeComparaison')({n:'Visual Studio Code'},e)),true);
ok('sans comparaison, aucun badge',G('badgeComparaison')({n:'Krita'},null),'');

console.log('\n--- l\'onglet Pilotes ---');
// Il ne dit JAMAIS qu'une version plus récente existe : aucun appel réseau
// n'est fait, donc il ne peut pas le savoir.
const cibleP=Object.assign({},cible,{
  machine:{os:'Windows 11 Pro',nom:'PC-CIBLE',fabricant:'ASUSTeK',modele:'ROG STRIX B850-A',serie:'ABC123'},
  materiel:{cm:'ASUSTeK ROG STRIX B850-A'},
  pilotes:[{nom:'Contrôleur Ethernet',classe:'',probleme:'aucun pilote installe',code:28}],
  pilotesTiers:[{classe:'Net',fournisseur:'Realtek',appareils:['Realtek Gaming GbE']}]});
vm.runInContext('INV_CIBLE='+JSON.stringify(cibleP)+';',ctx);
G('renderPilotes()');
const pil=els['list-pilotes'].innerHTML;
ok('le périphérique en défaut est nommé',/Contrôleur Ethernet/.test(pil),true);
ok('le lien du constructeur est proposé',/support du constructeur/.test(pil),true);
ok('le modèle relevé y sert',/ROG STRIX B850-A/.test(pil),true);
ok('les pilotes en place sont listés',/Realtek/.test(pil),true);
ok('rien ne prétend qu\'une version est plus récente',
  /plus récente est disponible|mise à jour disponible/.test(pil),false);

console.log('\n--- le constat règle la ligne, la case décide ---');
// Avant, une case voulait dire « c'est installé » — ce que le scan sait déjà.
// Il fallait donc cocher soixante cases pour redire un constat, et un bouton
// « cocher ce qui est constaté » existait pour rattraper cette comptabilité en
// double. Les deux sont partis : le fait vient du scan, la case reste une
// décision, et la progression compte l'union des deux.
G('appliquerProfil')(G('inventaireVersProfil')(source),true);
vm.runInContext('INV_SOURCE='+JSON.stringify(source)
  +';INV_CIBLE='+JSON.stringify(cible)+';',ctx);
const avant=G('lignesConstatees()');
// Trois applications sur quatre : Krita n'est pas arrivé.
ok('trois lignes constatées présentes',avant.length,3);
ok('elles comptent comme faites',avant.every(id=>G('estFait')(id)),true);
// Et rien n'a été écrit dans le suivi manuel : c'est tout l'intérêt.
ok('sans rien écrire dans les cases',
  avant.filter(id=>G('S').checked[id]).length,0);

// La ligne que le scan n'a pas trouvée reste à décider, et cocher à la main
// marche toujours.
const absente=G('APPS_DATA').filter(a=>/Krita/.test(a.n))[0];
ok('la manquante n est pas faite',G('estFait')(absente.id),false);
G('toggle')(absente.id,absente.n);
ok('cochée à la main, elle est faite',G('estFait')(absente.id),true);
ok('et la case porte bien la décision',G('S').checked[absente.id],true);

// Le bouton disparu ne doit pas revenir par une autre porte.
ok('plus de bouton « cocher le constaté »',
  typeof G('window').cocherLeConstate,'undefined');

// La ligne constatée s'affiche réglée et non cliquable : un contrôle qui ne
// répond pas au clic sans le dire passe pour un défaut.
G('renderApps()');
const htmlApps=G('document').getElementById('list-apps').innerHTML;
ok('la ligne constatée est marquée',/lg-constate/.test(htmlApps),true);
ok('et annoncée désactivée',/aria-disabled="true"/.test(htmlApps),true);
ok('le bandeau explique la règle',/r[ée]gl[ée]e?s? d.office/.test(htmlApps),true);
// Une ligne constatée ne porte pas de gestionnaire de bascule : c'est ce qui
// garantit qu'un clic ne peut pas décocher un fait. Vérifié sur le HTML plutôt
// que par un sélecteur : le DOM de ces tests est un mannequin, son
// querySelectorAll ne reconstruit pas l'arbre depuis innerHTML.
const blocsLignes=htmlApps.split('<div class="lg-l').slice(1);
const cst=blocsLignes.filter(function(b){return /^[^>]*lg-constate/.test(b);});
ok('des lignes constatées sont rendues',cst.length,3);
ok('aucune bascule sur une ligne constatée',
  cst.every(function(b){return !/onclick="toggle/.test(b.split('lg-n')[0]);}),true);
// Et une ligne encore à décider garde la sienne, sinon on aurait tout bloqué.
const libres=blocsLignes.filter(function(b){return !/^[^>]*lg-constate/.test(b);});
ok('la ligne à décider reste cliquable',
  libres.length>0&&libres.every(function(b){return /onclick="toggle/.test(b.split('lg-n')[0]);}),true);

// Le mode guidé ne propose pas d'installer ce que la machine porte déjà.
const restantes=G('tachesRestantes')().map(function(e){return e.id;});
ok('le guidé saute les constatées',
  avant.filter(id=>restantes.indexOf(id)>=0).length,0);


console.log('\n--- le relais par la clé USB ---');
// Le cas qui compte pour la procédure réelle : on scanne la source, on
// débranche la clé, on la branche sur le PC cible, on scanne. Le navigateur du
// PC cible n'a JAMAIS vu l'instantané de la source — sa mémoire locale est
// vide. Sans le relais, la page reçoit un scan de cible et n'a rien à
// comparer : c'est exactement le moment où l'utilisateur attend une réponse.
G('INV_SOURCE=null;INV_CIBLE=null;');
try{Object.keys(store).forEach(k=>delete store[k]);}catch(e){}
// Le champ « role » est ce qui aiguille : sans lui la page prendrait le scan
// de la cible pour un nouvel inventaire et remplacerait la checklist par la
// liste — vide — de la machine neuve. Les vrais instantanés le portent.
vm.runInContext('window.MIGRATION_PC_SOURCE='+JSON.stringify(Object.assign({},source,{role:'source'}))
  +';window.MIGRATION_PC_SCAN='+JSON.stringify(Object.assign({},cible,{role:'cible'}))+';',ctx);
G('appliquerScanLocal()');
ok('la source est arrivée par la clé',!!G('INV_SOURCE'),true);
ok('et la cible avec elle',!!G('INV_CIBLE'),true);
const relais=G('comparerInstantanes(INV_SOURCE,INV_CIBLE)');
ok('la comparaison se fait sans rien importer à la main',relais.ok,true);
ok('et elle trouve ce qui manque',relais.total.attendu-relais.total.arrive,1);
// L'ordre compte : appliquer la cible en premier construirait la checklist
// depuis le PC neuf, c'est-à-dire depuis une machine vide.
ok('la checklist vient bien de la source',
  G('APPS_DATA').some(a=>/Krita/.test(a.n)),true);


console.log('\n--- le script des restants suit la comparaison ---');
// Il partait des cases non cochées : sur une checklist où personne n'a rien
// coché, il proposait de réinstaller des logiciels déjà en place. La
// comparaison sait ce qui manque, et c'est un constat, pas une supposition.
const fichiers=[];
ctx.URL={createObjectURL:b=>{fichiers.push(String((b&&b.p&&b.p[0])||''));return 'blob:x';},
         revokeObjectURL:()=>{}};
G('appliquerProfil')(G('inventaireVersProfil')(source),true);
G('S').checked={};
vm.runInContext('INV_SOURCE='+JSON.stringify(Object.assign({},source,{role:'source'}))
  +';INV_CIBLE='+JSON.stringify(Object.assign({},cible,{role:'cible'}))+';',ctx);
G('exportWingetRemaining()');
// Firefox, 7-Zip et VS Code sont sur la cible ; seul Krita manque, et il n'a
// pas d'identifiant winget ici. Il n'y a donc rien à écrire — et surtout pas
// les trois qui sont déjà là, ce que faisait l'ancienne version.
ok('rien à installer, donc aucun fichier',fichiers.length,0);
ok('et on dit pourquoi',/sans identifiant winget/.test(els['annul-txt'].textContent),true);

// Avec un manquant qui porte un identifiant winget, il ressort.
fichiers.length=0;
const src2=Object.assign({},source,{role:'source',
  apps:source.apps.concat([{nom:'Notepad++',version:'8.6',winget:'Notepad.Notepad'}])});
G('appliquerProfil')(G('inventaireVersProfil')(src2),true);
G('S').checked={};
vm.runInContext('INV_SOURCE='+JSON.stringify(src2)
  +';INV_CIBLE='+JSON.stringify(Object.assign({},cible,{role:'cible'}))+';',ctx);
G('exportWingetRemaining()');
ok('le manquant est dans le script',/Notepad\.Notepad/.test(fichiers[0]||''),true);

// Une case cochée à la main affirme que c'est fait : le script ne contredit
// pas quelqu'un qui coche, même quand le scan dit le contraire.
fichiers.length=0;
const ligne=G('APPS_DATA').filter(a=>/Notepad/.test(a.n))[0];
G('toggle')(ligne.id,ligne.n);
G('exportWingetRemaining()');
ok('une ligne cochée à la main est respectée',fichiers.length,0);

console.log(ko?'\n'+ko+' EN ECHEC':'\nRECONCILIATION OPERATIONNELLE');
process.exit(ko?1:0);
