// Formats winget natifs : reconnaissance, conversion en profil, export officiel
// et aller-retour. Couvre aussi la regression du script .ps1 restant, dont la
// liste de categories figee omettait les apps des profils generiques.
//
//   node tests/test-winget.js
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
const store={};const fichiers=[];
function mkEl(id){return{id,textContent:'',innerHTML:'',value:'',style:{},dataset:{},classList:{_s:new Set(),add(c){this._s.add(c)},remove(c){this._s.delete(c)},toggle(c,v){v?this._s.add(c):this._s.delete(c)},contains(c){return this._s.has(c)}},setAttribute(){},appendChild(){},removeChild(){},click(){},focus(){},querySelector:()=>null,querySelectorAll:()=>[],addEventListener(){},getContext:()=>null};}
const els={};const document={documentElement:mkEl('h'),body:mkEl('b'),getElementById(i){return els[i]||(els[i]=mkEl(i))},querySelectorAll:()=>[],querySelector:()=>null,createElement:t=>mkEl(t),addEventListener(){},set title(v){},get title(){return''}};
const alerts=[];
const ctx={document,console,window:{addEventListener(e,f){if(e==='DOMContentLoaded')ctx.__i=f},matchMedia:()=>({matches:false})},localStorage:{getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=String(v)},removeItem:k=>{delete store[k]}},setInterval:()=>0,clearInterval(){},setTimeout(){},alert:m=>alerts.push(m),confirm:()=>true,
  Blob:function(p){this.parts=p;fichiers.push(p.join(''))},URL:{createObjectURL:()=>'x'},FileReader:function(){},navigator:{clipboard:{writeText:()=>Promise.resolve()}}};
ctx.window.document=document;vm.createContext(ctx);vm.runInContext(js,ctx);ctx.__i();
const G=e=>vm.runInContext(e,ctx);
let ko=0;const ok=(l,a,b)=>{const p=a===b;console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(b)+')'));if(!p)ko++;};

console.log('--- reconnaissance du format ---');
const wg=JSON.parse(fs.readFileSync(path.join(__dirname,'winget-export-exemple.json'),'utf8'));
ok('export winget reconnu',G('estExportWinget')(wg),true);
ok('inventaire non confondu',G('estExportWinget')({type:'inventaire-migration-pc',apps:[]}),false);
ok('profil non confondu',G('estExportWinget')(JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'))),false);
ok('progression non confondue',G('estExportWinget')({version:3,state:{checked:{}}}),false);
ok('sans $schema mais avec Sources',G('estExportWinget')({Sources:[{Packages:[{PackageIdentifier:'A.B'}]}]}),true);

console.log('\n--- conversion en profil ---');
const p=G('wingetVersProfil')(wg);
ok('doublon 7zip fusionné',p.apps.length,7);
ok('nom lisible',p.apps[0].n,'7zip');
ok('identifiant conservé',p.apps[1].w,'Mozilla.Firefox');
ok('nom déduit',p.apps[1].n,'Firefox');
ok('version reprise',p.apps[1].d.indexOf('version 142.0')>=0,true);
ok('VS Code décamélisé',p.apps.find(a=>a.w==='Microsoft.VisualStudioCode').n,'Visual Studio Code');
ok('Steam classé jeux',p.apps.find(a=>a.w==='Valve.Steam').c,'jeux');
ok('Discord classé comms',p.apps.find(a=>a.w==='Discord.Discord').c,'comms');
ok('VLC classé media',p.apps.find(a=>a.w==='VideoLAN.VLC').c,'media');
ok('Git classé dev',p.apps.find(a=>a.w==='Git.Git').c,'dev');
ok('étapes du défaut reprises',p.npc.length>0,true);
ok('date dans le sous-titre',p.meta.soustitre.indexOf('2026-09-20')>=0,true);
ok('identifiants uniques',new Set(p.apps.map(a=>a.id)).size,p.apps.length);

console.log('\n--- application ---');
G('appliquerProfil')(p,true);
ok('apps chargées',G('APPS_DATA').length,7);
ok('catégories déclarées',G('APPS_DATA').every(a=>!!G('CATS')[a.c]),true);

console.log('\n--- export winget natif ---');
fichiers.length=0;
G('exportWingetJSON')(false);
const produit=JSON.parse(fichiers[0]);
ok('schéma officiel',produit.$schema.indexOf('winget-packages')>=0,true);
ok('tous les paquets',produit.Sources[0].Packages.length,7);
ok('identifiant correct',produit.Sources[0].Packages[0].PackageIdentifier,'7zip.7zip');
ok('source déclarée',produit.Sources[0].SourceDetails.Name,'winget');
ok('date ISO',!isNaN(Date.parse(produit.CreationDate)),true);

console.log('\n--- aller-retour ---');
ok('réimportable',G('estExportWinget')(produit),true);
const p2=G('wingetVersProfil')(produit);
ok('mêmes identifiants après aller-retour',
   JSON.stringify(p2.apps.map(a=>a.w).sort()),JSON.stringify(p.apps.map(a=>a.w).sort()));

console.log('\n--- export restantes seulement ---');
G('toggle')(G('APPS_DATA')[0].id,'x');
fichiers.length=0;
G('exportWingetJSON')(true);
ok('la cochée est exclue',JSON.parse(fichiers[0]).Sources[0].Packages.length,6);

console.log('\n--- script .ps1 restant : plus de catégorie perdue ---');
const ex=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
G('appliquerProfil')(ex,false);
fichiers.length=0;
G('exportWingetRemaining')();
const lignes=fichiers[0].split('\n').filter(l=>l.startsWith('winget install'));
const avecWinget=ex.apps.filter(a=>a.w).length;
ok('toutes les apps winget présentes',lignes.length,avecWinget);
ok('bureautique incluse',fichiers[0].indexOf('Google.Chrome')>=0,true);

console.log(ko?'\n'+ko+' EN ECHEC':'\nWINGET NATIF OPERATIONNEL');
process.exit(ko?1:0);
