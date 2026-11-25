# Migration PC — Journal

L'histoire du projet : ce qui a été fait, et ce que chaque lot a révélé de plus que prévu. L'état actuel est dans
`README.md`, ce qui reste dans `RESTE-A-FAIRE.md`, la façon de tester et de publier dans `CONTRIBUER.md`. Chaque lot
s'ajoute en fin de fichier, sous `### Titre — jj/mm/aaaa`.

## Lots fermés de RESTE-A-FAIRE.md (déplacés tels quels le 16/11/2026)

### Lot 1 — Le BOM du fichier qu'on double-clique → **fait**

**Fait le 27 octobre 2026.** Les trois octets sont partis (le fichier était de l'ASCII pur
après eux, rien d'autre n'a changé), et `test-lanceur.ps1` lit désormais les octets. Le
contrôle a été vu échouer sur l'ancien fichier avant la correction. Ce qui reste vrai : aucun
cmd.exe n'a jamais lu ce fichier ici, et le job Windows de la CI ne l'exécute pas.

**En tout premier** : trois octets à retirer, aucune dépendance, et c'est le défaut le plus
visible du projet — la première chose qu'un utilisateur voit. Détail : section 6, défaut 1.

Le contrôle qui l'accompagne compte autant que la correction. `test-lanceur.ps1` vérifie
déjà les fins de ligne de ce fichier, mais il le lit avec `ReadAllText`, qui décode et
supprime le BOM : le test écrit pour cette famille de problème est aveugle à ce cas. Le
nouveau contrôle lit **les octets**, pas le texte.

*Fini quand* : les trois premiers octets de `Migration PC.bat` ne sont plus `EF BB BF`, un
contrôle au niveau octet refuse leur retour, et il échoue si on les remet.

*Ce qu'il faut pour démarrer* : rien.

### Lot 2 — Le canal de notification, jamais traduit → **fait**

**Fait le 27 octobre 2026.** Le périmètre était plus large que l'audit : « 17 messages » était
le nombre d'appels à `informer()` seul. Le contrôle écrit pour ce lot a trouvé, en lisant le
code, **72 morceaux de texte brut** à sept points d'entrée (`informer`, `memoriserAnnulation`,
`dire`, `signalerPanne`, `proteger`, la provenance d'un import) et **onze affectations de
`.textContent`** que personne n'avait comptées, dont l'indicateur de sauvegarde. Tout passe
maintenant par `tr()`, par phrases entières, une par cas.

Ce que le travail a révélé en plus :
- Le message de panne de stockage renvoyait vers un bouton « Sauvegarder » **qui n'existe
  plus** (fusionné avec « Exporter le profil »). C'est le message qui prévient d'une perte
  de données ; il est corrigé dans les deux langues.
- Trois singuliers fautifs en français : « 1 paquets », « 1 applications », « 1 tâches
  cochées ». Corrigés, parce qu'écrire une phrase par cas oblige à décider du cas « un ».
- Les libellés du thème et de l'affichage mentaient sur l'état après un changement de
  langue, **et** restaient en français au démarrage d'une page anglaise. Les deux sont
  gardés par un test.

Le français est inchangé partout ailleurs : le même test, lancé contre l'ancien
`index.html`, donne 62 échecs, et le français de 34 scénarios sur 41 est identique mot pour
mot — les sept autres sont les corrections ci-dessus.

**Resté ouvert, et c'est à toi de trancher :**
- `remiseAZero()` dit **deux phrases différentes** pour le même événement selon qu'un profil
  était mémorisé, et la seconde parle de « notes et clés » — les notes ont été supprimées du
  projet. Traduite fidèlement, pas réécrite : la réécrire est une décision de contenu.
- Les commentaires d'en-tête des scripts winget générés (« # Exécuter dans PowerShell en
  tant qu'administrateur ») restent en français dans la page anglaise. Ce n'est pas un
  message de l'interface mais le contenu d'un fichier téléchargé ; le traduire changerait un
  export, ce que ce projet traite à part.
- Le contrôle statique ne voit pas un texte glissé dans du balisage (`innerHTML` avec des
  balises) ni un message construit dans une variable ; le second cas est couvert par les
  scénarios du test anglais, le premier est un trou connu.

**En deuxième** parce que c'est le plus étendu, et parce qu'une seule cause racine explique
tout le lot : du texte destiné à l'utilisateur qui ne passe pas par `tr()`. Détail :
section 6, défauts 2 et 3.

Trois choses y entrent ensemble, et les séparer serait traiter trois fois la même cause :
les 17 messages de `informer()`, les deux libellés de bascule qui se réécrivent en français
brut par-dessus leur propre `data-t`, et l'échec silencieux de `copyCatWinget` qui appartient
au même code.

Le test est la moitié du lot, et il doit faire ce qu'aucun test actuel ne fait :
**déclencher réellement une notification sur la page en anglais**, puis lire le bandeau.
`test-anglais.js` passe aujourd'hui parce qu'il n'inspecte que le DOM statique.

*Fini quand* : les 17 chaînes sont dans la table et passent par `tr()`, basculer le thème
puis la langue ne produit plus un libellé qui mente sur l'état, et un test déclenche une
notification en anglais et refuse d'y lire du français.

*Ce qu'il faut pour démarrer* : rien. Les deux appels déjà corrects montrent la forme
attendue.

### Lot 6 — Le service worker met en cache ce qu'il promet de ne pas garder → **fait**

**Fait le 16 novembre 2026.** Le gestionnaire `fetch` ne traite plus que les adresses du
squelette ; tout le reste va au réseau sans entrer dans le cache. `test-pwa.js` charge un
inventaire factice une fois la page contrôlée et refuse toute entrée hors du squelette : vu
échouer sur l'ancien `sw.js` (`/resultat-scan.js` en cache), vert après, hors ligne intact.
**Ce que le travail a révélé de plus** : depuis l'audit, `index.html` ne charge plus
l'inventaire qu'en `file://`, où aucun service worker n'existe ; le chemin décrit par l'audit
était donc déjà fermé, mais le défaut de fond (tout GET de même origine gardé) restait. Le
premier contrôle écrit passait pour cette raison, sans rien regarder : il demande maintenant
le fichier lui-même.

**En sixième** parce que c'est le seul défaut de l'audit dont l'usage prévu est épargné.
Détail : section 6, défaut 5.

Le commentaire de `sw.js` promet « Jamais de données ». Son gestionnaire `fetch` met en
cache tout GET de même origine qui répond `ok`, et la page charge l'inventaire du PC par un
`<script src="resultat-scan.js">`, qui en est un. Depuis une clé USB en `file://` aucun
service worker ne s'enregistre, donc le trajet normal du projet ne rencontre pas ce défaut ;
servir le dossier en HTTPS ou sur localhost, si.

*Fini quand* : le cache ne retient que le squelette qu'il déclare, un contrôle le vérifie,
et le commentaire décrit ce que le code fait.

*Ce qu'il faut pour démarrer* : rien.

## Lots

### Règles communes et suivi unifié — 16/11/2026

Bloc commun des 8 dépôts en tête de `CLAUDE.md` (décisions d'Antoni : fusion sur « go » seulement, noms de modèle
autorisés, zones tactiles de 48 px dans les applis utilisées au doigt, ce que ce projet n'est pas). Ce journal est créé :
le détail des lots fermés 1, 2 et 6 y passe tel quel, `RESTE-A-FAIRE.md` garde leur titre et un renvoi.

### CI, trois niveaux — 16/11/2026

Bloc commun : règle « CI, trois niveaux » (rapide à chaque PR, lourd seulement si autre chose que des `.md` change, appareil réel). Le job Linux est coupé en deux : « Tests rapides » (les suites Node et PowerShell sans navigateur, sans `npm ci`,
à chaque PR) et « Tests navigateur » (Chromium et les onze suites qui le pilotent). Celui-ci et « Tests sur Windows »
dépendent d'un job `changements` et se sautent sur une PR qui ne touche que des `.md` ; `test-archive.js`, qui vérifie la
présence d'un guide `.md` dans l'archive, reste dans les rapides. La publication attend les trois. Aucune suite retirée ni
déplacée hors de la CI ; leur liste dans `package.json` et `verifier-comme-ci.sh` ne change pas.

### Actions figées par SHA ; CSP écartée — 16/11/2026

- Les 10 appels d'actions de `ci.yml` sont figés sur un commit précis, la version en commentaire : une étiquette comme
  `@v5` peut être déplacée par son auteur, ou par qui lui vole son compte. Dependabot (déjà en place, mensuel) met à jour
  le commit et le commentaire.
- CSP envisagée puis écartée : la page compte 61 gestionnaires d'événements écrits dans le HTML (`onclick=`…) et charge
  `resultat-scan.js` par `document.write`, qu'une CSP stricte bloquerait. Il faudrait réécrire une bonne partie de la page
  pour un gain faible ; `test-profil-hostile.js` garde déjà l'injection par un profil reçu.

### Règles communes : trois changements — 21/11/2026

Bloc commun de `CLAUDE.md` mis à jour (décision d'Antoni) : deux règles en plus et une règle précisée, « Versions et API » (vérifier les
versions dans la doc officielle, signaler tout code déprécié) et « Contradiction » (signaler une demande qui contredit une
règle avant de l'appliquer) ; « Proposer d'abord » demande désormais un plan détaillé et des suggestions avant tout code, et un visuel (maquette HTML ou schéma ASCII) pour une fonctionnalité ou un design ; « les 8 dépôts » devient « tous les dépôts d'Antoni, existants et futurs », avec l'arrivée de game_timer.

### Règles communes : « Proposer d'abord » reformulée — 21/11/2026

Formulation d'Antoni : un plan détaillé (étapes, fichiers touchés, approche) et des suggestions d'amélioration avant tout changement, puis l'« ok » ; pour une fonctionnalité ou un design, proposer sans coder, avec questions et visuel (maquette HTML sans canvas ou schéma ASCII). Le bloc est identique dans tous les dépôts et dans le skill `regles-communes-depots`.

### Règles communes mises à jour — 21/11/2026

Bloc commun de `CLAUDE.md` aligné sur `regles-communes` (BLOC.md, commit 98885d3), par la propagation automatique.

### Règles communes mises à jour — 21/11/2026

Bloc commun de `CLAUDE.md` aligné sur `regles-communes` (BLOC.md, commit 400626b), par la propagation automatique.

### Règles communes mises à jour — 21/11/2026

Bloc commun de `CLAUDE.md` aligné sur `regles-communes` (BLOC.md, commit 2005adb), par la propagation automatique.

### Couleurs en jetons — 24/11/2026

Audit de la règle commune « Design ». Le `<style>` écrivait 18 couleurs dans les règles elles-mêmes : le blanc posé sur
l'accent (12 fois), deux survols (clair et sombre, dont une règle `[data-theme=dark]` à part), le fond du badge d'onglet,
l'ombre du menu et le bandeau de panne. Ils deviennent `--sur-acc`, `--survol`, `--tab-badge-bg`, `--ombre-menu`,
`--panne-bg` et `--panne-bd`, mêmes valeurs : rien ne change à l'écran. `tests/test-couleurs.js` refuse toute couleur
hors d'une définition de jeton, blocs `@media print` exceptés (une page imprimée est noire sur blanc quel que soit le
thème) ; enregistré dans `package.json`, `ci.yml` et `verifier-comme-ci.sh`. Vu rouge sur l'ancien code (18 relevés),
vert après. Plus que les « deux survols » annoncés par l'audit : il ne comptait que les `rgba`.
Vérifié : toutes les suites Node de `verifier-comme-ci.sh` (accessibilité et mobile compris) ; les suites PowerShell ne
tournent pas dans ce conteneur (pas de `pwsh`), la CI les joue. Deux survols à contraste faible, repérés en route, sont
notés dans `RESTE-A-FAIRE.md` (lot E), pas corrigés ici.

### Survols lisibles : le blanc sur un fond fait pour lui — 24/11/2026

Repéré pendant le lot E. Trois survols posaient du blanc sur un fond trop clair : `.next-btn` et `.sm-btn.warn-btn` sur
`--acc` (#5493FF, 3,00:1), `.reglages-danger button` en sombre sur `--bh-tx` (#f09595, 2,23:1). Ils passent sur `--acc-fond`
(4,59:1) et sur un nouveau `--danger-fond` (#a32d2d, 7,07:1, le même dans les deux thèmes). `tests/test-couleurs.js` refuse
désormais le blanc sur un autre fond que ces deux-là (vu échouer sur l'ancien code : les trois survols). axe-core ne mesure
pas un état de survol, d'où ce contrôle par déclaration. Repéré et non corrigé : la coche blanche sur `--bok-tx` en sombre
(2,03:1). Vérifié : toutes les suites Node de `verifier-comme-ci.sh` ; PowerShell par la CI.

### Coche lisible en thème sombre — 25/11/2026

Choix d'Antoni : la coche d'une case « après réinstallation » cochée prend la couleur du fond de page (`var(--bg)`) au lieu du
blanc. Blanche sur le vert foncé du thème clair (6,21:1, inchangé), presque noire sur le vert clair du thème sombre (8,76:1, au
lieu de 2,03:1). Le vert ne change pas. `tests/test-couleurs.js` lit chaque règle « .done .chkbox », son fond et sa couleur, et
mesure le rapport avec les jetons des deux thèmes (seuil 3:1 d'un signe graphique) ; vu échouer sur l'ancien code (2,03:1).
La coche ordinaire (blanc sur `--acc`) tient 3,00:1, juste au seuil. Vérifié : toutes les suites Node de `verifier-comme-ci.sh` ;
PowerShell par la CI.

### Règles communes mises à jour — 25/11/2026

Bloc commun de `CLAUDE.md` aligné sur `regles-communes` (BLOC.md, commit 864f26d), par la propagation automatique.

### Icônes Material au lieu des emojis — 25/11/2026

Règle commune « Design » écrite le même jour (choix d'Antoni) : jamais d'emoji comme icône, des Material Symbols de Google en
variante arrondie, embarqués. La page en affichait une trentaine de différents (95 occurrences relevées par le nouveau test) :
leur dessin dépendait de la police du système, sans suivre la couleur ni le thème. Ils deviennent des `<symbol>` d'un sprite
en tête du body (tracés de @material-symbols/svg-400 0.49.0, Apache-2.0, copiés : aucune police ni requête, `file://` intact)
appelés par `icone(nom)`. Choix d'Antoni : les profils gardent l'emoji de tête de leurs catégories (c'est du contenu, exporté
tel quel) et `catAff()` le remplace à l'affichage par l'icône correspondante ; les champs de recherche portent une loupe à
gauche, leur texte d'aide perd l'emoji. Les clés de traduction perdent leur emoji (l'icône est posée à côté, hors `tr()`) ;
les doublons qui en résultaient (« Ouvrir », « Rechercher ») sont fusionnés. Un « ↩ » et un « ⊘ » ont été trouvés en plus
de l'audit (Annuler, Ignorer). `tests/test-icones.js` refuse tout pictogramme hors profils et commentaires et vérifie que
chaque icône appelée existe dans le sprite (vu échouer : 95 relevés) ; enregistré à trois endroits. Cinq tests lisaient les
anciens textes (`test-ignorer`, `test-langue`, `test-guide`, `test-profil-hostile`, `test-anglais`) : ils vérifient maintenant
le mot et la présence de l'icône ; `test-profil-hostile` n'admet comme `<svg>` que les icônes du sprite, qui ne contiennent
qu'un `<use href="#i-…">`. Vérifié : les 23 suites Node de `verifier-comme-ci.sh` ; PowerShell par la CI.

### Mention « Fait par AntoniMan31/Claude Code » et version — 25/11/2026

Règle commune « Interface » écrite le même jour (choix d'Antoni : Réglages › À propos, même texte dans toutes les langues).
Le panneau « Réinitialiser… » se termine par un bloc « À propos » (« About » en anglais) : « Fait par AntoniMan31/Claude Code ·
version a1b2c3d du 25/11/2026 ». La version vient d'une balise `<meta name="version-deployee">` dont le job de déploiement
(`ci.yml`) remplace les marqueurs `__COMMIT__` et `__BUILD_DATE__`, avant `construire-zip.sh` pour que l'archive porte la
même version, et refuse de publier s'il en reste un. Une balise plutôt qu'un script : le contenu change au déploiement sans
toucher aux scripts. Hors déploiement : « version locale ». La date se lit en heure de Paris. Le texte passe par `tr()` avec
une traduction identique. `test-anglais.js` refusait, à raison, ce texte français sur la page anglaise : il retire cette seule
ligne exacte, raison écrite à côté. Contrôles vus échouer sur le code d'avant : `test-reinit.js` (mention absente) et
`test-archive.js` (déploiement sans marqueurs). Vérifié : `npm test` et les suites Node de `verifier-comme-ci.sh` (les
suites PowerShell n'ont pas tourné ici, faute de `pwsh` : la CI les joue) ; le remplacement des marqueurs rejoué sur une copie.

### Signature : logo AM.31 aux couleurs de la page — 25/11/2026

Suite de la mention du même jour (choix d'Antoni : variante C d'une maquette, texte centré). Le bas du panneau « Réinitialiser… » porte le
logo AM.31 (34 px de haut), « Fait par AntoniMan31/Claude Code » (le nom en `--acc-fort`) et « version a1b2c3d · jj/mm/aaaa ». Le logo est
en trois calques (contour, remplissage, reflets) que le CSS colore avec `--acc-fond` mêlé de noir ou de blanc. Les masques sont intégrés à la
page en données (25 Ko environ) : la page reste un seul fichier, utilisable depuis une clé USB en `file://`. Un double clic (vrai bouton de 48 px,
`appuiLogoAm31`) alterne l'accent et le bleu d'origine (`--logo-contour`, `--logo-remplissage`) ; rien n'est mémorisé, pas de lien GitHub
(choix d'Antoni). Le double appui se compte à la main (deux appuis de moins de 350 ms) : `dblclick` n'existe pas au clavier. `ligneVersion`
devient `versionTexte`. Le plancher de 12 px du texte (`test-plancher-texte.js`) a refusé la ligne de version à 11 px : elle passe à 12 px.
`test-anglais.js` retire de son contrôle les deux lignes exactes de la signature, texte identique en français et en anglais par choix.
Contrôles vus échouer sur le code d'avant : `test-reinit.js` (signature absente). Vérifié : `npm test` et les suites navigateur (réinit, anglais,
accessibilité, mobile, profil hostile, archive, PWA, langue) ; les suites PowerShell n'ont pas tourné ici (pas de `pwsh`), la CI les joue.

### Règles communes mises à jour — 25/11/2026

Bloc commun de `CLAUDE.md` aligné sur `regles-communes` (BLOC.md, commit 8e4cde6), par la propagation automatique.
