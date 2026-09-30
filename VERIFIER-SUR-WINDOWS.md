# Vérifier sur une vraie machine Windows

Ce programme **n'a jamais tourné sur un Windows réel.** Le classement, la fusion entre
sources, le parsing de la sortie winget, la réconciliation source/cible et la traduction
sont couverts par des tests sur données écrites à la main, plus un job d'intégration qui
exerce le raisonnement — pas la machine. La lecture du registre, des paquets du Store et
des bibliothèques de jeux demande Windows : ce code est relu, pas éprouvé.

Ce document sert au premier essai. Il dit quoi regarder, dans quel ordre, et surtout
**ce qui n'est pas un défaut** — parce que le scan écrit beaucoup et que la moitié de ce
qu'il annonce est une situation normale.

## Avant de commencer

Posez le dossier entier sur une clé USB. Si un seul fichier manque, les scripts s'arrêtent
au démarrage en le disant — c'est voulu, et c'est la première chose que le diagnostic
vérifie.

```
scripts\diagnostic.ps1
```

Lancez-le **d'abord**, avant même d'essayer le programme. Il écrit
`diagnostic-migration-pc.txt` à côté de lui, et ce fichier suffit à répondre aux trois
questions qui expliquent la plupart des ennuis : quelle version de PowerShell, quelle
langue d'interface, et quel encodage de console.

Il ne porte **aucun nom de logiciel, de machine ou d'utilisateur** — seulement des
comptes, des versions et des messages d'erreur. Un message d'erreur peut contenir un
chemin de fichier : parcourez-le avant de le coller quelque part.

## Ce qui n'est PAS un défaut

À lire avant de signaler quoi que ce soit. Chacune de ces lignes est une situation prévue,
et le scan continue :

| Ce que vous lisez | Ce que ça veut dire |
|---|---|
| `winget... absent, ignore` | winget n'est pas installé. Le scan se rabat sur le registre. |
| `Microsoft Store... indisponible, ignore` | `Get-AppxPackage` a refusé. Fréquent hors session interactive. |
| `Steam... non installe, ignore` | Steam n'est pas sur la machine. Idem pour GOG, Epic, EA, Ubisoft. |
| `Xbox / Game Pass... aucun jeu, ignore` | Le launcher est là, sans jeu installé. |
| `pilotes tiers... aucun` | Tous les pilotes viennent de Microsoft. C'est un bon signe. |
| `0 entrees` sur une source | Cette source-là n'a rien donné. Une autre a peut-être tout trouvé. |
| Un périphérique « sans pilote » que vous savez fonctionnel | Windows signale le code d'erreur du gestionnaire de périphériques, qui reste parfois affiché après coup. Le programme rapporte, il ne juge pas. |

**Un vrai défaut ressemble à autre chose** : une exception non rattrapée qui arrête le
scan, un compte manifestement faux (deux logiciels quand vous en avez cent), des accents
en charabia, du français dans une interface anglaise ou l'inverse, ou un fichier JSON que
la page refuse de relire.

## L'ordre à suivre

**1. Le diagnostic.** `scripts\diagnostic.ps1`. Regardez la ligne d'essai d'accents : si
elle est abîmée dans le fichier, l'encodage de console ne suit pas, et c'est à traiter
avant tout le reste — sinon chaque autre constat sera brouillé par ça.

**2. Le menu.** Double-cliquez `Migration PC.bat`. Vérifiez qu'il s'affiche dans la langue
attendue : il suit celle de Windows, et `Migration PC.bat -Langue fr` tranche si les deux
ne concordent pas. Les accents doivent être nets. Le trait sous le titre doit faire la
largeur du titre.

**3. Le scan SOURCE.** Choisissez SOURCE. Comparez le compte annoncé à ce que vous savez
de la machine : c'est la seule vérification que les tests ne peuvent pas faire, puisqu'ils
n'ont jamais vu un registre réel. Un logiciel installé que le scan ne voit pas est le
défaut le plus intéressant à signaler.

**4. La page.** Elle doit s'ouvrir déjà remplie. Si elle s'ouvre sur l'exemple garni,
`ecrire-resultat.ps1` n'a pas pu poser son fichier — le diagnostic le dira.

**5. Le scan CIBLE**, sur l'autre machine ou après réinstallation. Vérifiez que la page
compare les deux sans rien importer à la main, et que ce qu'elle déclare manquant manque
vraiment. Une erreur de réconciliation — un logiciel présent annoncé absent — vient
probablement de la normalisation des noms, et `tests/cles-normalisation.json` est
l'endroit où l'ajouter.

**6. L'installation.** Le menu propose « Installer ce qui manque ». Il montre la liste et
attend que vous tapiez `INSTALLER` ou `INSTALL` — les deux marchent. C'est la **seule
action du programme qui change la machine** ; tout le reste ne fait que lire. Rien ne
s'enchaîne automatiquement après un scan.

## Si quelque chose casse

Relancez `scripts\diagnostic.ps1` **après** l'incident : il exerce le scan lui-même et
attrape l'erreur avec sa position dans le code. Collez le fichier produit. C'est
suffisant dans la plupart des cas, et ça évite un aller-retour à décrire de mémoire ce
que la console a affiché.

Si le scan s'est arrêté net, le diagnostic le dit avec le message et la ligne. Si le scan
est allé au bout mais que le résultat vous paraît faux, c'est la comparaison entre ce que
le programme annonce et ce que vous savez de la machine qui compte — et elle, personne ne
peut la faire à votre place.

## Ce que ce document ne couvre pas

Le comportement de la page elle-même : il est vérifié par vingt-six suites de tests, dont
dix dans un vrai navigateur. Si la page se comporte mal, c'est un défaut d'une autre
nature, et [CONTRIBUER.md](CONTRIBUER.md) dit où regarder.
