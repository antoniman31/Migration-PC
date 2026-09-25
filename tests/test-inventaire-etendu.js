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
// Les champs de variables vivent dans le detail depliable.
G('DATA_SAVES').forEach(d=>{G('lignesOuvertes')[d.id]=true;});G('renderData')();
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

// ── L'adresse officielle relevée au registre remonte jusqu'à la checklist ──
{
  console.log('\n--- adresse officielle de l\'éditeur ---');
  const inv={type:'inventaire-migration-pc',apps:[
    {nom:'VLC',cat:'media',lien:'https://www.videolan.org/'},
    {nom:'Truc sans site',cat:'media'},
    {nom:'Truc mal renseigné',cat:'media',lien:'C:\\Program Files\\Truc'}
  ]};
  const p=G('inventaireVersProfil')(inv);
  const parNom={};p.apps.forEach(function(a){parNom[a.n]=a;});
  ok('adresse portée par l\'item',parNom['VLC'].u,'https://www.videolan.org/');
  ok('sans adresse, champ absent',parNom['Truc sans site'].u,undefined);

  // mkLink doit ouvrir le vrai site quand l'adresse tient, et retomber sur la
  // recherche sinon — y compris quand le registre contient un chemin local.
  const mkLink=G('mkLink');
  ok('bouton site officiel',/Site officiel/.test(mkLink('VLC',parNom['VLC'])),true);
  ok('adresse dans le href',/videolan\.org/.test(mkLink('VLC',parNom['VLC'])),true);
  ok('sans adresse, recherche',/Rechercher/.test(mkLink('X',parNom['Truc sans site'])),true);
  ok('chemin local, recherche',/Rechercher/.test(mkLink('X',parNom['Truc mal renseigné'])),true);
  ok('javascript: refusé',/Rechercher/.test(mkLink('X',{u:'javascript:alert(1)'})),true);
}

// ── urlSure : le faux constructeur URL du harnais masquait deux defauts ──
{
  console.log('\n--- adresses sûres ---');
  const u=G('urlSure');
  ok('https accepté',u('https://a.example/x'),'https://a.example/x');
  ok('mailto accepté',u('mailto:a@b.example'),'mailto:a@b.example');
  // Résolue contre la page, la chaîne vide donnait l'adresse de la checklist :
  // un bouton « Ouvrir » qui se contentait de la recharger.
  ok('vide refusée',u(''),'');
  ok('nulle refusée',u(null),'');
  ok('relative refusée',u('page.html'),'');
  ok('javascript: refusé',u('javascript:alert(1)'),'');
  ok('file: refusé',u('file:///C:/x'),'');
  // Et le bouton doit bien dire qu'il n'y a pas de lien.
  ok('mkDirectLink sans adresse',/Pas de lien/.test(G('mkDirectLink')('')),true);
  ok('mkDirectLink avec adresse',/a\.example/.test(G('mkDirectLink')('https://a.example')),true);
}

// ── Licences : une OEM ne suit pas la migration, la checklist doit le dire ──
{
  console.log('\n--- licences ---');
  const inv={type:'inventaire-migration-pc',apps:[{nom:'VLC',cat:'media'}],licences:[
    {nom:'Windows(R), Professional edition',canal:'OEM',etat:'active',clePartielle:'7X2QK',
     suitLeMateriel:false,quoi:'Attachee a la carte mere de cet ordinateur.'},
    {nom:'Office 16, Office16ProPlus',canal:'Retail',etat:'active',clePartielle:'9BQRT',
     suitLeMateriel:true,quoi:'Achetee separement : transferable.'}
  ]};
  const p=G('inventaireVersProfil')(inv);
  const lics=p.data.filter(function(d){return /^Licence : /.test(d.n);});
  ok('deux licences en données',lics.length,2);
  // Elles passent devant : c'est ce qui décide de l'achat de la machine.
  ok('la licence est la première ligne',/^Licence : /.test(p.data[0].n),true);
  const oem=lics.filter(function(l){return /Professional/.test(l.n);})[0];
  const ret=lics.filter(function(l){return /Office/.test(l.n);})[0];
  ok('OEM en priorité haute',oem.pr,'high');
  ok('OEM porte un avertissement',/ne suivra pas/.test(oem.warn||''),true);
  ok('Retail sans avertissement',ret.warn,undefined);
  ok('Retail en priorité normale',ret.pr,'med');
  ok('clé partielle affichée',/7X2QK/.test(oem.note),true);
  ok('canal affiché',/OEM/.test(oem.note),true);
  ok('couverture déclarée',oem.scan,'licences');
  ok('le résumé compte les OEM',/1 licence qui ne suivra pas/.test(p.meta.soustitre||''),true);

  // Sans licences relevées, rien ne doit apparaître ni planter.
  const p2=G('inventaireVersProfil')({type:'inventaire-migration-pc',apps:[{nom:'VLC'}]});
  ok('aucune licence, aucune ligne',p2.data.filter(function(d){return /^Licence : /.test(d.n);}).length,0);
  const p3=G('inventaireVersProfil')({type:'inventaire-migration-pc',apps:[{nom:'VLC'}],licences:[{},{nom:'   '}]});
  ok('entrées vides ignorées',p3.data.filter(function(d){return /^Licence : /.test(d.n);}).length,0);
}

// ── Les quatre contrôles de la machine neuve ──
{
  console.log('\n--- contrôles de la machine neuve ---');
  const mk=G('mkControles');
  const att={nom:'Vitesse de la mémoire',etat:'attention',
    constat:'La mémoire tourne à 4800 MHz alors qu\'elle sait faire 6000 MHz.',
    quoi:'Le profil XMP n\'est pas activé dans le BIOS.'};
  const bon={nom:'TRIM du SSD',etat:'ok',constat:'TRIM est actif.',quoi:'Rien à faire.'};
  const inc={nom:'Secure Boot et TPM',etat:'inconnu',constat:'Secure Boot : indéterminé',
    quoi:'Relance ce script en tant qu\'administrateur.'};

  ok('sans contrôle, rien',mk({}),'');
  ok('liste vide, rien',mk({controles:[]}),'');
  // Quatre « tout va bien » noieraient le seul point qui compte.
  ok('que du vert, rien',mk({controles:[bon,Object.assign({},bon,{nom:'X'})]}),'');

  const h=mk({controles:[att,bon,inc]});
  ok('un point à regarder annoncé',/1 point à regarder/.test(h),true);
  ok('le conforme est tu',/TRIM du SSD/.test(h),false);
  ok('le problème est montré',/Vitesse de la mémoire/.test(h),true);
  ok('son constat aussi',/4800 MHz/.test(h),true);
  ok('et le remède',/XMP/.test(h),true);
  ok('l\'indéterminé est montré',/Secure Boot et TPM/.test(h),true);

  // Deux problèmes : le pluriel doit suivre.
  const h2=mk({controles:[att,Object.assign({},att,{nom:'Usure des disques'})]});
  ok('deux points au pluriel',/2 points à regarder/.test(h2),true);
  // Rien que des indéterminés : ce n'est pas un problème, c'est une question.
  const h3=mk({controles:[inc]});
  ok('que des indéterminés',/Contrôles à confirmer/.test(h3),true);

  // Le HTML doit être échappé : un constat vient d'un fichier importé.
  const h4=mk({controles:[{nom:'<img src=x onerror=alert(1)>',etat:'attention',constat:'x',quoi:'y'}]});
  ok('le nom est échappé',/<img/.test(h4),false);
  ok('mais bien affiché',/&lt;img/.test(h4),true);
}

console.log(ko?'\n'+ko+' EN ECHEC':'\nSCANNER ETENDU OPERATIONNEL');
process.exit(ko?1:0);
