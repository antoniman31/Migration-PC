// Tests de la checklist : extrait le JS de index.html et l'execute dans un DOM simule.
//   node tests/test-checklist.js
const fs=require('fs'),vm=require('vm'),path=require('path');
const racine=path.join(__dirname,'..');
const html=fs.readFileSync(path.join(racine,'index.html'),'utf8');
const m=html.match(/<script>([\s\S]*)<\/script>/);
if(!m){console.error('script introuvable dans index.html');process.exit(1);}
const js=m[1];

// DOM minimal : suffisant pour valider le rendu, pas pour valider l'affichage.
const store={};
function mkEl(id){
  const el={id,textContent:'',innerHTML:'',value:'',style:{},dataset:{},children:[],
    classList:{_s:new Set(),add(c){this._s.add(c)},remove(c){this._s.delete(c)},
      toggle(c,v){v===undefined?(this._s.has(c)?this._s.delete(c):this._s.add(c)):(v?this._s.add(c):this._s.delete(c))},
      contains(c){return this._s.has(c)}},
    setAttribute(){},getAttribute(){return null},appendChild(){},removeChild(){},click(){},focus(){},
    querySelector(){return null},querySelectorAll(){return []},addEventListener(){},getContext(){return null}};
  return el;
}
const els={};
const document={
  documentElement:mkEl('html'),body:mkEl('body'),
  getElementById(id){if(!els[id])els[id]=mkEl(id);return els[id];},
  querySelectorAll(){return []},querySelector(){return null},
  createElement(t){return mkEl(t)},addEventListener(){},
  get title(){return this._t||''},set title(v){this._t=v}
};
const ctx={document,console,
  window:{addEventListener(e,f){if(e==='DOMContentLoaded')ctx.__init=f;},matchMedia:()=>({matches:false}),print(){}},
  localStorage:{getItem:k=>store[k]===undefined?null:store[k],setItem:(k,v)=>{store[k]=String(v)},removeItem:k=>{delete store[k]}},
  setInterval:()=>0,clearInterval(){},setTimeout(f){},alert:m=>{ctx.__alerts.push(m)},confirm:()=>true,
  Blob:function(p){this.p=p},URL:{createObjectURL:()=>'blob:x'},FileReader:function(){},
  requestAnimationFrame(){},navigator:{clipboard:{writeText:()=>Promise.resolve()}},
  __alerts:[]};
ctx.window.document=document;ctx.globalThis=ctx;
vm.createContext(ctx);
vm.runInContext(js,ctx,{filename:'app.js'});

ctx.__init();  // simule DOMContentLoaded
// les `let` de haut niveau ne sont pas des propriétés du contexte vm : on les lit par évaluation
const G=expr=>vm.runInContext(expr,ctx);

function eq(label,a,b){const ok=a===b;console.log((ok?'  ok  ':' FAIL ')+label+' → '+a+(ok?'':' (attendu '+b+')'));if(!ok)process.exitCode=1;}

console.log('\n--- profil par défaut ---');
const DEF=G('PROFIL_DEFAUT');
eq('apps chargées',G('APPS_DATA').length,DEF.apps.length);
eq('étapes nouveau PC',G('NPC_DATA').length,DEF.npc.length);
eq('données',G('DATA_SAVES').length,DEF.data.length);
eq('pwa',G('PWA_DATA').length,DEF.pwa.length);
eq('titre du profil',G('PROFIL_NOM'),DEF.meta.nom);
eq('entête rendue',els['profil-titre'].textContent,DEF.meta.nom);
eq('filtres générés',els['cat-filters'].innerHTML.split('<button').length-1,Object.keys(DEF.cats).length+1);
eq('liste apps rendue',els['list-apps'].innerHTML.length>500,true);
eq('liste npc rendue',els['list-npc'].innerHTML.length>500,true);
// Somme de toutes les sections du profil, y compris celles ajoutées depuis.
const SECTIONS=['quitter','npc','apps','data','pwa'];
const TOT=SECTIONS.reduce(function(n,s){return n+((DEF[s]||[]).length);},0);
eq('total global',String(els['gp-total'].textContent),String(TOT));

console.log('\n--- cocher une tâche ---');
G('toggle')('a1','7-Zip');
eq('case enregistrée',G('S').checked[DEF.apps[0].id],true);
eq('compteur global',String(els['gp-done'].textContent),'1');
eq('persisté en localStorage',JSON.parse(store['mpc_state_v1']).checked[DEF.apps[0].id],true);

console.log('\n--- import d\'un inventaire ---');
const inv={type:'inventaire-migration-pc',version:1,genere:'2026-09-24T10:00:00Z',
  machine:{os:'Windows 11 Pro 24H2',nom:'PC-TEST'},
  apps:[{nom:'Mozilla Firefox',editeur:'Mozilla',version:'140.0',source:'registre',winget:'Mozilla.Firefox',cat:'bureautique'},
        {nom:'Krita',editeur:'KDE',version:'5.2',source:'winget',winget:'KDE.Krita',cat:'media'},
        {nom:'Un truc sans winget',editeur:'Perso',version:'1.0',source:'registre'}]};
const p=G('inventaireVersProfil')(inv);
eq('apps converties',p.apps.length,3);
eq('winget conservé',p.apps[0].w,'Mozilla.Firefox');
eq('app sans winget',p.apps[2].w,undefined);
eq('étapes reprises du défaut',p.npc.length,DEF.npc.length);
eq('sous-titre machine',p.meta.soustitre.indexOf('Windows 11 Pro 24H2')>=0,true);
G('appliquerProfil')(p,true);
eq('profil appliqué',G('APPS_DATA').length,3);
eq('profil mémorisé',JSON.parse(store['mpc_profil_v1']).apps.length,3);
eq('entête mise à jour',els['profil-titre'].textContent,'Migration PC — inventaire importé');
eq('catégories déduites',Object.keys(G('CATS')).length,3);
eq('progression conservée',G('S').checked[DEF.apps[0].id],true);

console.log('\n--- exports ---');
G('exportWinget')();
G('exportTxt')();
G('exportProfil')();
eq('export sans plantage',true,true);

console.log('\n--- rechargement avec le profil mémorisé ---');
const memorise=G('chargerProfilMemorise')();
eq('profil relu',memorise.apps.length,3);

console.log('\n--- retour au profil d\'exemple ---');
G('reinitProfil')();
eq('exemple rechargé',G('APPS_DATA').length,DEF.apps.length);
eq('mémoire effacée',store['mpc_profil_v1'],undefined);


// --- chaine complete : le JSON reellement produit par scan-pc.ps1 ---
const fInv=path.join(__dirname,'inventaire-exemple.json');
if(fs.existsSync(fInv)){
  console.log('\n--- inventaire reel produit par scan-pc.ps1 ---');
  const reel=JSON.parse(fs.readFileSync(fInv,'utf8'));
  const pr=G('inventaireVersProfil')(reel);
  G('appliquerProfil')(pr,true);
  eq('apps importees',G('APPS_DATA').length,reel.apps.length);
  eq('liste rendue',els['list-apps'].innerHTML.length>200,true);
  eq('badge winget present',els['list-apps'].innerHTML.indexOf('7zip.7zip')>=0,true);
  eq('app sans winget toleree',G('APPS_DATA').filter(a=>!a.w).length,1);
  eq('categories deduites',Object.keys(G('CATS')).length>=2,true);
}

console.log(process.exitCode?'\nDES TESTS ONT ÉCHOUÉ':'\nTOUS LES TESTS PASSENT');
