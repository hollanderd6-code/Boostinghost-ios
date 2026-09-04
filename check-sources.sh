#!/usr/bin/env bash
# Vérifie que tout .swift sous Boostinghost/ est dans la phase Sources du pbxproj.
# Usage : ./check-sources.sh
# Retourne 0 si tout est enregistré, 1 s'il manque des fichiers.

set -euo pipefail

PBXPROJ="Boostinghost.xcodeproj/project.pbxproj"
SOURCE_DIR="Boostinghost"

if [ ! -f "$PBXPROJ" ]; then
    echo "Erreur : $PBXPROJ introuvable. Lance ce script depuis la racine du dépôt." >&2
    exit 2
fi

# Noms de fichiers déclarés dans la phase Sources (commentaires "Foo.swift in Sources")
in_sources=$(grep -oE '/\* [A-Za-z0-9_]+\.swift in Sources \*/' "$PBXPROJ" \
    | sed 's|/\* ||; s| in Sources \*/||' \
    | sort -u)

# Noms de fichiers .swift présents sur le disque
on_disk=$(find "$SOURCE_DIR" -name "*.swift" -not -path "*/.build/*" \
    | while read -r f; do basename "$f"; done \
    | sort -u)

missing=$(comm -23 <(echo "$on_disk") <(echo "$in_sources"))

if [ -z "$missing" ]; then
    count=$(echo "$on_disk" | wc -l | tr -d ' ')
    echo "✓ $count fichiers .swift — tous présents dans la phase Sources."
    exit 0
else
    echo "✗ Fichiers sur le disque mais absents de la phase Sources :"
    echo "$missing" | while IFS= read -r f; do
        # Retrouve le chemin complet pour faciliter l'ajout dans Xcode
        path=$(find "$SOURCE_DIR" -name "$f" | head -1)
        echo "  $f  →  $path"
    done
    echo ""
    echo "Dans Xcode : sélectionne le fichier dans le Project Navigator"
    echo "→ File Inspector → Target Membership → coche la cible Boostinghost."
    exit 1
fi
