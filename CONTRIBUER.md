# Toucher au code

Comment les tests sont organisés, ce qu'ils prouvent et ce qu'ils ne prouvent
pas, et comment le dépôt se publie. Pour se servir du programme, voir
[README.md](README.md) ; pour le format des profils,
[FORMATS.md](FORMATS.md) ; pour ce que le scan détecte et refuse de détecter,
[COUVERTURE.md](COUVERTURE.md).

## Tests

```bash
npm install                       # une seule fois
./verifier-comme-ci.sh            # les 18 étapes du job Linux, dans l'ordre
npm test                          # les sept suites sans navigateur, en 2 s
npm run test:scan                 # les quatre suites PowerShell
npm run test:navigateur           # rendu réel dans Chromium
npm run test:pwa                  # installabilité et fonctionnement hors ligne
npm run test:mobile               # ergonomie tactile
npm run test:a11y                 # accessibilité et réversibilité
npm run test:guide                # mode guidé
npm run test:reinit               # remises à zéro et leur annulation
npm run test:menu                 # menu « Plus » de la barre du haut
npm run test:hostile              # profil piégé : aucune injection
npm run test:config               # bloc configuration et affichage grand écran
npm run test:reconciliation       # comparaison source → cible
npm run test:archive              # contenu de l'archive téléchargeable
```

`npm test` ne lance que ce qui tourne partout sans rien installer. Les suites
navigateur demandent Chromium (`npm install` le fournit via Playwright), les suites
PowerShell demandent `pwsh`.

Vingt-quatre suites. Vingt-trois tournent dans le job Linux, dans l'ordre où la CI les
lance ; `tests/test-windows-reel.ps1` n'a de sens que dans le job Windows.

### Ce que seul un vrai Windows peut dire

Les suites PowerShell tournent sur Linux, contre des données écrites à la main : elles
vérifient un raisonnement, jamais Windows. Le registre, `Get-AppxPackage`, WMI et
l'encodage d'une console réelle n'y sont jamais exercés — et c'est pourtant là que ces
scripts vont tourner.

La CI les rejoue donc aussi sur un runner `windows-latest`, deux fois : sous PowerShell 7,
puis sous **Windows PowerShell 5.1**, celui qui est livré avec Windows et celui qu'on
obtient en double-cliquant sur un `.bat`. C'est la version que les gens exécutent
vraiment, et elle n'avait jamais rien exécuté.

Ce job **bloque la publication**, au même titre que les suites Linux : rien ne part en
ligne sans avoir tourné sur le système où il est censé tourner. Il a démarré en
`continue-on-error` le temps de se stabiliser — un garde-fou neuf qui bloquerait le site
serait pire que pas de garde-fou — et il l'a perdu dès qu'il a été vert deux fois de
suite. Un garde-fou qui laisse passer ce qu'il refuse ne sert qu'à décorer.

`tests/test-windows-reel.ps1` va plus loin : il lance le scan pour de vrai, sur la vraie
machine. Un runner n'est pas un PC de bureau — on ne sait pas ce qui y est installé —
donc il vérifie la **forme** de ce qui sort et les erreurs qui ne doivent jamais
apparaître : le registre a répondu, WMI aussi, aucun nom n'est abîmé par l'encodage,
aucune exception n'a échappé aux garde-fous, aucun composant Windows n'est présenté
comme un jeu Xbox, aucun certificat n'est recopié à la place d'un éditeur. Hors Windows,
ce fichier s'arrête en le disant plutôt que de prétendre avoir vérifié quoi que ce soit.

Ce que même ça ne teste pas : votre carte mère, vos pilotes, Steam, Epic, GOG, et
le lanceur sur une vraie session. Un runner est un Windows Server nu.

Ça a payé au premier passage utile. `Get-ChildItem -Include` combiné à `-LiteralPath`
est **ignoré par Windows PowerShell 5.1**, qui rend alors tous les fichiers au lieu des
seuls demandés : la recherche de clés de signature rapportait le disque entier. PowerShell 7
le respecte, donc le défaut était invisible partout sauf là où il compte — sur la machine
de quelqu'un, par double-clic. Le filtre se fait maintenant à la main, et un contrôle
statique interdit ce mélange dans tout le dépôt.

`tests/test-profil-sync.js` garantit que le profil embarqué dans `index.html` et
`presets/exemple.json` ne divergent pas, et vérifie les invariants du profil :
identifiants uniques sur les deux listes, priorités valides, catégories déclarées,
ordre conseillé ne citant que des éléments existants. Il contrôle aussi que les fichiers
dont les tests dépendent sont bien versionnés, et qu'aucune fonction n'est définie deux
fois dans `index.html` — une redéfinition écrase silencieusement la première et ce piège
a coûté trois bugs au projet.

`tests/test-checklist.js` extrait le JS de `index.html` et l'exécute dans un DOM simulé.
Il rejoue l'import d'un inventaire réellement produit par le scanner
(`tests/inventaire-exemple.json`), ce qui couvre la chaîne de bout en bout.

`tests/test-scan.ps1` couvre le classement, la fusion entre sources, le parsing de la
sortie winget et la mise en forme du matériel, des pilotes et de la machine, sans toucher
à la machine.

`tests/test-reconciliation.js` est la seule partie du projet qui se prouve vraiment : la
comparaison ne touche ni à Windows ni au DOM, elle prend deux JSON et rend un rapport.

`tests/test-ignorer.js` couvre le fait d'écarter une ligne : qu'elle reste affichée mais
sorte du total, du script winget et du mode guidé ; que cocher et écarter se chassent dans
les deux sens ; que l'identifiant fabriqué pour un périphérique ne dépende que de son nom,
puisque sa position dans la liste bouge d'un scan à l'autre ; que « Tout décocher » garde les
lignes écartées et « Tout effacer » les enlève ; et que l'annulation les rende — ce dernier
point parce que le bandeau promet une annulation, et qu'un instantané incomplet la rendrait
menteuse, comme ce fut le cas pour la configuration matérielle.

`tests/test-langue.js` vérifie la mécanique de traduction, et `tests/test-anglais.js`
vérifie qu'elle a été appliquée partout. Le second est écrit à l'envers des autres : il
cherche ce qui **ne doit pas** être là. Un test qui vérifie la présence de traductions se
satisfait de la première ; un test qui refuse le français ne passe que quand il n'en reste
plus. Il a quatre détections, parce qu'aucune ne suffit seule — les accents, une liste de
mots, les clés de la table cherchées telles quelles, et la comparaison ligne à ligne de la
page française avec la page anglaise. Les trois premières dépendent de quelque chose écrit
à la main, et la deuxième a laissé passer « Passer » : pas d'accent, pas dans la liste. La
quatrième ne dépend de rien et l'a trouvé. Ce qu'aucune des quatre ne voit est écrit en
tête du fichier : un intitulé d'interface dont le texte est exactement celui d'une valeur
du profil est effacé des deux côtés par le retrait du profil.

`tests/cles-normalisation.json` est un contrat partagé, et il mérite une explication. La
liste de ce qui manque est calculée **deux fois** : par la page, en JavaScript, pour
l'afficher ; et par le scan de la cible, en PowerShell, pour écrire le
`winget-restant.json` que le menu joue. C'est une duplication assumée — le fichier de la
page part dans les téléchargements du navigateur, où le menu ne peut pas le retrouver.
Deux normalisations de noms différentes rapprocheraient alors des logiciels différents de
chaque côté, sans que rien ne le signale. Ce fichier liste vingt noms et la clé attendue ;
`test-reconciliation.js` et `test-scan.ps1` le rejouent tous les deux, donc une divergence
fait tomber l'un des deux. Si vous touchez à `cleNom` ou à `Get-CleNom`, touchez aux deux.

`tests/test-navigateur.js` charge la page dans un vrai Chromium et vérifie ce qu'un DOM
simulé ne voit pas : que les quatre panneaux sont bien frères et non imbriqués, que les
éléments ont une taille non nulle, que la saisie de la configuration survit à un
rechargement, et qu'une exception pendant un rendu s'affiche au lieu de disparaître.
Deux variables d'environnement facultatives : `CHROME` pour pointer un binaire Chromium
existant, `PROFIL` pour tester votre propre profil à la place de l'exemple (par défaut
il cherche `profil-local.json` à la racine).

`tests/test-pwa.js` sert le dépôt en HTTP local — un service worker ne s'enregistre pas
en `file://` — et vérifie que la page s'installe, se met en cache et s'ouvre réseau
coupé, tout en restant fonctionnelle en `file://`.

`tests/test-mobile.js` ouvre la page à la largeur de deux téléphones, dans les deux
thèmes, et mesure les cibles tactiles, les écarts entre elles, les tailles de texte et
les débordements horizontaux. Par défaut il rapporte ; `STRICT=1` le fait échouer, ce
que la CI utilise.

`tests/test-accessibilite.js` calcule le contraste de chaque texte sur le fond
réellement peint dans les deux thèmes, parcourt la page au clavier jusqu'à cocher une
tâche, vérifie les rôles et états annoncés, l'annulation des actions destructrices et le
respect du mouvement réduit.

`tests/test-guide.js` couvre le mode guidé : ce qui doit rester visible, ce qui doit
disparaître, le parcours d'une tâche à l'autre, la copie de la commande dans le
presse-papier, et le fait que ce mode tient les mêmes exigences de contraste, de cible
tactile et de clavier que la vue liste.

`tests/test-reinit.js` couvre les deux remises à zéro : que « Tout décocher » ne touche
ni au profil, ni à la configuration matérielle, que « Tout effacer » vide bien les trois clés du
navigateur et que rien ne revient après un rechargement, et que l'annulation rend dans
les deux cas ce qui avait été effacé, profil importé compris. Il mesure
aussi le panneau à 360 px de large, dans les deux thèmes.

`tests/test-menu.js` compte les boutons restés dans la barre, vérifie qu'aucun n'y est
réduit à une icône muette, que les actions du menu agissent réellement (l'affichage compact
s'applique, le fichier exporté porte les listes et les cases cochées), qu'il reste sept
entrées permanentes et une seule conditionnelle, que le menu se
referme par les trois chemins attendus et qu'il reste utilisable au clavier comme au doigt.

`tests/test-profil-sync.js` garde aussi une porte fermée : il échoue si `Get-Duree`,
`Get-Priorite`, `PRIO[` ou `fmtTime(` reviennent dans le dépôt. Ces durées et priorités
étaient inventées par mots-clés et alimentaient un « temps restant » fabriqué. « On pourrait
estimer » n'est pas une raison de les rétablir.

`tests/test-profil-hostile.js` charge un profil piégé sur quinze champs — nom de
catégorie, identifiant winget, adresse de raccourci, intitulés, descriptions, chemins —
puis clique tout ce qui est cliquable sur les trois onglets et en mode guidé. Il échoue
si une seule charge s'exécute.

`tests/test-config.js` vérifie que les composants saisis tiennent d'un rechargement à
l'autre, que seule la machine constatée par un scan de cible écrase ce qu'on a saisi pour
elle, que l'onglet Pilotes affiche les périphériques en défaut avec le lien du
constructeur, et que l'élargissement sur grand écran ne change rien au téléphone ni à la
tablette.

`tests/test-lanceur.ps1` couvre ce que le lanceur propose et ce qu'il vérifie avant : que
chaque action mène à un fichier qui existe, qu'un dossier incomplet grise les actions
concernées en nommant ce qui manque, et que les `.bat` portent bien des fins de ligne
Windows — en fins de ligne Unix, ils ne s'exécutent pas. Il vérifie aussi qu'aucun script
ne réintroduit de dépendance graphique, que la sortie console est forcée en UTF-8 — sans
quoi les accents arriveraient en charabia — et que les textes du menu en portent, sans
être abîmés. La liste des actions vit dans `lanceur-actions.ps1`, séparée de l'affichage :
c'est elle qui décide de tout, et elle se teste partout.

`tests/test-powershell-compatibility.ps1` garde un piège fermé : Windows PowerShell 5.1 —
celui livré avec Windows, et celui qu'on obtient par double-clic — lit un `.ps1` sans
marqueur d'encodage comme de l'ANSI et non de l'UTF-8. « Clés SSH » y devient
« ClÃ©s SSH », et ce texte part dans le JSON de l'inventaire, donc dans la page. Le test
vérifie que chaque script porte le marqueur, que tous parsent, et que les textes accentués
du lanceur arrivent intacts.

### Intégration continue

`.github/workflows/ci.yml` lance les vingt-trois suites Linux à chaque push et sur chaque pull
request. La publication sur GitHub Pages dépend de ce job : un test rouge, et rien n'est
mis en ligne.

Ce garde-fou suppose que Pages publie par le workflow et non par la branche — voir
[Déploiement](#déploiement).

## Déploiement

```
Migration-PC/
│   # Les deux seuls fichiers qu'on ouvre
├── Migration PC.bat              # le menu : il demande quoi faire et lance le reste
├── index.html                    # la checklist (tout est dedans)
│
│   # Ce que le menu appelle — à lire, pas à lancer à la main
├── scripts/migration-pc.ps1      # le menu qui aiguille
├── scripts/lanceur-actions.ps1   # ce qu'il propose et ce qu'il vérifie avant
├── scripts/lib-detection.ps1     # détection partagée par tous les scripts
├── scripts/ecrire-resultat.ps1   # pose le résultat à côté de la page et l'ouvre
├── scripts/scan-pc.ps1           # fige la source, puis constate sur la cible
│
├── manifest.json, sw.js, icons/  # installation et fonctionnement hors ligne
├── presets/exemple.json          # la checklist livrée, aussi embarquée dans index.html
├── presets/demonstration.json    # l'exemple garni, chargé à la demande
├── scripts-sync.js               # recopie le profil et le nom de cache du sw
├── captures/                     # images du README
├── refaire-captures.js           # les refabrique — `node refaire-captures.js`
├── resultat-scan.js              # écrit par les scripts, lu par la page en file://
├── instantane-source.json        # le relais : posé par le scan source, relu par le scan cible
├── tests/                        # suites Node, PowerShell et navigateur
├── verifier-comme-ci.sh          # rejoue localement les 18 étapes du job Linux
├── package.json                  # scripts de test uniquement
├── winget-restant.json           # écrit par le scan cible, joué par le menu
├── COUVERTURE.md                 # ce que le scan détecte, refuse et ne peut pas
├── FORMATS.md                    # les fichiers que la page lit et écrit
├── CONTRIBUER.md                 # ce fichier : tests, CI, publication
├── construire-zip.sh             # fabrique l'archive proposée au téléchargement
├── LICENSE                       # GNU AGPL v3
└── .github/workflows/ci.yml      # tests, puis publication si tout est vert
```

Les scripts PowerShell ont besoin de `lib-detection.ps1` à côté d'eux : copiez le
dossier, pas un fichier isolé.

`package.json` ne sert qu'aux tests : `index.html` n'a aucune dépendance et n'a jamais
besoin d'être construit.

Les fichiers personnels sont exclus par `.gitignore`, à la racine seulement :
`profil-*.json`, `inventaire-*.json`, `progression-*.json`, `winget-*.json` et
`winget-*.ps1`. Gardez les vôtres en local, hors du dépôt — les fichiers d'exemple de
`tests/` et `presets/` ne sont pas concernés.

Le dépôt se publie sur GitHub Pages par le workflow, pas par la branche : réglez
**Settings → Pages → Source : GitHub Actions**. Sur « Deploy from a branch », GitHub
publierait la branche en parallèle et un push dont les tests échouent partirait quand
même en ligne.

```bash
git clone https://github.com/antoniman31/Migration-PC.git
cd Migration-PC
npm install && npm test
```

URL publiée : `https://antoniman31.github.io/Migration-PC`

