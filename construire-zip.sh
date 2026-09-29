#!/usr/bin/env bash
# Fabrique migration-pc.zip : ce qu'il faut pour faire tourner le programme,
# et rien d'autre.
#
# L'archive automatique de GitHub emporte tout le depot — les tests, les
# captures du README, la CI, les profils d'exemple. Quelqu'un qui veut juste
# migrer son PC n'a que faire de quarante fichiers dont aucun ne se lance.
#
# Ce qui N'EST PAS dedans, et pourquoi : manifest.json, sw.js et icons/ ne
# servent qu'a la version en ligne — depuis une cle USB la page s'ouvre en
# file://, ou un navigateur refuse d'enregistrer un service worker. Les
# profils de presets/ sont deja embarques dans index.html. Les tests et les
# captures ne se lancent pas.
#
# LICENSE, en revanche, y est : l'AGPL oblige a joindre la licence a toute
# redistribution. Ce n'est pas du superflu, c'est la condition pour avoir le
# droit de distribuer le reste.
#
#   ./construire-zip.sh [dossier-de-sortie]
set -euo pipefail
cd "$(dirname "$0")"
sortie="${1:-.}"
archive="$sortie/migration-pc.zip"

fichiers=(
  "index.html"
  "Migration PC.bat"
  "LICENSE"
  scripts/*.ps1
)

for f in "${fichiers[@]}"; do
  [ -f "$f" ] || { echo "manquant : $f" >&2; exit 1; }
done

rm -f "$archive"
# -X : pas d'attributs propres a la machine qui construit, pour que deux
# constructions du meme contenu donnent le meme fichier.
zip -q -X "$archive" "${fichiers[@]}"
echo "$archive"
unzip -Z1 "$archive" | sort
