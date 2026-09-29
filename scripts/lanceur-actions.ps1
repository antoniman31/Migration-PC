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

function Get-LigneCommande {
    param([string[]]$Arguments)
    return @($Arguments | ForEach-Object { Format-Argument $_ })
}

function Get-ActionsMigration {
    param([string]$Racine)

    @(
        [ordered]@{
            id      = 'source'
            titre   = "Ce PC est la SOURCE (celui que je quitte)"
            detail  = "Fige l'etat de cette machine : les logiciels installes et les pilotes en place. C'est l'instantane qu'on rejouera ailleurs."
            script  = 'scan-pc.ps1'
            arguments = @('-Role', 'source')
            requis  = @('scan-pc.ps1', 'lib-detection.ps1')
            duree   = "1 a 3 minutes"
            suite   = @(
                "La checklist s'ouvre déjà remplie de vos logiciels.",
                "Onglet « Apps » : décochez ce que vous ne voulez pas reprendre.",
                "Posez l'instantané et cette page sur la clé, et emportez-la."
            )
        },
        [ordered]@{
            id      = 'cible'
            titre   = "Ce PC est la CIBLE (le neuf, ou celui que je viens de reinstaller)"
            detail  = "Refait le meme releve ici, pour le comparer a l'instantane de la source. La page dira ce qui est arrive et ce qui manque encore."
            script  = 'scan-pc.ps1'
            arguments = @('-Role', 'cible')
            requis  = @('scan-pc.ps1', 'lib-detection.ps1')
            duree   = "1 a 3 minutes"
            suite   = @(
                "Onglet « Reste à faire » : le compte de ce qui est arrivé, et ce qui manque.",
                "Chaque manquant porte sa commande d'installation ou son chemin.",
                "Onglet « Nouveau PC » : les périphériques sans pilote, et où chercher.",
                "Importez l'instantané de la source si la page ne l'a pas encore."
            )
        },
        [ordered]@{
            id      = 'checklist'
            titre   = "Ouvrir la checklist"
            detail  = "La page seule, sans rien scanner."
            # La page est a la racine du dossier, les scripts dans scripts\ :
            # on la designe depuis la ou ils vivent.
            fichier = '..\index.html'
            requis  = @('..\index.html')
            duree   = "immediat"
            suite   = @(
                "Au premier lancement, deux questions adaptent la liste à votre cas.",
                "Le sélecteur en haut de page permet d'en changer à tout moment."
            )
        }
    ) | ForEach-Object {
        $a = $_
        # Une action dont il manque un fichier est montree, mais desactivee et
        # expliquee : plus utile qu'une action absente dont on ignore pourquoi.
        $manquants = @($a.requis | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Racine $_)) })
        $a.manquants = $manquants
        $a.possible  = ($manquants.Count -eq 0)
        [pscustomobject]$a
    }
}

# Le parcours complet, pour qui ouvre le lanceur sans savoir par ou commencer.
function Get-Parcours {
    @(
        "  D'un PC vers un autre — la clé USB fait le voyage",
        "    1. Clé branchée sur la SOURCE : scanner. La page s'ouvre remplie",
        "       de vos logiciels, et l'instantané reste sur la clé.",
        "       Le scan LISTE, il ne copie rien. Vos fichiers personnels,",
        "       c'est à vous de les sauvegarder — ce programme ne s'en occupe pas.",
        "    2. Débranchez la clé et branchez-la sur la CIBLE.",
        "    3. Scanner de nouveau, en CIBLE. La page compare les deux toute",
        "       seule et dit ce qui manque encore : rien à importer à la main.",
        "    4. Installez ce qui manque, et réglez les pilotes signalés.",
        "",
        "  Vous réinstallez Windows sur CETTE machine",
        "    Le meme parcours : cette machine est la source avant le formatage,",
        "    et la cible apres. C'est le meme script des deux cotes.",
        "    1. Scanner en SOURCE d'abord : apres le formatage, il n'y a plus rien.",
        "       Gardez la clé hors de la machine pendant le formatage.",
        "    2. Sauvegardez vos fichiers AVANT de formater. Après, il est trop tard.",
        "    3. Après réinstallation : rebranchez la clé, scanner en CIBLE.",
        "",
        "  Vous gardez les deux PC",
        "    Même chose, mais ne déliez rien sur l'ancien : il reste en service."
    )
}

function Get-MessageManquants {
    param([string[]]$Manquants)
    if (-not $Manquants -or $Manquants.Count -eq 0) { return '' }
    $liste = ($Manquants -join ', ')
    if ($Manquants -contains 'lib-detection.ps1') {
        return "Fichier(s) absent(s) : $liste. Copiez le dossier entier, pas un fichier isolé."
    }
    return "Fichier(s) absent(s) : $liste."
}
