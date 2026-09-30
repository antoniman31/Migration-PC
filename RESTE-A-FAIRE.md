# Ce qui reste à faire

Écrit le 30 septembre 2026, à la clôture d'une série de sept pull requests : la
traduction complète du projet, la correction d'un défaut d'affichage, et de quoi rendre
utile le premier essai sur un vrai Windows.

Ce document existe parce qu'une décision prise en conversation ne survit pas à la
conversation. Il ne contient que ce qui est **réellement en attente** — pas une liste de
souhaits.

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

## 4. Écartés, et pourquoi c'est écrit quand même

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

---

## Ce qui n'est PAS dans cette liste, et c'est volontaire

**Les références matérielles du dépôt.** Des modèles précis de carte mère, processeur et
carte graphique traversent dix fichiers comme jeu de test. Un audit de l'historique
complet — 132 commits — a confirmé le 30 septembre qu'aucun instantané, profil ou export
réel n'a jamais été committé, et que la clé OEM complète n'apparaît nulle part. Ces
références sont du matériel inventé : le sujet est clos.

**Le comportement de la page.** Vingt-six suites de tests le couvrent, dont dix dans un
vrai navigateur. [CONTRIBUER.md](CONTRIBUER.md) dit où regarder.
