// La mecanique de traduction.
//   node tests/test-langue.js
//
// Ce fichier ne verifie PAS que la page est entierement traduite : elle ne l'est
// pas encore, et un test qui pretendrait le contraire en excluant ce qui reste
// serait un test qui passe au lieu d'un test qui prouve. Il verifie la
// mecanique — que la table est coherente, que le choix se memorise, que la
// langue du navigateur decide au premier chargement, et qu'une cle manquante en
// anglais retombe sur le francais plutot que d'afficher une cle brute.
//
// Le test qui exigera zero francais a l'ecran en mode anglais arrivera AVEC la
// traduction des chaines, pas avant.
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
    _attrs:{},
    setAttribute(k,v){this._attrs[k]=String(v)},
    getAttribute(k){return this._attrs[k]===undefined?null:this._attrs[k]},
    appendChild(){},removeChild(){},
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

console.log('--- la table et le code se repondent ---');
// Le texte francais EST la cle : il n'y a donc pas de parite de cles a verifier,
// mais quelque chose de plus utile. Une entree anglaise dont le francais
// n'apparait nulle part dans le code est ORPHELINE — signe qu'on a reformule le
// francais sans toucher a sa traduction. C'est le seul risque reel de cette
// methode, et c'est ce test qui le tient.
const TR=G('TRADUCTIONS');
ok('la table anglaise existe',typeof TR.en,'object');
const clesEn=Object.keys(TR.en);
ok('elle n\'est pas vide',clesEn.length>0,true);

const brut=fs.readFileSync(path.join(racine,'index.html'),'utf8');
const debutTable=brut.indexOf('const TRADUCTIONS=');
const finTable=brut.indexOf('\n};',debutTable);
if(debutTable<0||finTable<0)throw new Error('table de traductions introuvable');
// LA TABLE EST EXCLUE DE LA RECHERCHE. Sans cette coupe, chaque cle se trouvait
// elle-meme dans la table, et le controle des orphelines ne prouvait rien : il a
// laisse passer neuf cles de categories fausses, ecrites sans l'emoji que portent
// les vrais libelles, en les declarant presentes dans le code.
const source=brut.slice(0,debutTable)+brut.slice(finTable);
ok('la table est exclue de la recherche',source.indexOf('const TRADUCTIONS=')<0,true);
// On cherche la cle telle qu'elle apparait dans le code : entre apostrophes
// simples, ou comme contenu d'un noeud marque data-t. Une cle absente des deux
// est orpheline.
const orphelines=clesEn.filter(function(k){
  if(source.indexOf("'"+k.replace(/'/g,"\\'")+"'")>=0)return false;
  if(source.indexOf('>'+k+'<')>=0)return false;
  if(source.indexOf('"'+k+'"')>=0)return false;
  return true;
});
ok('aucune traduction orpheline',orphelines.slice(0,5).join(' | '),'');
// Une traduction identique au francais passe parfois — un nom propre — mais une
// majorite identique voudrait dire que la traduction n'a pas eu lieu.
const identiques=clesEn.filter(k=>TR.en[k]===k);
ok('la plupart des textes different',identiques.length<clesEn.length/2,true);

console.log('\n--- tr() rend le bon texte ---');
const tr=G('tr');
G('LANG="fr";');
ok('en francais, le texte passe tel quel',tr('Logiciels'),'Logiciels');
G('LANG="en";');
ok('en anglais, il est traduit',tr('Logiciels'),TR.en['Logiciels']);
// Un texte sans traduction rend le francais : une page a moitie traduite reste
// utilisable, et c'est le test qui signale l'oubli.
ok('sans traduction, le francais',tr('Texte jamais traduit'),'Texte jamais traduit');
// Les nombres et les noms ne se placent pas au meme endroit d'une langue a
// l'autre : on substitue plutot que de concatener.
vm.runInContext('TRADUCTIONS.en["{0} sur {1}"]="{0} of {1}";',ctx);
ok('les trous sont remplis, en anglais',tr('{0} sur {1}',3,7),'3 of 7');
G('LANG="fr";');
ok('et en francais aussi',tr('{0} sur {1}',3,7),'3 sur 7');
ok('un trou repete l\'est partout',tr('{0}, encore {0}','x'),'x, encore x');

console.log('\n--- le choix se memorise ---');
G('setLangue("en");');
ok('la langue change',G('LANG'),'en');
ok('et part dans le navigateur',G('localStorage').getItem('mpc_langue_v1'),'en');
ok('l\'attribut lang du document suit',
  G('document').documentElement.getAttribute('lang'),'en');
G('setLangue("fr");');
ok('et on revient',G('localStorage').getItem('mpc_langue_v1'),'fr');
// Une langue inconnue ne doit pas laisser la page dans un etat impossible.
G('setLangue("kl");');
ok('une langue inconnue est refusee',G('LANG'),'fr');

console.log('\n--- la langue du navigateur decide au premier chargement ---');
// Rien en memoire : c'est navigator qui tranche.
const essai=function(langues,attendu){
  vm.runInContext('localStorage.removeItem("mpc_langue_v1");',ctx);
  ctx.navigator.languages=langues;
  ctx.navigator.language=langues[0];
  G('chargerLangue();');
  ok('navigator '+JSON.stringify(langues[0])+' → '+attendu,G('LANG'),attendu);
};
essai(['fr-FR'],'fr');
essai(['fr'],'fr');
essai(['en-US'],'en');
essai(['de-DE'],'en');
essai([''],'fr');
// Mais un choix explicite l'emporte sur le navigateur, pour toujours.
ctx.navigator.languages=['en-US'];ctx.navigator.language='en-US';
vm.runInContext('localStorage.setItem("mpc_langue_v1","fr");',ctx);
G('chargerLangue();');
ok('le choix explicite l\'emporte',G('LANG'),'fr');

console.log('\n--- le selecteur annonce l\'etat ---');
G('setLangue("en");');
ok('le bouton EN est enfonce',
  G('document').getElementById('lang-en').classList.contains('actif'),true);
ok('et le bouton FR ne l\'est plus',
  G('document').getElementById('lang-fr').classList.contains('actif'),false);

// ── aucun texte brut n'atteint ce que la page dit ───────────────────────
// LE TROU QU'IL FERME. test-anglais.js regarde ce qui est a l'ecran quand il
// passe : les listes, les panneaux, les boutons. Un message n'y est qu'au
// moment ou il est dit — « Fichier illisible », « Configuration effacee » — et
// aucun des scenarios du test ne les declenchait. Dix-sept chaines de ce genre
// sont restees en francais dans une page declaree entierement traduite, parce
// que le test passait. Celui-ci ne regarde pas l'ecran : il lit le CODE, a
// chaque endroit ou la page prend la parole, et refuse tout texte qui n'y entre
// pas par tr().
//
// CE QU'IL NE VOIT PAS, et il faut le savoir : un message construit dans une
// variable puis passe au bandeau (`msg='…'; informer(msg)`) ne montre aucun
// litteral a l'appel. C'est le travail de la section « ce que la page dit » de
// test-anglais.js, qui declenche ces cas pour de vrai.
console.log('\n--- aucun texte brut n\'atteint ce que la page dit ---');
// Les numeros de ligne doivent rester ceux du fichier : la table, retiree de la
// recherche plus haut, est remplacee par autant de lignes vides.
const nbLignesTable=brut.slice(debutTable,finTable).split('\n').length-1;
const codeSeul=brut.slice(0,debutTable)+'\n'.repeat(nbLignesTable)+brut.slice(finTable);
// Chaque endroit ou la page parle, et comment chaque argument doit etre dit.
//   'site'  → traduit a l'appel : tr('phrase {0}',x). C'est la regle des
//             messages, qui portent des trous et des pluriels.
//   'puits' → traduit UNE fois par la fonction qui l'affiche. C'est la regle
//             des etiquettes d'une panne (« Logiciels », « Import ») : un mot
//             fixe, repete a vingt endroits, et inutile a envelopper vingt fois.
//             Le litteral doit alors etre une cle de la table.
//   null    → l'argument ne s'affiche pas (un booleen, une fonction a executer).
const PAROLES={
  informer:['site'], memoriserAnnulation:['site'],
  signalerPanne:['puits','site'], proteger:['puits'],
  traiterDonnees:[null,'site'], dire:['site'], afficherBandeau:['site']
};
function depiler(s){
  return s.replace(/\\(['"\\nrt])/g,function(_,c){return c==='n'?'\n':c==='r'?'\r':c==='t'?'\t':c;});
}
// Lit un appel a partir de la parenthese ouvrante, en respectant les chaines et
// les commentaires. Rend les arguments de premier niveau, ou null si le code
// est illisible — et un code illisible fait ECHOUER le test plutot que passer.
function lireAppel(src,debut,surPointVirgule){
  const args=[];let cour='';let prof=0;let i=debut+1;
  while(i<src.length){
    const c=src[i];
    if(c==="'"||c==='"'||c==='`'){
      let j=i+1;
      while(j<src.length&&src[j]!==c){ if(src[j]==='\\')j++; j++; }
      cour+=src.slice(i,j+1); i=j+1; continue;
    }
    if(c==='/'&&src[i+1]==='/'){ while(i<src.length&&src[i]!=='\n')i++; continue; }
    if(c==='/'&&src[i+1]==='*'){ i=src.indexOf('*/',i+2)+2; continue; }
    if(c===';'&&prof===0&&surPointVirgule){ args.push(cour); return {args:args,fin:i}; }
    if(c==='('||c==='['||c==='{')prof++;
    if(c===')'||c===']'||c==='}'){
      if(prof===0){ args.push(cour); return {args:args,fin:i}; }
      prof--;
    }
    if(c===','&&prof===0){ args.push(cour); cour=''; i++; continue; }
    cour+=c; i++;
  }
  return null;
}
// Un litteral qu'on COMPARE (`m==='compact'`) n'est pas un texte affiche : il
// decide de ce qu'on dit, il ne le dit pas. Sans cette retouche le controle
// criait sur chaque ternaire.
function sansComparaisons(s){
  return s.replace(/[=!]==?\s*(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")/g,'')
          .replace(/(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")\s*[=!]==?/g,'');
}
// Retire de l'argument chaque tr(…), en gardant sa cle quand elle est un seul
// litteral. Ce qui reste est ce qui atteindrait l'ecran sans etre traduit.
function sansTr(arg){
  const cles=[];let reste='';let i=0;
  const re=/(^|[^A-Za-z0-9_$.])tr\(/g;
  while(i<arg.length){
    re.lastIndex=i;
    const m=re.exec(arg);
    if(!m){ reste+=arg.slice(i); break; }
    const ouvre=m.index+m[0].length-1;
    reste+=arg.slice(i,m.index)+m[1];
    const a=lireAppel(arg,ouvre);
    if(!a){ reste+='<ILLISIBLE>'; break; }
    const seul=/^\s*(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")\s*$/.exec(a.args[0]||'');
    if(seul)cles.push(depiler(seul[1]!==undefined?seul[1]:seul[2]));
    i=a.fin+1;
  }
  return {reste:reste,cles:cles};
}
const nomsParoles=Object.keys(PAROLES);
const reAppel=new RegExp('(^|[^A-Za-z0-9_$.])('+nomsParoles.join('|')+')\\(','g');
const bruts=[],sansCle=[],illisibles=[];
let nbAppels=0,m;
while((m=reAppel.exec(codeSeul))){
  const nom=m[2];
  const avant=codeSeul.slice(Math.max(0,m.index-12),m.index+m[1].length);
  if(/function\s+$/.test(avant))continue;            // la definition, pas un appel
  const ouvre=m.index+m[0].length-1;
  const ligne=codeSeul.slice(0,ouvre).split('\n').length;
  const a=lireAppel(codeSeul,ouvre);
  if(!a){ illisibles.push(nom+' l.'+ligne); continue; }
  nbAppels++;
  PAROLES[nom].forEach(function(mode,i){
    if(!mode)return;
    const arg=a.args[i]||'';
    if(mode==='puits'){
      // Une variable (`ou`, passee de fonction en fonction) n'a rien a verifier
      // ici : c'est son point de depart, un litteral, qui sera examine.
      const seul=/^\s*(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")\s*$/.exec(arg);
      if(!seul)return;
      const k=depiler(seul[1]!==undefined?seul[1]:seul[2]);
      if(!(k in TR.en))sansCle.push(nom+' l.'+ligne+' (puits) : '+JSON.stringify(k.slice(0,60)));
      return;
    }
    const s=sansTr(arg);
    if(/<ILLISIBLE>/.test(s.reste)){ illisibles.push(nom+' l.'+ligne); return; }
    // Un morceau de texte ne compte que s'il porte une lettre : « , », « . » et
    // « ( » ne se traduisent pas, et en exiger la traduction serait absurde.
    const lits=sansComparaisons(s.reste).match(/'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"/g)||[];
    lits.filter(function(l){return /[A-Za-zÀ-ÿ]{2,}/.test(l);}).forEach(function(l){
      bruts.push(nom+' l.'+ligne+' : '+l.slice(0,70));
    });
    s.cles.forEach(function(k){
      if(!(k in TR.en))sansCle.push(nom+' l.'+ligne+' : '+JSON.stringify(k.slice(0,60)));
    });
  });
}
ok('le code des appels est lisible',illisibles.join(' | '),'');
ok('la recherche a trouve des appels (elle ne tourne pas a vide)',nbAppels>30,true);
bruts.slice(0,60).forEach(function(l){ console.log('      brut : '+l); });
ok('aucun litteral brut dans ce que la page dit',bruts.length,0);
sansCle.slice(0,30).forEach(function(l){ console.log('      sans traduction : '+l); });
ok('chaque cle passee a tr() existe dans la table',sansCle.length,0);

// Les memes textes peuvent aussi arriver a l'ecran sans passer par le bandeau :
// un libelle de bouton reecrit apres un clic (« ✓ Copié ! »), l'etat d'une
// bascule (« Clair » / « Sombre »), une info-bulle. Ils s'ecrivent par
// `.textContent = …` ou `.title = …`.
// `.innerHTML` n'est pas examine : son contenu est du balisage, qui porte des
// lettres (« div », « class ») sans etre du texte, et le controle y crierait
// au loup.
const affectes=[];let nbAffectations=0,m2;
// Ce qui n'est pas une phrase a traduire : le nom du produit, qui est le meme
// dans toutes les langues. Chaque entree est une decision, pas un oubli.
const NOMS_PROPRES={'Migration PC':'nom du produit, identique dans toutes les langues'};
const reAff=/\.(?:textContent|title|innerHTML)\s*=(?!=)/g;
while((m2=reAff.exec(codeSeul))){
  const ouvre=m2.index+m2[0].length-1;
  const ligne=codeSeul.slice(0,ouvre).split('\n').length;
  const a=lireAppel(codeSeul,ouvre,true);
  if(!a){ illisibles.push('affectation l.'+ligne); continue; }
  nbAffectations++;
  const s=sansTr(a.args[0]||'');
  const estHtml=/\.innerHTML/.test(m2[0]);
  // innerHTML : seulement l'affectation d'un litteral NU. Une expression qui
  // appelle une fonction (`messageOngletVide('apps')`) porte des identifiants,
  // pas du texte, et le controle y crierait au loup.
  if(estHtml&&!/^\s*(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")\s*$/.test(a.args[0]||''))continue;
  (sansComparaisons(s.reste).match(/'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"/g)||[])
    // innerHTML porte du balisage, dont les lettres (« div », « class ») ne sont
    // pas du texte : on n'y examine que les litteraux sans balise, comme
    // `innerHTML='✓ Copié !'`. Un texte glisse dans du balisage reste un trou connu.
    .filter(function(l){return !(estHtml&&/</.test(l));})
    .filter(function(l){return !(l.slice(1,-1) in NOMS_PROPRES);})
    .filter(function(l){return /[A-Za-zÀ-ÿ]{2,}/.test(l);})
    .forEach(function(l){ affectes.push('affectation l.'+ligne+' : '+l.slice(0,60)); });
  s.cles.forEach(function(k){
    if(!(k in TR.en))sansCle.push('affectation l.'+ligne+' : '+JSON.stringify(k.slice(0,60)));
  });
}
ok('la recherche des affectations ne tourne pas a vide',nbAffectations>20,true);
affectes.slice(0,40).forEach(function(l){ console.log('      brut : '+l); });
ok('aucun litteral brut affecte a un texte',affectes.length,0);

console.log(ko?'\n'+ko+' TEST(S) EN ECHEC':'\nMECANIQUE DE LANGUE : OPERATIONNELLE');
process.exit(ko?1:0);
