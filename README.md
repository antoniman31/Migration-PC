# Migration PC — checklist de réinstallation

Checklist HTML pour réinstaller un PC Windows sans rien oublier. Des scripts PowerShell
relèvent les logiciels installés sur l'ancienne machine et les pilotes de la nouvelle ;
la page compare les deux et dit ce qui manque.

**Ce qu'il fait, et rien d'autre** : lister les logiciels du PC source, lister ceux du PC
cible, dire la différence — et signaler les périphériques sans pilote sur la cible, avec
le lien du constructeur. Il ne sauvegarde **rien**. Vos fichiers personnels restent
entièrement à votre charge.

`index.html` se suffit à lui-même : aucune dépendance, aucun serveur, aucune étape de
construction. Il s'ouvre depuis une clé USB sur un PC fraîchement installé, sans réseau.
Les scripts sont facultatifs.

## Aperçu

Ces images se refabriquent par `node refaire-captures.js` : une capture ne casse
aucun test, donc rien ne signale qu'elle a vieilli — celles-ci ont montré une
page à six onglets plusieurs semaines après qu'il n'y en ait plus que trois.

L'onglet **Logiciels** : la liste des logiciels relevés sur l'ancien PC, regroupés par
catégorie, avec leur version, leur poids et la commande qui les réinstalle.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="captures/checklist-sombre.png">
  <img alt="La checklist, onglet Logiciels" src="captures/checklist-clair.png">
</picture>

Le **mode guidé**, pour le jour de l'installation : une tâche à l'écran, « c'est fait »
ou « passer », et rien d'autre.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="captures/mode-guide-sombre.png">
  <img alt="Le mode guidé, une tâche à la fois" src="captures/mode-guide-clair.png">
</picture>

Et sur **téléphone**, parce que la page sert aussi à cocher d'une main pendant que
l'autre branche un câble.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="captures/mobile-sombre.png">
  <img alt="La checklist sur téléphone" src="captures/mobile-clair.png" width="320">
</picture>


## Comment on s'en sert

Posez le dossier entier sur une clé USB. Un seul fichier se lance,
**`Migration PC.bat`** ; tout le reste est rangé dans `scripts/`, qui est là pour être lu.

1. Clé branchée sur le **PC que vous quittez** : double-cliquez `Migration PC.bat`,
   choisissez **SOURCE**. La page s'ouvre déjà remplie de vos logiciels.
2. Débranchez la clé, branchez-la sur le **PC cible** — le neuf, ou le même une fois
   réinstallé.
3. Double-cliquez `Migration PC.bat`, choisissez **CIBLE**. La page s'ouvre sur ce qu'il
   reste à installer : **📦 Logiciels** dit ce qui manque, **🎛️ Pilotes** montre les
   périphériques sans pilote et le lien du constructeur.
4. Relancez `Migration PC.bat` : il propose **Installer ce qui manque**. Il montre la
   liste, attend que vous tapiez `INSTALLER`, puis joue `winget import`. C'est la seule
   action du programme qui change la machine, et rien ne s'enchaîne tout seul après un
   scan.

Rien à importer à la main entre les deux, et rien à retrouver dans un dossier.

Le menu ne vous demande plus de quel côté vous êtes quand il peut le déduire : si la clé
porte déjà l'instantané d'une autre machine — numéro de série du SMBIOS différent — c'est
que vous êtes arrivé sur la cible. Il l'annonce, met cette entrée en tête, et vous laissez
Entrée ou choisissez autre chose. Les deux cas vraiment ambigus restent une question : même
numéro de série (vous réinstallez ce PC-ci) et numéro de série absent des deux côtés.

À part l'installation, le menu n'ajoute aucune capacité : il appelle les mêmes scripts,
qu'on peut toujours lancer à la main. Une action dont il manque un fichier reste affichée, grisée, avec la raison —
plus utile qu'une action absente dont on ignore pourquoi. Après chaque action il dit quoi
faire ensuite, et une entrée **Par où commencer ?** décrit le parcours des trois situations :
changer de PC, réinstaller sur place, garder les deux machines.

```
PC SOURCE                                        PC CIBLE
(celui qu'on quitte)                (le neuf, ou le même réinstallé)
────────────────────                ───────────────────────────────
scan-pc.ps1 -Role source                  scan-pc.ps1 -Role cible
        │                                           │
        └──► instantane-source-AAAA-MM-JJ.json ──┐  └──► instantane-cible-….json
                                                 │              │
                                                 └──► index.html ◄┘
                                                    compare les deux
```

**Le même script des deux côtés.** Sur la source il fige l'état de la machine, sur la
cible il refait le même relevé, et c'est la page qui compare. Conséquence qui simplifie
tout : « PC neuf » et « même PC après réinstallation » deviennent le même cas. Le
vocabulaire compte pour ça — source et cible peuvent être le même ordinateur à deux
moments différents.

Chaque instantané porte sa date et n'écrase jamais le précédent ; un raccourci
`inventaire-pc.json` pointe toujours vers le dernier.

Le scan n'est pas obligatoire : `index.html` s'ouvre seul sur un profil d'exemple, sans
dépendance, sans serveur, sans réseau.

### Ce qui se passe entre les deux machines

Entre le scan de la source et celui de la cible il y a un changement de machine, donc de
navigateur — et la mémoire locale de la page, où vit l'instantané de la source, ne
traverse pas. Sans relais, le PC neuf recevrait un scan de lui-même et rien à quoi le
comparer.

Le relais, c'est la clé. Le scan de la source dépose une copie de son instantané à côté
de `index.html`, sous le nom fixe `instantane-source.json` ; celui de la cible la relit
et la joint au résultat. Si la clé ne porte pas la page, le scan de la source le dit tout
de suite, au lieu de laisser découvrir le problème sur l'autre machine.

Et la page se remplit toute seule parce qu'ouverte depuis une clé, elle n'a pas le droit
d'aller lire un fichier — le navigateur refuse — mais elle peut charger un fichier
JavaScript posé à côté d'elle. Les scripts écrivent donc `resultat-scan.js` en plus du
`.json`, et ouvrir `index.html` suffit. Sans ce fichier, la page s'ouvre normalement.

Ce fichier étant chargé, il est exécuté : sur votre propre clé c'est sans objet, sur une
clé prêtée c'est du code qui tourne. Ce qu'il dépose est traité comme n'importe quel
import — des données, jamais des instructions — et la page annonce d'où ça vient.
`-PasDOuverture` empêche les scripts d'ouvrir le navigateur.

> Windows affiche un avertissement SmartScreen sur un `.bat` téléchargé depuis Internet :
> « Informations complémentaires » puis « Exécuter quand même ». Aucune astuce ne l'évite
> sans certificat de signature payant. Les fichiers sont lisibles dans le Bloc-notes.
> Le `.bat` existe pour une seule raison : Windows refuse d'exécuter un `.ps1` par
> double-clic. Il contourne ce blocage pour ce seul lancement et reste lisible —
> contrairement à un `.exe`, qu'il faudrait croire sur parole pour un outil qui lit tout
> votre PC.

### En ligne de commande

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\scan-pc.ps1 -Role source
```

puis, sur la machine fraîchement installée :

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\scan-pc.ps1 -Role cible
```

| Option | Effet |
|---|---|
| `-Role source\|cible` | De quel côté on est. `source` par défaut |
| `-Sortie <chemin>` | Change le fichier produit (défaut : `instantane-<role>-<date>.json`) |
| `-SansStore` | Ignore les applications du Microsoft Store |
| `-SansJeux` | Ignore les bibliothèques de jeux |
| `-ToutInclure` | Garde aussi les redistribuables et les composants système |
| `-PasDOuverture` | N'ouvre pas le navigateur à la fin |

Le scan de la cible écrit en plus `winget-restant.json` à côté de la page : la liste de ce
qui manque, au format `winget import`. C'est ce fichier que le menu joue. Il est calculé par
PowerShell et non par la page, parce que le fichier que la page produit part dans le dossier
des téléchargements du navigateur, où le menu n'a aucun moyen fiable de le retrouver.

**Entre les deux, sauvegardez vos fichiers personnels.** Le scan liste, il ne copie rien.
Cette étape n'est pas outillée par ce projet : c'est le seul geste irréversible de la
procédure, et il est entièrement à vous.

### Ce que le scan va chercher

| Source | Ce qu'elle apporte |
|---|---|
| `winget list` | Les identifiants d'installation officiels |
| Registre `Uninstall` | Les logiciels installés classiquement (32 et 64 bits, machine et utilisateur) |
| Paquets APPX | Les applications du Microsoft Store |
| Steam, Epic, GOG, Xbox, Ubisoft, EA | Les jeux installés, sur tous les disques |
| WMI et registre | La machine : fabricant, modèle, n° de série, portable ou fixe, écrans branchés |
| `Win32_PnPSignedDriver` | Les pilotes qui ne viennent pas de Microsoft, groupés par classe |

Une entrée vue par plusieurs sources est fusionnée : le nom vient du registre,
l'identifiant winget de winget, la taille de celle qui la connaît, et rien n'apparaît deux
fois. Le rapprochement source/cible se fait sur le nom normalisé avec les mêmes règles des
deux côtés, sinon « Mozilla Firefox (x64 fr) » et « Mozilla Firefox » compteraient pour
deux logiciels. Rien n'est coché sans votre validation : un rapprochement par nom peut
confondre deux logiciels voisins, et une case cochée à tort fait sauter une installation.

Sur la cible, le script relève en plus ce qui n'a de sens que là : les périphériques que
Windows signale comme sans pilote ou en erreur.

Il a relevé jusqu'à trente-deux familles — réglages, favoris, Wi-Fi, polices, tâches
planifiées, VPN, machines virtuelles, gros dossiers. Tout ça marchait, et tout ça a été
retiré : le programme **listait sans jamais copier**, et une liste de ce qu'on va perdre
présentée à côté de logiciels réellement installables laissait croire à une sauvegarde
juste avant un formatage. [COUVERTURE.md](COUVERTURE.md) dit lesquelles et pourquoi.

## La page

Trois onglets. **Logiciels** est la liste relevée sur le PC source, par catégorie, avec la
version, le poids et la commande qui réinstalle. Dès que le scan du PC cible arrive, la
même liste change d'état : un bandeau dit combien de logiciels sont là sur combien, et
chaque ligne porte son verdict — *là*, *manque*, ou *plus ancien* avec les deux versions.
Une ligne que le scan a trouvée est **réglée d'office** : elle s'affiche cochée et ne se
décoche pas, parce qu'un constat n'est pas une décision. La case garde son sens entier
avant tout scan de cible, et devient après une décision — installé, ou je m'en passe. Le
scan n'écrit jamais dans vos cases : rien de ce qui a été coché à la main n'est effacé ni
contredit en silence. Si un verdict « là » est faux, c'est que le rapprochement par nom
s'est trompé : corrigez le nom dans le JSON et relancez le scan.

**Pilotes** montre ceux du PC receveur après son scan : les périphériques en défaut, ceux
déjà en place groupés par fournisseur, et le lien vers la page de support du constructeur,
construit depuis le modèle et le numéro de série relevés dans le SMBIOS. Avant ce scan, il
montre ce que portait l'ancienne machine — une bonne idée de ce qu'il faudra retrouver. Ce
qu'il ne dit **jamais** : qu'une version plus récente existe. Le programme ne fait aucun
appel réseau, il ne peut pas le savoir, et l'affirmer serait mentir.

**PWA** liste les applications web installées depuis le navigateur, à rouvrir depuis leur
site.

**Réinstaller** — le badge winget copie la commande en un clic, un bouton par catégorie
copie le script de toute la section. Deux exports : **⬇️ Script des restants** produit un
`.ps1`, et **⬇️ winget .json** le format officiel de `winget import`, à préférer — il saute
ce qui est déjà installé et reprend proprement après une interruption.

```powershell
winget import -i winget-restant.json --accept-package-agreements --accept-source-agreements
```

Le script des restants change de source selon ce qu'on lui donne. Sans scan du PC cible, il
part des cases non cochées, faute de mieux. Dès que la comparaison existe, c'est elle qui
décide : elle sait ce qui **manque**, et c'est un constat, pas une supposition. Une ligne
cochée à la main reste exclue même quand le scan la dit manquante — quelqu'un qui coche
affirme l'avoir faite.

**Le reste** — recherche sur les trois onglets, filtre par catégorie et sur les apps sans
winget, vue compacte, thème suivant le système, barres de progression. La liste est groupée
par catégorie, sans autre vue : il y a eu quatre tris, dont
deux lisaient les durées et priorités inventées, et un troisième — « ordre conseillé » —
n'était qu'un autre affichage des mêmes lignes. L'ordre d'installation compte là où il change
quelque chose, les scripts winget et le mode guidé, pas comme façon de lire. Tout ce qui sort
en fichier est
ce qui est affiché. La progression est enregistrée au fur et à mesure et la barre « Récent »
en porte l'heure, ou un avertissement quand le navigateur refuse — plutôt que de laisser
croire que le travail est gardé.

**Il n'y a ni durée ni priorité par logiciel, et c'est voulu.** Le scan en a produit
pendant des mois : trente minutes si le nom contenait « Adobe » ou « Unity », quinze pour un
jeu, cinq sinon ; priorité haute parce que la catégorie était « bureautique ». La page les
additionnait pour afficher « ⏱ 2h15 restant » — un chiffre fabriqué présenté comme une
mesure, et le seul de la page que personne ne pouvait vérifier. Une catégorie approximative
reste, elle : une erreur de catégorie se voit d'un coup d'œil, une durée fausse ne se voit
jamais.

**Le menu** contient sept entrées, avec un vrai libellé : importer, exporter le profil,
affichage compact, thème, ma configuration, imprimer, réinitialiser. Une huitième n'apparaît
que lorsqu'un fichier de scan attend à côté de la page. Il en a compté seize : deux entrées
d'import pour un bouton qui reconnaît déjà le format, deux lignes pour un réglage à deux
états, deux impressions, un export texte que l'impression couvre, une réinitialisation par
onglet que le panneau fait déjà en plus large, et deux entrées qui vivent désormais dans le
bandeau de la page vide, là où elles ont un sens. **Exporter le profil** produit un seul
fichier qui porte les listes **et** les cases cochées. **Réinitialiser…** offre
deux portées distinctes : *Tout décocher* remet la progression à zéro et laisse le profil et
votre configuration matérielle en place ; *Tout effacer* vide tout et revient au profil
d'exemple. Les deux passent par un bandeau d'annulation plutôt que par une boîte de
confirmation — une seconde chance après coup vaut mieux qu'un « oui » réflexe avant, et ça
vaut aussi pour un import qui remplace du travail. L'annulation rend les cases, le profil
remplacé **et** la configuration matérielle : ce dernier point manquait, et l'oubli était
silencieux.

**🎯 Mode guidé**, pour le moment où l'on est debout devant la machine : une tâche à la
fois, dans l'ordre des dépendances, avec la commande winget prête à copier et rien d'autre.
« C'est fait » coche et avance, « Passer » remet la tâche en fin de file.

**Clavier et contrastes** — tout se fait au clavier : les lignes sont des cases à cocher
activées par Entrée ou Espace, et le focus reste sur la ligne après la coche. Les contrastes
respectent le seuil WCAG de 4,5:1 dans les deux thèmes,
mesurés sur le fond réellement peint. Le réglage système « réduire les animations » est
respecté.

Depuis la version en ligne, la page **s'installe comme une application** et s'ouvre ensuite
sans réseau ; ouverte en `file://` depuis une clé, elle ignore cette partie, elle est déjà
autonome. Si un onglet échoue au rendu, les autres s'affichent quand même et un bandeau
nomme l'onglet fautif.

### Ma configuration

Neuf champs, tous saisissables à la main, que les scripts remplissent tout seuls — Windows
connaît la machine, il n'y a pas de raison de recopier une étiquette de carton. Cinq
décrivent le PC (carte mère, processeur, carte graphique, mémoire, SSD) et quatre servent à
retrouver un pilote : réseau filaire, Wi-Fi, puce audio, version du BIOS.

Le réseau passe devant parce que c'est le pilote dont dépend la recherche de tous les
autres : sur une machine fraîche sans Ethernet, il n'y a pas d'autre PC sous la main.
Ethernet et Wi-Fi sont deux champs, parce qu'on ne cherche pas le même pilote et qu'un fixe
n'a souvent que le premier. La sortie audio d'une carte graphique est écartée — elle passe
par HDMI et arrive avec le pilote de la carte, c'est la puce de la carte mère qu'on veut.
Les cartes virtuelles aussi — Hyper-V, VMware, VirtualBox, les TAP de VPN, le Bluetooth qui
se déclare en réseau : prendre la première venue enverrait chercher le pilote d'un
adaptateur qui n'existe pas physiquement. La version du BIOS porte sa date, parce que la
question devant la page du constructeur est « est-ce que la mienne est vieille ? ».

Une valeur déjà saisie n'est jamais écrasée : elle est peut-être plus précise que ce que
Windows rapporte. Une exception, et elle a une raison — le scan lancé avec `-Role cible`
tourne sur le PC qu'on équipe, donc lui seul sait de quelle machine il parle et lui seul
corrige une valeur. Sinon, sur le PC neuf, le lien du constructeur viserait le support de la
machine qu'on vient d'abandonner.

Ce que ce bloc ne fait pas, volontairement : deviner quel pilote va avec quel modèle. Il
faudrait une table de correspondances que personne ne tient à jour, et on servirait des
liens faux qui ont l'air vrais. La page amène au bon endroit ; c'est vous qui lisez la page
du constructeur.

La configuration voyage avec le profil exporté, dans un champ `materiel` — sans ça tout le
bénéfice disparaissait au moment du transfert, c'est-à-dire là où il sert.

## Licence

**GNU AGPL v3 ou ultérieure.** En clair, et sans jargon : le code est ouvert, vous
pouvez le lire, l'utiliser, le modifier et le redistribuer. La seule contrainte est
une réciprocité — si vous distribuez une version modifiée, **ou si vous la faites
tourner comme service en ligne**, vous devez publier votre code source sous la même
licence. C'est cette seconde clause qui distingue l'AGPL des autres licences libres,
et c'est exactement pour elle qu'elle a été choisie ici : quelqu'un peut reprendre ce
travail et le faire avancer, personne ne peut le refermer.

Le nom de l'auteur reste attaché au code. L'historique git, horodaté et public, en est
la trace.

Ce projet a d'abord été publié sous licence MIT, du 24 au 26 septembre 2026. Les
versions distribuées pendant cette période restent sous MIT : un changement de licence
ne vaut que pour la suite, jamais pour ce qui est déjà parti.

## Vie privée

Tout reste sur votre machine. La page est un fichier statique sans serveur ni appel
réseau : la progression et le profil importé vivent dans le stockage local du
navigateur, les exports sont des téléchargements ordinaires.

L'inventaire produit par le scan décrit précisément votre machine — son modèle, son numéro
de série, tout ce qui est installé dessus. Ne le publiez pas.

Le scan applique une règle constante : **le nom dans l'inventaire, le secret
ailleurs.** Il relève le chemin d'un fichier de licence mais pas son contenu, et
les cinq derniers caractères d'une clé de produit — ce que Windows affiche
lui-même — mais jamais la clé complète. Quand il relevait encore les réseaux
Wi-Fi, les volumes BitLocker et le gestionnaire d'identification, il en donnait
les noms et jamais les clés, les mots de passe ni la clé de récupération. Dans
chacun de ces cas la commande qui donnerait le secret existe : ne pas s'en servir
est le choix, et il tient à une seule raison — ce fichier voyage sur une clé USB
qui se perd. [COUVERTURE.md](COUVERTURE.md) garde la trace de ces trois arrêts
volontaires même si le code est parti.

Le stockage local est lié au navigateur **et** au chemin du fichier. Si la lettre de
lecteur de la clé USB change d'un PC à l'autre, la progression ne suit pas : l'export
JSON est le seul transfert fiable.

### Un profil reçu est une entrée non fiable

Le projet est fait pour qu'on s'échange des profils, donc un profil vient souvent d'un
fichier qu'on n'a pas écrit. La page le traite comme une saisie quelconque : tout ce
qu'il contient est échappé avant d'atteindre la page, et l'adresse d'un raccourci n'est
ouverte que si c'est du `http`, `https` ou `mailto` — un `javascript:` devient un bouton
visiblement inerte plutôt qu'un lien qui exécute du code. Ce qui est en jeu n'est pas
théorique : le stockage local contient l'inventaire de votre machine.
`tests/test-profil-hostile.js` rejoue un profil piégé à chaque publication.

## Limites connues

**La détection n'a jamais été exécutée sur une machine Windows réelle.** Le classement, la
fusion entre sources, le parsing de la sortie winget et le rapprochement source/cible sont
couverts par des tests sur données écrites à la main. La lecture du registre, des paquets du
Store et des bibliothèques de jeux demande Windows : ce code est relu, pas éprouvé. Si un
résultat vous paraît faux, c'est probablement là.

**Le projet ne sauvegarde rien.** C'est la limite la plus importante, et elle est voulue.
Il a listé un temps les dossiers de réglages, les favoris et les archives mail — sans jamais
les copier.

**Il ne déménagera pas vos applications.** Les outils commerciaux comme PCmover copient les
fichiers *et* les clés de registre *et* les composants partagés, en réécrivant des milliers
de références qui changent d'une machine à l'autre. Windows n'a jamais été conçu pour ça, les
applications du Store ne se copient pas, les licences liées au matériel se désactivent, et on
déménagerait aussi les restes accumulés depuis cinq ans. Une réinstallation propre par winget
couvre l'essentiel sans rien greffer qu'on ne comprenne.

**Il n'y a plus de checklist d'installation.** Les 29 étapes de « Nouveau PC » — BIOS, TPM,
Secure Boot, XMP, installation de Windows — étaient des consignes génériques qu'on trouve
partout, pas quelque chose que ce programme savait vérifier. Une vraie perte au passage : le
seul endroit qui rappelait d'activer le profil XMP, un réglage qu'on ne voit pas et qui coûte
10 à 15 % de performances en silence.

**Tous les logiciels n'ont pas d'identifiant winget.** Ceux détectés par le registre seul
sortent avec un lien de recherche à la place de la commande. Le filtre « Sans winget » les
isole ; ils n'apparaissent pas dans l'export `winget .json`, qui ne peut contenir que des
paquets connus de winget.

**Un export winget importé perd les noms d'origine** : le format ne stocke que les
identifiants, `7zip.7zip` donne « 7zip » et non « 7-Zip ». Passer par `scan-pc.ps1` donne des
noms corrects, puisqu'il lit le registre.

**La déduplication est approximative.** Elle ignore la version, les numéros de mise à jour et
les mentions entre parenthèses, ce qui rapproche correctement `Mozilla Firefox (x64 fr)` de
`Mozilla Firefox` — mais fusionne aussi deux versions majeures d'un même logiciel : Python
3.12 et 3.13 donnent une seule ligne.

**Le classement par catégorie est indicatif**, fondé sur des mots-clés. Un logiciel peu connu
atterrit dans « Utilitaires Système ». Les catégories se corrigent dans le JSON.

**Les tailles sur disque sont partielles.** Steam et Epic les donnent exactement, le registre
les estime — et se trompe parfois largement —, le Store, GOG et Xbox ne les donnent pas du
tout. Le total est un minimum, utile pour dimensionner un disque, pas un inventaire
comptable.

**Windows uniquement**, PowerShell 5.1 ou supérieur, et `lib-detection.ps1` doit être à côté
des scripts : copiez le dossier, pas un fichier isolé. S'ils refusent de démarrer, lancez-les
avec `-ExecutionPolicy Bypass`. L'installation comme application demande HTTPS — depuis une
clé USB la page fonctionne mais ne s'installe pas, et elle n'en a pas besoin.

## Pour aller plus loin

- [COUVERTURE.md](COUVERTURE.md) — ce que le scan détecte, ce qu'il refuse volontairement de
  détecter, et les vingt-sept familles retirées.
- [FORMATS.md](FORMATS.md) — les quatre formats que la page importe, et comment écrire son
  propre profil.
- [CONTRIBUER.md](CONTRIBUER.md) — les dix-huit suites de tests, la CI, la publication.
