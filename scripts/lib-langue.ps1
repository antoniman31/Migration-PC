<#
.SYNOPSIS
    La langue de ce que les scripts ecrivent a l'ecran.

.DESCRIPTION
    Meme mecanique que la page, volontairement : LA CLE EST LA PHRASE
    FRANCAISE. Une cle absente de la table rend donc le francais, jamais un
    identifiant technique — c'est la difference avec une table de cles
    inventees, ou l'oubli d'une traduction affiche « MENU_TITRE_2 » a
    quelqu'un qui reinstalle son PC.

    Les trous se notent {0}, {1} et se remplissent par les arguments qui
    suivent la phrase. Une phrase entiere par cas plutot qu'un morceau
    recolle : « 1 jeu » et « 3 jeux » sont deux entrees, parce que l'accord
    ne se fabrique pas de la meme facon dans toutes les langues.

    CE QUI N'EST PAS ICI, et ne doit pas y venir : tout ce qui part dans le
    fichier JSON. lib-detection.ps1 y ecrit des noms de categories et de
    logiciels que la page relit et normalise ; tests/cles-normalisation.json
    est le contrat partage entre les deux. Traduire ces textes-la casserait
    la reconciliation sans que rien ne le dise a l'ecran. Ici, on ne traduit
    que ce qu'un humain lit dans la console.

.NOTES
    Windows. PowerShell 5.1 ou superieur.
#>

# La langue en cours. 'fr' par defaut : si quelque chose se passe mal dans la
# detection, on retombe sur la langue d'origine des scripts.
$script:LangueActive = 'fr'

$script:LANGUES_DISPO = @('fr', 'en')

<#
.SYNOPSIS
    Quelle langue employer : le parametre s'il est donne, sinon Windows.
.DESCRIPTION
    Get-UICulture donne la langue de l'interface Windows, pas le format des
    nombres et des dates (ca, c'est Get-Culture) : un Windows francais avec
    un clavier americain reste francais ici, ce qui est le bon choix.

    Le repli est l'anglais et non le francais : quelqu'un dont le Windows
    n'est ni francais ni anglais a plus de chances de lire l'anglais. Le
    parametre -Langue reste la pour trancher, notamment pour un francophone
    sur un Windows anglais.
#>
function Resolve-Langue {
    param([string]$Demandee = '')

    if ($Demandee) {
        $d = $Demandee.Trim().ToLower()
        if ($script:LANGUES_DISPO -contains $d) { return $d }
        # Une valeur inconnue ne doit pas arreter un scan : on le dit et on
        # continue dans la langue de la machine.
        Write-Warning "Langue inconnue : $Demandee. Valeurs possibles : $($script:LANGUES_DISPO -join ', ')."
    }

    try {
        $c = (Get-UICulture).TwoLetterISOLanguageName
        if ($c -eq 'fr') { return 'fr' }
        return 'en'
    } catch {
        return 'fr'
    }
}

function Set-Langue {
    param([string]$Langue)
    $script:LangueActive = Resolve-Langue $Langue
    return $script:LangueActive
}

function Get-LangueActive { return $script:LangueActive }

<#
.SYNOPSIS
    La phrase a afficher. Tr comme la fonction tr() de la page.
.EXAMPLE
    Tr 'non installe, ignore'
.EXAMPLE
    Tr '{0} jeux' $n
#>
function Tr {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Fr,
        [Parameter(ValueFromRemainingArguments = $true)][object[]]$Trous
    )

    $s = $Fr
    if ($script:LangueActive -ne 'fr' -and $script:MESSAGES.ContainsKey($Fr)) {
        $s = $script:MESSAGES[$Fr]
    }
    if ($null -ne $Trous -and $Trous.Count -gt 0) {
        for ($i = 0; $i -lt $Trous.Count; $i++) {
            $s = $s.Replace('{' + $i + '}', [string]$Trous[$i])
        }
    }
    return $s
}

# La console de Windows n'ecrit pas en UTF-8 par defaut. Les .bat font un
# « chcp 65001 », mais un .ps1 peut aussi etre lance directement, et sous
# Windows PowerShell 5.1 chcp ne suffit pas toujours. On le fixe ici pour que
# chaque script qui charge ce fichier en herite, sans rien casser si l'hote
# refuse (sortie redirigee, console absente).
function Set-SortieUTF8 {
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
}

# Couper un paragraphe a la largeur d'une console, avec une marge a gauche et
# une marge supplementaire pour les lignes suivantes — de quoi aligner le texte
# d'une puce sous son numero au lieu de le ramener sous le chiffre.
#
# 76 colonnes : une console Windows en fait 80 par defaut, et les deux qui
# restent evitent un retour a la ligne involontaire quand la fenetre est pile a
# la bonne taille.
function Format-Paragraphe {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Texte,
        [Parameter(Position = 1)][int]$Marge = 0,
        [Parameter(Position = 2)][int]$MargeSuite = -1,
        [Parameter(Position = 3)][int]$Largeur = 76
    )
    if ($MargeSuite -lt 0) { $MargeSuite = $Marge }
    $lignes = @()
    $courante = ''
    # PAS $marge : PowerShell ignore la casse, ce serait le parametre [int]
    # $Marge, et « prefixe + texte » deviendrait une addition d'entiers.
    $prefixe = ' ' * $Marge
    foreach ($mot in ($Texte -split ' +')) {
        if (-not $mot) { continue }
        $essai = if ($courante) { "$courante $mot" } else { $mot }
        if (($prefixe.Length + $essai.Length) -gt $Largeur -and $courante) {
            $lignes += ($prefixe + $courante)
            $prefixe = ' ' * $MargeSuite
            $courante = $mot
        } else {
            $courante = $essai
        }
    }
    if ($courante) { $lignes += ($prefixe + $courante) }
    return $lignes
}

# ── La table ────────────────────────────────────────────────────────────────
# Rangee dans l'ordre des fichiers, pour qu'on retrouve une phrase la ou on
# l'a lue. Les cles sont ecrites exactement comme dans les scripts : le test
# refuse une cle qui ne s'y trouve pas, parce qu'une cle mal recopiee ne
# traduit rien et ne se voit pas.
$script:MESSAGES = @{

    # ── migration-pc.ps1 : le menu ──
    'Migration PC'                                = 'PC migration'
    'Que voulez-vous faire ?'                     = 'What do you want to do?'
    '  Votre choix'                               = '  Your choice'
    '  Votre reponse'                             = '  Your answer'
    'Quitter'                                     = 'Quit'
    'Par où commencer ?'                          = 'Where to start?'
    'Le parcours complet, selon ce que vous voulez faire.' = 'The whole route, depending on what you want to do.'
    'Choix inconnu.'                              = 'Unknown choice.'
    'Ensuite, sur le site :'                      = 'Then, on the site:'
    'indisponible'                                = 'unavailable'
    'proposé'                                     = 'suggested'
    'Quel dossier ?'                              = 'Which folder?'
    'Collez le chemin du dossier (clic droit dans cette fenêtre), ou laissez' = 'Paste the folder path (right-click in this window), or leave it'
    'vide pour annuler.'                          = 'empty to cancel.'
    '  Dossier'                                   = '  Folder'
    'lanceur-actions.ps1 est introuvable à côté de ce script. Copiez le dossier entier.' = 'lanceur-actions.ps1 cannot be found beside this script. Copy the whole folder.'
    'Annulé.'                                     = 'Cancelled.'
    'Terminé.'                                    = 'Done.'
    'Checklist ouverte.'                          = 'Checklist opened.'
    "Rien a installer. Relancez le scan CIBLE d'abord." = 'Nothing to install. Run the TARGET scan again first.'
    "Annulé. Rien n'a été installé."              = 'Cancelled. Nothing has been installed.'
    "winget est introuvable sur cette machine. Installez « Programme d'installation d'application » depuis le Microsoft Store." = 'winget cannot be found on this machine. Install « App Installer » from the Microsoft Store.'
    'winget import en cours. Laissez cette fenêtre ouverte.' = 'winget import running. Leave this window open.'
    "winget a fini avec des avertissements (code {0}) : au moins un paquet n'est pas passé." = 'winget finished with warnings (code {0}): at least one package did not go through.'

    # ── lanceur-actions.ps1 : les actions du menu ──
    'Ce PC est la SOURCE (celui que je quitte)'   = 'This PC is the SOURCE (the one I am leaving)'
    "Fige l'etat de cette machine : les logiciels installes et les pilotes en place. C'est l'instantane qu'on rejouera ailleurs." = "Freezes this machine's state: the software installed and the drivers in place. This is the snapshot to replay elsewhere."
    'Ce PC est la CIBLE (le neuf, ou celui que je viens de reinstaller)' = 'This PC is the TARGET (the new one, or the one I have just reinstalled)'
    "Refait le meme releve ici, pour le comparer a l'instantane de la source. La page dira ce qui est arrive et ce qui manque encore." = 'Runs the same survey here, to compare it with the source snapshot. The page will say what has arrived and what is still missing.'
    'Installer ce qui manque'                     = 'Install what is missing'
    'Joue « winget import » sur la liste calculee par le scan de la cible. La liste est montree, et rien ne part sans confirmation.' = 'Runs « winget import » on the list worked out by the target scan. The list is shown, and nothing starts without confirmation.'
    'Ouvrir la checklist'                         = 'Open the checklist'
    'La page seule, sans rien scanner.'           = 'The page on its own, scanning nothing.'
    '1 a 3 minutes'                               = '1 to 3 minutes'

    'Aucun instantané sur la clé : ce PC est probablement la SOURCE.' = 'No snapshot on the stick: this PC is probably the SOURCE.'
    'La clé porte l''instantané de « {0} », qui n''est pas cette machine : ce PC est la CIBLE.' = 'The stick holds the snapshot of « {0} », which is not this machine: this PC is the TARGET.'
    'L''instantané de la clé décrit CETTE machine. Si vous venez de la réinstaller, c''est la CIBLE ; si vous refaites le relevé avant de formater, c''est la SOURCE.' = 'The snapshot on the stick describes THIS machine. If you have just reinstalled it, it is the TARGET; if you are running the survey again before formatting, it is the SOURCE.'
    'La clé porte l''instantané de « {0} » et ce PC s''appelle « {1} » : ce PC est la CIBLE. (Numéro de série indisponible, la déduction vaut ce que valent les noms de machine.)' = 'The stick holds the snapshot of « {0} » and this PC is called « {1} »: this PC is the TARGET. (No serial number available, so the guess is only as good as machine names are.)'
    'L''instantané de la clé porte le même nom de machine que celui-ci, sans numéro de série pour trancher.' = 'The snapshot on the stick carries the same machine name as this one, with no serial number to settle it.'
    'La clé porte un instantané, mais rien ne permet de dire de quelle machine : ni numéro de série, ni nom.' = 'The stick holds a snapshot, but nothing says which machine it came from: no serial number, no name.'
    'La checklist s''ouvre déjà remplie de vos logiciels.' = 'The checklist opens already filled with your software.'
    'Onglet « Logiciels » : décochez ce que vous ne voulez pas reprendre.' = '« Software » tab: uncheck whatever you do not want to take with you.'
    'Posez l''instantané et cette page sur la clé, et emportez-la.' = 'Put the snapshot and this page on the stick, and take it with you.'
    'Onglet « Logiciels » : le compte de ce qui est arrivé, et ce qui manque.' = '« Software » tab: the count of what has arrived, and what is missing.'
    'Chaque manquant porte sa commande d''installation.' = 'Each missing one carries its install command.'
    'Onglet « Pilotes » : les périphériques sans pilote, et où chercher.' = '« Drivers » tab: the devices with no driver, and where to look.'
    'Importez l''instantané de la source si la page ne l''a pas encore.' = 'Import the source snapshot if the page does not have it yet.'
    'Onglet « Logiciels » : relancez le scan CIBLE pour voir le resultat.' = '« Software » tab: run the TARGET scan again to see the result.'
    'Ce que winget n''a pas pu installer reste marque « manque ».' = 'Whatever winget could not install stays marked « missing ».'
    'Sans scan, la page s''ouvre sur un profil d''exemple.' = 'With no scan, the page opens on an example profile.'
    '« Importer » accepte un instantané déjà produit, ou un export winget.' = '« Import » takes a snapshot already produced, or a winget export.'
    'variable : ca telecharge' = 'varies: it downloads'
    'immediat' = 'immediate'
    'D''un PC vers un autre — la clé USB fait le voyage' = 'From one PC to another — the USB stick makes the trip'
    '1. Clé branchée sur la SOURCE : scanner. La page s''ouvre remplie de vos logiciels, et l''instantané reste sur la clé. Le scan LISTE, il ne copie rien. Vos fichiers personnels, c''est à vous de les sauvegarder — ce programme ne s''en occupe pas.' = '1. Stick plugged into the SOURCE: scan. The page opens filled with your software, and the snapshot stays on the stick. The scan LISTS, it copies nothing. Your personal files are yours to back up — this program does not deal with them.'
    '2. Débranchez la clé et branchez-la sur la CIBLE.' = '2. Unplug the stick and plug it into the TARGET.'
    '3. Scanner de nouveau, en CIBLE. La page compare les deux toute seule et dit ce qui manque encore : rien à importer à la main.' = '3. Scan again, as TARGET. The page compares the two on its own and says what is still missing: nothing to import by hand.'
    '4. Installez ce qui manque, et réglez les pilotes signalés.' = '4. Install what is missing, and sort out the drivers it flags.'
    'Vous réinstallez Windows sur CETTE machine' = 'You are reinstalling Windows on THIS machine'
    'Le même parcours : cette machine est la source avant le formatage, et la cible après. C''est le même script des deux côtés.' = 'The same route: this machine is the source before formatting, and the target after. It is the same script on both sides.'
    '1. Scanner en SOURCE d''abord : après le formatage, il n''y a plus rien. Gardez la clé hors de la machine pendant le formatage.' = '1. Scan as SOURCE first: after formatting there is nothing left. Keep the stick out of the machine while it formats.'
    '2. Sauvegardez vos fichiers AVANT de formater. Après, il est trop tard.' = '2. Back up your files BEFORE formatting. Afterwards it is too late.'
    '3. Après réinstallation : rebranchez la clé, scanner en CIBLE.' = '3. After reinstalling: plug the stick back in, scan as TARGET.'
    'Vous gardez les deux PC' = 'You are keeping both PCs'
    'Même chose, mais ne déliez rien sur l''ancien : il reste en service.' = 'Same thing, but unlink nothing on the old one: it stays in service.'
    'Rien a installer : la liste est vide.' = 'Nothing to install: the list is empty.'
    '1 logiciel va etre installe par winget sur CETTE machine :' = '1 program is about to be installed by winget on THIS machine:'
    '{0} logiciels vont etre installes par winget sur CETTE machine :' = '{0} programs are about to be installed by winget on THIS machine:'
    'winget telecharge depuis le depot Microsoft et lance chaque installeur.' = 'winget downloads from the Microsoft repository and runs each installer.'
    'L''operation saute ce qui est deja present et peut etre longue.' = 'It skips whatever is already there, and can take a while.'
    'Tapez {0} pour lancer, ou n''importe quoi d''autre pour annuler.' = 'Type {0} to start, or anything else to cancel.'
    'INSTALLER' = 'INSTALL'
    'Fichier(s) absent(s) : {0}. Copiez le dossier entier, pas un fichier isolé.' = 'Missing file(s): {0}. Copy the whole folder, not a single file.'
    'Fichier(s) absent(s) : {0}.' = 'Missing file(s): {0}.'

    # ── lib-detection.ps1 : l'avancement du relevé ──
    'absent, ignore'                              = 'not there, skipped'
    'sortie illisible, ignore'                    = 'unreadable output, skipped'
    'colonnes illisibles, ignore'                 = 'unreadable columns, skipped'
    'indisponible, ignore'                        = 'unavailable, skipped'
    'non installe, ignore'                        = 'not installed, skipped'
    'aucun jeu, ignore'                           = 'no game, skipped'
    'erreur ignoree : {0}'                        = 'error ignored: {0}'
    '1 entree'                                    = '1 entry'
    '{0} entrees'                                 = '{0} entries'
    '1 jeu'                                       = '1 game'
    '{0} jeux'                                    = '{0} games'
    'aucun paquet du catalogue'                   = 'no package from the catalogue'
    '{0} identifiant(s), {1} pose(s), {2} ligne(s) ajoutee(s)' = '{0} identifier(s), {1} matched, {2} line(s) added'

    'winget...' = 'winget...'
    'registre...' = 'registry...'
    'Microsoft Store...' = 'Microsoft Store...'
    'Steam...' = 'Steam...'
    'Epic Games...' = 'Epic Games...'
    'GOG...' = 'GOG...'
    'Xbox / Game Pass...' = 'Xbox / Game Pass...'
    'Ubisoft Connect...' = 'Ubisoft Connect...'
    'EA App...' = 'EA App...'
    'materiel...' = 'hardware...'
    'machine...' = 'machine...'
    'pilotes tiers...' = 'third-party drivers...'
    'peripheriques sans pilote...' = 'devices with no driver...'
    'winget export... aucun paquet du catalogue' = 'winget export... no package from the catalogue'
    'winget export... {0} identifiant(s), {1} pose(s), {2} ligne(s) ajoutee(s)' = 'winget export... {0} identifier(s), {1} matched, {2} line(s) added'
    'winget export... erreur ignoree : {0}' = 'winget export... error ignored: {0}'
    '{0} : ignore, {1}' = '{0}: skipped, {1}'
    'aucun' = 'none'
    '1 composant' = '1 component'
    '{0} composants' = '{0} components'
    '1 information' = '1 detail'
    '{0} informations' = '{0} details'
    '1 fournisseur' = '1 vendor'
    '{0} fournisseurs' = '{0} vendors'
    '{0} a regler' = '{0} to sort out'

    # ── scan-pc.ps1 et ecrire-resultat.ps1 : la fin du travail ──
    'lib-detection.ps1 est introuvable a cote de ce script. Copiez les deux fichiers ensemble.' = 'lib-detection.ps1 cannot be found beside this script. Copy both files together.'
    'Inventaire des logiciels installes' = 'Inventory of installed software'
    '(raccourci inventaire-pc.json non ecrit : {0})' = '(inventaire-pc.json shortcut not written: {0})'
    '(copie pour la cle non ecrite : {0})' = '(copy for the stick not written: {0})'
    '(instantane de la source illisible, ignore)' = '(source snapshot unreadable, skipped)'
    '(liste des manquants non ecrite : {0})' = '(list of missing items not written: {0})'
    'ecrire-resultat.ps1 n''est pas a cote de ce script : la page ne se remplira pas toute seule. Importez le fichier JSON a la main, ou reprenez le dossier complet depuis le site.' = 'ecrire-resultat.ps1 is not beside this script: the page will not fill itself in. Import the JSON file by hand, or take the whole folder again from the site.'
    '1 application retenue, dont {0} avec un identifiant winget.' = '1 program kept, of which {0} with a winget identifier.'
    '{0} applications retenues, dont {1} avec un identifiant winget.' = '{0} programs kept, of which {1} with a winget identifier.'
    'Taille connue : {0} Go — partielle, toutes les sources ne la donnent pas.' = 'Known size: {0} GB — partial, not every source gives it.'
    '1 pilote non-Microsoft releve.' = '1 non-Microsoft driver found.'
    '{0} pilotes non-Microsoft releves.' = '{0} non-Microsoft drivers found.'
    '1 peripherique sans pilote ou en erreur.' = '1 device with no driver, or in error.'
    '{0} peripheriques sans pilote ou en erreur.' = '{0} devices with no driver, or in error.'
    'La page donne le lien du constructeur a partir du modele de la machine.' = 'The page gives the maker''s link from the machine model.'
    'Fichier ecrit : {0}' = 'File written: {0}'
    'Etape suivante' = 'Next step'
    '1. Debranchez cette cle USB.' = '1. Unplug this USB stick.'
    '2. Branchez-la sur le PC cible : le neuf, ou celui-ci une fois reinstalle.' = '2. Plug it into the target PC: the new one, or this one once reinstalled.'
    '3. Lancez « Migration PC.bat » et choisissez CIBLE.' = '3. Run « Migration PC.bat » and choose TARGET.'
    'index.html n''est pas a cote des scripts : copiez le dossier entier sur la cle, sinon le PC cible n''aura rien a comparer.' = 'index.html is not beside the scripts: copy the whole folder onto the stick, or the target PC will have nothing to compare.'
    'La page s''ouvre sur ce qu''il reste a installer : les deux instantanes y sont.' = 'The page opens on what is left to install: both snapshots are there.'
    'Relancez « Migration PC.bat » : il propose maintenant d''installer ce qui manque, apres vous avoir montre la liste.' = 'Run « Migration PC.bat » again: it now offers to install what is missing, after showing you the list.'
    'Aucun instantane du PC source sur cette cle : la page n''a rien a comparer.' = 'No source PC snapshot on this stick: the page has nothing to compare.'
    'Scannez d''abord le PC source, ou importez son fichier a la main.' = 'Scan the source PC first, or import its file by hand.'
    'Une entree manque ? Relancer avec -ToutInclure pour desactiver le filtrage.' = 'An entry missing? Run again with -ToutInclure to turn the filtering off.'
    'index.html n''est pas a cote de ce script : le fichier JSON est ecrit, a importer a la main depuis le site.' = 'index.html is not beside this script: the JSON file has been written, to import by hand from the site.'
    'Impossible de poser le resultat a cote de la page :' = 'Could not put the result beside the page:'
    'Le fichier JSON est ecrit : importez-le a la main depuis le site.' = 'The JSON file has been written: import it by hand from the site.'
    'Resultat pose a cote de la page.'            = 'Result put beside the page.'
    "Ouvrez index.html : elle s'affichera deja remplie." = 'Open index.html: it will come up already filled in.'
    'Ouverture de la checklist...'                = 'Opening the checklist...'
    'Ouvrez index.html a la main : {0}'           = 'Open index.html by hand: {0}'
}
