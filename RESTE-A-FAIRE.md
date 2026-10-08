# Ce qui reste à faire

Écrit le 30 septembre 2026, à la clôture d'une série de sept pull requests : la
traduction complète du projet, la correction d'un défaut d'affichage, et de quoi rendre
utile le premier essai sur un vrai Windows.

Ce document existe parce qu'une décision prise en conversation ne survit pas à la
conversation. Il ne contient que ce qui est **réellement en attente** — pas une liste de
souhaits.

Mis à jour le 6 octobre 2026 : un ordre de travail, en tête. Le détail de chaque élément
reste dans les sections numérotées, et le plan y renvoie plutôt que de le répéter — deux
textes qui décrivent le même travail finissent par ne plus dire la même chose.

Mis à jour le 8 octobre 2026 : un audit complet du dépôt a trouvé onze défauts. Ils entrent
dans l'ordre de travail comme **lots 1 à 7**, devant les lots lettrés, et leur preuve est en
section 6. Ils sont écrits ici et non dans un document séparé pour la raison que l'audit
vient de démontrer six fois : deux textes qui décrivent le même travail finissent par ne
plus dire la même chose.

---

## L'ordre de travail

**L'ordre n'est pas arbitraire.** Deux éléments de ce document se dissolvent dans un autre
si on les prend dans le bon sens — le lot A dans le lot 4, et la copie du plancher de
`test-guide.js` dans le lot B — et écrire le contrat de qualité avant d'avoir tranché la
question mobile obligerait à le réécrire aussitôt. Le lot 3 chevauche le lot B sans s'y
dissoudre, et la raison est écrite dans le lot 3.

**Deux séries, et les numérotées passent avant les lettrées.** Les lots **1 à 7** viennent
de l'audit du 8 octobre 2026 : ce sont des défauts constatés, détaillés en section 6. Les
lots **A à D** sont le plan d'amélioration d'avant l'audit, et aucun d'eux n'est urgent au
sens où un défaut l'est. Corriger ce qui est cassé passe avant améliorer ce qui marche.

### Lot 1 — Le BOM du fichier qu'on double-clique

**En tout premier** : trois octets à retirer, aucune dépendance, et c'est le défaut le plus
visible du projet — la première chose qu'un utilisateur voit. Détail : section 6, défaut 1.

Le contrôle qui l'accompagne compte autant que la correction. `test-lanceur.ps1` vérifie
déjà les fins de ligne de ce fichier, mais il le lit avec `ReadAllText`, qui décode et
supprime le BOM : le test écrit pour cette famille de problème est aveugle à ce cas. Le
nouveau contrôle lit **les octets**, pas le texte.

*Fini quand* : les trois premiers octets de `Migration PC.bat` ne sont plus `EF BB BF`, un
contrôle au niveau octet refuse leur retour, et il échoue si on les remet.

*Ce qu'il faut pour démarrer* : rien.

### Lot 2 — Le canal de notification, jamais traduit

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

### Lot 3 — Le code et le CSS morts, et les exceptions périmées

**En troisième** parce que c'est du retrait, donc sans risque de régression de
comportement, et parce que le lot 4 sera plus facile à écrire sur un dépôt propre.
Détail : section 6, défauts 8 et 9.

Deux fonctions mortes (`fmtMo`, `setCat` — la troisième part au lot 5), 28 classes CSS sur
227 qui n'apparaissent plus dans le balisage, et **quatre exceptions périmées dans
`test-plancher-texte.js`** : `gp-label`, `sec-prog-txt`, `save-path`, `save-note` ont une
règle et une justification nommée, mais leur classe ne sert plus. Le test vérifie que la
règle CSS existe, pas que la classe serve — il surveille la mauvaise moitié de la paire, et
son propre commentaire décrit le piège où il est tombé.

**Chevauchement assumé avec le lot B.** Si le mobile est abandonné, la plus grande partie de
ces vingt-quatre exceptions disparaît de toute façon. Les quatre périmées se corrigent
quand même maintenant : c'est quatre lignes, le lot B est bloqué sur une décision, et une
liste fausse qui attend une décision reste une liste fausse.

*Fini quand* : plus une classe CSS déclarée sans emploi, plus une fonction définie sans
appel, les quatre exceptions parties, et le contrôle du plancher regarde désormais l'emploi
de la classe et non la seule existence de la règle.

*Ce qu'il faut pour démarrer* : rien.

### Lot 4 — Les listes et les chiffres qui ne décrivent plus le dépôt

**En quatrième, et ce lot absorbe le lot A.** Les deux demandent exactement la même
mécanique : comparer une liste écrite à la main à la réalité du dépôt, et refuser l'écart.
Le lot A ne couvrait que l'enregistrement des fichiers de test ; l'audit a montré que le
même trou laisse passer six chiffres faux. Les traiter séparément serait écrire deux fois
le même test. Détail : section 6, défaut 6, et section 4 pour la conception déjà arrêtée du
garde-fou d'enregistrement.

**Ce fichier-ci porte deux des six chiffres faux** (« dix dans un vrai navigateur »,
« vingt-quatre exceptions »). Ils ne sont pas corrigés en même temps que ce plan, parce
qu'ils appartiennent à ce lot : les corriger seuls ferait décrire par ce document un état
que le reste du dépôt n'a pas. C'est écrit ici pour que personne ne les lise en les croyant.

*Fini quand* : un seul contrôle refuse à la fois un fichier de test non enregistré, une
liste nommant un fichier disparu, et un chiffre annoncé dans la documentation qui ne
correspond plus au dépôt ; le sabotage le fait échouer dans les trois sens ; et les six
chiffres sont justes.

*Ce qu'il faut pour démarrer* : rien.

### Lot 5 — Les commandes qui mentent, et le bouton branché sur rien

**En cinquième** parce qu'une partie du lot demande un mot, et que l'autre non. Détail :
section 6, défauts 4, 7 et 10.

Ce qui ne demande rien : `npm test` ne lance que 10 des 26 suites, `npm run test:mobile`
**ne peut pas échouer** faute de `STRICT=1`, et `verifier-comme-ci.sh` affirme rejouer la CI
« dans le même ordre » alors que l'ordre diffère. C'est exactement le défaut qui a fait
écrire `verifier-comme-ci.sh` — une vérification locale plus faible que la CI — et il a
survécu dans les commandes `npm`.

Ce qui demande un mot : `importerScanCible()` est morte, elle est le seul endroit qui met
`attendCible` à vrai, donc un inventaire sans champ `role` utilisable ne peut être classé
que « source ». Deux issues, et c'est un choix de conception, pas une correction :
rebrancher le bouton « importer le scan de la cible », ou retirer le code mort et assumer
que le rôle vient toujours du fichier. La seconde est plus simple et suffit pour les
fichiers que le projet produit lui-même ; la première couvre un export winget ou un fichier
retouché à la main.

*Fini quand* : les trois commandes font ce qu'elles annoncent, et `attendCible` a disparu ou
sert.

*Ce qu'il faut pour démarrer* : un mot sur `importerScanCible` — rebrancher, ou retirer. Le
reste du lot avance sans.

### Lot 6 — Le service worker met en cache ce qu'il promet de ne pas garder

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

### Lot 7 — Les six points mineurs

**En dernier des lots numérotés**, et tenables en une seule passe. Détail : section 6,
défaut 11.

`VERIFIER-SUR-WINDOWS.md` absent du zip — celui qui fera le premier essai réel aura
`diagnostic.ps1` sans le document qui dit ce qui n'est pas un défaut. `viewMode` jamais
persisté alors que thème, langue, configuration, ignorés et profil le sont tous.
`ecrire-resultat.ps1` sans `Set-StrictMode` ni `$ErrorActionPreference`. L'empreinte du
cache du service worker qui ne couvre qu'`index.html`. Et `manifest.json` avec son
`"lang": "fr"`, qu'un manifeste statique ne peut guère éviter — écrit pour que la question
ne se repose pas.

*Fini quand* : chacun est corrigé, ou écarté avec sa raison nommée dans ce document.

*Ce qu'il faut pour démarrer* : rien.

### Lot A — Le garde-fou d'enregistrement des tests → **absorbé par le lot 4**

**Ce lot n'existe plus à part.** Il demandait un contrôle refusant un fichier de test non
enregistré ; l'audit du 8 octobre a montré que le même trou laisse passer six chiffres faux
dans la documentation. C'est la même mécanique — comparer une liste écrite à la main à la
réalité du dépôt — et l'écrire deux fois serait exactement le travail en double que ce
document cherche à éviter. Sa conception arrêtée reste valable et reste en section 4 ; son
exécution est le lot 4.

### Lot B — Le mobile

**En deuxième parce qu'il commande le reste.** Détail : section 3.

**Et c'est ici que la « copie du plancher dans `test-guide.js` » de la section 5
disparaît.** Ce fichier porte son propre seuil de 12 px et sa propre règle des 44 × 24 px ;
une fois la question mobile tranchée, soit les deux seuils sautent ensemble, soit ils
deviennent une seule règle partagée. Le traiter à part serait le traiter deux fois.

*Proposition, refusable* : **séparer plutôt que jeter.** Garder du test mobile ce qui relève
de la lisibilité — pas de débordement horizontal, contraste — et retirer ce qui relève de
l'usage tactile : les cibles de 44 px et le plancher calibré pour une main. Conséquence
directe, les vingt-quatre exceptions du plancher deviennent largement inutiles et
`test-plancher-texte.js` se recalibre sur l'écran PC. Le README perd sa promesse mobile et
sa capture.

*Fini quand* : la CI est verte, le document explique pourquoi le seuil a changé, et aucune
exception ne subsiste sans raison.

*Ce qu'il faut pour démarrer* : un seul mot — séparer, ou jeter en bloc.

### Lot C — `CONSTRAINTS.md`

**Après le lot B, obligatoirement** : le plancher de texte est l'une des contraintes que ce
document recensera, et l'écrire avant reviendrait à le réécrire. Détail et point d'entrée :
section 4.

*Fini quand* : le document existe, chaque seuil porte un chiffre et une raison **venus de
l'auteur du projet**, et un contrôle refuse l'affaiblissement silencieux — assertion
retirée, test sauté, seuil édité à la baisse, exception ajoutée sans justification.

*Ce qu'il faut pour démarrer* : l'entretien. Rien ne s'écrit avant.

### Lot D — Les attentes en dur

**En dernier, et proposé sans être recommandé.** Détail : section 5.

Jusqu'à vingt-trois `waitForTimeout` par fichier sur onze suites. C'est la plus grosse
pièce, la moins urgente, et celle dont le bénéfice est le plus difficile à démontrer : **on
n'a pas observé un seul faux échec dû à ça.** À ne faire qu'après en avoir vu un — autrement
c'est du travail guidé par une inquiétude et non par une preuve, ce que ce projet s'est
justement appris à refuser.

### Hors lots : ce qui n'est pas du code

Les deux réglages de la section 2, et l'essai Windows de la section 1.

**Un seul a un effet sur l'ordre** : l'autorisation réseau. Sans elle, le plancher du lot B
se change et se vérifie **par déclaration**, mais on ne peut pas confirmer que la mise en
page rendue se comporte pareil en local et en intégration. L'autoriser avant le lot B est
préférable ; sinon, la limite doit être écrite dans la pull request au lieu d'être passée
sous silence.

---

## 1. La réserve qui domine tout le reste

**Rien de ce projet n'a jamais tourné sur une machine Windows réelle.**

Sept pull requests, vingt-six suites de tests, un job d'intégration Windows — et la seule
chose qui validera vraiment ce programme, c'est une clé USB branchée sur une vraie
machine. Le classement, la fusion entre sources, le parsing de la sortie winget et la
réconciliation source/cible sont couverts par des tests sur données écrites à la main.
La lecture du registre, des paquets du Store et des bibliothèques de jeux demande
Windows : ce code est relu, pas éprouvé.

[VERIFIER-SUR-WINDOWS.md](VERIFIER-SUR-WINDOWS.md) est la marche à suivre pour ce
jour-là, et `scripts\diagnostic.ps1` ramasse ce qu'il faut pour que l'aller-retour serve.
Commencer par le diagnostic, avant même d'essayer le programme.

**Cette session a montré pourquoi ça compte.** Deux défauts n'ont été trouvés que parce
que le job Windows existe, et aucun des deux n'était visible sous Linux :

- La fonction de traduction s'appelait `Tr`, et `tr` est un binaire d'Unix que Git for
  Windows installe. Sur Windows les noms de fichiers ignorent la casse, donc
  `Get-Command Tr` trouvait `tr.exe`, le garde qui chargeait la table en concluait
  qu'elle était déjà là, et chaque appel partait vers le binaire.
- Un test lançait le menu sans préciser de langue et cherchait du français. Le jour où
  les scripts ont su parler anglais, le menu a suivi l'interface du runner — anglaise —
  et le test est tombé. Le menu avait raison, le test avait tort.

---

## 2. Deux réglages, qui ne sont pas du code

### La source de GitHub Pages

**À mettre sur « GitHub Actions »**, dans les réglages Pages du dépôt.

Aujourd'hui deux chemins publient le même site : celui que GitHub déclenche à chaque
push, et le job `publier` de `ci.yml` qui attend les tests. Ils courent en parallèle vers
la même cible. Le 30 septembre le chemin automatique a échoué sur un délai d'attente en
récupérant son jeton OIDC, pendant que le nôtre publiait correctement trois minutes plus
tard.

Le vrai problème n'est pas cet échec, qui était passager : c'est que **le chemin
automatique peut gagner la course et publier une version dont les tests n'ont pas fini de
tourner.** C'est précisément ce que le job `publier` cherche à empêcher en dépendant
d'eux.

### Deux hôtes à autoriser, si on veut mesurer comme la CI

`cdn.playwright.dev` et `playwright.azureedge.net`, dans les réglages réseau de
l'environnement de développement. Les deux : le téléchargement part en redirection du
premier vers le second.

Sans eux, le conteneur de développement ne peut pas installer le Chromium que la version
épinglée de Playwright attend. Le 30 septembre la CI mesurait avec Chromium **153** et le
conteneur avec **141** — douze versions d'écart, qui expliquent rétrospectivement
plusieurs semaines pendant lesquelles `test-mobile.js` était vert en intégration et rouge
en local, sur un défaut bien réel.

Ce n'est plus urgent : les quatre suites qui mesurent des pixels **annoncent désormais
leur navigateur** à chaque passage, avec un avertissement quand `CHROME` est forcé. Un
désaccord se lit au lieu de se deviner. Mais tant que les deux machines ne mesurent pas
avec le même navigateur, aucune correction de mise en page n'est vérifiable ailleurs que
là où elle a été écrite.

---

## 3. Décidé, pas encore appliqué : le mobile n'est pas un usage de ce projet

**La décision est prise.** Le projet vit sur une clé USB, et tout se passe entre la clé,
le PC source et le PC cible. Un téléphone ne lit pas la clé, ne lance pas PowerShell, ne
scanne rien.

Et l'argument est plus fort que ça : **le stockage local est lié au navigateur ET au
chemin du fichier.** Un téléphone qui ouvrirait la page publiée aurait donc une
progression entièrement séparée de celle de la page sur la clé. Cocher sur le mobile ne se
refléterait nulle part. L'usage mobile n'était pas seulement improbable, il était
**incohérent avec le fonctionnement même du projet** — la promesse du README, « cocher
d'une main pendant que l'autre branche un câble », décrivait quelque chose qui n'aurait
pas marché.

### Ce que ça entraîne

| Où | Quoi |
|---|---|
| `tests/test-mobile.js` | Mesure à 360 et 414 px de large et fait échouer la CI sur ces largeurs. Ce sont deux tailles de téléphone qui ne servent à rien ici. |
| `tests/test-plancher-texte.js` | Son plancher de 12 px vient de ce test-là. Vingt-quatre règles CSS passent en dessous et sont déclarées comme exceptions ; sur un écran PC, la plupart n'en sont pas. |
| `README.md` | Promet l'usage au téléphone, et une capture `captures/mobile-*.png` l'illustre. |
| `tests/test-guide.js` | Porte sa propre copie du plancher de 12 px et de la règle des 44 × 24 px. |

### La nuance à garder

**Lire n'est pas utiliser.** La page publiée doit rester lisible sur un téléphone, parce
que c'est ainsi qu'on découvre le projet et qu'on regarde à quoi il ressemble. Ce n'est
pas la même exigence que des cibles tactiles de 44 px et un plancher de texte calibré pour
une main. Supprimer le test mobile en entier retirerait aussi la garantie qu'il n'y a pas
de débordement horizontal, ce qui reste utile.

Le choix à faire n'est donc pas binaire : il s'agit de séparer ce qui relève de la
lisibilité de ce qui relève de l'usage tactile.

---

## 4. Deux chantiers proposés, décidés d'avance, pas encore faits

Issus d'une analyse du 6 octobre 2026. Ni l'un ni l'autre n'est commencé : la décision a
été de les remettre à plus tard. Les choix de conception, en revanche, sont tranchés — ils
sont écrits ici pour qu'on n'ait pas à les reprendre.

### Rien ne vérifie qu'un fichier de test est lancé

**Et ce projet s'est déjà fait prendre.** `tests/test-outils.js` a pourri **non enregistré
pendant des semaines**, cherchant une entrée de menu et un onglet supprimés depuis
longtemps. Il n'a été retrouvé que par hasard, le 30 septembre, et réparé à la main. Rien
n'empêche le suivant.

Les trois listes — `package.json`, `.github/workflows/ci.yml`, `verifier-comme-ci.sh` —
concordent aujourd'hui, mais par vérification manuelle.

**Ce que le contrôle doit refuser, décidé :** un fichier `tests/test-*.{js,ps1}` doit
figurer dans les **trois** listes, sauf s'il est déclaré avec sa raison — comme
`test-windows-reel.ps1`, qui ne tourne légitimement que dans le job Windows. Et **l'inverse
aussi** : une liste qui nomme un fichier disparu échoue. C'est le motif déjà employé deux
fois dans ce projet (`NOMS_PROPRES` dans `test-anglais.js`, `TOLEREES` dans
`test-plancher-texte.js`) et la leçon du 30 septembre : refuser dans les deux sens, parce
qu'une liste qui décrit un code disparu est exactement ce qui est arrivé aux captures
d'écran.

Coût estimé : une trentaine de lignes. Risque : nul.

### `CONSTRAINTS.md` : la barre de qualité n'est écrite nulle part

Elle existe — plancher de texte, cibles tactiles, contraste, encodage, zéro français sur la
page anglaise, aucune injection depuis un profil reçu — mais elle est éparpillée dans
vingt-six fichiers de test, et le 30 septembre a prouvé qu'elle est **partiellement
fictive** : vingt-quatre règles CSS passaient sous un plancher que personne n'avait vu.

**Ce qui rend le sujet sérieux, c'est que le travail de cette journée-là l'aurait
déclenché.** Cinq assertions en pixels exacts ont été remplacées par des relations plus
souples, et vingt-quatre exceptions ont été ajoutées à un seuil. Chaque décision est
défendable et reste défendue. Mais c'est précisément la situation où un contrat écrit sert :
non pas empêcher de desserrer, mais obliger à le dire, au lieu de le décider seul dans un
message de commit que personne ne relira.

**Le point d'entrée, décidé : un entretien, pas un brouillon.** Les dimensions qui comptent
— accessibilité, lisibilité, encodage, vie privée, et lesquelles ont un seuil chiffré —
doivent venir de l'auteur du projet, dimension par dimension, avant que la moindre ligne
du contrat soit écrite. Un document rédigé d'après ce que les tests existants laissent
croire porterait des suppositions, pas des priorités.

### La méthode, pour les deux

Une spec courte — ce qu'on construit, pourquoi, comment on saura que c'est fini — validée,
puis l'implémentation. Pas le cycle complet en quatre phases barrées : pour trente lignes
de test, la cérémonie coûterait plus que le travail, et la compétence qui décrit ce cycle
exclut elle-même les petits changements.

---

## 5. Écartés, et pourquoi c'est écrit quand même

Deux constats réels, laissés de côté volontairement le 30 septembre. Ils ne sont pas
urgents ; ils sont notés pour ne pas être redécouverts.

**La copie du plancher dans `tests/test-guide.js`.** Il porte son propre seuil de 12 px et
sa propre règle des 44 × 24 px, sans la liste d'exceptions de `test-mobile.js`. Deux
seuils qui disent la même chose finiront par ne plus la dire pareil. À traiter avec le
point 3, puisque c'est la même question.

**Les attentes en dur dans les suites.** Jusqu'à vingt-trois `waitForTimeout` par fichier,
sur onze suites navigateur. C'est une source d'échecs intermittents : un test qui attend
250 ms passe ou casse selon la charge de la machine. Les remplacer par des attentes sur
condition (`waitForFunction`, `waitForSelector`) est un chantier à part, et qui mérite un
plan avant d'être commencé.

## 6. L'audit du 8 octobre 2026 : les onze défauts, et la preuve de chacun

Audit complet du dépôt à `34cb604`, les vingt-cinq étapes de la CI rejouées vertes avant de
commencer. Les lots 1 à 7 corrigent ce qui suit. Chaque constat porte **comment il a été
établi**, pour qu'on puisse le contredire sans refaire le travail.

### Les cinq défauts sérieux

**1. `Migration PC.bat` porte un BOM UTF-8.** Ses trois premiers octets sont `EF BB BF`,
lus à l'octet. cmd.exe ne les comprend pas : il lit `<BOM>@echo off` comme un nom de
commande, s'en plaint, et comme `@echo off` n'a jamais pris effet, le reste du script
défile. C'est le seul fichier qu'on double-clique. **Réserve honnête** : le mécanisme est
certain, la formulation exacte de l'erreur non — il n'y a pas de cmd.exe ici pour le
constater, et le job Windows de la CI n'exécute jamais ce fichier. Les douze `.ps1`, eux,
ont tous leur BOM à juste titre : c'est là que PowerShell 5.1 en a besoin.

**2. Le canal de notification n'a jamais été traduit.** `informer()` écrit son argument tel
quel (`afficherBandeau` fait `textContent=libelle`). Sur 23 appels, **2** passent par
`tr()`. Les 17 autres ne sont pas seulement non traduits : **aucune des 17 chaînes n'existe
dans la table**, vérifié en extrayant les 184 clés de `TRADUCTIONS` et en les croisant avec
les littéraux des appels. Ce n'est donc pas une traduction presque finie avec quelques
trous, c'est la voie par laquelle la page rapporte chaque erreur et chaque confirmation qui
est restée en français. `test-anglais.js` passe parce qu'il n'inspecte que le DOM statique
et ne déclenche jamais de notification. Les 2 appels corrects prouvent que la règle était
connue.

**3. Deux libellés de bascule mentent sur l'état.** `#theme-lbl` et `#mode-lbl` portent
`data-t`, et leur bascule les réécrit en français brut (`'Clair'`/`'Sombre'`,
`'Affichage normal'`/`'Affichage compact'`). `setLangue` ne rappelle pas `applyTheme`. Deux
conséquences : le libellé repasse en français dès qu'on bascule le thème sur la page
anglaise, et le `data-t` mémorisé devient faux — après un changement de langue, le bouton
affiche « Dark » alors que le thème est clair. Il ne se contente pas d'être dans la mauvaise
langue, il dit le contraire de l'état.

**4. `importerScanCible()` est morte, et c'est le seul endroit qui met `attendCible` à
vrai.** `roleDe()` retombe sur `attendCible?'cible':'source'` : la branche « cible » est
donc inatteignable, et un inventaire dont le champ `role` manque ou n'est pas reconnu ne
peut être classé que « source ». **Latent pour les fichiers du projet** — `scan-pc.ps1`
écrit toujours `role` (ligne 167) — **réel pour tout le reste** : un export winget, un
fichier retouché à la main, un fichier dont le rôle s'est perdu. Le bouton qui aurait permis
de dire « celui-là, c'est la cible » n'est branché sur rien.

**5. Le service worker met en cache l'inventaire du PC.** Le commentaire en tête de `sw.js`
promet « Jamais de données : la progression et le profil vivent dans localStorage ». Son
gestionnaire `fetch` fait `c.put` sur **tout** GET de même origine qui répond `ok`, et
`index.html` charge l'inventaire par `document.write('<script src="resultat-scan.js">')`
(ligne 861), qui en est un. Il n'y a aucun `fetch()` dans la page, donc c'est bien ce
chemin-là. Servie en HTTPS ou sur localhost, la page recopie l'inventaire dans le cache.
`file://` n'enregistre aucun service worker, donc l'usage prévu — la clé USB — est épargné ;
`python -m http.server` ne l'est pas. Le commentaire et le comportement se contredisent.

### La dérive documentation/code : la maladie nommée du projet, et elle court toujours

**6. Six chiffres annoncés ne décrivent plus le dépôt.** `CONTRIBUER.md` annonce « les 18
étapes du job Linux » deux fois (lignes 13 et 286) : il y en a 25. « les sept suites » de
`npm test` : 10. « les quatre suites PowerShell » de `test:scan` : 5. « dont dix dans un
vrai navigateur », repris dans ce fichier et dans `VERIFIER-SUR-WINDOWS.md` : 11. Et
`test-plancher-texte.js` se trompe sur lui-même ligne 129 — « vingt-cinq veut dire que le
plancher décrit une intention » — alors que sa liste en compte 24. Les comptes justes
(« vingt-six suites », « vingt-cinq dans le job Linux ») le sont par chance : rien ne les
garde.

**7. Deux commandes documentées ne valent pas ce qu'elles promettent.** `npm test` ne lance
que 10 des 26 suites : qui tape la commande universelle obtient un vert sur 38 % de la
couverture. Et `npm run test:mobile` **ne peut pas échouer** — `test-mobile.js` sort 0 sans
`STRICT=1`, que `package.json` n'y met pas, et son écran le dit (« Rapport seulement ») mais
son code de sortie non. La CI a raison, la commande locale non. C'est le défaut même qui a
fait écrire `verifier-comme-ci.sh`, survivant dans `npm`. Accessoirement ce script affirme
rejouer la CI « dans le même ordre » : l'ensemble est exact, l'ordre non — `langue-ps` y
passe en 13e position au lieu de la 25e.

**8. Le test qui existe contre les exceptions périmées en porte quatre.**
`test-plancher-texte.js` refuse « une exception devenue inutile » en vérifiant que sa règle
CSS existe encore. Il ne vérifie pas que la classe serve encore. `gp-label`,
`sec-prog-txt`, `save-path` et `save-note` ont leur règle et leur justification nommée,
mais leur classe n'apparaît nulle part dans le balisage. Son propre commentaire décrit le
piège : « sinon la liste finit par décrire un CSS qui n'existe plus — c'est exactement ce
qui est arrivé aux captures d'écran de ce projet ». Il surveille la mauvaise moitié de la
paire.

**9. Vingt-huit classes CSS mortes sur 227**, et deux fonctions définies sans aucun appel
(`fmtMo`, `setCat`). Mesuré en retirant le bloc `<style>` et en cherchant chaque nom dans
tout le reste du fichier ; les concaténations de classes ont été relues une par une pour
écarter les faux positifs — elles ajoutent toutes un suffixe à une base présente.

**10. `VERIFIER-SUR-WINDOWS.md` n'est pas dans le zip.** `diagnostic.ps1` y est, attrapé
par le glob `scripts/*.ps1`. Le document qui dit « voilà ce qui n'est PAS un défaut » ne
voyage pas avec lui : celui qui fera le premier essai réel aura l'outil sans le mode
d'emploi, alors que ce tableau a été écrit exactement pour ce moment-là.

### Les points mineurs

**11.** `viewMode` n'est jamais persisté alors que thème, langue, configuration, ignorés et
profil le sont tous, et rien ne documente ce choix. `copyCatWinget` avale son échec
(`.catch(function(){})`) là où ses deux jumelles informent l'utilisateur.
`ecrire-resultat.ps1` tourne sans `Set-StrictMode` ni `$ErrorActionPreference` alors que les
autres scripts autonomes les posent — les deux bibliothèques héritent de leur appelant, ce
qui est normal. L'empreinte du cache du service worker ne couvre qu'`index.html` : changer
`manifest.json` ou une icône ne renouvelle pas le cache. `manifest.json` fixe
`"lang": "fr"` en dur.

### Ce que l'audit a vérifié et trouvé sain

À écrire aussi, sinon la liste ci-dessus donne du projet une image qu'il ne mérite pas.
**Aucun des pièges PowerShell que ce projet s'est documentés n'est présent** : pas un `if`
nu dans une parenthèse, pas de `-Include`, pas de test de collection falsy sur un compte,
le BOM correct sur les douze `.ps1`. **La politique des secrets est honnête** :
`COUVERTURE.md` dit explicitement que le code est parti dans l'historique et que les trois
arrêts volontaires — clé BitLocker, clés Wi-Fi, mots de passe Windows — restent écrits faute
de code à montrer. C'est la bonne façon de documenter une absence, et c'est le seul endroit
du projet où doc et code divergent **exprès**. **Aucune assertion creuse trouvée**, et les
21 suites JS peuvent toutes échouer : un premier contrôle disait le contraire, il était
faux, il a été refait. L'échappement est en place et le profil hostile est testé. Les neuf
`+=` en boucle de `lib-detection.ps1` sont du O(n²) théorique sans portée à cette échelle :
**à ne pas toucher**, c'est écrit ici pour que personne n'en fasse un chantier.

### Les deux limites de cet audit

Rien n'a jamais tourné sur un Windows réel, donc tout ce qui précède sur le comportement
des scripts reste de la lecture — le BOM du `.bat` compris. Et sur les 1434 lignes de
`lib-detection.ps1`, les pièges connus ont été cherchés et les structures relues, pas la
logique de détection ligne à ligne. C'est le seul endroit du dépôt où personne ne peut dire
« j'ai tout vu ».

---

## Ce qui n'est PAS dans cette liste, et c'est volontaire

**Les références matérielles du dépôt.** Des modèles précis de carte mère, processeur et
carte graphique traversent dix fichiers comme jeu de test. Un audit de l'historique
complet — 132 commits — a confirmé le 30 septembre qu'aucun instantané, profil ou export
réel n'a jamais été committé, et que la clé OEM complète n'apparaît nulle part. Ces
références sont du matériel inventé : le sujet est clos.

**Le comportement de la page.** Vingt-six suites de tests le couvrent, dont dix dans un
vrai navigateur. [CONTRIBUER.md](CONTRIBUER.md) dit où regarder.

**La performance de la page.** Soupçonnée le 6 octobre, mesurée, écartée. La plus grosse
fixture du projet fait six logiciels et l'exemple dix-huit, alors qu'un vrai registre
Windows en rend deux à quatre cents — le soupçon était légitime. Mesure à six cents
logiciels : 54 ms de rendu, 41 ms par clic, 620 Ko de HTML, aucune erreur. Même sur une
machine cinq fois plus lente, c'est confortable. Inutile de rouvrir sans un chiffre qui
contredise celui-là.

**La perte silencieuse en cas de quota localStorage dépassé.** Soupçonnée le 6 octobre,
vérifiée, écartée. Les huit écritures sont non seulement protégées par un `try` mais
**signalées à l'utilisateur**, avec un drapeau `stockageEnPanne` et un message quand la
sauvegarde se rétablit.
