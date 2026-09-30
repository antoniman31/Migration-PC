// La mecanique de traduction.
//   node tests/test-langue.js
//
// Ce fichier ne verifie PAS que la page est entierement traduite : elle ne l'est
// pas encore, et un test qui pretendrait le contraire en excluant ce qui reste
// serait un test qui passe au lieu d'un test qui prouve. Il verifie la
// mecanique — que la table est coherente, que le choix se memorise, que la
// langue du navigateur decide au premier chargement, et qu'une cle manquante en
// anglais retombe sur le francais plutot que d'afficher une cle brute.
//
// Le test qui exigera zero francais a l'ecran en mode anglais arrivera AVEC la
// traduction des chaines, pas avant.
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
    _attrs:{},
    setAttribute(k,v){this._attrs[k]=String(v)},
    getAttribute(k){return this._attrs[k]===undefined?null:this._attrs[k]},
    appendChild(){},removeChild(){},
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

console.log('--- la table et le code se repondent ---');
// Le texte francais EST la cle : il n'y a donc pas de parite de cles a verifier,
// mais quelque chose de plus utile. Une entree anglaise dont le francais
// n'apparait nulle part dans le code est ORPHELINE — signe qu'on a reformule le
// francais sans toucher a sa traduction. C'est le seul risque reel de cette
// methode, et c'est ce test qui le tient.
const TR=G('TRADUCTIONS');
ok('la table anglaise existe',typeof TR.en,'object');
const clesEn=Object.keys(TR.en);
ok('elle n\'est pas vide',clesEn.length>0,true);

const brut=fs.readFileSync(path.join(racine,'index.html'),'utf8');
const debutTable=brut.indexOf('const TRADUCTIONS=');
const finTable=brut.indexOf('\n};',debutTable);
if(debutTable<0||finTable<0)throw new Error('table de traductions introuvable');
// LA TABLE EST EXCLUE DE LA RECHERCHE. Sans cette coupe, chaque cle se trouvait
// elle-meme dans la table, et le controle des orphelines ne prouvait rien : il a
// laisse passer neuf cles de categories fausses, ecrites sans l'emoji que portent
// les vrais libelles, en les declarant presentes dans le code.
const source=brut.slice(0,debutTable)+brut.slice(finTable);
ok('la table est exclue de la recherche',source.indexOf('const TRADUCTIONS=')<0,true);
// On cherche la cle telle qu'elle apparait dans le code : entre apostrophes
// simples, ou comme contenu d'un noeud marque data-t. Une cle absente des deux
// est orpheline.
const orphelines=clesEn.filter(function(k){
  if(source.indexOf("'"+k.replace(/'/g,"\\'")+"'")>=0)return false;
  if(source.indexOf('>'+k+'<')>=0)return false;
  if(source.indexOf('"'+k+'"')>=0)return false;
  return true;
});
ok('aucune traduction orpheline',orphelines.slice(0,5).join(' | '),'');
// Une traduction identique au francais passe parfois — un nom propre — mais une
// majorite identique voudrait dire que la traduction n'a pas eu lieu.
const identiques=clesEn.filter(k=>TR.en[k]===k);
ok('la plupart des textes different',identiques.length<clesEn.length/2,true);

console.log('\n--- tr() rend le bon texte ---');
const tr=G('tr');
G('LANG="fr";');
ok('en francais, le texte passe tel quel',tr('Logiciels'),'Logiciels');
G('LANG="en";');
ok('en anglais, il est traduit',tr('Logiciels'),TR.en['Logiciels']);
// Un texte sans traduction rend le francais : une page a moitie traduite reste
// utilisable, et c'est le test qui signale l'oubli.
ok('sans traduction, le francais',tr('Texte jamais traduit'),'Texte jamais traduit');
// Les nombres et les noms ne se placent pas au meme endroit d'une langue a
// l'autre : on substitue plutot que de concatener.
vm.runInContext('TRADUCTIONS.en["{0} sur {1}"]="{0} of {1}";',ctx);
ok('les trous sont remplis, en anglais',tr('{0} sur {1}',3,7),'3 of 7');
G('LANG="fr";');
ok('et en francais aussi',tr('{0} sur {1}',3,7),'3 sur 7');
ok('un trou repete l\'est partout',tr('{0}, encore {0}','x'),'x, encore x');

console.log('\n--- le choix se memorise ---');
G('setLangue("en");');
ok('la langue change',G('LANG'),'en');
ok('et part dans le navigateur',G('localStorage').getItem('mpc_langue_v1'),'en');
ok('l\'attribut lang du document suit',
  G('document').documentElement.getAttribute('lang'),'en');
G('setLangue("fr");');
ok('et on revient',G('localStorage').getItem('mpc_langue_v1'),'fr');
// Une langue inconnue ne doit pas laisser la page dans un etat impossible.
G('setLangue("kl");');
ok('une langue inconnue est refusee',G('LANG'),'fr');

console.log('\n--- la langue du navigateur decide au premier chargement ---');
// Rien en memoire : c'est navigator qui tranche.
const essai=function(langues,attendu){
  vm.runInContext('localStorage.removeItem("mpc_langue_v1");',ctx);
  ctx.navigator.languages=langues;
  ctx.navigator.language=langues[0];
  G('chargerLangue();');
  ok('navigator '+JSON.stringify(langues[0])+' → '+attendu,G('LANG'),attendu);
};
essai(['fr-FR'],'fr');
essai(['fr'],'fr');
essai(['en-US'],'en');
essai(['de-DE'],'en');
essai([''],'fr');
// Mais un choix explicite l'emporte sur le navigateur, pour toujours.
ctx.navigator.languages=['en-US'];ctx.navigator.language='en-US';
vm.runInContext('localStorage.setItem("mpc_langue_v1","fr");',ctx);
G('chargerLangue();');
ok('le choix explicite l\'emporte',G('LANG'),'fr');

console.log('\n--- le selecteur annonce l\'etat ---');
G('setLangue("en");');
ok('le bouton EN est enfonce',
  G('document').getElementById('lang-en').classList.contains('actif'),true);
ok('et le bouton FR ne l\'est plus',
  G('document').getElementById('lang-fr').classList.contains('actif'),false);

console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nMECANIQUE DE LANGUE : OPERATIONNELLE');
process.exit(ko?1:0);
