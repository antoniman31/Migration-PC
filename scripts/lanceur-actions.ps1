# Ce que le lanceur sait faire, et ce dont chaque action a besoin.
#
# Separe de l'interface pour une raison pratique : cette partie se teste
# partout, l'interface graphique seulement sur Windows. Une action mal decrite
# ou un fichier manquant se voit ici, pas devant l'utilisateur.

# Construire la ligne de commande passee a powershell.exe.
#
# Start-Process -ArgumentList @(...) recolle les elements avec des espaces,
# sans jamais les proteger. Un chemin qui en contient — « D:\Migration PC »,
# « E:\Sauvegarde du 12 » — se coupait en deux et powershell.exe refusait la
# ligne entiere en affichant son aide. Le lanceur ne marchait donc que depuis
# un dossier sans espace, ce qui n'est pas une hypothese qu'on peut faire :
# le dossier de ce projet s'appelle « Migration PC ». Trouve en l'executant.
#
# Les guillemets sont doubles a l'interieur, comme le veut la convention de
# ligne de commande de Windows. Une chaine sans espace ni guillemet est
# laissee telle quelle : plus lisible dans les messages d'erreur.
function Format-Argument {
    param([string]$Valeur)
    if ($null -eq $Valeur) { return '""' }
    if ($Valeur -eq '') { return '""' }
    if ($Valeur -notmatch '[\s"]') { return $Valeur }
    return '"' + ($Valeur -replace '"', '""') + '"'
}

# La table de traduction et la fonction Tr. Ce fichier est aussi source seul
# par les tests : on charge la mecanique si elle n'est pas deja la, plutot que
# de supposer qu'un appelant l'a fait.
if (-not (Get-Command Tr -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'lib-langue.ps1')
}

function Get-LigneCommande {
    param([string[]]$Arguments)
    return @($Arguments | ForEach-Object { Format-Argument $_ })
}

# ----------------------------------------------- deduire le cote ou l'on est
#
# Le menu ne posait qu'une question — source ou cible — et cette question a une
# reponse mecanique : si la cle porte deja l'instantane d'une AUTRE machine,
# c'est qu'on est arrive sur la cible. Se tromper coutait cher : un scan lance
# en source ecrase l'instantane de l'ancien PC par celui du neuf, et la
# comparaison est perdue sans que rien ne le dise.
#
# La deduction propose, elle ne decide pas. Un numero de serie vide ou
# identique arrive souvent — une machine assemblee dont personne n'a rempli le
# SMBIOS, ou le cas « je reinstalle ce PC-ci », qui est justement ambigu.

# L'instantane que le scan de la source a pose sur la cle, s'il y en a un.
# Cherche a cote des scripts puis un cran au-dessus, comme Get-DossierPage :
# les scripts vivent dans scripts\ et la page a la racine.
function Get-InstantaneSourceSurCle {
    param([Parameter(Mandatory)][string]$Racine)
    $dossiers = @($Racine)
    $parent = Split-Path $Racine -Parent
    if ($parent) { $dossiers += $parent }
    foreach ($d in $dossiers) {
        $f = Join-Path $d 'instantane-source.json'
        if (Test-Path -LiteralPath $f) {
            # Un fichier abime ne doit rien faire deviner : on rend $null et le
            # menu repose la question, plutot que de proposer n'importe quoi.
            try { return (Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json) }
            catch { return $null }
        }
    }
    return $null
}

# Lire un champ sans que Set-StrictMode ne fasse echouer le script quand il
# manque : un instantane peut ne porter aucun champ machine.
function Get-ChampInstantane {
    param($Objet, [string]$Nom)
    if ($null -eq $Objet) { return '' }
    $p = $Objet.PSObject.Properties[$Nom]
    if (-not $p) { return '' }
    return ([string]$p.Value).Trim()
}

function Get-RoleSuggere {
    param(
        [AllowNull()]$Instantane,
        [string]$SerieLocale = '',
        [string]$NomLocal = ''
    )
    # Rend toujours un objet, jamais $null : le menu affiche la raison, parce
    # qu'une deduction qu'on ne peut pas verifier ne vaut pas mieux qu'une
    # question posee franchement.
    $rien = [pscustomobject]@{ role = ''; raison = (Tr "Aucun instantané sur la clé : ce PC est probablement la SOURCE.") }
    if ($null -eq $Instantane) { return $rien }

    $machine   = if ($Instantane.PSObject.Properties['machine']) { $Instantane.machine } else { $null }
    $serieSrc  = Get-ChampInstantane -Objet $machine -Nom 'serie'
    $nomSrc    = Get-ChampInstantane -Objet $machine -Nom 'nom'
    $modeleSrc = Get-ChampInstantane -Objet $machine -Nom 'modele'
    $quoi = if ($modeleSrc) { $modeleSrc } elseif ($nomSrc) { $nomSrc } else { 'une autre machine' }

    $serieLoc = ([string]$SerieLocale).Trim()
    $nomLoc   = ([string]$NomLocal).Trim()

    # Le numero de serie d'abord : c'est le seul identifiant qui ne change pas
    # quand on reinstalle Windows. Le nom de machine, lui, se ressaisit a
    # l'installation, donc deux machines peuvent le partager.
    if ($serieSrc -and $serieLoc) {
        if ($serieSrc -ne $serieLoc) {
            return [pscustomobject]@{
                role   = 'cible'
                raison = (Tr "La clé porte l'instantané de « {0} », qui n'est pas cette machine : ce PC est la CIBLE." $quoi)
            }
        }
        return [pscustomobject]@{
            role   = ''
            raison = (Tr "L'instantané de la clé décrit CETTE machine. Si vous venez de la réinstaller, c'est la CIBLE ; si vous refaites le relevé avant de formater, c'est la SOURCE.")
        }
    }

    if ($nomSrc -and $nomLoc) {
        if ($nomSrc -ne $nomLoc) {
            return [pscustomobject]@{
                role   = 'cible'
                raison = (Tr "La clé porte l'instantané de « {0} » et ce PC s'appelle « {1} » : ce PC est la CIBLE. (Numéro de série indisponible, la déduction vaut ce que valent les noms de machine.)" $quoi $nomLoc)
            }
        }
        return [pscustomobject]@{
            role   = ''
            raison = (Tr "L'instantané de la clé porte le même nom de machine que celui-ci, sans numéro de série pour trancher.")
        }
    }

    return [pscustomobject]@{
        role   = ''
        raison = (Tr "La clé porte un instantané, mais rien ne permet de dire de quelle machine : ni numéro de série, ni nom.")
    }
}

function Get-ActionsMigration {
    param([string]$Racine, [string]$RoleSuggere = '')

    $toutes = @(
        [ordered]@{
            id      = 'source'
            titre   = (Tr "Ce PC est la SOURCE (celui que je quitte)")
            detail  = (Tr "Fige l'etat de cette machine : les logiciels installes et les pilotes en place. C'est l'instantane qu'on rejouera ailleurs.")
            script  = 'scan-pc.ps1'
            arguments = @('-Role', 'source')
            requis  = @('scan-pc.ps1', 'lib-detection.ps1')
            duree   = (Tr "1 a 3 minutes")
            suite   = @(
                (Tr "La checklist s'ouvre déjà remplie de vos logiciels."),
                (Tr "Onglet « Logiciels » : décochez ce que vous ne voulez pas reprendre."),
                (Tr "Posez l'instantané et cette page sur la clé, et emportez-la.")
            )
        },
        [ordered]@{
            id      = 'cible'
            titre   = (Tr "Ce PC est la CIBLE (le neuf, ou celui que je viens de reinstaller)")
            detail  = (Tr "Refait le meme releve ici, pour le comparer a l'instantane de la source. La page dira ce qui est arrive et ce qui manque encore.")
            script  = 'scan-pc.ps1'
            arguments = @('-Role', 'cible')
            requis  = @('scan-pc.ps1', 'lib-detection.ps1')
            duree   = (Tr "1 a 3 minutes")
            suite   = @(
                (Tr "Onglet « Logiciels » : le compte de ce qui est arrivé, et ce qui manque."),
                (Tr "Chaque manquant porte sa commande d'installation."),
                (Tr "Onglet « Pilotes » : les périphériques sans pilote, et où chercher."),
                (Tr "Importez l'instantané de la source si la page ne l'a pas encore.")
            )
        },
        [ordered]@{
            id      = 'installer'
            titre   = (Tr "Installer ce qui manque")
            detail  = (Tr "Joue « winget import » sur la liste calculee par le scan de la cible. La liste est montree, et rien ne part sans confirmation.")
            requis  = @('..\winget-restant.json')
            duree   = (Tr "variable : ca telecharge")
            winget  = $true
            suite   = @(
                (Tr "Onglet « Logiciels » : relancez le scan CIBLE pour voir le resultat."),
                (Tr "Ce que winget n'a pas pu installer reste marque « manque ».")
            )
        },
        [ordered]@{
            id      = 'checklist'
            titre   = (Tr "Ouvrir la checklist")
            detail  = (Tr "La page seule, sans rien scanner.")
            # La page est a la racine du dossier, les scripts dans scripts\ :
            # on la designe depuis la ou ils vivent.
            fichier = '..\index.html'
            requis  = @('..\index.html')
            duree   = (Tr "immediat")
            suite   = @(
                (Tr "Sans scan, la page s'ouvre sur un profil d'exemple."),
                (Tr "« Importer » accepte un instantané déjà produit, ou un export winget.")
            )
        }
    ) | ForEach-Object {
        $a = $_
        # Une action dont il manque un fichier est montree, mais desactivee et
        # expliquee : plus utile qu'une action absente dont on ignore pourquoi.
        $manquants = @($a.requis | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Racine $_)) })
        $a.manquants = $manquants
        $a.possible  = ($manquants.Count -eq 0)
        # Le cote deduit passe en premier et porte une marque. Le menu garde
        # toutes ses entrees : proposer n'est pas choisir a la place de
        # quelqu'un, et une deduction fausse doit rester rattrapable d'une
        # touche.
        $a.suggere = ($RoleSuggere -and $a.id -eq $RoleSuggere)
        [pscustomobject]$a
    }

    # Le cote deduit passe en tete, le reste garde son ordre. Volontairement a
    # la main : Sort-Object -Stable n'existe qu'a partir de PowerShell 6, et ce
    # script tourne surtout sous Windows PowerShell 5.1 — celui qu'on obtient
    # en double-cliquant un .bat.
    $suggerees = @($toutes | Where-Object { $_.suggere })
    $autres    = @($toutes | Where-Object { -not $_.suggere })
    return @($suggerees + $autres)
}

# Le parcours complet, pour qui ouvre le lanceur sans savoir par ou commencer.
function Get-Parcours {
    # LES PHRASES SONT ENTIERES ET L'HABILLAGE EST CALCULE. Elles etaient
    # coupees a la main en fragments de ligne — « La page s'ouvre remplie »,
    # puis « de vos logiciels, et l'instantane reste sur la cle ». Une coupe
    # faite pour le francais ne survit pas a la traduction : chaque fragment
    # aurait ete traduit separement, et l'anglais aurait ete du charabia. La
    # coupe se refait donc a l'affichage, dans la langue affichee.
    $l = @()
    $l += Format-Paragraphe (Tr "D'un PC vers un autre — la clé USB fait le voyage") 2
    $l += Format-Paragraphe (Tr "1. Clé branchée sur la SOURCE : scanner. La page s'ouvre remplie de vos logiciels, et l'instantané reste sur la clé. Le scan LISTE, il ne copie rien. Vos fichiers personnels, c'est à vous de les sauvegarder — ce programme ne s'en occupe pas.") 4 7
    $l += Format-Paragraphe (Tr "2. Débranchez la clé et branchez-la sur la CIBLE.") 4 7
    $l += Format-Paragraphe (Tr "3. Scanner de nouveau, en CIBLE. La page compare les deux toute seule et dit ce qui manque encore : rien à importer à la main.") 4 7
    $l += Format-Paragraphe (Tr "4. Installez ce qui manque, et réglez les pilotes signalés.") 4 7
    $l += ""
    $l += Format-Paragraphe (Tr "Vous réinstallez Windows sur CETTE machine") 2
    $l += Format-Paragraphe (Tr "Le même parcours : cette machine est la source avant le formatage, et la cible après. C'est le même script des deux côtés.") 4
    $l += Format-Paragraphe (Tr "1. Scanner en SOURCE d'abord : après le formatage, il n'y a plus rien. Gardez la clé hors de la machine pendant le formatage.") 4 7
    $l += Format-Paragraphe (Tr "2. Sauvegardez vos fichiers AVANT de formater. Après, il est trop tard.") 4 7
    $l += Format-Paragraphe (Tr "3. Après réinstallation : rebranchez la clé, scanner en CIBLE.") 4 7
    $l += ""
    $l += Format-Paragraphe (Tr "Vous gardez les deux PC") 2
    $l += Format-Paragraphe (Tr "Même chose, mais ne déliez rien sur l'ancien : il reste en service.") 4
    return $l
}

# ------------------------------------------------ installer ce qui manque
#
# Jusqu'ici la page fabriquait un fichier « winget import » parfaitement
# utilisable, puis demandait d'ouvrir PowerShell et de coller une commande. Le
# programme savait quoi faire et laissait le faire a la main.
#
# Ce qui est installe sur la machine de quelqu'un ne se decide pas a sa place :
# la liste complete est montree, la confirmation est un mot tape et non une
# touche, et rien ne s'enchaine automatiquement apres un scan.

# Les identifiants d'un fichier winget import, dans l'ordre du fichier —
# « winget import » les traite dans cet ordre.
function Read-WingetImport {
    param([Parameter(Mandatory)][string]$Chemin)
    if (-not (Test-Path -LiteralPath $Chemin)) { return @() }
    try {
        $d = Get-Content -LiteralPath $Chemin -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { return @() }
    if ($null -eq $d -or -not $d.PSObject.Properties['Sources']) { return @() }
    $ids = @()
    foreach ($s in @($d.Sources)) {
        if (-not $s -or -not $s.PSObject.Properties['Packages']) { continue }
        foreach ($p in @($s.Packages)) {
            if (-not $p -or -not $p.PSObject.Properties['PackageIdentifier']) { continue }
            $id = ([string]$p.PackageIdentifier).Trim()
            if ($id) { $ids += $id }
        }
    }
    return @($ids)
}

# Le mot a taper, sans ambiguite : « o », « y » ou Entree se tapent par
# reflexe, et ce qui suit installe des logiciels.
#
# Il s'affiche dans la langue de l'interface, et les DEUX mots sont acceptes.
# N'accepter que le mot traduit enfermerait dehors quelqu'un qui a lu la
# procedure en francais et tape « INSTALLER » sur une console anglaise. Pour
# une action qui installe des logiciels, une saisie refusee sans raison
# visible est le pire des resultats — et accepter les deux ne retire rien a la
# protection, qui est qu'un mot se tape et ne se tape pas par reflexe.
$MotDeConfirmation = 'INSTALLER'
$MotsDeConfirmation = @('INSTALLER', 'INSTALL')

function Get-MotDeConfirmation {
    return (Tr 'INSTALLER')
}

function Test-Confirmation {
    param([string]$Saisi)
    return ($MotsDeConfirmation -contains ([string]$Saisi).Trim().ToUpperInvariant())
}

function Get-InviteInstallation {
    param([string[]]$Identifiants)
    $n = @($Identifiants).Count
    if ($n -eq 0) {
        return @((Tr "Rien a installer : la liste est vide."))
    }
    $l = @()
    $l += if ($n -eq 1) { Tr "1 logiciel va etre installe par winget sur CETTE machine :" }
          else { Tr "{0} logiciels vont etre installes par winget sur CETTE machine :" $n }
    $l += ""
    foreach ($id in $Identifiants) { $l += "  - $id" }
    $l += ""
    $l += (Tr "winget telecharge depuis le depot Microsoft et lance chaque installeur.")
    $l += (Tr "L'operation saute ce qui est deja present et peut etre longue.")
    $l += ""
    $l += (Tr "Tapez {0} pour lancer, ou n'importe quoi d'autre pour annuler." (Get-MotDeConfirmation))
    return $l
}

function Get-MessageManquants {
    param([string[]]$Manquants)
    if (-not $Manquants -or $Manquants.Count -eq 0) { return '' }
    $liste = ($Manquants -join ', ')
    if ($Manquants -contains 'lib-detection.ps1') {
        return (Tr "Fichier(s) absent(s) : {0}. Copiez le dossier entier, pas un fichier isolé." $liste)
    }
    return (Tr "Fichier(s) absent(s) : {0}." $liste)
}
