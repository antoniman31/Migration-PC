// Refabrique les captures du README. Six images : la liste, le mode guidé et
// le téléphone, chacun dans les deux thèmes.
//
// Ce fichier existe parce que les captures ont menti. Le projet est passé de
// six onglets à cinq, l'onglet « Données » a disparu, et le README a continué
// d'afficher l'ancienne page pendant tout ce temps : une capture ne casse
// aucun test, donc rien ne signale qu'elle a vieilli. Avec un script, les
// refaire coûte une commande au lieu d'une demi-heure de clics.
//
//   node refaire-captures.js
//
// Le profil de démonstration est chargé comme le ferait quelqu'un qui clique
// « Voir un exemple garni » — le profil livré n'a aucune application, et une
// capture vide n'apprendrait rien.
const {chromium}=require('playwright');
const path=require('path');

const R=__dirname;
const HTML='file://'+path.join(R,'index.html');

(async()=>{
  const b=await chromium.launch({executablePath:process.env.CHROME});
  for(const theme of ['clair','sombre']){
    const t=theme==='clair'?'light':'dark';
    // — bureau —
    let ctx=await b.newContext({viewport:{width:1280,height:900},deviceScaleFactor:2});
    let pg=await ctx.newPage();
    await pg.goto(HTML,{waitUntil:'networkidle'});
    await pg.evaluate(x=>document.documentElement.setAttribute('data-theme',x),t);
    await pg.evaluate(()=>{try{chargerDemo();}catch(e){}});
    await pg.waitForTimeout(400);
    await pg.evaluate(()=>{
      ['debut','annul'].forEach(id=>{const e=document.getElementById(id);if(e)e.style.display='none';});
      document.querySelectorAll('.annul-bar,.annul').forEach(e=>e.style.display='none');
    });
    await pg.click('#tab-apps');
    await pg.waitForTimeout(400);
    await pg.screenshot({path:path.join(R,'captures','checklist-'+theme+'.png')});
    await ctx.close();
    // — mode guidé : une tâche à l'écran, donc une fenêtre à sa mesure —
    ctx=await b.newContext({viewport:{width:1100,height:620},deviceScaleFactor:2});
    pg=await ctx.newPage();
    await pg.goto(HTML,{waitUntil:'networkidle'});
    await pg.evaluate(x=>document.documentElement.setAttribute('data-theme',x),t);
    await pg.evaluate(()=>{try{chargerDemo();}catch(e){}});
    await pg.waitForTimeout(400);
    await pg.evaluate(()=>{
      ['debut','annul'].forEach(id=>{const e=document.getElementById(id);if(e)e.style.display='none';});
      document.querySelectorAll('.annul-bar,.annul').forEach(e=>e.style.display='none');
      try{basculerGuide();}catch(e){}
    });
    await pg.waitForTimeout(400);
    await pg.screenshot({path:path.join(R,'captures','mode-guide-'+theme+'.png')});
    await ctx.close();
    // — téléphone —
    ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:3,hasTouch:true,isMobile:true});
    pg=await ctx.newPage();
    await pg.goto(HTML,{waitUntil:'networkidle'});
    await pg.evaluate(x=>document.documentElement.setAttribute('data-theme',x),t);
    await pg.evaluate(()=>{try{chargerDemo();}catch(e){}});
    await pg.waitForTimeout(400);
    await pg.evaluate(()=>{
      ['debut','annul'].forEach(id=>{const e=document.getElementById(id);if(e)e.style.display='none';});
      document.querySelectorAll('.annul-bar,.annul').forEach(e=>e.style.display='none');
    });
    await pg.click('#tab-apps');
    await pg.waitForTimeout(400);
    await pg.screenshot({path:path.join(R,'captures','mobile-'+theme+'.png')});
    await ctx.close();
  }
  await b.close();
  console.log('six captures refaites');
})();
