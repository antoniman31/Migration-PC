<#
.SYNOPSIS
    Le point d'entree : une fenetre qui demande ce qu'on veut faire, et lance
    le script correspondant.

.DESCRIPTION
    Trois scripts font le travail, et il fallait savoir lequel lancer, dans
    quel ordre, sur quelle machine. Cette fenetre pose la question a la place.

    Elle n'ajoute aucune capacite : elle appelle les memes scripts, qu'on peut
    toujours lancer a la main. C'est un aiguillage, pas une couche de plus.

    Sans interface graphique disponible (PowerShell 7 sans Windows Desktop,
    session distante, Linux), elle bascule sur un menu texte qui propose
    exactement les memes choix.

.PARAMETER Console
    Force le menu texte, meme quand la fenetre est possible.

.NOTES
    Windows. PowerShell 5.1 ou superieur.
    Si l'execution est bloquee : double-cliquez « Migration PC.bat », ou
        powershell -ExecutionPolicy Bypass -File .\migration-pc.ps1
#>

[CmdletBinding()]
param([switch]$Console)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Racine = $PSScriptRoot
if (-not $Racine) { $Racine = (Get-Location).Path }

$actionsFichier = Join-Path $Racine 'lanceur-actions.ps1'
if (-not (Test-Path -LiteralPath $actionsFichier)) {
    Write-Error "lanceur-actions.ps1 est introuvable a cote de ce script. Copiez le dossier entier."
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
        $dossier = Read-DossierSauvegarde
        if (-not $dossier) { return @{ ok = $false; message = "Annule." } }
        $parametres += @('-Destination', $dossier)
    }

    # Une nouvelle fenetre : le script ecrit beaucoup, et on veut pouvoir lire
    # sa sortie apres coup meme si le lanceur est referme.
    Start-Process -FilePath 'powershell.exe' -ArgumentList $parametres -Wait
    return @{ ok = $true; message = "Termine."; suite = $Action.suite }
}

function Read-DossierSauvegarde {
    # Le selecteur de dossier n'existe qu'avec l'interface graphique.
    if (Test-InterfaceGraphique) {
        $boite = New-Object System.Windows.Forms.FolderBrowserDialog
        $boite.Description = "Ou se trouve la copie a verifier ?"
        if ($boite.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $boite.SelectedPath
        }
        return $null
    }
    $saisi = Read-Host "Chemin de la copie a verifier (vide pour annuler)"
    if ([string]::IsNullOrWhiteSpace($saisi)) { return $null }
    return $saisi
}

# ---------------------------------------------------------------- interface

$script:GraphiqueTeste = $null
function Test-InterfaceGraphique {
    if ($null -ne $script:GraphiqueTeste) { return $script:GraphiqueTeste }
    $script:GraphiqueTeste = $false
    if ($Console) { return $false }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        [System.Windows.Forms.Application]::EnableVisualStyles()
        $script:GraphiqueTeste = $true
    } catch {
        $script:GraphiqueTeste = $false
    }
    return $script:GraphiqueTeste
}

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
        Write-Host ("  {0}. Par ou commencer ?" -f (@($Actions).Count + 1))
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

function Show-Fenetre {
    param($Actions)

    $f = New-Object System.Windows.Forms.Form
    $f.Text = "Migration PC"
    $f.Size = New-Object System.Drawing.Size(620, 520)
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false
    $f.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)
    $f.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $titre = New-Object System.Windows.Forms.Label
    $titre.Text = "Que voulez-vous faire ?"
    $titre.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $titre.Location = New-Object System.Drawing.Point(24, 20)
    $titre.Size = New-Object System.Drawing.Size(560, 30)
    $f.Controls.Add($titre)

    $sous = New-Object System.Windows.Forms.Label
    $sous.Text = "Les memes scripts que vous pouvez lancer a la main. Cette fenetre choisit lequel."
    $sous.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $sous.Location = New-Object System.Drawing.Point(24, 50)
    $sous.Size = New-Object System.Drawing.Size(560, 20)
    $f.Controls.Add($sous)

    $etat = New-Object System.Windows.Forms.Label
    $etat.Location = New-Object System.Drawing.Point(24, 430)
    $etat.Size = New-Object System.Drawing.Size(560, 40)
    $etat.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $f.Controls.Add($etat)

    $y = 86
    foreach ($a in $Actions) {
        $b = New-Object System.Windows.Forms.Button
        $b.Location = New-Object System.Drawing.Point(24, $y)
        $b.Size = New-Object System.Drawing.Size(560, 74)
        $b.TextAlign = 'MiddleLeft'
        $b.FlatStyle = 'Flat'
        $b.BackColor = [System.Drawing.Color]::White
        $b.Padding = New-Object System.Windows.Forms.Padding(14, 0, 14, 0)
        $detail = if ($a.possible) { $a.detail } else { (Get-MessageManquants $a.manquants) }
        $b.Text = "$($a.titre)`r`n$detail"
        $b.Enabled = [bool]$a.possible
        $b.Tag = $a
        $b.Add_Click({
            $act = $this.Tag
            $this.FindForm().Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            try {
                $r = Invoke-Action -Action $act
                $texte = $r.message
                if ($r.ok -and $r.ContainsKey('suite') -and $r.suite) {
                    $texte = $r.message + "  Ensuite : " + ($r.suite -join '  ')
                }
                $etat.Text = $texte
            } catch {
                $etat.Text = "Erreur : $($_.Exception.Message)"
            } finally {
                $this.FindForm().Cursor = [System.Windows.Forms.Cursors]::Default
            }
        }.GetNewClosure())
        $f.Controls.Add($b)
        $y += 82
    }

    [void]$f.ShowDialog()
}

# ---------------------------------------------------------------- lancement

$actions = @(Get-ActionsMigration -Racine $Racine)

if (Test-InterfaceGraphique) {
    Show-Fenetre -Actions $actions
} else {
    Show-MenuTexte -Actions $actions
}
