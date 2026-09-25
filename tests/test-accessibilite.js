// Accessibilité et réversibilité, mesurées dans un vrai navigateur.
//
// Couvre ce qu'un audit à l'œil ne voit pas : le contraste calculé sur le fond
// réellement peint, le parcours au clavier, les rôles annoncés aux lecteurs
// d'écran, l'annulation des actions destructrices et le respect du réglage
// système de mouvement réduit.
//
//   node tests/test-accessibilite.js
//   CHROME=/chemin/vers/chromium node tests/test-accessibilite.js
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

let ko=0;
const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);
  console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));
  if(!p)ko++;};


// Le profil livré ne contient aucune application : celles d'une autre machine
// feraient croire à l'arrivant que c'est sa liste. Les suites qui exercent
// l'onglet Apps chargent donc la démonstration, comme le ferait quelqu'un qui
// clique « Voir un exemple garni ».
async function chargerExemple(pg){
  await pg.evaluate(()=>{chargerDemo();});
  await pg.waitForTimeout(250);
}

(async()=>{
const b=await chromium.launch(lancement);

// ─────────── contraste et sémantique, dans les deux thèmes ───────────
for(const theme of ['light','dark']){
  const pg=await (await b.newContext({viewport:{width:1280,height:900}})).newPage();
  await pg.goto(HTML,{waitUntil:'networkidle'});
  await pg.evaluate(t=>document.documentElement.setAttribute('data-theme',t),theme);
  await pg.click('#tab-apps'); await pg.waitForTimeout(200);

  const r=await pg.evaluate(()=>{
    // Contraste WCAG 1.4.3 : 4.5:1, ou 3:1 pour un texte large.
    const lum=c=>{const [r,g,b]=c.map(v=>{v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);});
      return 0.2126*r+0.7152*g+0.0722*b;};
    const rgb=s=>{const m=s.match(/rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)/);
      return m?{c:[+m[1],+m[2],+m[3]],a:m[4]===undefined?1:+m[4]}:null;};
    // On remonte jusqu'au premier fond opaque : c'est lui qui est peint.
    const fondDe=e=>{let n=e;while(n&&n!==document.documentElement){const p=rgb(getComputedStyle(n).backgroundColor);
      if(p&&p.a>0.9)return p.c;n=n.parentElement;}return [255,255,255];};
    const ratio=(f,d)=>{const a=lum(f),b=lum(d);return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);};
    const visible=e=>{const b=e.getBoundingClientRect();const s=getComputedStyle(e);
      return b.width>0&&b.height>0&&s.visibility!=='hidden'&&s.opacity!=='0';};

    const faibles=[];
    [...document.querySelectorAll('*')].forEach(e=>{
      if(!visible(e)||e.children.length)return;
      const t=(e.textContent||'').trim(); if(!t)return;
      if(e.closest('[aria-hidden="true"]'))return;   // décoratif
      const s=getComputedStyle(e); const av=rgb(s.color); if(!av)return;
      const px=parseFloat(s.fontSize), gras=parseInt(s.fontWeight)>=700;
      const seuil=(px>=24||(px>=18.66&&gras))?3:4.5;
      const v=ratio(av.c,fondDe(e));
      if(v<seuil){const cl=[...e.classList].join('.');
        faibles.push(e.tagName.toLowerCase()+(cl?'.'+cl:'')+' « '+t.slice(0,20)+' » '+v.toFixed(2)+':1 (seuil '+seuil+')');}
    });

    const focusables='a[href],button,input,select,textarea,[tabindex]:not([tabindex="-1"])';
    return {
      faibles:[...new Set(faibles)],
      nonFocusables:[...new Set([...document.querySelectorAll('[onclick]')]
        .filter(e=>visible(e)&&!e.matches(focusables))
        .map(e=>e.tagName.toLowerCase()+'.'+[...e.classList].join('.')))],
      sansRole:[...document.querySelectorAll('.item')].filter(e=>e.getAttribute('role')!=='checkbox').length,
      sansEtat:[...document.querySelectorAll('.item')].filter(e=>!e.hasAttribute('aria-checked')).length,
      ongletsSansRole:[...document.querySelectorAll('.snav')].filter(e=>e.getAttribute('role')!=='tab').length,
      champsSansNom:[...document.querySelectorAll('input,select,textarea')]
        .filter(e=>visible(e)&&!e.getAttribute('aria-label')&&!e.getAttribute('title')
          &&!document.querySelector('label[for="'+e.id+'"]')&&!e.closest('label')).length,
      lang:document.documentElement.getAttribute('lang'),
      h1:document.querySelectorAll('h1').length,
      reperes:['header','main'].filter(t=>document.querySelector(t)).length
    };
  });

  console.log('--- thème '+theme+' ---');
  r.faibles.forEach(f=>console.log('      '+f));
  ok('contrastes suffisants',r.faibles.length,0);
  if(theme==='light'){
    ok('tout cliquable est focusable',r.nonFocusables.length,0);
    ok('les lignes ont role=checkbox',r.sansRole,0);
    ok('les lignes portent aria-checked',r.sansEtat,0);
    ok('les onglets ont role=tab',r.ongletsSansRole,0);
    ok('les champs ont un nom accessible',r.champsSansNom,0);
    ok('langue déclarée',r.lang,'fr');
    ok('un seul titre de niveau 1',r.h1,1);
    ok('repères header et main',r.reperes,2);
  }
  await pg.close();
}

// ─────────── clavier et focus ───────────
{
const pg=await (await b.newContext({viewport:{width:1280,height:900}})).newPage();
pg.on('pageerror',e=>{console.log(' FAIL erreur JS → '+e.message);ko++;});
await pg.goto(HTML,{waitUntil:'networkidle'});
console.log('--- le focus est-il visible après une vraie tabulation ? ---');
await pg.keyboard.press('Tab');
const f1=await pg.evaluate(()=>{const e=document.activeElement;const s=getComputedStyle(e);
  return {el:e.id||e.className,outline:s.outlineWidth+' '+s.outlineStyle+' '+s.outlineColor};});
console.log('   1re tabulation :',JSON.stringify(f1));
ok('anneau de focus visible',f1.outline.indexOf('0px')<0,true);

console.log('\n--- atteindre puis cocher une tâche ---');
let n=0,atteint=false;
for(let i=0;i<60;i++){await pg.keyboard.press('Tab');n++;
  if(await pg.evaluate(()=>document.activeElement.getAttribute('role')==='checkbox')){atteint=true;break;}}
ok('une case est atteinte en '+n+' tabulations',atteint,true);
const info=await pg.evaluate(()=>{const e=document.activeElement;
  return {aria:e.getAttribute('aria-checked'),pos:e.getAttribute('data-pos'),
    outline:getComputedStyle(e).outlineWidth};});
console.log('   état annoncé :',JSON.stringify(info));
ok('la case focalisée a un anneau',info.outline!=='0px',true);

const avant=await pg.evaluate(()=>Object.keys(S.checked).length);
await pg.keyboard.press('Space');
await pg.waitForTimeout(200);
const apres=await pg.evaluate(()=>Object.keys(S.checked).length);
ok('Espace coche la case',apres,avant+1);
const apresEtat=await pg.evaluate(()=>{const e=document.activeElement;
  return {aria:e.getAttribute('aria-checked'),role:e.getAttribute('role'),estCase:!!e.closest('.item')};});
console.log('   après Espace :',JSON.stringify(apresEtat));
ok('aria-checked passe à true',apresEtat.aria,'true');
ok('le focus reste sur la case',apresEtat.estCase,true);

await pg.keyboard.press('Enter');
await pg.waitForTimeout(200);
const apres2=await pg.evaluate(()=>Object.keys(S.checked).length);
ok('Entrée décoche',apres2,avant);

console.log('\n--- Espace ne fait pas défiler la page ---');
const y=await pg.evaluate(()=>window.scrollY);
await pg.keyboard.press('Space');await pg.waitForTimeout(150);
ok('pas de défilement parasite',await pg.evaluate(()=>window.scrollY),y);

console.log('\n--- un bouton dans la ligne garde son rôle propre ---');
// L'onglet Apps arrive vide : la liste des logiciels est celle de la machine
// qu'on scanne, pas une liste livrée d'avance.
await chargerExemple(pg);
await pg.click('#tab-apps');await pg.waitForTimeout(200);
const av=await pg.evaluate(()=>Object.keys(S.checked).length);
await pg.evaluate(()=>{document.querySelector('#list-apps .lg-plus').click();document.querySelector('#list-apps .note-btn').focus();});
await pg.keyboard.press('Enter');await pg.waitForTimeout(200);
ok('Entrée sur 📝 ne coche pas la tâche',await pg.evaluate(()=>Object.keys(S.checked).length),av);
ok('la zone de note s\'ouvre',await pg.evaluate(()=>!!document.querySelector('#list-apps .note-area.open')),true);

console.log('\n--- onglets ---');
const t=await pg.evaluate(()=>({sel:document.getElementById('tab-apps').getAttribute('aria-selected'),
  autre:document.getElementById('tab-npc').getAttribute('aria-selected')}));
ok('aria-selected suit l\'onglet actif',t.sel+'/'+t.autre,'true/false');

await pg.close();
}

// ─────────── annulation et mouvement réduit ───────────
{
const pg=await (await b.newContext({viewport:{width:1280,height:900}})).newPage();
pg.on('pageerror',e=>{console.log(' FAIL erreur JS → '+e.message);ko++;});
const dialogues=[];pg.on('dialog',d=>{dialogues.push(d.type());d.accept();});
await pg.goto(HTML,{waitUntil:'networkidle'});
// a1, a2, a3 sont des applications : elles vivent dans la démonstration.
await chargerExemple(pg);
await pg.click('#tab-apps');await pg.waitForTimeout(150);
console.log('--- réinitialisation annulable ---');
await pg.evaluate(()=>{['a1','a2','a3'].forEach(i=>{S.checked[i]=true;S.dates[i]=Date.now();});saveState();renderAll();updateGlobal();});
ok('3 cases cochées',await pg.evaluate(()=>Object.keys(S.checked).length),3);
await pg.evaluate(()=>resetSection('apps'));
await pg.waitForTimeout(200);
ok('aucune boîte de dialogue',dialogues.length,0);
ok('bandeau visible',await pg.isVisible('#annul'),true);
console.log('   message :',await pg.textContent('#annul-txt'));
ok('cases effacées',await pg.evaluate(()=>Object.keys(S.checked).length),0);
await pg.click('.annul-btn');
await pg.waitForTimeout(200);
ok('annulation restaure les 3 cases',await pg.evaluate(()=>Object.keys(S.checked).length),3);
ok('dates restaurées',await pg.evaluate(()=>Object.keys(S.dates).length),3);
ok('bandeau refermé',await pg.isVisible('#annul'),false);

console.log('\n--- rien à réinitialiser : pas de bouton Annuler ---');
await pg.evaluate(()=>{S.checked={};S.dates={};saveState();renderAll();updateGlobal();});
await pg.evaluate(()=>resetSection('apps'));
await pg.waitForTimeout(150);
ok('bandeau informatif',await pg.isVisible('#annul'),true);
ok('bouton Annuler masqué',await pg.isVisible('.annul-btn'),false);
await pg.click('.annul-fermer');

console.log('\n--- import annulable ---');
await pg.evaluate(()=>{S.checked={a1:true};saveState();renderAll();});
const avantApps=await pg.evaluate(()=>APPS_DATA.length);
const avantNom=await pg.textContent('#profil-titre');
dialogues.length=0;
await pg.setInputFiles('#json-file',{name:'w.json',mimeType:'application/json',
  buffer:Buffer.from(fs.readFileSync(path.join(__dirname,'winget-export-exemple.json')))});
await pg.waitForTimeout(400);
ok('aucune alerte bloquante',dialogues.length,0);
ok('profil remplacé',await pg.evaluate(()=>APPS_DATA.length),7);
ok('bandeau visible',await pg.isVisible('#annul'),true);
ok('bouton Annuler présent',await pg.isVisible('.annul-btn'),true);
await pg.click('.annul-btn');
await pg.waitForTimeout(400);
ok('profil restauré',await pg.evaluate(()=>APPS_DATA.length),avantApps);
ok('titre restauré',await pg.textContent('#profil-titre'),avantNom);
ok('progression restaurée',await pg.evaluate(()=>!!S.checked.a1),true);
ok('profil mémorisé restauré',await pg.evaluate(()=>JSON.parse(localStorage.getItem('mpc_profil_v1')).apps.length),avantApps);

console.log('\n--- mouvement réduit ---');
const ctx2=await b.newContext({viewport:{width:1280,height:900},reducedMotion:'reduce'});
const pg2=await ctx2.newPage();
await pg2.goto(HTML,{waitUntil:'networkidle'});
const m=await pg2.evaluate(()=>{
  const bar=document.querySelector('.gp-bar-fill');
  const dot=document.querySelector('.session-dot');
  return {transition:getComputedStyle(bar).transitionDuration,
          animation:getComputedStyle(dot).animationDuration,
          media:window.matchMedia('(prefers-reduced-motion: reduce)').matches};
});
ok('média détecté',m.media,true);
ok('transitions coupées',parseFloat(m.transition)<0.05,true);
ok('animations coupées',parseFloat(m.animation)<0.05,true);

// et sans le reglage, les animations restent
const pg3=await (await b.newContext({viewport:{width:1280,height:900}})).newPage();
await pg3.goto(HTML,{waitUntil:'networkidle'});
const n=await pg3.evaluate(()=>getComputedStyle(document.querySelector('.gp-bar-fill')).transitionDuration);
ok('transitions conservées par défaut',parseFloat(n)>0.1,true);

}

await b.close();
console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nACCESSIBILITE ET REVERSIBILITE : AUCUN DEFAUT');
process.exit(ko?1:0);
})();
