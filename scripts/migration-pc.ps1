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
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# La console de Windows n'ecrit pas en UTF-8 par defaut : les accents de ce
# script y arriveraient en charabia. Les .bat font un « chcp 65001 », mais on
# peut aussi lancer ce fichier directement, et sous Windows PowerShell 5.1
# chcp ne suffit pas toujours. On le fixe ici, sans rien casser si l'hote
# refuse (redirection, console absente).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

$Racine = $PSScriptRoot
if (-not $Racine) { $Racine = (Get-Location).Path }

$actionsFichier = Join-Path $Racine 'lanceur-actions.ps1'
if (-not (Test-Path -LiteralPath $actionsFichier)) {
    Write-Error "lanceur-actions.ps1 est introuvable à côté de ce script. Copiez le dossier entier."
    exit 1
}
. $actionsFichier

# ---------------------------------------------------------------- execution

function Invoke-Action {
    param($Action)

    if (-not $Action.possible) {
        return @{ ok = $false; message = (Get-MessageManquants $Action.manquants) }
    }

    if ($Action.PSObject.Properties['fichier']) {
        $cible = Join-Path $Racine $Action.fichier
        Start-Process $cible
        return @{ ok = $true; message = "Checklist ouverte."; suite = $Action.suite }
    }

    $script = Join-Path $Racine $Action.script
    # Surtout pas $args : c'est la variable automatique des arguments non lies,
    # et l'ecraser dans un script est un piege classique.
    $parametres = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script)

    if ($Action.PSObject.Properties['dossier'] -and $Action.dossier) {
        $dossier = Read-DossierSauvegarde -Invite $Action.titre
        if (-not $dossier) { return @{ ok = $false; message = "Annulé." } }
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
    return @{ ok = $true; message = "Terminé."; suite = $Action.suite }
}

# Il y a eu un selecteur de dossier graphique ici. Il est parti avec la
# fenetre : le garder aurait maintenu la dependance a WinForms qu'on venait
# d'enlever, pour un seul champ. Dans une console on colle un chemin par un
# clic droit, et l'explorateur Windows sait copier celui d'un dossier.
function Read-DossierSauvegarde {
    param([string]$Invite = "Quel dossier ?")
    Write-Host ""
    Write-Host "  $Invite" -ForegroundColor Cyan
    Write-Host "  Collez le chemin du dossier (clic droit dans cette fenêtre), ou laissez"
    Write-Host "  vide pour annuler."
    $saisi = Read-Host "  Dossier"
    if ([string]::IsNullOrWhiteSpace($saisi)) { return $null }
    # Un chemin colle depuis l'explorateur arrive parfois entoure de
    # guillemets : les laisser ferait chercher un dossier qui n'existe pas.
    return $saisi.Trim().Trim('"').Trim()
}

# ---------------------------------------------------------------- menu

function Show-MenuTexte {
    param($Actions)
    while ($true) {
        Write-Host ""
        Write-Host "  Migration PC" -ForegroundColor Cyan
        Write-Host "  ------------"
        Write-Host "  Que voulez-vous faire ?"
        Write-Host ""
        $i = 0
        foreach ($a in $Actions) {
            $i++
            $etat = if ($a.possible) { '' } else { '  [indisponible]' }
            Write-Host ("  {0}. {1}{2}" -f $i, $a.titre, $etat) -ForegroundColor $(if ($a.possible) { 'White' } else { 'DarkGray' })
            Write-Host ("     {0}" -f $a.detail) -ForegroundColor DarkGray
            if (-not $a.possible) {
                Write-Host ("     {0}" -f (Get-MessageManquants $a.manquants)) -ForegroundColor Yellow
            }
        }
        Write-Host ""
        Write-Host ("  {0}. Par où commencer ?" -f (@($Actions).Count + 1))
        Write-Host "     Le parcours complet, selon ce que vous voulez faire." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  0. Quitter"
        Write-Host ""
        $choix = Read-Host "  Votre choix"
        if ($choix -eq '0' -or [string]::IsNullOrWhiteSpace($choix)) { return }
        $n = 0
        if (-not [int]::TryParse($choix, [ref]$n) -or $n -lt 1 -or $n -gt (@($Actions).Count + 1)) {
            Write-Host "  Choix inconnu." -ForegroundColor Yellow
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
            Write-Host "  Ensuite, sur le site :" -ForegroundColor Cyan
            $res.suite | ForEach-Object { Write-Host ("    - " + $_) }
        }
    }
}

# ---------------------------------------------------------------- lancement

$actions = @(Get-ActionsMigration -Racine $Racine)
Show-MenuTexte -Actions $actions
