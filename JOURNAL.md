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
