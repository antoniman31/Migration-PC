// Aucun emoji comme icône d'interface : les icônes sont des Material Symbols (règle commune « Design », 25/11/2026).
//
//   node tests/test-icones.js
//
// POURQUOI. À l'audit du 25/11/2026, la page affichait une trentaine d'emojis différents en guise d'icônes (📦 🔍 ⬇️ ⚠️ ✓…) :
// leur dessin dépend de la police du système, ils ne suivent ni la couleur ni le thème, et Windows 10 et 11 ne les dessinent
// pas pareil. Les icônes viennent maintenant du sprite Material Symbols en tête du body ; ce test refuse d'en réécrire un.
//
// CE QUI N'EST PAS DE L'INTERFACE, et reste permis :
//   - les profils embarqués (PROFIL_DEFAUT, PROFIL_DEMO) : du contenu, recopié de presets/ par npm run sync, exporté tel quel ;
//   - LIBELLES_CATS et ICONES_CATS : les noms de catégorie écrits DANS un profil, et la table qui les traduit en icône ;
//   - les commentaires.
// Les flèches (→) et les signes typographiques ne sont pas des icônes : seuls les pictogrammes sont cherchés.
const fs=require('fs');
const path=require('path');

let ko=0;
function ok(label,a,b){
  const bon=JSON.stringify(a)===JSON.stringify(b);
  console.log((bon?'  ok  ':' FAIL ')+label+' → '+JSON.stringify(a)
    +(bon?'':' (attendu '+JSON.stringify(b)+')'));
  if(!bon)ko++;
}

const ICONE=/[\p{Extended_Pictographic}✓✔✕✖]/u;
const blanc=m=>m.replace(/[^\n]/g,' ');
function retire(s,debut,fin){
  const d=s.indexOf(debut); if(d<0)return s;
  const f=s.indexOf(fin,d); if(f<0)return s;
  return s.slice(0,d)+blanc(s.slice(d,f+fin.length))+s.slice(f+fin.length);
}
function emojisIcones(source){
  let s=source.replace(/<!--[\s\S]*?-->/g,blanc).replace(/\/\*[\s\S]*?\*\//g,blanc).replace(/^\s*\/\/.*$/gm,blanc);
  s=retire(s,'const PROFIL_DEFAUT = ','\n};');
  s=retire(s,'const PROFIL_DEMO = ','\n};');
  s=retire(s,'const LIBELLES_CATS={','\n};');
  s=retire(s,'const ICONES_CATS={','};');
  const trouves=[];
  s.split('\n').forEach(function(l,i){ const m=l.match(ICONE); if(m)trouves.push('index.html:'+(i+1)+' '+m[0]); });
  return trouves;
}

// Le contrôle du contrôle : une expression cassée donnerait du vert partout.
ok('le détecteur voit un emoji et une coche',emojisIcones('<b>📦</b>\n<i>✓ fait</i>').length,2);
ok('il ignore une flèche, un commentaire et un profil embarqué',
  emojisIcones('a → b\n// 📦 dans un commentaire\nconst PROFIL_DEMO = {\n "c":"🎮 Jeux"\n};'),[]);

const html=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const trouves=emojisIcones(html);
ok('aucun emoji comme icône dans index.html ('+trouves.length+' trouvé(s))',trouves.slice(0,8),[]);
ok('le sprite des icônes est présent',/<svg class="sprite"[^>]*>(<symbol id="i-[\w]+"[^>]*><path d="[^"]+"\/><\/symbol>)+<\/svg>/.test(html),true);
// Chaque icône appelée existe dans le sprite : un nom mal tapé laisserait un trou blanc, sans erreur.
const definies=new Set([...html.matchAll(/<symbol id="i-([\w]+)"/g)].map(m=>m[1]));
const appelees=new Set([...html.matchAll(/#i-([\w]+)"|icone\('([\w]+)'\)/g)].map(m=>m[1]||m[2]));
// icone(cond?'a':'b') : seuls les noms placés après « ? » et « : » sont des icônes (« m==='compact' » n'en est pas une).
for(const m of html.matchAll(/icone\(([^()]*\?[^()]*)\)/g))for(const n of m[1].matchAll(/[?:]\s*'([\w]+)'/g))appelees.add(n[1]);
for(const m of html.matchAll(/LIBELLES_ONGLETS=\{([^}]*)\}/g))for(const n of m[1].matchAll(/\['([\w]+)'/g))appelees.add(n[1]);
for(const m of html.matchAll(/ICONES_CATS=\{([^}]*)\}/g))for(const n of m[1].matchAll(/:'([\w]+)'/g))appelees.add(n[1]);
appelees.add('category');
ok('chaque icône appelée existe dans le sprite',[...appelees].filter(n=>!definies.has(n)),[]);

if(ko){console.log('\n'+ko+' echec(s)');process.exit(1);}
console.log('\nTout est vert.');
