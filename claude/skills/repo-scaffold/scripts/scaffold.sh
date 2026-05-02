#!/usr/bin/env bash
# scaffold.sh — copy a repo and rename all name variants throughout
# Usage: scaffold.sh --source <dir> --dest <dir> --old <name> --new <name>
set -euo pipefail

usage() {
  echo "Usage: $0 --source <src-dir> --dest <dest-dir> --old <old-name> --new <new-name>"
  echo "  --source   Path to the source repo"
  echo "  --dest     Path for the new repo (must not exist)"
  echo "  --old      Current service name in kebab-case  (e.g. my-service)"
  echo "  --new      New service name in kebab-case      (e.g. new-service)"
  exit 1
}

SOURCE="" DEST="" OLD_NAME="" NEW_NAME=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --source) SOURCE="$2"; shift 2 ;;
    --dest)   DEST="$2";   shift 2 ;;
    --old)    OLD_NAME="$2"; shift 2 ;;
    --new)    NEW_NAME="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$SOURCE" || -z "$DEST" || -z "$OLD_NAME" || -z "$NEW_NAME" ]] && usage
[[ ! -d "$SOURCE" ]] && { echo "ERROR: source dir '$SOURCE' does not exist"; exit 1; }
[[ -e "$DEST" ]]     && { echo "ERROR: dest '$DEST' already exists"; exit 1; }

# ── Derive all naming variants ──────────────────────────────────────────────
to_pascal()        { echo "$1" | sed -E 's/(^|[-_])([a-z])/\U\2/g'; }
to_camel()         { p=$(to_pascal "$1"); echo "${p,}"; }
to_snake()         { echo "$1" | tr '-' '_'; }
to_screaming()     { echo "$1" | tr '-' '_' | tr '[:lower:]' '[:upper:]'; }
to_title()         { echo "$1" | sed -E 's/(^|[-_])([a-zA-Z])/\U\2 /g' | sed 's/ $//'; }

OLD_PASCAL=$(to_pascal "$OLD_NAME")
OLD_CAMEL=$(to_camel "$OLD_NAME")
OLD_SNAKE=$(to_snake "$OLD_NAME")
OLD_SCREAMING=$(to_screaming "$OLD_NAME")
OLD_TITLE=$(to_title "$OLD_NAME")

NEW_PASCAL=$(to_pascal "$NEW_NAME")
NEW_CAMEL=$(to_camel "$NEW_NAME")
NEW_SNAKE=$(to_snake "$NEW_NAME")
NEW_SCREAMING=$(to_screaming "$NEW_NAME")
NEW_TITLE=$(to_title "$NEW_NAME")

echo "Scaffolding: $OLD_NAME → $NEW_NAME"
echo "  Pascal:    $OLD_PASCAL → $NEW_PASCAL"
echo "  camel:     $OLD_CAMEL → $NEW_CAMEL"
echo "  snake:     $OLD_SNAKE → $NEW_SNAKE"
echo "  SCREAMING: $OLD_SCREAMING → $NEW_SCREAMING"
echo "  Title:     $OLD_TITLE → $NEW_TITLE"
echo ""

# ── Copy source → dest (excluding generated/secret dirs) ────────────────────
echo "Copying files..."
rsync -a \
  --exclude='.git/' \
  --exclude='node_modules/' \
  --exclude='vendor/' \
  --exclude='.venv/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='dist/' \
  --exclude='build/' \
  --exclude='target/' \
  --exclude='.next/' \
  --exclude='out/' \
  --exclude='coverage/' \
  --exclude='.nyc_output/' \
  --exclude='*.log' \
  --exclude='.env' \
  "$SOURCE/" "$DEST/"

# ── Substitute content in all text files ────────────────────────────────────
echo "Substituting names in file contents..."
# Order matters: longest/most-specific variants first to avoid partial replacements
find "$DEST" -type f -not -path '*/.git/*' | while read -r f; do
  # Skip binary files
  if file "$f" | grep -qE 'binary|executable|ELF|Mach-O|PE32'; then
    continue
  fi
  sed -i \
    -e "s/${OLD_SCREAMING}/${NEW_SCREAMING}/g" \
    -e "s/${OLD_PASCAL}/${NEW_PASCAL}/g" \
    -e "s/${OLD_CAMEL}/${NEW_CAMEL}/g" \
    -e "s/${OLD_SNAKE}/${NEW_SNAKE}/g" \
    -e "s/${OLD_TITLE}/${NEW_TITLE}/g" \
    -e "s/${OLD_NAME}/${NEW_NAME}/g" \
    "$f" 2>/dev/null || true
done

# ── Rename files and directories containing the old name ────────────────────
echo "Renaming files and directories..."
# Process deepest paths first so parent renames don't break child paths
find "$DEST" -depth -name "*${OLD_NAME}*" -not -path '*/.git/*' | while read -r f; do
  dir=$(dirname "$f")
  base=$(basename "$f")
  newbase="${base//$OLD_NAME/$NEW_NAME}"
  [[ "$base" != "$newbase" ]] && mv "$f" "$dir/$newbase"
done
find "$DEST" -depth -name "*${OLD_SNAKE}*" -not -path '*/.git/*' | while read -r f; do
  dir=$(dirname "$f")
  base=$(basename "$f")
  newbase="${base//$OLD_SNAKE/$NEW_SNAKE}"
  [[ "$base" != "$newbase" ]] && mv "$f" "$dir/$newbase"
done

# ── Initialize fresh git repo ────────────────────────────────────────────────
echo "Initializing git repo..."
cd "$DEST"
git init -q
git add .
git commit -q -m "init: scaffold from ${OLD_NAME}"

echo ""
echo "Done! New repo at: $DEST"
echo ""
echo "Next steps:"
echo "  1. cd $DEST"
echo "  2. Apply your specific tweaks (versions, ports, configs)"
echo "  3. Regenerate lockfiles: npm install / go mod tidy / pip-compile"
echo "  4. Review .env.example — update service-specific vars"
echo "  5. Review CI config — update registry paths and deploy targets"
echo "  6. gh repo create <org>/${NEW_NAME} --private --source=. --push"
