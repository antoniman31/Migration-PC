// Dependances : les deux formats, l'avertissement hors ordre, le tri
// topologique et les exports ordonnes.
//
//   node tests/test-dependances.js
const fs=require('fs'),vm=require('vm'),path=require('path');
const racine=path.join(__dirname,'..');
const html=fs.readFileSync(path.join(racine,'index.html'),'utf8');
// index.html porte plusieurs blocs <script> : un tres court en tete, qui ne
// charge le resultat d'un scan qu'en file://, et le gros bloc de la page. Une
// regex gloutonne les avalait tous les deux avec le HTML entre eux. On prend
// le plus long.
function blocJS(html){
  const blocs=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
  if(!blocs.length)throw new Error('aucun bloc <script> inline dans index.html');
  return blocs.reduce((a,b)=>b.length>a.length?b:a);
}
const js=blocJS(html);

const store={},fichiers=[];
function mkEl(id){return{id,textContent:'',innerHTML:'',value:'',style:{},dataset:{},
  classList:{_s:new Set(),add(c){this._s.add(c)},remove(c){this._s.delete(c)},
    toggle(c,v){v?this._s.add(c):this._s.delete(c)},contains(c){return this._s.has(c)}},
  setAttribute(){},getAttribute(){return null},appendChild(){},removeChild(){},click(){},focus(){},
  querySelector:()=>null,querySelectorAll:()=>[],addEventListener(){},getContext:()=>null};}
const els={};
const document={documentElement:mkEl('h'),body:mkEl('b'),
  getElementById(i){return els[i]||(els[i]=mkEl(i))},
  querySelectorAll:()=>[],querySelector:()=>null,createElement:t=>mkEl(t),
  addEventListener(){},set title(v){},get title(){return''}};
const ctx={document,console,
  window:{addEventListener(e,f){if(e==='DOMContentLoaded')ctx.__i=f},matchMedia:()=>({matches:false})},
  localStorage:{getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=String(v)},removeItem:k=>{delete store[k]}},
  setInterval:()=>0,clearInterval(){},setTimeout(){},alert(){},confirm:()=>true,
  Blob:function(p){fichiers.push(p.join(''))},URL:{createObjectURL:()=>'x'},FileReader:function(){},
  navigator:{clipboard:{writeText:()=>Promise.resolve()}}};
ctx.window.document=document;vm.createContext(ctx);vm.runInContext(js,ctx);ctx.__i();
const G=e=>vm.runInContext(e,ctx);

let ko=0;
const ok=(l,a,b)=>{const p=JSON.stringify(a)===JSON.stringify(b);
  console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(b)+')'));
  if(!p)ko++;};

console.log('--- les deux formats coexistent ---');
// Les dependances relient des applications entre elles : elles vivent dans
// le profil de demonstration depuis que la checklist livree n'en porte plus.
const profil=JSON.parse(fs.readFileSync(path.join(racine,'presets','demonstration.json'),'utf8'));
const tous=[].concat(profil.npc,profil.apps,profil.data,profil.pwa);
const enTableau=tous.filter(e=>Array.isArray(e.dep));
const enTexte=tous.filter(e=>e.dep&&!Array.isArray(e.dep));
ok('le profil a des dépendances en tableau',enTableau.length>0,true);
ok('et au moins une en texte libre',enTexte.length>0,true);
ok('une chaîne ne décrit aucun lien',G('depsDe')({dep:'Installer avant machin'}),[]);
ok('un tableau décrit des liens',G('depsDe')({dep:['n1','n2']}),['n1','n2']);
ok('une référence inexistante est ignorée',G('depsDe')({dep:['n1','zzz']}),['n1']);
ok('sans dep, rien',G('depsDe')({}),[]);

console.log('\n--- badges ---');
ok('texte libre rendu tel quel',G('mkDepBadge')('Après le chipset').indexOf('Après le chipset')>=0,true);
const badgeTab=G('mkDepBadge')(['n1']);
ok('tableau résolu en nom lisible',badgeTab.indexOf(G('nomDe')('n1'))>=0,true);
ok('prérequis non coché signalé',badgeTab.indexOf('b-dep-manque')>=0,true);
G('S').checked['n1']=true;
ok('une fois coché, le badge se calme',G('mkDepBadge')(['n1']).indexOf('b-dep-manque')<0,true);
G('S').checked={};

console.log('\n--- avertissement hors ordre ---');
const avecDep=enTableau.find(e=>profil.npc.some(n=>n.id===e.id))||enTableau[0];
G('S').checked={};
G('toggle')(avecDep.id,avecDep.n);
const msg=els['annul-txt'].textContent;
ok('on est prévenu',msg.indexOf('se fait normalement après')>=0,true);
ok('mais la case est bien cochée',!!G('S').checked[avecDep.id],true);
console.log('      « '+msg+' »');
// prérequis d'abord : plus d'avertissement
G('S').checked={};els['annul-txt'].textContent='';
G('depsDe')(avecDep).forEach(id=>{G('S').checked[id]=true;});
G('toggle')(avecDep.id,avecDep.n);
ok('aucun avertissement dans le bon ordre',els['annul-txt'].textContent,'');

console.log('\n--- tri topologique ---');
G('S').checked={};
const ordonne=G('ordreParDependances')(profil.npc.slice().reverse());
const pos={};ordonne.forEach((e,i)=>{pos[e.id]=i;});
let violations=[];
profil.npc.forEach(e=>{
  G('depsDe')(e).forEach(d=>{if(pos[d]>pos[e.id])violations.push(e.id+' avant '+d);});
});
ok('aucun élément avant son prérequis',violations,[]);
ok('aucun élément perdu',ordonne.length,profil.npc.length);

console.log('\n--- un cycle ne fige pas la page ---');
const cyclique={meta:{nom:'Cycle'},cats:{x:'X'},npc:[],data:[],pwa:[],ordre:[],requetes:{},
  apps:[{id:'c1',n:'A',c:'x',src:'t',p:'med',t:1,d:'',dep:['c2']},
        {id:'c2',n:'B',c:'x',src:'t',p:'med',t:1,d:'',dep:['c3']},
        {id:'c3',n:'C',c:'x',src:'t',p:'med',t:1,d:'',dep:['c1']}]};
G('appliquerProfil')(cyclique,false);
const debut=Date.now();
const r=G('ordreParDependances')(G('APPS_DATA'));
ok('le tri termine',Date.now()-debut<1000,true);
ok('les trois éléments sont là',r.length,3);

console.log('\n--- exports ordonnés ---');
G('appliquerProfil')(profil,false);
G('S').checked={};
fichiers.length=0;
G('exportWingetJSON')(false);
const paquets=JSON.parse(fichiers[0]).Sources[0].Packages.map(p=>p.PackageIdentifier);
const parW={};profil.apps.forEach(a=>{if(a.w)parW[a.w]=a.id;});
const posW={};paquets.forEach((w,i)=>{posW[parW[w]]=i;});
let vio2=[];
profil.apps.filter(a=>a.w).forEach(a=>{
  G('depsDe')(a).forEach(d=>{
    if(posW[d]!==undefined&&posW[a.id]!==undefined&&posW[d]>posW[a.id])vio2.push(a.id+' avant '+d);});
});
ok('le JSON winget respecte les dépendances',vio2,[]);
ok('tous les paquets présents',paquets.length,profil.apps.filter(a=>a.w).length);

console.log('\n--- un profil sans dépendance garde son ordre manuel ---');
const sansDep=JSON.parse(JSON.stringify(profil));
// Les cinq onglets, pas deux : des dependances vivent aussi dans « Donnees »
// (la synchronisation entre deux machines s'enchaine), et n'en nettoyer qu'une
// partie laissait le test croire a un profil sans dependance.
['quitter','npc','apps','data','pwa'].forEach(c=>{
  (sansDep[c]||[]).forEach(e=>{delete e.dep;});
});
sansDep.ordre=['a3','a1','a2'];
G('appliquerProfil')(sansDep,false);
ok('aDesDependances est faux',G('aDesDependances')(),false);

console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nDEPENDANCES OPERATIONNELLES');
process.exit(ko?1:0);
