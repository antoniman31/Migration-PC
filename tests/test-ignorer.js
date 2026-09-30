// Ignorer un logiciel ou un peripherique.
//   node tests/test-ignorer.js
//
// Tout ce que la source portait n'est pas a reprendre : un logiciel dont on ne
// veut plus, un peripherique en defaut qu'on n'utilisera jamais. Sans moyen de
// le dire, ces lignes restaient dans « il manque N » a chaque ouverture, et le
// seul recours etait de cocher une case qui veut dire « regle » — donc de
// mentir.
//
// Ce que ce fichier verifie, et qui est le coeur du mecanisme : une ligne
// ecartee reste AFFICHEE, sort des comptes, ne sort pas dans le script winget,
// et ne peut pas etre cochee en meme temps. Plus le cas des peripheriques, qui
// n'ont pas d'identifiant et pour lesquels on en fabrique un.
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

// Le profil livre est vide depuis la reduction du projet : sans l'exemple garni
// il n'y aurait rien a ecarter, et ce fichier ne prouverait rien.
G('chargerDemo()');
const apps=G('APPS_DATA');
ok('la demonstration porte des logiciels',apps.length>0,true);
const cible=apps[0];
const total=G('aCompter')(G('itemsVisibles')()).length;

console.log('\n--- ecarter une ligne ---');
ok('rien n\'est ecarte au depart',Object.keys(G('IGNORES')).length,0);
G('basculerIgnore')(cible.id,cible.n);
ok('la ligne est ecartee',G('estIgnore')(cible.id),true);
ok('et c\'est memorise dans le navigateur',
  !!JSON.parse(G('localStorage').getItem('mpc_ignores_v1'))[cible.id],true);
// Le point du mecanisme : elle sort du total, pas de l'ecran.
ok('elle sort des comptes',G('aCompter')(G('itemsVisibles')()).length,total-1);
G('renderApps()');
const vueApps=G('document').getElementById('list-apps').innerHTML;
ok('mais elle reste affichee',vueApps.indexOf('lg-ignore')>=0,true);
ok('avec une etiquette qui le dit',vueApps.indexOf('b-ignore')>=0,true);

console.log('\n--- ecarter et cocher se chassent ---');
// Les deux etats disent le contraire l'un de l'autre — « je m'en passe » et
// « c'est regle ». Les autoriser ensemble produirait des comptes que personne
// ne peut expliquer.
const autre=apps[1];
G('toggle')(autre.id,autre.n);
ok('la seconde ligne est cochee',!!G('S').checked[autre.id],true);
G('basculerIgnore')(autre.id,autre.n);
ok('l\'ecarter la decoche',!!G('S').checked[autre.id],false);
ok('et elle est bien ecartee',G('estIgnore')(autre.id),true);
// Dans l'autre sens : cocher une ligne ecartee la remet dans la liste.
G('toggle')(autre.id,autre.n);
ok('cocher la remet dans la liste',G('estIgnore')(autre.id),false);
ok('et la case porte la decision',!!G('S').checked[autre.id],true);

console.log('\n--- le script winget saute ce qu\'on a ecarte ---');
// C'est la raison pratique du mecanisme : ne pas reinstaller ce dont on ne veut
// plus. Un logiciel ecarte ne doit pas se retrouver dans le fichier.
const avecW=apps.filter(a=>a.w);
ok('la demonstration porte des identifiants winget',avecW.length>1,true);
G('S').checked={};
vm.runInContext('IGNORES={};saveIgnores();',ctx);
G('IGNORES')[avecW[0].id]=true;G('saveIgnores')();
const sorties=[];
G('URL').createObjectURL=b=>{sorties.push(b);return 'blob:x';};
G('exportWingetJSON')(true);
const paquets=JSON.parse(String(sorties[0].p[0])).Sources[0].Packages
  .map(x=>x.PackageIdentifier);
ok('l\'ecarte n\'est pas dans le fichier',paquets.indexOf(avecW[0].w),-1);
ok('les autres y sont',paquets.length,avecW.length-1);

console.log('\n--- le mode guide ne le propose pas ---');
const restantes=G('tachesRestantes')().map(e=>e.id);
ok('l\'ecarte ne revient pas dans la file',restantes.indexOf(avecW[0].id),-1);

console.log('\n--- un peripherique en defaut ---');
// Les peripheriques n'ont pas d'identifiant : le scan rend un nom et un
// probleme. On en fabrique un, stable d'un scan a l'autre parce qu'il ne depend
// que du nom — la position dans la liste, elle, bouge.
const idA=G('idPilote')({nom:'Lecteur de cartes Realtek',probleme:'Aucun pilote'});
const idB=G('idPilote')({nom:'Lecteur de cartes Realtek',probleme:'En erreur'});
ok('l\'identifiant ne depend que du nom',idA,idB);
ok('il est prefixe',idA.indexOf('pil:'),0);
ok('un peripherique sans nom n\'en a pas',G('idPilote')({probleme:'x'}),'');

const invCible={type:'inventaire-migration-pc',role:'cible',
  machine:{nom:'PC-NEUF',fabricant:'ASUS',modele:'B850-A'},
  materiel:{cm:'ASUS ROG STRIX B850-A'},
  apps:[],pilotesTiers:[],
  pilotes:[{nom:'Lecteur de cartes Realtek',probleme:'Aucun pilote',classe:'Unknown'},
           {nom:'Contrôleur audio',probleme:'En erreur',classe:'Media'}]};
G('INV_CIBLE='+JSON.stringify(invCible)+';');
G('renderPilotes()');
ok('les deux sont a regler',G('document').getElementById('badge-pilotes').textContent,'2');
G('basculerIgnore')(idA,'Lecteur de cartes Realtek');
G('renderPilotes()');
ok('l\'ecarte sort du badge',G('document').getElementById('badge-pilotes').textContent,'1');
const hp=G('document').getElementById('list-pilotes').innerHTML;
ok('mais il reste a l\'ecran',hp.indexOf('pil-ignore')>=0,true);
ok('et on le dit',hp.indexOf('ignoré')>=0,true);
// Ecarter le dernier : le compte tombe a zero et le titre change.
G('basculerIgnore')(G('idPilote')({nom:'Contrôleur audio'}),'Contrôleur audio');
G('renderPilotes()');
ok('plus rien a regler',G('document').getElementById('badge-pilotes').textContent,'✓');

console.log('\n--- ce qui survit aux remises a zero ---');
// « Tout decocher » remet la progression a zero : une decision d'ecarter n'en
// fait pas partie. « Tout effacer » vide tout, y compris elle.
G('toutDecocher()');
ok('« Tout decocher » garde les ecartes',G('estIgnore')(idA),true);
G('remiseAZero()');
ok('« Tout effacer » les enleve',Object.keys(G('IGNORES')).length,0);
ok('et vide la cle du navigateur',G('localStorage').getItem('mpc_ignores_v1'),null);

console.log('\n--- l\'annulation les rend ---');
// Le bandeau promet une annulation : sans IGNORES dans l'instantane, elle
// perdait les lignes ecartees en silence. C'est exactement le defaut qu'on
// venait de corriger pour la configuration materielle.
G('chargerDemo()');
const app2=G('APPS_DATA')[0];
G('basculerIgnore')(app2.id,app2.n);
ok('une ligne est ecartee',G('estIgnore')(app2.id),true);
G('remiseAZero()');
ok('la remise a zero l\'a enlevee',G('estIgnore')(app2.id),false);
G('annuler()');
ok('l\'annulation la rend',G('estIgnore')(app2.id),true);

console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nIGNORER : OPERATIONNEL');
process.exit(ko?1:0);
