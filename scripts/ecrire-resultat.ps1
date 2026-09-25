# Fonction commune aux deux scripts de scan : poser le resultat a cote de
# index.html et ouvrir la page dessus.
#
# Pourquoi un .js et pas seulement le .json : une page ouverte depuis une cle
# USB (file://) ne peut pas aller LIRE un fichier — le navigateur refuse fetch
# sur le disque local — mais elle peut charger un fichier JavaScript pose a
# cote d'elle. En ecrivant resultat-scan.js, ouvrir index.html suffit : la page
# s'affiche deja remplie, sans fichier a retrouver ni a deposer.
#
# Le .json reste ecrit : c'est le format d'echange, lisible et reutilisable.

function Write-ResultatPourSite {
    param(
        [Parameter(Mandatory)] $Donnees,
        [Parameter(Mandatory)] [string] $DossierScript,
        [switch] $NePasOuvrir
    )

    # Les scripts vivent dans scripts\ et la page a la racine : on la cherche
    # a cote d'abord — un dossier decompresse a plat reste possible — puis un
    # cran au-dessus.
    $page = Join-Path $DossierScript 'index.html'
    if (-not (Test-Path -LiteralPath $page)) {
        $parent = Split-Path $DossierScript -Parent
        if ($parent) {
            $candidat = Join-Path $parent 'index.html'
            if (Test-Path -LiteralPath $candidat) { $page = $candidat; $DossierScript = $parent }
        }
    }
    if (-not (Test-Path -LiteralPath $page)) {
        Write-Host ""
        Write-Host "index.html n'est pas a cote de ce script : le fichier JSON est ecrit," -ForegroundColor Yellow
        Write-Host "a importer a la main depuis le site." -ForegroundColor Yellow
        return
    }

    $cible = Join-Path $DossierScript 'resultat-scan.js'
    # Ce depot est un confort, pas le resultat : le JSON est deja ecrit. Une
    # cle protegee en ecriture, un disque plein ou un antivirus ne doivent pas
    # faire finir en rouge un scan qui a reussi.
    try {
        $json = $Donnees | ConvertTo-Json -Depth 8 -Compress
        # Une ligne, un objet pose sur window : la page le lit comme une donnee.
        [System.IO.File]::WriteAllText(([System.IO.Path]::GetFullPath($cible)), "window.MIGRATION_PC_SCAN=$json;", (New-Object System.Text.UTF8Encoding $false))
    } catch {
        Write-Host ""
        Write-Host "Impossible de poser le resultat a cote de la page :" -ForegroundColor Yellow
        Write-Host ("  " + $_.Exception.Message) -ForegroundColor Yellow
        Write-Host "Le fichier JSON est ecrit : importez-le a la main depuis le site."
        return
    }

    Write-Host ""
    Write-Host "Resultat pose a cote de la page." -ForegroundColor Green
    if ($NePasOuvrir) {
        Write-Host "Ouvrez index.html : elle s'affichera deja remplie."
        return
    }
    Write-Host "Ouverture de la checklist..."
    try { Start-Process $page }
    catch { Write-Host "Ouvrez index.html a la main : $($_.Exception.Message)" -ForegroundColor Yellow }
}
