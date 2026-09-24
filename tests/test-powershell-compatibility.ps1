# Verification statique des constructions compatibles avec Windows PowerShell 5.1.
$scriptPath = Join-Path $PSScriptRoot '..\scan-pc.ps1'
$content = [System.IO.File]::ReadAllText((Resolve-Path $scriptPath))

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    throw "scan-pc.ps1 ne parse pas : $($errors[0].Message)"
}

$expected = 'Write-Host ($nombreVariables.ToString() + " variable(s) d''environnement relevee(s).")'
if ($content.IndexOf($expected, [System.StringComparison]::Ordinal) -lt 0) {
    throw "La sortie du nombre de variables n'utilise pas la construction attendue."
}

"Compatibilite PowerShell 5.1 OK"
