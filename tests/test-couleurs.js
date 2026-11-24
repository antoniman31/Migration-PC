// Aucune couleur ecrite en dur dans le CSS, hors des definitions de jetons.
//
//   node tests/test-couleurs.js
//
// POURQUOI. Regle commune « Design » (21/11/2026) : couleurs par jetons, au
// moins deux themes. A l'audit du 24/11/2026, une vingtaine de couleurs etaient
// ecrites dans les regles elles-memes (le blanc pose sur l'accent, deux survols,
// une ombre, le bandeau de panne) : le theme sombre ne pouvait pas les corriger,
// et rien ne voyait en ajouter une. Elles vivent maintenant en tete du <style>,
// dans :root et [data-theme=dark] ; ce test refuse d'en reecrire une ailleurs.
//
// EXCEPTIONS, avec leur raison :
//   - les blocs @media print : une feuille imprimee est noire sur blanc quel que
//     soit le theme choisi a l'ecran, c'est voulu ;
//   - <meta name="theme-color"> : une balise, hors du CSS, qui ne lit aucun jeton.
const fs=require('fs');
const path=require('path');

let ko=0;
function ok(label,a,b){
  const bon=JSON.stringify(a)===JSON.stringify(b);
  console.log((bon?'  ok  ':' FAIL ')+label+' → '+JSON.stringify(a)
    +(bon?'':' (attendu '+JSON.stringify(b)+')'));
  if(!bon)ko++;
}

const COULEUR=/(?<![&\w])#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?)\(/g;

// Retire les commentaires (ils citent des valeurs d'avant), les definitions de
// jetons (l'endroit ou une couleur doit vivre) et les blocs @media print.
// Les sauts de ligne sont gardes pour que le numero de ligne reste juste.
function couleursEnDur(css,decalage){
  const blanc=m=>m.replace(/[^\n]/g,' ');
  let s=css.replace(/\/\*[\s\S]*?\*\//g,blanc);
  s=s.replace(/@media print\s*\{(?:[^{}]|\{[^{}]*\})*\}/g,blanc);
  const trouvees=[];
  s.split('\n').forEach((ligne,i)=>{
    const hors=ligne.replace(/--[\w-]+\s*:[^;}]*[;}]/g,'');
    for(const m of hors.matchAll(COULEUR))trouvees.push('index.html:'+(i+decalage)+' '+m[0]);
  });
  return trouvees;
}

// Le controle du controle : une expression cassee donnerait du vert partout.
ok('le detecteur voit #fff et rgba(',couleursEnDur('.a{color:#fff;background:rgba(0,0,0,.1)}',1).length,2);
ok('il ignore une definition de jeton',couleursEnDur(':root{--x:#fff;--y:rgba(0,0,0,.1)}',1),[]);
ok('il ignore un commentaire',couleursEnDur('/* etait #aaaaaa */ .a{color:var(--tx)}',1),[]);
ok('il ignore un bloc @media print',couleursEnDur('@media print{ body{background:#fff!important} }',1),[]);
ok('il voit une couleur hors du bloc print',couleursEnDur('@media print{.a{color:#000}}\n.b{color:#111}',1),['index.html:2 #111']);

const html=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
const d=html.indexOf('<style>'), f=html.indexOf('</style>');
if(d<0||f<0)throw new Error('bloc <style> introuvable');
const avant=html.slice(0,d).split('\n').length;
ok('aucune couleur en dur dans le <style> d\'index.html',couleursEnDur(html.slice(d,f),avant),[]);

// Le blanc (--sur-acc) ne se pose que sur un fond fait pour lui. A l'audit du
// 24/11/2026, trois survols le posaient sur --acc (#5493FF, 3,00:1) et sur
// --bh-tx (#f09595 en sombre, 2,23:1). Fonds permis, ratio mesure dans les
// deux themes : --acc-fond (4,59:1) et --danger-fond (7,07:1).
// Exception : .chkbox, vide tant que la case n'est pas cochee (la coche est
// un signe graphique, regle a part).
const FONDS_SOUS_BLANC=['--acc-fond','--danger-fond'];
function blancSurMauvaisFond(css){
  const sans=css.replace(/\/\*[\s\S]*?\*\//g,'').replace(/@media print\s*\{(?:[^{}]|\{[^{}]*\})*\}/g,'');
  const mauvais=[];
  for(const m of sans.matchAll(/([^{}]+)\{([^{}]*)\}/g)){
    const sel=m[1].trim(), corps=m[2];
    if(!/(^|;)\s*color:var\(--sur-acc\)/.test(corps)||sel==='.chkbox')continue;
    const fond=/background:var\((--[\w-]+)\)/.exec(corps);
    if(fond&&!FONDS_SOUS_BLANC.includes(fond[1]))mauvais.push(sel+' → '+fond[1]);
  }
  return mauvais;
}
ok('le detecteur voit du blanc sur --acc',blancSurMauvaisFond('.a:hover{background:var(--acc);color:var(--sur-acc)}'),['.a:hover → --acc']);
ok('il accepte --acc-fond',blancSurMauvaisFond('.a{background:var(--acc-fond);color:var(--sur-acc)}'),[]);
ok('le blanc ne se pose que sur --acc-fond ou --danger-fond',blancSurMauvaisFond(html.slice(d,f)),[]);

if(ko){console.log('\n'+ko+' echec(s)');process.exit(1);}
console.log('\nTout est vert.');
