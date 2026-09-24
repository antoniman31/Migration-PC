// Mode guide : une tache a la fois, pour le moment ou l'on est devant la
// machine. Verifie ce qui doit rester visible (la commande et
// l'avertissement), ce qui doit disparaitre (filtres, badges, durees), le
// parcours, et que le mode tient les exigences d'accessibilite et
// d'ergonomie tactile acquises sur la vue liste.
//
//   node tests/test-guide.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const PROFIL=JSON.parse(fs.readFileSync(path.join(racine,'presets','exemple.json'),'utf8'));
const SECTIONS=['quitter','npc','apps','data','pwa'];
const TOTAL=SECTIONS.reduce(function(n,s){return n+((PROFIL[s]||[]).length);},0);
// La file suit l'ordre des onglets : ce qui se fait sur l'ancien PC passe en
// premier quand le profil déclare cette section.
const PREMIERE=(PROFIL.quitter&&PROFIL.quitter.length)?'Avant de quitter':'Nouveau PC';
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

let ko=0;
const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);
  console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));
  if(!p)ko++;};

(async()=>{
const b=await chromium.launch(lancement);

// ─────────── parcours ───────────
{
const ctx=await b.newContext({viewport:{width:1200,height:820},permissions:['clipboard-read','clipboard-write']});
const pg=await ctx.newPage();
pg.on('pageerror',e=>{console.log(' FAIL erreur JS → '+e.message);ko++;});
await pg.goto(HTML,{waitUntil:'networkidle'});
console.log('--- bascule ---');
ok('guide masqué par défaut',await pg.isVisible('#guide'),false);
ok('la vue liste est là',await pg.isVisible('.tabs'),true);
await pg.click('#guide-btn');
await pg.waitForTimeout(250);
ok('guide affiché',await pg.isVisible('#guide'),true);
ok('onglets masqués',await pg.isVisible('.tabs'),false);
ok('recherche masquée',await pg.isVisible('.gsearch'),false);
ok('aria-pressed suit',await pg.getAttribute('#guide-btn','aria-pressed'),'true');

console.log('\n--- contenu : une seule tâche ---');
const t=await pg.evaluate(()=>({
  titres:document.querySelectorAll('.guide-titre').length,
  titre:document.querySelector('.guide-titre').textContent,
  onglet:document.querySelector('.guide-onglet').textContent,
  etape:document.querySelector('.guide-etape').textContent,
  reste:document.querySelector('.guide-reste').textContent}));
console.log('   ',JSON.stringify(t));
ok('une seule tâche affichée',t.titres,1);
ok('la 1re tâche vient de la 1re section',t.onglet,PREMIERE);
ok('compteur présent',t.etape,'Tâche 1 sur '+TOTAL);

console.log('\n--- ce qui reste visible : commande et avertissement ---');
await pg.evaluate(()=>{
  // on avance jusqu'a une tache qui a les deux
  const cible=fileGuide().find(e=>e.w&&e.warn)||fileGuide().find(e=>e.w);
  fileGuide().forEach(e=>{if(e.id!==cible.id)S.checked[e.id]=true;});
  saveState();renderAll();updateGlobal();});
await pg.waitForTimeout(250);
const c=await pg.evaluate(()=>({
  cmd:document.querySelector('.guide-cmd code')?document.querySelector('.guide-cmd code').textContent:null,
  aBouton:!!document.querySelector('#guide-copier'),
  pasDeFiltre:!document.querySelector('#guide .fb'),
  pasDeBadge:!document.querySelector('#guide .badge'),
  pasDeDuree:!/~\d+min/.test(document.getElementById('guide').textContent)}));
console.log('   commande :',c.cmd);
ok('commande winget complète',/^winget install --id .+ -e --accept/.test(c.cmd),true);
ok('bouton copier présent',c.aBouton,true);
ok('aucun filtre dans le guide',c.pasDeFiltre,true);
ok('aucun badge dans le guide',c.pasDeBadge,true);
ok('aucune durée affichée',c.pasDeDuree,true);

console.log('\n--- copie dans le presse-papier ---');
await pg.click('#guide-copier');
await pg.waitForTimeout(300);
const presse=await pg.evaluate(()=>navigator.clipboard.readText());
ok('le presse-papier contient la commande',presse,c.cmd);
ok('le bouton confirme',await pg.textContent('#guide-copier'),'✓ Copié');

console.log('\n--- avertissement ---');
await pg.evaluate(()=>{
  S.checked={};
  const cible=fileGuide().find(e=>e.warn);
  fileGuide().forEach(e=>{if(e.id!==cible.id)S.checked[e.id]=true;});
  saveState();renderAll();updateGlobal();});
await pg.waitForTimeout(250);
ok('avertissement affiché',await pg.isVisible('.guide-warn'),true);
console.log('   ',(await pg.textContent('.guide-warn')).trim().slice(0,70));

console.log('\n--- avancer, passer ---');
await pg.evaluate(()=>{S.checked={};sautees={};saveState();renderAll();updateGlobal();});
await pg.waitForTimeout(200);
const premier=await pg.textContent('.guide-titre');
await pg.click('.guide-fait');
await pg.waitForTimeout(250);
const second=await pg.textContent('.guide-titre');
ok('« C\'est fait » passe à la suivante',second!==premier,true);
ok('la tâche est cochée',await pg.evaluate(()=>Object.keys(S.checked).length),1);
await pg.click('.guide-actions button:nth-child(2)');
await pg.waitForTimeout(250);
const troisieme=await pg.textContent('.guide-titre');
ok('« Passer » change de tâche',troisieme!==second,true);
ok('sans la cocher',await pg.evaluate(()=>Object.keys(S.checked).length),1);

console.log('\n--- fin de parcours ---');
await pg.evaluate(()=>{fileGuide().forEach(e=>{S.checked[e.id]=true;});saveState();renderAll();updateGlobal();});
await pg.waitForTimeout(250);
ok('écran de fin',await pg.isVisible('.guide-fin'),true);
console.log('   ',(await pg.textContent('.guide-fin-titre')).trim());

console.log('\n--- retour à la vue liste ---');
await pg.click('#guide-btn');
await pg.waitForTimeout(250);
ok('onglets revenus',await pg.isVisible('.tabs'),true);
ok('guide masqué',await pg.isVisible('#guide'),false);
ok('progression conservée',await pg.evaluate(()=>Object.keys(S.checked).length)>0,true);

await pg.close();
}

// ─────────── accessibilité, tactile et clavier ───────────
for(const [nom,w,h] of [['mobile',360,740],['bureau',1280,900]]){
for(const theme of ['light','dark']){
const pg=await (await b.newContext({viewport:{width:w,height:h},hasTouch:w<500})).newPage();
await pg.goto(HTML,{waitUntil:'networkidle'});
await pg.evaluate(t=>document.documentElement.setAttribute('data-theme',t),theme);
await pg.click('#guide-btn');await pg.waitForTimeout(250);

const r=await pg.evaluate(()=>{
  const lum=c=>{const [r,g,b]=c.map(v=>{v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);});return 0.2126*r+0.7152*g+0.0722*b;};
  const rgb=s=>{const m=s.match(/rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)/);return m?{c:[+m[1],+m[2],+m[3]],a:m[4]===undefined?1:+m[4]}:null;};
  const fondDe=e=>{let n=e;while(n&&n!==document.documentElement){const p=rgb(getComputedStyle(n).backgroundColor);if(p&&p.a>0.9)return p.c;n=n.parentElement;}return [255,255,255];};
  const ratio=(f,d)=>{const a=lum(f),b=lum(d);return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);};
  const vis=e=>{const b=e.getBoundingClientRect();const s=getComputedStyle(e);return b.width>0&&b.height>0&&s.visibility!=='hidden';};
  const g=document.getElementById('guide');
  const faibles=[];
  [...g.querySelectorAll('*')].forEach(e=>{
    if(!vis(e)||e.children.length)return;const t=(e.textContent||'').trim();if(!t)return;
    if(e.closest('[aria-hidden="true"]'))return;
    const s=getComputedStyle(e);const av=rgb(s.color);if(!av)return;
    const px=parseFloat(s.fontSize),gras=parseInt(s.fontWeight)>=700;
    const seuil=(px>=24||(px>=18.66&&gras))?3:4.5;
    const v=ratio(av.c,fondDe(e));
    if(v<seuil)faibles.push(e.tagName+'.'+[...e.classList].join('.')+' '+v.toFixed(2)+' ('+Math.round(px)+'px)');
  });
  const petites=[...g.querySelectorAll('button,a')].filter(e=>{const b=e.getBoundingClientRect();
    return vis(e)&&(b.width<44||b.height<24);}).map(e=>e.textContent.trim().slice(0,16)+' '+Math.round(e.getBoundingClientRect().width)+'x'+Math.round(e.getBoundingClientRect().height));
  const petitTexte=[...g.querySelectorAll('*')].filter(e=>vis(e)&&!e.children.length&&(e.textContent||'').trim()
    &&parseFloat(getComputedStyle(e).fontSize)<12).map(e=>e.className+' '+getComputedStyle(e).fontSize);
  return {faibles,petites,petitTexte,
    deborde:document.documentElement.scrollWidth-document.documentElement.clientWidth};
});
console.log('--- '+nom+' / '+theme+' ---');
r.faibles.forEach(f=>console.log('      contraste '+f));
r.petites.forEach(f=>console.log('      cible '+f));
r.petitTexte.forEach(f=>console.log('      texte '+f));
ok('contrastes',r.faibles.length,0);
if(nom==='mobile'){ok('cibles tactiles',r.petites.length,0);ok('tailles de texte',r.petitTexte.length,0);
  ok('pas de débordement',r.deborde,0);}
await pg.close();
}}

// clavier
const pg=await (await b.newContext({viewport:{width:1280,height:900}})).newPage();
await pg.goto(HTML,{waitUntil:'networkidle'});
await pg.click('#guide-btn');await pg.waitForTimeout(200);
let n=0,atteint=false;
await pg.evaluate(()=>document.body.focus());
for(let i=0;i<40;i++){await pg.keyboard.press('Tab');n++;
  if(await pg.evaluate(()=>document.activeElement.classList.contains('guide-fait'))){atteint=true;break;}}
console.log('--- clavier ---');
ok('« C\'est fait » atteint en '+n+' tabulations',atteint,true);
const anneau=await pg.evaluate(()=>getComputedStyle(document.activeElement).outlineWidth);
ok('anneau de focus visible',anneau!=='0px',true);
const avant=await pg.evaluate(()=>Object.keys(S.checked).length);
await pg.keyboard.press('Enter');await pg.waitForTimeout(250);
ok('Entrée coche la tâche',await pg.evaluate(()=>Object.keys(S.checked).length),avant+1);

await b.close();
console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nMODE GUIDE OPERATIONNEL');
process.exit(ko?1:0);
})();
