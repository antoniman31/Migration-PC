// Un profil vient d'un fichier qu'on n'a pas ecrit. Le projet est bati sur
// l'echange de profils — on en telecharge un, on en recoit un — donc son
// contenu est une entree non fiable, au meme titre qu'une saisie.
//
// Trois endroits le laissaient passer tel quel : le nom d'une categorie, qui
// s'executait au rendu sans qu'on clique sur rien ; l'identifiant winget, qui
// sortait de son attribut onclick ; et l'adresse d'un raccourci, ou
// « javascript: » etait accepte. Ce qui est en jeu n'est pas rien :
// localStorage contient les cles de licence saisies dans l'onglet Donnees.
//
// Ce test rejoue le profil piege sur tous les champs qu'un profil controle.
//
//   node tests/test-profil-hostile.js
const {chromium}=require('playwright');
const path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;


// Le detail d'une application (description, commande, avertissement) s'ouvre
// au clic. Ces assertions le deplient d'abord au lieu de chercher dans une
// ligne repliee ce qui n'y est plus.
async function deplierApps(pg){
  await pg.evaluate(()=>{APPS_DATA.forEach(a=>{lignesOuvertes[a.id]=true;});renderApps();});
}

(async()=>{
const b=await chromium.launch(lancement);
const pg=await (await b.newContext()).newPage();
const execute=[];
await pg.exposeFunction('__boum',t=>execute.push(t));
const errs=[];
pg.on('pageerror',e=>errs.push(e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:(typeof a==='object'?JSON.stringify(a)===JSON.stringify(c):a===c));console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};

const C='window.__boum';
const charges={
  catBalise:'<img src=x onerror="'+C+'(\'categorie/balise\')">',
  catQuote:"');"+C+"('categorie/apostrophe');//",
  wQuote:"');"+C+"('winget/apostrophe');//",
  wSlash:"\\');"+C+"('winget/antislash');//",
  idApp:"');"+C+"('identifiant/app');//",
  idNpc:"');"+C+"('identifiant/etape');//",
  urlJs:'javascript:'+C+"('url/javascript')",
  urlData:'data:text/html,<script>parent.'+C+"('url/data')<\/script>",
  urlAttr:'" onmouseover="'+C+'(\'url/sortie-attribut\')" x="',
  nomSvg:'<svg onload="'+C+'(\'nom/svg\')">',
  desc:'<img src=x onerror="'+C+'(\'description/balise\')">',
  src:'<img src=x onerror="'+C+'(\'source/balise\')">',
  chemin:'<img src=x onerror="'+C+'(\'chemin/balise\')">',
  alt:'<img src=x onerror="'+C+'(\'libelle-alternatif/balise\')">',
  meta:'<img src=x onerror="'+C+'(\'nom-du-profil/balise\')">'
};

await pg.evaluate(c=>{
  appliquerProfil({
    meta:{nom:c.meta,soustitre:'x'},
    cats:{[c.catQuote]:c.catBalise},
    apps:[{id:c.idApp,n:c.nomSvg,c:c.catQuote,src:c.src,d:c.desc,w:c.wQuote},
          {id:'a2',n:'B',c:'z',src:'S',d:'D',w:c.wSlash}],
    npc:[{id:c.idNpc,o:1,n:'E',src:'S',d:'D',alt:{n:c.alt,d:'x'}}],
    data:[{id:'d1',n:'D',pr:'high',p:c.chemin}],
    pwa:[{id:'p1',n:'P1',d:'D',u:c.urlJs},
         {id:'p2',n:'P2',d:'D',u:c.urlData},
         {id:'p3',n:'P3',d:'D',u:c.urlAttr},
         {id:'p4',n:'P4',d:'D',u:'https://exemple.test/ok'}]
  },false);
},charges);
await pg.waitForTimeout(400);

console.log('--- au rendu, sans rien cliquer ---');
ok('aucune balise injectée dans les listes',
  await pg.evaluate(()=>document.querySelectorAll(
    '#list-apps img,#list-apps svg,#list-data img,#list-npc img,#list-pwa img,h1 img').length),0);
ok('le nom de catégorie s\'affiche en texte',
  await pg.evaluate(()=>{
    const h=document.querySelector('#list-apps .sec-hdr');
    return !!(h&&h.textContent.indexOf('<img')>=0);}),true);

console.log('\n--- les adresses des raccourcis ---');
const liens=await pg.evaluate(()=>[...document.querySelectorAll('#list-pwa .lnk-btn')]
  .map(a=>({balise:a.tagName,href:a.getAttribute('href')})));
ok('« javascript: » est refusé',liens[0]&&liens[0].href,null);
ok('« data: » est refusé',liens[1]&&liens[1].href,null);
ok('une adresse qui sort de l\'attribut est refusée',liens[2]&&liens[2].href,null);
ok('une adresse http normale passe',liens[3]&&liens[3].href,'https://exemple.test/ok');
ok('un lien refusé reste visible mais inerte',
  liens[0]&&liens[0].balise,'SPAN');
ok('les liens qui restent sont isolés de la page ouverte',
  await pg.evaluate(()=>[...document.querySelectorAll('a.lnk-btn[target="_blank"]')]
    .every(a=>(a.getAttribute('rel')||'').indexOf('noopener')>=0)),true);

console.log('\n--- on clique tout ce qui est cliquable ---');
for(const sc of ['tout','reinstall']){
  await pg.evaluate(s=>changerScenario(s),sc);
  await pg.waitForTimeout(150);
  for(const sel of ['.b-winget','.cat-winget','.chk-all','.note-btn','.lnk-btn','.item','.fb']){
    for(const el of (await pg.$$(sel)).slice(0,4)){
      try{await el.click({timeout:800});}catch(e){}
    }
  }
}
await pg.evaluate(()=>{try{basculerGuide();}catch(e){}});
await pg.waitForTimeout(250);
for(const sel of ['.guide-fait','.guide-corps button']){
  for(const el of (await pg.$$(sel)).slice(0,3)){
    try{await el.click({timeout:800});}catch(e){}
  }
}
await pg.evaluate(()=>{try{basculerGuide();}catch(e){}});
await pg.waitForTimeout(400);

ok('aucun code n\'a été exécuté',execute,[]);
ok('et rien n\'a planté au passage',errs.length?errs[0]:'aucune erreur','aucune erreur');

console.log('\n--- le matériel d\'un profil reçu ---');
// Ce champ finit dans les intitulés des pilotes et dans les boutons de
// recherche : c'est un chemin d'injection de plus, et il accepte n'importe
// quel JSON.
await pg.evaluate(()=>{CONFIG={};saveConfig();construireConfig();});
await pg.evaluate(()=>traiterDonnees({
  meta:{nom:'H'},cats:{},npc:[],apps:[{id:'z',n:'Z',c:'x',src:'s',d:'d'}],
  data:[],pwa:[],quitter:[],
  materiel:{cm:"x' onclick='window.__inject=1' data-a='",
            gpu:'<img src=x onerror=window.__inject=2>',
            ram:{objet:1},ssd:['tableau'],cpu:'Un vrai processeur'}},''));
await pg.waitForTimeout(400);
ok('un objet n\'est pas recopié en [object Object]',
  await pg.evaluate(()=>CONFIG.ram||'(vide)'),'(vide)');
ok('un tableau non plus',await pg.evaluate(()=>CONFIG.ssd||'(vide)'),'(vide)');
ok('une chaîne honnête passe',await pg.evaluate(()=>CONFIG.cpu),'Un vrai processeur');
ok('et rien ne s\'exécute',await pg.evaluate(()=>window.__inject===undefined),true);
await pg.evaluate(()=>{CONFIG={};saveConfig();construireConfig();});

console.log('\n--- un profil honnête marche toujours ---');
await pg.evaluate(()=>{
  changerScenario('tout');
  appliquerProfil(PROFIL_DEFAUT,false);
});
await pg.waitForTimeout(300);
ok('les listes se remplissent',
  await pg.evaluate(()=>document.querySelectorAll('#list-apps .lg-l').length>0),true);
ok('les catégories accentuées s\'affichent correctement',
  await pg.evaluate(()=>{
    const h=document.querySelector('#list-apps .sec-hdr');
    return h?h.textContent.indexOf('&')<0:false;}),true);
await deplierApps(pg);
ok('le badge winget copie toujours',
  await pg.evaluate(()=>!!document.querySelector('.b-winget')),true);

await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nPROFIL HOSTILE : AUCUNE INJECTION');
process.exit(ko?1:0);
})();
