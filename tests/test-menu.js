// Le menu « Plus » de la barre du haut. Verifie que les quatre actions rares y
// sont, qu'elles agissent vraiment, que le menu se referme quand il le faut —
// apres une action, au clic ailleurs, a Echap — et qu'il reste utilisable au
// clavier et au doigt, dans les deux themes.
//
//   node tests/test-menu.js
const {chromium}=require('playwright');
const path=require('path');
const racine=path.join(__dirname,'..');
const HTML='file://'+path.join(racine,'index.html');
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;

(async()=>{
const b=await chromium.launch(lancement);
const ctx=await b.newContext({viewport:{width:1200,height:900},permissions:[]});
const pg=await ctx.newPage();
pg.on('pageerror',e=>console.log('ERREUR JS:',e.message));
await pg.goto(HTML,{waitUntil:'networkidle'});
let ko=0;const ok=(l,a,c)=>{const p=(c===undefined?!!a:a===c);console.log((p?'  ok  ':' FAIL ')+l+' → '+JSON.stringify(a)+(p?'':' (attendu '+JSON.stringify(c)+')'));if(!p)ko++;};

console.log('--- la barre a maigri ---');
const visibles=await pg.evaluate(()=>
  [...document.querySelectorAll('.hdr-right > button, .hdr-menu > button')]
    .filter(x=>x.offsetParent!==null).map(x=>x.textContent.trim()));
console.log('   boutons visibles :',visibles.join(' · '));
// Dix avant le menu. Sept apres : les deux bascules de vue, importer,
// sauvegarder, le mode guide, le menu et le theme.
ok('sept boutons au plus dans la barre',visibles.length<=7,true);
ok('plus aucune icone muette',
  await pg.evaluate(()=>[...document.querySelectorAll('.hdr-right button')]
    .filter(x=>x.offsetParent!==null&&x.classList.contains('icon-only')).length),0);

console.log('\n--- ce que le menu contient ---');
await pg.click('#menu-btn');await pg.waitForTimeout(200);
const items=await pg.evaluate(()=>
  [...document.querySelectorAll('#hdr-menu-liste button')].map(x=>x.textContent.trim()));
ok('six actions',items.length,6);
['Commencer une session','Exporter le profil','Adapter à mon cas','Réinitialiser','Exporter en texte','Imprimer'].forEach(t=>
  ok('« '+t+' » y est',items.some(x=>x.indexOf(t)>=0),true));
ok('chaque action a un libelle, pas qu\'un emoji',
  items.every(t=>t.replace(/[^\p{L}]/gu,'').length>3),true);
ok('role de menu annonce',await pg.getAttribute('#hdr-menu-liste','role'),'menu');
ok('les items aussi',
  await pg.evaluate(()=>[...document.querySelectorAll('#hdr-menu-liste button')]
    .every(x=>x.getAttribute('role')==='menuitem')),true);

console.log('\n--- les facons de le refermer ---');
await pg.keyboard.press('Escape');await pg.waitForTimeout(200);
ok('Echap referme',await pg.isVisible('#hdr-menu-liste'),false);
ok('et rend le focus',await pg.evaluate(()=>document.activeElement.id),'menu-btn');
await pg.click('#menu-btn');await pg.waitForTimeout(150);
await pg.click('h1#profil-titre');await pg.waitForTimeout(200);
ok('un clic ailleurs referme',await pg.isVisible('#hdr-menu-liste'),false);
await pg.click('#menu-btn');await pg.waitForTimeout(150);
await pg.click('#menu-btn');await pg.waitForTimeout(200);
ok('le bouton lui-meme referme',await pg.isVisible('#hdr-menu-liste'),false);
// Le clavier doit en sortir comme la souris : tabuler hors du menu le laissait
// ouvert par-dessus la page, le focus deja ailleurs.
await pg.evaluate(()=>document.getElementById('menu-btn').focus());
await pg.keyboard.press('Enter');await pg.waitForTimeout(200);
for(let i=0;i<6;i++)await pg.keyboard.press('Tab');
await pg.waitForTimeout(200);
ok('sortir au clavier referme aussi',await pg.isVisible('#hdr-menu-liste'),false);
ok('et le focus a bien quitte le menu',
  await pg.evaluate(()=>!document.getElementById('hdr-menu-liste').contains(document.activeElement)),true);
// Mais tabuler DANS le menu ne doit pas le fermer sous les doigts.
await pg.evaluate(()=>document.getElementById('menu-btn').focus());
await pg.keyboard.press('Enter');await pg.waitForTimeout(200);
await pg.keyboard.press('Tab');await pg.waitForTimeout(150);
ok('tabuler d\'un item a l\'autre le garde ouvert',await pg.isVisible('#hdr-menu-liste'),true);
await pg.keyboard.press('Escape');await pg.waitForTimeout(150);

console.log('\n--- les actions agissent vraiment ---');
await pg.click('#menu-btn');await pg.waitForTimeout(150);
await pg.click('#session-start-btn');await pg.waitForTimeout(300);
ok('la session demarre',await pg.evaluate(()=>session&&session.active),true);
ok('le menu s\'est referme derriere',await pg.isVisible('#hdr-menu-liste'),false);
ok('la barre de session s\'affiche',
  await pg.evaluate(()=>document.getElementById('session-bar').classList.contains('active')),true);
await pg.click('#menu-btn');await pg.waitForTimeout(200);
ok('« Commencer une session » a disparu du menu',
  await pg.isVisible('#session-start-btn'),false);
ok('le focus va au premier item encore affiche',
  await pg.evaluate(()=>document.activeElement.textContent.indexOf('Exporter le profil')>=0),true);
await pg.keyboard.press('Escape');await pg.waitForTimeout(150);
await pg.evaluate(()=>stopSession());

// Le telechargement du profil : l'action la plus facile a casser en la deplacant.
await pg.click('#menu-btn');await pg.waitForTimeout(150);
const dl=pg.waitForEvent('download',{timeout:5000}).catch(()=>null);
await pg.getByRole('menuitem',{name:/Exporter le profil/}).click();
const fichier=await dl;
ok('« Exporter le profil » produit bien un fichier',!!fichier,true);
if(fichier)console.log('   nom :',fichier.suggestedFilename());

console.log('\n--- l\'export texte suit le scenario et ses intitules ---');
await pg.evaluate(()=>{
  // Un intitule alternatif et un element hors scenario, pour voir si le
  // fichier dit la meme chose que l'ecran.
  QUITTER_DATA[0].alt={n:'INTITULE-REINSTALL',d:'Test.'};
  QUITTER_DATA.push({id:'zz-txt',pr:'high',n:'RESERVE-MIGRATION',
    p:'C:\\zz',d:'Test.',cas:['migration']});
  viderIndex();changerScenario('reinstall');
});
await pg.click('#menu-btn');await pg.waitForTimeout(150);
const dlTxt=pg.waitForEvent('download',{timeout:5000}).catch(()=>null);
await pg.getByRole('menuitem',{name:/Exporter en texte/}).click();
const f2=await dlTxt;
ok('« Exporter en texte » produit un fichier',!!f2,true);
if(f2){
  const chemin=await f2.path();
  const txt=require('fs').readFileSync(chemin,'utf8');
  ok('le fichier porte l\'intitulé du scénario',txt.indexOf('INTITULE-REINSTALL')>=0,true);
  ok('et pas celui de l\'autre mode',txt.indexOf('RESERVE-MIGRATION')<0,true);
  ok('il nomme le cas en tête',txt.indexOf('Cas :')>=0,true);
  ok('les cinq sections y sont',
    ['AVANT DE QUITTER','NOUVEAU PC','APPS','DONNÉES','PWA']
      .every(t=>txt.indexOf(t)>=0),true);
}
await pg.evaluate(()=>{
  delete QUITTER_DATA[0].alt;
  QUITTER_DATA.splice(QUITTER_DATA.findIndex(x=>x.id==='zz-txt'),1);
  viderIndex();changerScenario('tout');renderAll();updateGlobal();
});

console.log('\n--- au clavier ---');
await pg.evaluate(()=>document.getElementById('menu-btn').focus());
await pg.keyboard.press('Enter');await pg.waitForTimeout(200);
ok('Entree ouvre le menu',await pg.isVisible('#hdr-menu-liste'),true);
ok('et pose le focus dedans',
  await pg.evaluate(()=>document.getElementById('hdr-menu-liste').contains(document.activeElement)),true);
const ordre=[];
for(let i=0;i<4;i++){
  ordre.push(await pg.evaluate(()=>document.activeElement.textContent.trim().slice(0,20)));
  await pg.keyboard.press('Tab');
}
ok('Tab parcourt les items dans l\'ordre',
  ordre.filter(t=>items.some(x=>x.indexOf(t)>=0)).length>=3,true);
await pg.keyboard.press('Escape');await pg.waitForTimeout(150);

console.log('\n--- au doigt, dans les deux themes ---');
for(const theme of ['light','dark']){
  await pg.setViewportSize({width:360,height:740});
  await pg.evaluate(t=>document.documentElement.setAttribute('data-theme',t),theme);
  await pg.click('#menu-btn');await pg.waitForTimeout(250);
  const m=await pg.evaluate(()=>{
    const lum=c=>{const v=c.match(/[\d.]+/g).slice(0,3).map(x=>{x=x/255;
      return x<=0.03928?x/12.92:Math.pow((x+0.055)/1.055,2.4);});
      return 0.2126*v[0]+0.7152*v[1]+0.0722*v[2];};
    const fond=el=>{let n=el;while(n&&n!==document.documentElement){
      const c=getComputedStyle(n).backgroundColor;
      if(c&&c!=='rgba(0, 0, 0, 0)'&&c!=='transparent')return c;n=n.parentElement;}
      return getComputedStyle(document.body).backgroundColor;};
    const l=document.getElementById('hdr-menu-liste');
    const r=[];
    l.querySelectorAll('button').forEach(btn=>{
      if(btn.offsetParent===null)return;
      const b=btn.getBoundingClientRect(),st=getComputedStyle(btn);
      const l1=lum(st.color),l2=lum(fond(btn));
      r.push({t:btn.textContent.trim().slice(0,22),h:Math.round(b.height),
        deborde:b.right>document.documentElement.clientWidth+1||b.left<-1,
        ct:+(((Math.max(l1,l2)+0.05)/(Math.min(l1,l2)+0.05)).toFixed(2))});
    });
    const c=l.getBoundingClientRect();
    return {items:r,sousEntete:c.top>=document.querySelector('.hdr').getBoundingClientRect().top,
      defile:document.documentElement.scrollWidth>document.documentElement.clientWidth+1};
  });
  ok(theme+' : pas de defilement horizontal',m.defile,false);
  ok(theme+' : le menu ne remonte pas au-dessus de l\'entete',m.sousEntete,true);
  m.items.forEach(x=>{
    ok(theme+' : « '+x.t+' » assez haut ('+x.h+'px)',x.h>=40,true);
    ok(theme+' : « '+x.t+' » dans l\'ecran',x.deborde,false);
    ok(theme+' : « '+x.t+' » lisible ('+x.ct+':1)',x.ct>=4.5,true);
  });
  await pg.keyboard.press('Escape');await pg.waitForTimeout(150);
}

ok('la page ne s\'est pas cassee',await pg.isVisible('#panne'),false);
await b.close();
console.log(ko?'\n'+ko+' ECHEC(S)':'\nMENU OPERATIONNEL');
process.exit(ko?1:0);
})();
