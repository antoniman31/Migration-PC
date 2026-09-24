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
const els={};const document={documentElement:mkEl('h'),body:mkEl('b'),getElementById(i){return els[i]||(els[i]=mkEl(i))},querySelectorAll:()=>[],querySelector:()=>null,createElement:t=>mkEl(t),addEventListener(){},set title(v){},get title(){return''}};
const ctx={document,console,window:{addEventListener(e,f){if(e==='DOMContentLoaded')ctx.__i=f},matchMedia:()=>({matches:false})},localStorage:{getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=String(v)},removeItem:k=>{delete store[k]}},setInterval:()=>0,clearInterval(){},setTimeout(){},alert(){},confirm:()=>true,Blob:function(){},URL:{createObjectURL:()=>'x'},FileReader:function(){},navigator:{clipboard:{writeText:()=>Promise.resolve()}}};
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
ok('apps converties',p.apps.length,6);
ok('taille dans la description',p.apps[1].d.indexOf('75 Go')>=0,true);
ok('app sans taille tolérée',p.apps[4].d.indexOf('Go')<0,true);
ok('total dans le sous-titre',p.meta.soustitre.indexOf('157 Go')>=0,true);
ok('machine dans le sous-titre',p.meta.soustitre.indexOf('Windows 11 Pro 24H2')>=0,true);
ok('les quatre lanceurs classés jeux',p.apps.filter(a=>a.c==='jeux').length,4);

console.log('\n--- variables pré-remplies ---');
ok('JAVA_HOME repris',G('S').env['JAVA_HOME'],'C:\\Program Files\\Java\\jdk-21');
ok('ANDROID_HOME repris',G('S').env['ANDROID_HOME'].indexOf('Android')>=0,true);
ok('PATH utilisateur repris',G('S').env['PATH (utilisateur)'].indexOf('outils')>=0,true);
ok('persisté',Object.keys(JSON.parse(store['mpc_state_v1']).env).length,3);
const elemEnv=p.data.find(d=>d.env);
ok('champs affichés = variables relevées',JSON.stringify(elemEnv.env),JSON.stringify(['JAVA_HOME','ANDROID_HOME','PATH (utilisateur)']));

console.log('\n--- rendu ---');
G('appliquerProfil')(p,true);
ok('apps rendues',G('APPS_DATA').length,6);
ok('taille visible dans la liste',els['list-apps'].innerHTML.indexOf('75 Go')>=0,true);
ok('champ JAVA_HOME rendu',els['list-data'].innerHTML.indexOf('JAVA_HOME')>=0,true);
ok('valeur pré-remplie rendue',els['list-data'].innerHTML.indexOf('jdk-21')>=0,true);

console.log('\n--- une saisie manuelle n\'est pas écrasée ---');
store['mpc_state_v1']=JSON.stringify({checked:{},notes:{},dates:{},lic:{},env:{JAVA_HOME:'valeur à moi'}});
G('S').env['JAVA_HOME']='valeur à moi';
G('inventaireVersProfil')(inv);
ok('valeur existante conservée',G('S').env['JAVA_HOME'],'valeur à moi');


// ── Dossiers de configuration ──────────────────────────────────────────
// Installer un logiciel prend une commande winget ; retrouver ses reglages
// prend une soiree. Le scanner releve maintenant ou vivent les configurations
// des logiciels qu'il vient de detecter.
console.log('\n--- dossiers de configuration ---');
{
  const inv={
    type:'inventaire-migration-pc',genere:'2026-09-24T12:00:00',
    machine:{os:'Windows 11',nom:'PC'},
    apps:[{nom:'Visual Studio Code',cat:'dev',source:'winget',winget:'Microsoft.VisualStudioCode'}],
    variables:{},
    configs:[
      {nom:'Clés SSH',chemin:'C:\\Users\\a\\.ssh',quoi:'Clés privées et known_hosts.',tailleMo:0.01},
      {nom:'Visual Studio Code',chemin:'C:\\Users\\a\\AppData\\Roaming\\Code\\User',quoi:'Réglages.',tailleMo:4.2},
      {nom:'Profils Firefox',chemin:'C:\\Users\\a\\AppData\\Roaming\\Mozilla\\Firefox\\Profiles',quoi:'Marque-pages.',tailleMo:2150}
    ]};
  const p=G('inventaireVersProfil')(inv);
  const cfg=p.data.filter(d=>String(d.id).startsWith('cfg'));
  ok('une ligne par dossier repéré',cfg.length,3);
  ok('les secrets passent en priorité haute',
    cfg.find(c=>/SSH/.test(c.n)).pr,'high');
  ok('et portent un avertissement',
    !!cfg.find(c=>/SSH/.test(c.n)).warn,true);
  ok('un dossier de réglages reste « important »',
    cfg.find(c=>/Visual Studio/.test(c.n)).pr,'med');
  ok('sans avertissement inutile',
    !!cfg.find(c=>/Visual Studio/.test(c.n)).warn,false);
  ok('le chemin réel est conservé',
    cfg.find(c=>/Visual Studio/.test(c.n)).p,'C:\\Users\\a\\AppData\\Roaming\\Code\\User');
  // Les tailles sont lues pour decider quoi emporter : 2 Go de profil Firefox
  // ne se traitent pas comme 4 Mo de reglages.
  ok('les mégaoctets se lisent',
    /4 Mo/.test(cfg.find(c=>/Visual Studio/.test(c.n)).note),true);
  ok('les gigaoctets aussi',
    /2,1 Go/.test(cfg.find(c=>/Firefox/.test(c.n)).note),true);
  ok('un dossier vide le dit',
    /moins de 1 Mo/.test(cfg.find(c=>/SSH/.test(c.n)).note),true);
  ok('on dit d\'où vient la ligne',
    /repéré par le scan/.test(cfg[0].note),true);

  // La ligne constatee remplace celle ecrite d'avance, au lieu de doubler.
  const ssh=p.data.filter(d=>/\.ssh/i.test(String(d.p||'')));
  ok('pas de doublon avec le chemin écrit à la main',ssh.length,1);
  ok('c\'est la ligne constatée qui reste',/^C:\\/.test(ssh[0].p),true);

  const sansConfigs=G('inventaireVersProfil')(
    Object.assign({},inv,{configs:undefined}));
  ok('un inventaire sans configs reste valide',
    sansConfigs.data.length,G('PROFIL_DEFAUT').data.length);
  ok('et un tableau vide ne change rien',
    G('inventaireVersProfil')(Object.assign({},inv,{configs:[]})).data.length,
    G('PROFIL_DEFAUT').data.length);
}

console.log('\n--- comparaison de chemins ---');
{
  const m=G('memeDossier');
  ok('variable contre chemin réel',m('%USERPROFILE%\\.ssh','C:\\Users\\a\\.ssh'),true);
  ok('deux segments comparés',m('%APPDATA%\\Code\\User','C:\\x\\AppData\\Roaming\\Code\\User'),true);
  // Un seul segment confondrait tous les dossiers nommes « User ».
  ok('« User » ne suffit pas à confondre',
    m('%APPDATA%\\Sublime Text\\Packages\\User','C:\\x\\Code\\User'),false);
  ok('barres obliques tolérées',m('%USERPROFILE%/.ssh','C:\\Users\\a\\.ssh'),true);
  ok('chemins sans rapport',m('%USERPROFILE%\\Documents','C:\\x\\Code\\User'),false);
  ok('chemin vide',m('','C:\\x'),false);
  ok('les deux vides',m('',''),false);
}

console.log(ko?'\n'+ko+' EN ECHEC':'\nSCANNER ETENDU OPERATIONNEL');
process.exit(ko?1:0);
