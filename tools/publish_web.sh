#!/usr/bin/env bash
# Builds the web version of the game and publishes it to the gh-pages branch (GitHub Pages).
# Usage:  GODOT="path/to/godot_console.exe" bash tools/publish_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
REMOTE="$(git remote get-url origin)"
NAME="$(git config user.name || echo geo-duel)"
EMAIL="$(git config user.email || echo geo-duel@users.noreply.github.com)"

rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
touch build/web/.nojekyll  # serve files as-is

cd build/web
git init -q -b gh-pages
git add -A
git -c user.name="$NAME" -c user.email="$EMAIL" commit -q -m "Publish web build"
git push -f "$REMOTE" gh-pages
rm -rf .git
echo "Published to the gh-pages branch."
