// Les deux remises a zero. « Tout decocher » ne touche qu'a la progression ;
// « Tout effacer » vide ce que le navigateur a memorise et revient au profil
// d'exemple. Les deux passent par le bandeau d'annulation : on verifie que
// l'annulation rend vraiment ce qui a ete efface.
//
//   node tests/test-reinit.js
const {chromium}=require('playwright');
const path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

(async()=>{
const b=await chromium.launch(lancement);
const pg=await (await b.newContext({viewport:{width:1200,height:900}})).newPage();
pg.on('pageerror',e=>console.log('ERREUR JS:',e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
const ouvrirPanneau=async()=>{
  await pg.click('#menu-btn');await pg.waitForTimeout(120);
  await pg.click('#reglages-btn');await pg.waitForTimeout(200);
};
const defaut=await pg.evaluate(()=>PROFIL_DEFAUT.meta.nom);
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};

// Etat de depart : quelques cases, une note, une cle, un scenario.
const prepare=async()=>pg.evaluate(()=>{
  const ids=tousLesItems().slice(0,6).map(e=>e.id);
  S.checked={};S.notes={};S.lic={};
  ids.forEach(i=>{S.checked[i]=true;S.dates[i]=Date.now();});
  S.notes[ids[0]]='ma note';
  S.lic['cle-test']='ABCD-1234';
  saveState();renderAll();updateGlobal();
  return ids.length;
});

console.log('--- le panneau ---');
ok('ferme au depart',await pg.isVisible('#reglages'),false);
ok('menu replie',await pg.getAttribute('#menu-btn','aria-expanded'),'false');
await pg.click('#menu-btn');await pg.waitForTimeout(200);
ok('le menu s\'ouvre',await pg.isVisible('#hdr-menu-liste'),true);
ok('menu deplie',await pg.getAttribute('#menu-btn','aria-expanded'),'true');
ok('le focus entre dans le menu',
  await pg.evaluate(()=>document.getElementById('hdr-menu-liste').contains(document.activeElement)),true);
await pg.click('#reglages-btn');await pg.waitForTimeout(250);
ok('le menu se referme derriere lui',await pg.isVisible('#hdr-menu-liste'),false);
ok('ouvert au clic',await pg.isVisible('#reglages'),true);
ok('le focus entre dans le panneau',
  await pg.evaluate(()=>document.getElementById('reglages').contains(document.activeElement)),true);
ok('les deux actions sont decrites',
  (await pg.$$('#reglages .reglages-item')).length,2);
await pg.keyboard.press('Escape');await pg.waitForTimeout(200);
ok('Echap referme',await pg.isVisible('#reglages'),false);
ok('et rend le focus au bouton du menu',
  await pg.evaluate(()=>document.activeElement.id),'menu-btn');
await ouvrirPanneau();
await pg.click('#reglages .reglages-fermer');await pg.waitForTimeout(150);
ok('« Fermer » referme aussi',await pg.isVisible('#reglages'),false);

console.log('\n--- tout decocher ---');
const n=await prepare();
await pg.click('#sc-reinstall');await pg.waitForTimeout(250);
await ouvrirPanneau();
await pg.click('#reglages .reglages-item:not(.reglages-danger) button');
await pg.waitForTimeout(300);
ok('plus aucune case cochee',await pg.evaluate(()=>Object.keys(S.checked).length),0);
ok('la note est conservee',await pg.evaluate(()=>S.notes&&Object.keys(S.notes).length),1);
ok('la cle est conservee',await pg.evaluate(()=>S.lic['cle-test']),'ABCD-1234');
ok('le scenario ne bouge pas',await pg.evaluate(()=>scenario),'reinstall');
ok('le panneau se referme',await pg.isVisible('#reglages'),false);
ok('le bandeau propose d\'annuler',await pg.isVisible('.annul-btn'),true);
await pg.click('.annul-btn');await pg.waitForTimeout(300);
ok('l\'annulation rend les cases',await pg.evaluate(()=>Object.keys(S.checked).length),n);

console.log('\n--- rien a decocher ---');
await pg.evaluate(()=>{S.checked={};saveState();renderAll();updateGlobal();});
await ouvrirPanneau();
await pg.click('#reglages .reglages-item:not(.reglages-danger) button');
await pg.waitForTimeout(250);
ok('un bandeau sans bouton inutile',await pg.isVisible('.annul-btn'),false);
ok('et il le dit',(await pg.textContent('#annul-txt')).indexOf('Rien à décocher')>=0,true);

console.log('\n--- tout effacer ---');
await prepare();
// Un profil importe et un scenario memorise, pour verifier qu'ils partent.
await pg.evaluate(()=>{
  const p=JSON.parse(JSON.stringify(PROFIL_DEFAUT));
  p.meta={nom:'Profil importé',soustitre:'test'};
  appliquerProfil(p,true);
});
await pg.click('#sc-migration');await pg.waitForTimeout(250);
ok('le profil importe est en memoire',
  await pg.evaluate(()=>!!localStorage.getItem(CLE_PROFIL)),true);
await ouvrirPanneau();
await pg.click('#reglages .reglages-danger button');
await pg.waitForTimeout(400);
const stock=await pg.evaluate(()=>({
  etat:localStorage.getItem(CLE_ETAT),
  profil:localStorage.getItem(CLE_PROFIL),
  scen:localStorage.getItem(CLE_SCENARIO)}));
ok('progression effacee du navigateur',stock.etat,null);
ok('profil efface du navigateur',stock.profil,null);
ok('scenario efface du navigateur',stock.scen,null);
ok('plus aucune case',await pg.evaluate(()=>Object.keys(S.checked).length),0);
ok('plus aucune note',await pg.evaluate(()=>Object.keys(S.notes).length),0);
ok('plus aucune cle',await pg.evaluate(()=>Object.keys(S.lic).length),0);
ok('retour au profil d\'exemple',await pg.textContent('#profil-titre'),defaut);
ok('retour au scenario complet',await pg.evaluate(()=>scenario),'tout');
ok('« Tout » redevient actif',await pg.getAttribute('#sc-tout','aria-pressed'),'true');
ok('l\'historique est vide',await pg.evaluate(()=>history.length),0);
ok('la page ne s\'est pas cassee',await pg.isVisible('#panne'),false);

console.log('\n--- annuler la remise a zero ---');
ok('l\'annulation est proposee',await pg.isVisible('.annul-btn'),true);
await pg.click('.annul-btn');await pg.waitForTimeout(400);
ok('le profil importe revient',await pg.textContent('#profil-titre'),'Profil importé');
ok('le scenario revient',await pg.evaluate(()=>scenario),'migration');
ok('les cases reviennent',await pg.evaluate(()=>Object.keys(S.checked).length>0),true);
ok('la note revient',await pg.evaluate(()=>S.notes&&Object.keys(S.notes).length),1);
ok('la cle revient',await pg.evaluate(()=>S.lic['cle-test']),'ABCD-1234');
ok('et tout est re-memorise',
  await pg.evaluate(()=>!!localStorage.getItem(CLE_PROFIL)&&!!localStorage.getItem(CLE_ETAT)),true);

console.log('\n--- apres rechargement ---');
await pg.reload({waitUntil:'networkidle'});
ok('le profil importe a tenu',await pg.textContent('#profil-titre'),'Profil importé');
// Puis une remise a zero definitive, suivie d'un rechargement.
await ouvrirPanneau();
await pg.click('#reglages .reglages-danger button');await pg.waitForTimeout(400);
await pg.reload({waitUntil:'networkidle'});
ok('rien ne revient d\'entre les morts',await pg.textContent('#profil-titre'),defaut);
ok('aucune case au chargement',await pg.evaluate(()=>Object.keys(S.checked).length),0);
ok('la page est saine',await pg.isVisible('#panne'),false);

console.log('\n--- le panneau sur petit ecran, dans les deux themes ---');
for(const theme of ['light','dark']){
  await pg.setViewportSize({width:360,height:740});
  await pg.evaluate(t=>document.documentElement.setAttribute('data-theme',t),theme);
  await ouvrirPanneau();
  const m=await pg.evaluate(()=>{
    const lum=c=>{const v=c.match(/[\d.]+/g).slice(0,3).map(x=>{x=x/255;
      return x<=0.03928?x/12.92:Math.pow((x+0.055)/1.055,2.4);});
      return 0.2126*v[0]+0.7152*v[1]+0.0722*v[2];};
    // Le fond peint : un parent transparent ne dit rien du contraste reel.
    const fond=el=>{let n=el;while(n&&n!==document.documentElement){
      const c=getComputedStyle(n).backgroundColor;
      if(c&&c!=='rgba(0, 0, 0, 0)'&&c!=='transparent')return c;n=n.parentElement;}
      return getComputedStyle(document.body).backgroundColor;};
    const r=[];
    document.querySelectorAll('#reglages button').forEach(btn=>{
      const b=btn.getBoundingClientRect(),st=getComputedStyle(btn);
      const l1=lum(st.color),l2=lum(fond(btn));
      r.push({t:btn.textContent.trim(),h:Math.round(b.height),w:Math.round(b.width),
        deborde:b.right>document.documentElement.clientWidth+1,
        ct:+(((Math.max(l1,l2)+0.05)/(Math.min(l1,l2)+0.05)).toFixed(2))});
    });
    return {btns:r,defile:document.documentElement.scrollWidth>document.documentElement.clientWidth+1};
  });
  ok(theme+' : pas de defilement horizontal',m.defile,false);
  m.btns.forEach(x=>{
    ok(theme+' : « '+x.t+' » assez haut ('+x.h+'px)',x.h>=34,true);
    ok(theme+' : « '+x.t+' » dans l\'ecran',x.deborde,false);
    ok(theme+' : « '+x.t+' » lisible ('+x.ct+':1)',x.ct>=4.5,true);
  });
  await pg.click('#reglages .reglages-fermer');await pg.waitForTimeout(150);
}

await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nREMISES A ZERO OPERATIONNELLES');
process.exit(ko?1:0);
})();
