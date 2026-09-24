// Ce qu'on ne voit pas en relisant le CSS.
//
// Les regles d'ergonomie tactile portent sur des pixels rendus, pas sur des
// declarations : un bouton correctement ecrit peut mesurer 30 px une fois la
// police appliquee et la marge heritee. Ce script ouvre la page a la largeur
// de deux telephones courants, dans les deux themes, et signale :
//   - une cible interactive sous 44 x 24 px (Apple HIG, WCAG 2.5.5) ;
//   - deux cibles voisines separees de moins de 8 px ;
//   - un texte sous 12 px ;
//   - un champ de saisie sous 16 px, sous quoi Safari iOS zoome tout seul ;
//   - un debordement horizontal de la page ;
//   - une erreur JavaScript.
//
// Les seuils sont des reperes, pas des lois : STRICT=1 fait echouer le script,
// sinon il rapporte et rend la main. La checklist se consulte souvent telephone
// en main pendant qu'on monte la machine, d'ou l'interet de mesurer.
//
//   node tests/test-mobile.js
//   STRICT=1 node tests/test-mobile.js
const {chromium}=require('playwright');
const path=require('path');

const ECRANS=[{nom:'petit',largeur:360,hauteur:740},{nom:'courant',largeur:414,hauteur:896}];
const THEMES=['light','dark'];
const CIBLE_MIN_L=44, CIBLE_MIN_H=24, ECART_MIN=8, TEXTE_MIN=12, CHAMP_MIN=16;

(async()=>{
const lancement={args:['--no-sandbox']};
if(process.env.CHROME)lancement.executablePath=process.env.CHROME;
const b=await chromium.launch(lancement);
const HTML='file://'+path.join(__dirname,'..','index.html');
const constats=[];

for(const ec of ECRANS){
  for(const theme of THEMES){
    const ctx=await b.newContext({viewport:{width:ec.largeur,height:ec.hauteur},hasTouch:true});
    const pg=await ctx.newPage();
    const erreurs=[];
    pg.on('pageerror',e=>erreurs.push(e.message));
    await pg.goto(HTML,{waitUntil:'networkidle'});
    await pg.evaluate(t=>document.documentElement.setAttribute('data-theme',t),theme);

    // Chaque onglet a sa propre mise en page : les mesurer tous.
    for(const onglet of ['npc','apps','data','pwa']){
      await pg.click('#tab-'+onglet);
      await pg.waitForTimeout(120);
      const ou=ec.nom+'/'+theme+'/'+onglet;

      const r=await pg.evaluate(({CIBLE_MIN_L,CIBLE_MIN_H,ECART_MIN,TEXTE_MIN,CHAMP_MIN})=>{
        const visible=e=>{
          const b=e.getBoundingClientRect();
          const s=getComputedStyle(e);
          return b.width>0&&b.height>0&&s.visibility!=='hidden'&&s.display!=='none'&&s.opacity!=='0';
        };
        // Signature par classes CSS, pas par identifiant : les boutons d'items
        // ont un id different chacun et un meme defaut ressortirait cent fois.
        const nom=e=>{
          const cl=[...e.classList].filter(c=>!/^(done|active|open|visible|has-note)$/.test(c));
          const t=(e.textContent||'').trim().replace(/\s+/g,' ').slice(0,22);
          return e.tagName.toLowerCase()+(cl.length?'.'+cl.join('.'):(e.id?'#'+e.id:''))
            +(t&&cl.length<2?' « '+t+' »':'');
        };
        const cibles=[...document.querySelectorAll('button,a,input,select,textarea,[onclick]')].filter(visible);

        const petites=cibles.filter(e=>{
          const b=e.getBoundingClientRect();
          return b.width<CIBLE_MIN_L||b.height<CIBLE_MIN_H;
        }).map(e=>{const b=e.getBoundingClientRect();
          return nom(e)+' ('+Math.round(b.width)+'×'+Math.round(b.height)+')';});

        // Deux cibles trop proches : le doigt ne peut pas viser l'une sans risquer l'autre.
        const serrees=[];
        for(let i=0;i<cibles.length;i++){
          for(let j=i+1;j<cibles.length;j++){
            const a=cibles[i].getBoundingClientRect(),c=cibles[j].getBoundingClientRect();
            if(cibles[i].contains(cibles[j])||cibles[j].contains(cibles[i]))continue;
            const dx=Math.max(0,Math.max(a.left,c.left)-Math.min(a.right,c.right));
            const dy=Math.max(0,Math.max(a.top,c.top)-Math.min(a.bottom,c.bottom));
            if(dx===0&&dy===0)continue;           // elles se chevauchent : autre probleme
            // Deux lignes de liste empilees ne sont pas des cibles concurrentes :
            // chacune prend toute la largeur et reste haute, on ne vise pas
            // l'une en risquant l'autre. La regle de separation vise les petits
            // boutons cote a cote, pas les listes — sans cette exception, toute
            // liste dense la declencherait a chaque ligne.
            // La regle de separation protege contre le fait de toucher la
            // mauvaise cible. Le risque vient de la petitesse, pas de la
            // proximite seule : deux elements empiles qui mesurent chacun plus
            // de 44 px dans le sens ou ils se suivent se visent sans peine —
            // c'est le cas de toute liste. On ne signale donc la promiscuite
            // que lorsqu'au moins une des deux cibles est petite dans cet axe.
            const petiteDansLAxe=(r)=>dx===0?r.height<44:r.width<44;
            if(!petiteDansLAxe(a)&&!petiteDansLAxe(c))continue;
            const d=Math.hypot(dx,dy);
            if(d<ECART_MIN&&d>0)serrees.push(nom(cibles[i])+' ~ '+nom(cibles[j])+' ('+Math.round(d)+'px)');
          }
        }

        // Texte : on ne mesure que les feuilles, pour ne pas compter un conteneur
        // dont la taille declaree n'est jamais celle d'un texte affiche.
        const petitTexte=[...document.querySelectorAll('*')].filter(e=>{
          if(!visible(e)||e.children.length)return false;
          if(!(e.textContent||'').trim())return false;
          return parseFloat(getComputedStyle(e).fontSize)<TEXTE_MIN;
        }).map(e=>nom(e)+' ('+getComputedStyle(e).fontSize+')');

        const champsPetits=[...document.querySelectorAll('input,select,textarea')].filter(e=>
          visible(e)&&parseFloat(getComputedStyle(e).fontSize)<CHAMP_MIN
        ).map(e=>nom(e)+' ('+getComputedStyle(e).fontSize+')');

        return {
          petites:[...new Set(petites)],
          serrees:[...new Set(serrees)].slice(0,12),
          petitTexte:[...new Set(petitTexte)],
          champsPetits:[...new Set(champsPetits)],
          debordement:document.documentElement.scrollWidth-document.documentElement.clientWidth
        };
      },{CIBLE_MIN_L,CIBLE_MIN_H,ECART_MIN,TEXTE_MIN,CHAMP_MIN});

      if(r.debordement>0)constats.push([ou,'débordement horizontal de '+r.debordement+'px']);
      r.petites.forEach(d=>constats.push([ou,'cible sous '+CIBLE_MIN_L+'x'+CIBLE_MIN_H+' : '+d]));
      r.serrees.forEach(d=>constats.push([ou,'cibles à moins de '+ECART_MIN+'px : '+d]));
      r.petitTexte.forEach(d=>constats.push([ou,'texte sous '+TEXTE_MIN+'px : '+d]));
      r.champsPetits.forEach(d=>constats.push([ou,'champ sous '+CHAMP_MIN+'px : '+d]));
      erreurs.forEach(e=>constats.push([ou,'erreur JS : '+e]));
    }
    await ctx.close();
  }
}
await b.close();

// Regroupe par constat : le meme defaut ressort sur les quatre combinaisons.
const parType={};
constats.forEach(([ou,quoi])=>{(parType[quoi]=parType[quoi]||[]).push(ou);});
const types=Object.keys(parType);

console.log('Écrans : '+ECRANS.map(e=>e.nom+' '+e.largeur+'px').join(', ')+' · thèmes : '+THEMES.join(', '));
if(!types.length){
  console.log('\nAUCUN DEFAUT D\'ERGONOMIE TACTILE');
  process.exit(0);
}
console.log('\n'+types.length+' constat(s) :\n');
types.forEach(t=>console.log('  • '+t+'\n      sur '+parType[t].length+' combinaison(s), ex. '+parType[t][0]));
if(process.env.STRICT){console.log('\nSTRICT : échec');process.exit(1);}
console.log('\nRapport seulement (STRICT=1 pour faire échouer).');
})();
