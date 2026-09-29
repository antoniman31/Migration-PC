// Inventaire enrichi : tailles sur disque et variables d'environnement
// relevees par le scanner, jusqu'a leur affichage dans la page.
//
//   node tests/test-inventaire-etendu.js
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
const store={};
function mkEl(id){return{id,textContent:'',innerHTML:'',value:'',style:{},dataset:{},classList:{_s:new Set(),add(c){this._s.add(c)},remove(c){this._s.delete(c)},toggle(c,v){v?this._s.add(c):this._s.delete(c)},contains(c){return this._s.has(c)}},setAttribute(){},appendChild(){},removeChild(){},click(){},focus(){},querySelector:()=>null,querySelectorAll:()=>[],addEventListener(){},getContext:()=>null};}
const els={};const document={baseURI:'https://exemple.test/index.html',documentElement:mkEl('h'),body:mkEl('b'),getElementById(i){return els[i]||(els[i]=mkEl(i))},querySelectorAll:()=>[],querySelector:()=>null,createElement:t=>mkEl(t),addEventListener(){},set title(v){},get title(){return''}};
const ctx={document,console,window:{addEventListener(e,f){if(e==='DOMContentLoaded')ctx.__i=f},matchMedia:()=>({matches:false})},localStorage:{getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=String(v)},removeItem:k=>{delete store[k]}},setInterval:()=>0,clearInterval(){},setTimeout(){},alert(){},confirm:()=>true,Blob:function(){},URL:Object.assign(URL,{createObjectURL:()=>'x'}),FileReader:function(){},navigator:{clipboard:{writeText:()=>Promise.resolve()}}};
ctx.window.document=document;vm.createContext(ctx);vm.runInContext(js,ctx);ctx.__i();
const G=e=>vm.runInContext(e,ctx);
let ko=0;const ok=(l,a,b)=>{const p=a===b;console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(b)+')'));if(!p)ko++;};

console.log('--- formatage des tailles ---');
ok('sous 1 Go en Mo',G('fmtTaille')(0.02),'20 Mo');
ok('conversion en Mo sur base 1024',G('fmtTaille')(0.4),'410 Mo');
ok('arrondi au-dessus de 10',G('fmtTaille')(74.5),'75 Go');
ok('une décimale entre 1 et 10',G('fmtTaille')(2.5),'2.5 Go');
ok('nul ignoré',G('fmtTaille')(null),'');
ok('zéro ignoré',G('fmtTaille')(0),'');

console.log('\n--- inventaire étendu ---');
const inv=JSON.parse(fs.readFileSync(path.join(__dirname,'inventaire-etendu.json'),'utf8'));
const p=G('inventaireVersProfil')(inv);
// Un inventaire converti ne porte plus ni durée ni priorité : elles étaient
// inventées par mots-clés, et le « temps restant » qu'elles alimentaient était
// un chiffre fabriqué présenté comme une mesure.
ok('aucune durée inventée',(p.apps||[]).filter(function(a){return a.t!==undefined;}).length,0);
ok('aucune priorité inventée',(p.apps||[]).filter(function(a){return a.p!==undefined;}).length,0);
ok('apps converties',p.apps.length,6);
ok('taille dans la description',p.apps[1].d.indexOf('75 Go')>=0,true);
ok('app sans taille tolérée',p.apps[4].d.indexOf('Go')<0,true);
ok('total dans le sous-titre',p.meta.soustitre.indexOf('157 Go')>=0,true);
ok('machine dans le sous-titre',p.meta.soustitre.indexOf('Windows 11 Pro 24H2')>=0,true);
ok('les quatre lanceurs classés jeux',p.apps.filter(a=>a.c==='jeux').length,4);

console.log('\n--- rendu ---');
G('appliquerProfil')(p,true);
ok('apps rendues',G('APPS_DATA').length,6);
ok('taille visible dans la liste',els['list-apps'].innerHTML.indexOf('75 Go')>=0,true);

// Le scan ne releve plus que les logiciels et les pilotes : un inventaire qui
// porte encore d'anciennes familles ne doit rien en faire apparaitre.
console.log('\n--- les familles retirees ne reviennent pas ---');
ok('aucun onglet Données',G('ONGLETS').indexOf('data'),-1);
ok('une seule famille comparée',G('FAMILLES_COMPARABLES').length,1);
ok('et c\'est les applications',G('FAMILLES_COMPARABLES')[0].cle,'apps');
console.log(ko?'\n'+ko+' EN ECHEC':'\nSCANNER ETENDU OPERATIONNEL');
process.exit(ko?1:0);
