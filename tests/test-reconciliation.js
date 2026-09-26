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

// Le test qui compte le plus pour les chemins : le profil utilisateur diffère
// entre les deux machines. Comparer les chemins réels rendrait tout manquant.
const cfg=famille(r,'configs');
ok('les clés SSH sont reconnues malgré un profil différent',cfg.arrives,1);
ok('et le dossier VS Code manque',cfg.manquants[0].libelle,'Visual Studio Code');

// Un cache .ost ne se copie pas : l'attendre sur la cible ferait compter
// comme manquant un fichier que personne ne doit emporter.
const mail=famille(r,'mail');
ok('seule l\'archive est attendue',mail.total,1);
ok('et elle manque',mail.manquants[0].libelle,'archive.pst');

ok('un réseau Wi-Fi sur deux',famille(r,'wifi').arrives,1);
ok('une variable sur deux',famille(r,'variables').arrives,1);
ok('la manquante est nommée',famille(r,'variables').manquants[0].libelle,'ANDROID_HOME');

// Personne n'attend que le PC neuf ait la même carte mère ni la même licence.
ok('le matériel n\'est pas comparé',famille(r,'materiel'),undefined);
ok('les licences non plus',famille(r,'licences'),undefined);

console.log('\n--- le compte global ---');
// 4 apps + 2 outils + 2 configs + 1 archive + 2 wifi + 2 variables = 13
ok('total attendu',r.total.attendu,13);
// 3 apps + 1 outil + 1 config + 0 mail + 1 wifi + 1 variable = 7
ok('total arrivé',r.total.arrive,7);

console.log('\n--- une migration terminée ---');
const fini=comparer(source,Object.assign({},source,{genere:'2026-09-28T10:00:00Z'}));
ok('tout est arrivé',fini.total.arrive,fini.total.attendu);
ok('aucun manquant',fini.familles.every(f=>f.manquants.length===0),true);
ok('aucune régression',fini.familles.every(f=>f.differents.length===0),true);

console.log('\n--- entrées hostiles ---');
// Un instantané vient d'un fichier qu'on n'a pas écrit : il peut porter
// n'importe quoi. La comparaison ne doit pas tomber.
const hostile=comparer(
  {apps:'pas un tableau',configs:[null,'x',{},{nom:'ok',modele:'%A%\\b'}],variables:'nope'},
  {apps:[{nom:null}],configs:null,variables:[1,2]});
ok('rien ne tombe',hostile.ok,true);
ok('les entrées vides sont ignorées',famille(hostile,'configs').total,1);
// Le compte doit toujours boucler : ce qui est attendu se retrouve soit
// arrivé, soit manquant, jamais nulle part.
const boucle=r.familles.every(f=>f.arrives+f.manquants.length===f.total);
ok('arrivés + manquants = attendus, partout',boucle,true);
ok('et sur le total global',
  r.familles.reduce((n,f)=>n+f.total,0),r.total.attendu);
ok('une famille non-tableau est ignorée',famille(hostile,'apps'),undefined);

console.log(ko?'\n'+ko+' EN ECHEC':'\nRECONCILIATION OPERATIONNELLE');
process.exit(ko?1:0);
