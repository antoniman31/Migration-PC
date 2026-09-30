<#
.SYNOPSIS
    Le point d'entree : un menu qui demande ce qu'on veut faire, et lance le
    script correspondant.

.DESCRIPTION
    Plusieurs scripts font le travail, et il fallait savoir lequel lancer, dans
    quel ordre, sur quelle machine. Ce menu pose la question a la place.

    Il n'ajoute aucune capacite : il appelle les memes scripts, qu'on peut
    toujours lancer a la main. C'est un aiguillage, pas une couche de plus.

    Il y a eu une fenetre graphique ici. Elle a ete retiree : elle etait le
    seul morceau du projet qu'aucun test ne pouvait exercer — WinForms ne se
    pilote pas sur une machine d'integration sans ecran — alors que le menu
    texte, lui, est lance et verifie a chaque publication. Moins de code, et
    plus rien qui echappe aux tests.

.NOTES
    Windows. PowerShell 5.1 ou superieur.
    Si l'execution est bloquee : double-cliquez « Migration PC.bat », ou
        powershell -ExecutionPolicy Bypass -File .\migration-pc.ps1
#>

[CmdletBinding()]
param(
    # La langue de ce que le programme ecrit. Vide : celle de l'interface
    # Windows. C'est la que quelqu'un tranche quand les deux ne concordent
    # pas — un francophone sur un Windows anglais, par exemple.
    [ValidateSet('fr', 'en')]
    [string]$Langue = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Racine = $PSScriptRoot
if (-not $Racine) { $Racine = (Get-Location).Path }

# La langue et l'encodage AVANT le premier affichage : un message d'erreur en
# charabia serait le premier chose que verrait quelqu'un dont le dossier est
# incomplet.
$langueFichier = Join-Path $Racine 'lib-langue.ps1'
if (-not (Test-Path -LiteralPath $langueFichier)) {
    Write-Error "lib-langue.ps1 est introuvable a cote de ce script. Copiez le dossier entier."
    exit 1
}
. $langueFichier
Set-SortieUTF8
$LangueChoisie = Set-Langue $Langue

$actionsFichier = Join-Path $Racine 'lanceur-actions.ps1'
if (-not (Test-Path -LiteralPath $actionsFichier)) {
    Write-Error (Tr "lanceur-actions.ps1 est introuvable à côté de ce script. Copiez le dossier entier.")
    exit 1
}
. $actionsFichier

# ---------------------------------------------------------------- execution

function Invoke-Action {
    param($Action)

    if (-not $Action.possible) {
        return @{ ok = $false; message = (Get-MessageManquants $Action.manquants) }
    }

    # L'installation est la seule action qui change la machine. Elle montre la
    # liste entiere, attend un mot tape, et n'est jamais enchainee toute seule
    # apres un scan : c'est le seul endroit du programme ou une erreur ne se
    # rattrape pas en rechargeant une page.
    if ($Action.PSObject.Properties['winget'] -and $Action.winget) {
        $fichier = Join-Path $Racine '..\winget-restant.json'
        $ids = @(Read-WingetImport -Chemin $fichier)
        Write-Host ""
        Get-InviteInstallation -Identifiants $ids | ForEach-Object { Write-Host ("  " + $_) }
        if (-not $ids.Count) {
            return @{ ok = $false; message = (Tr "Rien a installer. Relancez le scan CIBLE d'abord.") }
        }
        $saisi = Read-Host (Tr "  Votre reponse")
        if (-not (Test-Confirmation $saisi)) {
            return @{ ok = $false; message = (Tr "Annulé. Rien n'a été installé.") }
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            return @{ ok = $false; message = (Tr "winget est introuvable sur cette machine. Installez « Programme d'installation d'application » depuis le Microsoft Store.") }
        }
        Write-Host ""
        Write-Host ("  " + (Tr "winget import en cours. Laissez cette fenêtre ouverte.")) -ForegroundColor Cyan
        & winget import -i $fichier --accept-package-agreements --accept-source-agreements
        # winget rend un code non nul des qu'un seul paquet a echoue, meme si
        # tous les autres sont passes : ce n'est pas un echec de l'operation,
        # c'est une liste partielle. Le prochain scan CIBLE dira laquelle.
        if ($LASTEXITCODE -ne 0) {
            return @{ ok = $true
                      message = (Tr "winget a fini avec des avertissements (code {0}) : au moins un paquet n'est pas passé." $LASTEXITCODE)
                      suite = $Action.suite }
        }
        return @{ ok = $true; message = (Tr "Terminé."); suite = $Action.suite }
    }

    if ($Action.PSObject.Properties['fichier']) {
        $cible = Join-Path $Racine $Action.fichier
        Start-Process $cible
        return @{ ok = $true; message = (Tr "Checklist ouverte."); suite = $Action.suite }
    }

    $script = Join-Path $Racine $Action.script
    # Surtout pas $args : c'est la variable automatique des arguments non lies,
    # et l'ecraser dans un script est un piege classique.
    $parametres = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script)

    # Les arguments fixes de l'action : c'est par la que le meme scan-pc.ps1
    # tourne en source d'un cote et en cible de l'autre.
    if ($Action.PSObject.Properties['arguments'] -and $Action.arguments) {
        $parametres += @($Action.arguments)
    }

    # Le scan s'ouvre dans SA fenetre : sans cet argument il retomberait sur la
    # langue de Windows et repondrait en anglais a quelqu'un qui vient de
    # choisir le francais dans ce menu.
    $parametres += @('-Langue', (Get-LangueActive))

    if ($Action.PSObject.Properties['dossier'] -and $Action.dossier) {
        $dossier = Read-DossierSauvegarde -Invite $Action.titre
        if (-not $dossier) { return @{ ok = $false; message = (Tr "Annulé.") } }
        # Le nom du parametre varie : on copie VERS un dossier, on restaure
        # DEPUIS un dossier. Se tromper de sens serait le pire defaut possible.
        $nomParam = if ($Action.PSObject.Properties['argument'] -and $Action.argument) {
            $Action.argument
        } else { 'Destination' }
        $parametres += @("-$nomParam", $dossier)
    }

    # Une nouvelle fenetre : le script ecrit beaucoup, et on veut pouvoir lire
    # sa sortie apres coup meme si le lanceur est referme.
    Start-Process -FilePath 'powershell.exe' -ArgumentList (Get-LigneCommande $parametres) -Wait
    return @{ ok = $true; message = (Tr "Terminé."); suite = $Action.suite }
}

# Il y a eu un selecteur de dossier graphique ici. Il est parti avec la
# fenetre : le garder aurait maintenu la dependance a WinForms qu'on venait
# d'enlever, pour un seul champ. Dans une console on colle un chemin par un
# clic droit, et l'explorateur Windows sait copier celui d'un dossier.
function Read-DossierSauvegarde {
    param([string]$Invite = '')
    if (-not $Invite) { $Invite = Tr "Quel dossier ?" }
    Write-Host ""
    Write-Host "  $Invite" -ForegroundColor Cyan
    Write-Host ("  " + (Tr "Collez le chemin du dossier (clic droit dans cette fenêtre), ou laissez"))
    Write-Host ("  " + (Tr "vide pour annuler."))
    $saisi = Read-Host (Tr "  Dossier")
    if ([string]::IsNullOrWhiteSpace($saisi)) { return $null }
    # Un chemin colle depuis l'explorateur arrive parfois entoure de
    # guillemets : les laisser ferait chercher un dossier qui n'existe pas.
    return $saisi.Trim().Trim('"').Trim()
}

# ---------------------------------------------------------------- menu

function Show-MenuTexte {
    param($Actions, [string]$Deduction = '')
    while ($true) {
        Write-Host ""
        Write-Host ("  " + (Tr "Migration PC")) -ForegroundColor Cyan
        # Le trait fait la largeur du titre : « PC migration » est plus long que
        # « Migration PC », et un trait fixe depasserait ou serait trop court.
        Write-Host ("  " + ('-' * (Tr "Migration PC").Length))
        # Ce que la cle sait deja. Affiche avant le menu, pas a la place :
        # la deduction propose, et l'entree proposee est mise en premier.
        if ($Deduction) {
            Write-Host ("  " + $Deduction) -ForegroundColor Cyan
            Write-Host ""
        }
        Write-Host ("  " + (Tr "Que voulez-vous faire ?"))
        Write-Host ""
        $i = 0
        foreach ($a in $Actions) {
            $i++
            $etat = if (-not $a.possible) { '  [' + (Tr 'indisponible') + ']' }
                    elseif ($a.suggere)    { '   <-- ' + (Tr 'proposé') }
                    else                   { '' }
            Write-Host ("  {0}. {1}{2}" -f $i, $a.titre, $etat) -ForegroundColor $(if ($a.possible) { 'White' } else { 'DarkGray' })
            Write-Host ("     {0}" -f $a.detail) -ForegroundColor DarkGray
            if (-not $a.possible) {
                Write-Host ("     {0}" -f (Get-MessageManquants $a.manquants)) -ForegroundColor Yellow
            }
        }
        Write-Host ""
        Write-Host ("  {0}. {1}" -f (@($Actions).Count + 1), (Tr "Par où commencer ?"))
        Write-Host ("     " + (Tr "Le parcours complet, selon ce que vous voulez faire.")) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("  0. " + (Tr "Quitter"))
        Write-Host ""
        $choix = Read-Host (Tr "  Votre choix")
        if ($choix -eq '0' -or [string]::IsNullOrWhiteSpace($choix)) { return }
        $n = 0
        if (-not [int]::TryParse($choix, [ref]$n) -or $n -lt 1 -or $n -gt (@($Actions).Count + 1)) {
            Write-Host ("  " + (Tr "Choix inconnu.")) -ForegroundColor Yellow
            continue
        }
        if ($n -eq (@($Actions).Count + 1)) {
            Write-Host ""
            Get-Parcours | ForEach-Object { Write-Host $_ }
            continue
        }
        $res = Invoke-Action -Action $Actions[$n - 1]
        Write-Host ""
        Write-Host ("  " + $res.message) -ForegroundColor $(if ($res.ok) { 'Green' } else { 'Yellow' })
        # Le plus utile arrive apres : ce qu'il faut faire sur le site.
        if ($res.ok -and $res.ContainsKey('suite') -and $res.suite) {
            Write-Host ""
            Write-Host ("  " + (Tr "Ensuite, sur le site :")) -ForegroundColor Cyan
            $res.suite | ForEach-Object { Write-Host ("    - " + $_) }
        }
    }
}

# ---------------------------------------------------------------- lancement

# Le numero de serie du SMBIOS : le seul identifiant qui survit a une
# reinstallation de Windows. Indisponible ailleurs que sur Windows, et parfois
# vide sur une machine assemblee — la deduction s'en passe alors et pose la
# question.
$serieLocale = try {
    ([string](Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber).Trim()
} catch { '' }

$instantane = Get-InstantaneSourceSurCle -Racine $Racine
$suggestion = Get-RoleSuggere -Instantane $instantane -SerieLocale $serieLocale -NomLocal $env:COMPUTERNAME

$actions = @(Get-ActionsMigration -Racine $Racine -RoleSuggere $suggestion.role)
Show-MenuTexte -Actions $actions -Deduction $suggestion.raison
