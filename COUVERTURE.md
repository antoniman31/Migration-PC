# Ce que le scan sait détecter, et ce qu'il ne sait pas

Ce fichier existe parce que l'écart entre ce que la checklist propose et ce que
les scripts savent réellement aller chercher sur l'ancien PC s'était creusé sans
que personne ne le suive. Il est la référence : si une ligne de la checklist
prétend être remplie par un scan, elle doit apparaître ici comme couverte.

Le champ `scan` de chaque entrée `data` dans `presets/exemple.json` renvoie à ce
tableau, et `tests/test-profil-sync.js` refuse toute ligne qui déclare une
couverture inconnue. Les noms de famille utilisés ici sont ceux de
`$CouverturesScan`, dans `lib-detection.ps1`.

## Couvert

| Famille | Détecteur | Réserve |
|---|---|---|
| `apps` | `Read-Registre`, `Read-Winget`, `Read-Store` | — |
| `jeux` | `Read-Steam`, `Read-Epic`, `Read-GOG`, `Read-Xbox`, `Read-Ubisoft`, `Read-Ea` | — |
| `configs` | `Read-Configs` | registre inclus depuis peu ; reste la question des fichiers verrouillés, voir plus bas |
| `variables` | `Read-Variables` | — |
| `materiel` | `Read-Materiel` | — |
| `outils` | `Read-SdkAndroid`, `Read-Wsl`, `Read-GestionnairesPaquets`, `Read-OutilsLangages` | scoop, Chocolatey, npm, pip seulement |
| `extensions` | `Read-Extensions` | VS Code, Chromium, Firefox |
| `dossiers` | `Read-GrosDossiers` | — |
| `precieux` | `Read-FichiersPrecieux` | — |
| `portables` | `Read-Portables` | — |
| `web` | `Read-Registre` (applications web du navigateur) | — |
| `licences` | `Read-Licences` | Windows et Office seulement, via `SoftwareLicensingProduct` |
| `payants` | `Get-LicenceAPrevoir`, `Read-FichiersLicence` | Liste tenue à la main : une ligne absente veut dire « je ne sais pas », pas « gratuit » |
| `vpn` | `Read-Vpn` | Connexions Windows par `Get-VpnConnection` ; les clients tiers sont constatés, jamais lus |
| `favoris` | `Read-Favoris` | Comptés chez Chrome, Edge, Brave, Vivaldi, Opera ; constatés seulement chez Firefox |
| `vm` | `Read-MachinesVirtuelles` | VirtualBox, VMware, Hyper-V si la fonctionnalité est là |
| `mail` | `Read-ArchivesMail` | `.pst` et `.ost`, avec la distinction qui décide de tout |
| `bitlocker` | `Read-Bitlocker` | État et types de protecteurs. **Jamais** la clé de récupération. Demande les droits administrateur |
| `machine` | `Read-Machine` | Fabricant, modèle, n° de série, portable ou fixe, écrans branchés |
| `antivirus` | `Read-Antivirus` | Defender écarté : il revient seul |
| `pilotesTiers` | `Read-PilotesTiers` | Les fournisseurs qui ne sont pas Microsoft, groupés par classe |
| `compte` | `Read-CompteMicrosoft` | L'adresse, rien d'autre |
| `imprimantes` | `Read-Imprimantes` | Les virtuelles (PDF, XPS, fax) écartées |
| `wifi` | `Read-Wifi` | Les **noms** des réseaux. **Jamais** les clés |
| `identifiants` | `Read-Identifiants` | Les **cibles** de `cmdkey`. **Jamais** les mots de passe |
| `polices` | `Read-Polices` | Seulement les ajouts, pas celles livrées avec Windows |
| `lecteurs` | `Read-LecteursReseau` | `Get-SmbMapping`, plus `HKCU\Network` pour les non montés |
| `demarrage` | `Read-Demarrage` | `Win32_StartupCommand` |
| `taches` | `Read-TachesPlanifiees` | Seulement celles à la racine, auteur non Microsoft |
| `pareFeu` | `Read-PareFeu` | Seulement les entrantes autorisées sans groupe, c'est-à-dire ajoutées à la main |
| `associations` | `Read-Associations` | Liste pour re-décider : Windows signe ce choix, il ne se restaure pas |
| `controles` | `Read-Controles` | Machine **neuve** uniquement (`verifier-pc.ps1`) : XMP, TRIM, Secure Boot/TPM, heures du SSD |

### Les deux trous de `configs`, et où ils en sont

1. **Le registre — comblé.** `$ConfigsConnues` porte maintenant un champ
   `registre` à côté de `chemins`. PuTTY range ses sessions SSH entièrement
   dans `HKCU\Software\SimonTatham`, sans le moindre fichier ; 7-Zip, WinRAR,
   WinZip et TeamViewer font pareil. La sauvegarde les exporte en `.reg`, la
   restauration les réimporte. Une réimportation **fusionne** dans le registre
   au lieu de remplacer : c'est la seule chose du projet qui écrit sans filet,
   et le script le dit au moment de le faire.
2. **Les fichiers verrouillés — atténué, pas résolu.**
   `sauvegarder-configs.ps1` copie avec `Copy-Item`, qui échoue sur un fichier
   ouvert. Firefox ou Thunderbird en marche gardent la main sur
   `places.sqlite`, `cookies.sqlite` et `key4.db` — les marque-pages et les
   mots de passe, exactement ce qu'on vient chercher. Le script prévient
   maintenant **avant** de copier et demande confirmation, au lieu de signaler
   des échecs fichier par fichier une fois la copie finie. Il ne ferme rien à
   la place de l'utilisateur. La vraie solution serait un instantané VSS, qui
   demande les droits administrateur.

## Détectable, pas encore fait

Plus rien. Les quatorze lignes qui figuraient ici — imprimantes, Wi-Fi,
identifiants, polices, VPN, machines virtuelles, archives mail, favoris,
BitLocker, lecteurs réseau, pare-feu, démarrage, tâches planifiées,
associations de fichiers — ont toutes leur détecteur.

Trois d'entre elles s'arrêtent **volontairement** avant la fin, et c'est le
point important : la clé de récupération BitLocker, les clés Wi-Fi et les mots
de passe enregistrés dans Windows ne sont pas relevés. Ils sont lisibles, la
commande existe, et c'est précisément pour ça qu'il faut écrire qu'on ne le
fait pas : cet inventaire voyage sur une clé USB. On relève les noms, on dit
où l'utilisateur va chercher le secret lui-même.

## Repéré en relisant d'autres inventaires

Rien de tout cela n'était sur une liste avant de comparer notre scan à GLPI
Agent, OCS Inventory, UniGetUI, hellzerg/cloning et
Kozphy/installed-software-inventory. Les neuf ont été faits depuis, et sont
décrits dans la section suivante.

## Fait depuis la relecture

| Famille | Ce qui a changé |
|---|---|
| `licences` | `SoftwareLicensingProduct` dit si la licence Windows ou Office est OEM — attachée à la carte mère, elle **ne suit pas** — ou Retail. Les licences qui ne suivent pas passent en tête de l'onglet Données. |
| liens officiels | `URLInfoAbout` et `HelpLink` étaient déjà dans le registre et personne ne les lisait. La checklist ouvre le vrai site de l'éditeur au lieu de lancer une recherche. Ça ne demande aucun accès à Internet pendant le scan. |
| `apps` | `winget export` remplace `winget list` comme source d'identifiants. Voir le commentaire de `Read-Winget` : un relevé à zéro identifiant n'est pas forcément un bug. |
| `payants` | Deux choses qui n'ont rien à voir et se complètent. Une liste tenue à la main marque les logiciels connus pour réclamer une clé (Office, Adobe, WinRAR, antivirus payants, JetBrains…) : la ligne porte un badge « licence » et le champ où noter la clé. Et `Read-FichiersLicence` relève les fichiers qui **sont** la licence — `rarreg.key`, `wincmd.key`, `BCLicense` — dont on remonte le **chemin** et jamais le contenu : l'inventaire voyage sur une clé USB. La limite est assumée et écrite dans la page : rien ne distingue un logiciel payant d'un gratuit dans le registre, donc l'absence de badge ne prouve rien. |
| `vpn` | `Get-VpnConnection` rend le nom, le serveur et le type de tunnel des connexions Windows, sans droits particuliers et sans secret. Les clients tiers ne se lisent pas — chacun son format — mais leurs fichiers de configuration se constatent, en disant lesquels contiennent une clé en clair : un `.ovpn` en porte une. Et les VPN par abonnement (Nord, Proton, Mullvad, Tailscale) n'ont rien à copier, c'est un compte, la ligne le dit plutôt que d'envoyer chercher un fichier qui n'existe pas. |
| `favoris` | Les navigateurs Chromium rangent leurs marque-pages dans un `Bookmarks` qui est du JSON en clair : on en donne le **nombre**, ce qui rend la ligne vérifiable après la migration. Firefox les met dans `places.sqlite`, verrouillé quand le navigateur tourne et illisible sans SQLite : là on constate le fichier sans le compter, et on le dit, plutôt que d'embarquer une dépendance. |
| `vm` | Une machine virtuelle ne se réinstalle pas, elle se copie ou se refait — et elle pèse des dizaines de gigaoctets, ce qui décide de la taille du disque à commander. `VirtualBox.xml`, `inventory.vmls` et `Get-VM` donnent le nom et le chemin ; la taille est mesurée après coup. Elle n'entre **pas** dans le total « à prévoir sur la clé » : emporter 96 Go de VM est une décision, pas un choix par défaut. |
| `mail` | Toute la valeur de cette famille tient dans une distinction que personne ne fait spontanément : un `.pst` est une archive qui n'existe nulle part ailleurs, un `.ost` est le cache d'un compte en ligne qui se reconstruit tout seul. Ils se ressemblent, vivent côte à côte, et ne valent pas la même chose. Le `.pst` passe en priorité haute avec son avertissement, le `.ost` en priorité basse. |
| `bitlocker` | La seule famille où le scan s'arrête **volontairement** avant la fin. `Get-BitLockerVolume` rend aussi le mot de passe de récupération à 48 chiffres, et ce mot de passe *est* la sécurité du disque : l'écrire dans un inventaire qui voyage sur une clé USB annulerait le chiffrement qu'on vient de constater. On relève donc l'état et les types de protecteurs, jamais leur contenu, et un test vérifie qu'aucune clé ne ressort. Demande les droits administrateur ; sans eux, le script le dit au lieu de se taire. |
| `machine` | `Win32_ComputerSystem`, `Win32_BIOS`, `Win32_SystemEnclosure` et `WmiMonitorID` : fabricant, modèle, numéro de série, portable ou fixe, combien d'écrans. Les valeurs bidon du SMBIOS (« System Product Name », « To Be Filled By O.E.M. ») sont écartées, sinon on afficherait un modèle qui n'existe pas. Le numéro de série va dans une ligne de Données — il n'est pas secret, il est imprimé sous la machine, mais il disparaît avec le disque. |
| `antivirus` | `AntiVirusProduct` dans `root\SecurityCenter2`. Defender y figure aussi : c'est celui qu'on ne compte pas, il revient seul. Un antivirus tiers est presque toujours un abonnement, donc une licence à retrouver — la ligne passe en priorité haute. |
| `pilotesTiers` | `Win32_PnPSignedDriver`, filtré sur les fournisseurs qui ne sont pas Microsoft et groupé par classe. Une carte mère déclare vingt périphériques du même fournisseur : une ligne par couple suffit. Ce qu'on **ne** fait **pas** reste le même qu'avant — dire quel pilote installer demanderait une table que personne ne tient à jour. |
| `imprimantes` | `Win32_Printer`, sans les virtuelles. Une imprimante réseau se retrouve par son adresse ; une locale par le nom de son pilote, qu'on garde pour ça. |
| `wifi` | `netsh wlan show profiles` pour les **noms**. Pas `key=clear` : un nom de réseau est diffusé à la ronde par la box, une clé non. Une seule ligne de Données pour tous les réseaux — vingt lignes pour une seule action ne servent personne. |
| `identifiants` | `cmdkey /list` donne les **cibles**, jamais les secrets. Les entrées posées par Windows lui-même (`virtualapp/`, `WindowsLive:`) sont écartées. |
| `polices` | Les clés `Fonts` machine et utilisateur. Une police du système y porte un nom de fichier nu, un ajout porte un chemin complet : c'est ce qui les distingue, sans tenir de liste figée qui vieillirait mal. Une police absente ne provoque aucune erreur — Windows la remplace en silence — d'où l'avertissement. |
| `lecteurs` | `Get-SmbMapping`, et `HKCU\Network` en secours pour les lecteurs mémorisés mais non montés : ce sont justement ceux qu'on oublie. |
| `demarrage` | `Win32_StartupCommand`. La liste sert dans les deux sens : remettre ce qu'on veut retrouver, et ne pas remettre ce qui traînait là depuis trois ans. |
| `taches` | `Get-ScheduledTask`, filtré sur la racine et sur un auteur non Microsoft. Windows en pose plusieurs centaines ; toutes les lister rendrait la liste illisible. |
| `pareFeu` | `Get-NetFirewallRule`, filtré sur les entrantes autorisées **sans groupe** — un groupe veut dire Windows ou un installateur, l'absence de groupe veut dire un humain. Liste pour re-décider, pas pour rejouer, et la ligne le dit. |
| `associations` | `FileExts\<ext>\UserChoice`. Windows signe ce choix avec un condensé lié au compte **et** à la machine : il ne se rejoue pas, même en recopiant le registre. La ligne ne promet donc que de rappeler quoi refaire. |
| `date d'installation` | `InstallDate` au registre, validée avant d'être affichée. Elle ne dit pas depuis quand le logiciel n'a pas servi — Windows ne le sait pas — mais « posé il y a quatre ans » suffit souvent à décider de ne pas le remettre. |
| gestionnaires de paquets | `dotnet tool list -g`, `Get-InstalledModule` et `cargo install --list` rejoignent npm, pip, scoop et Chocolatey. Les modules PowerShell n'apparaissaient nulle part ailleurs : ni au registre, ni dans winget. |
| `controles` | Quatre contrôles de la machine neuve, repris de ce que fait SPECS : la mémoire tourne-t-elle à sa vitesse nominale (XMP/EXPO non activé = 10 à 15 % de performances perdues en silence), TRIM actif, Secure Boot et TPM, et surtout le compteur d'heures du SSD — un disque « neuf » à 400 heures ne l'est pas. |

## Hors de portée

Ces points ne sont pas des oublis : ils ne sont pas récupérables par un script
honnête, ou pas transférables du tout. La checklist doit le dire au lieu de
faire croire qu'un scan les couvrira un jour.

| Point | Pourquoi |
|---|---|
| Mots de passe enregistrés dans les navigateurs | Chiffrés par DPAPI avec une clé liée au compte **et** à la machine. Les déchiffrer demanderait d'imiter un voleur de mots de passe. Passer par l'export du navigateur ou la synchronisation du compte. |
| Sessions ouvertes dans les applications | Les jetons d'authentification sont liés à la machine. Il faudra se reconnecter partout, c'est normal. |
| Activations liées au matériel | Certaines licences comptent les machines activées. Désactiver **avant** de démonter l'ancien PC. |
| Données vivant chez l'éditeur | Ce qui est dans le cloud n'est pas sur le disque : rien à scanner, rien à copier. |
| État interne des applications du Store | Le bac à sable de `WindowsApps` n'est pas lisible depuis l'extérieur. |

## Chiffres

| | Avant la relecture des autres inventaires | Après |
|---|---|---|
| Familles couvertes | 11 | 32 |
| En attente d'un détecteur | 14 | 0 |
| Repérées ailleurs, à faire | — | 0 |
| Hors de portée | 6, jamais écrites | 5, écrites ici |
| Arrêts volontaires | 0 | 3, écrits ici |
| **Total à faire** | **14** | **0** |

Il ne reste rien dans la liste des choses détectables. Ce qui subsiste est
d'une autre nature : cinq points **hors de portée**, parce qu'un script
honnête ne peut pas les récupérer, et trois **arrêts volontaires** — la clé
BitLocker, les clés Wi-Fi, les mots de passe enregistrés dans Windows — où la
commande existe et où on choisit de ne pas s'en servir, parce que cet
inventaire voyage sur une clé USB.

La suite du travail n'est donc plus d'ajouter des familles, mais d'essayer
tout ça sur une vraie machine Windows. Rien de ce qui est décrit ici n'a été
exécuté sur un PC : c'est validé par les tests et par le job Windows de la CI,
qui vérifient que le code fait ce qu'il dit, pas que Windows réponde ce qu'on
croit.
