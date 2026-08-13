#!/usr/bin/env bash
# Prepare the Netlify publish directory (public/).
# Netlify cannot compile Godot/WASM; commit a local Godot Web export into public/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBLISH="$ROOT/public"
EXPORT="$ROOT/build/web"
HEADERS_SRC="$ROOT/deploy/netlify/_headers"

mkdir -p "$PUBLISH"

# Prefer a fresh Godot export from build/web when present (local workflow).
if [[ -f "$EXPORT/index.html" ]]; then
  echo "Syncing build/web → public/"
  # Copy export contents without deleting unrelated files we may keep in public/.
  cp -R "$EXPORT"/. "$PUBLISH"/
fi

if [[ ! -f "$PUBLISH/index.html" ]]; then
  cat <<'EOF'
ERROR: public/index.html is missing.

Netlify only publishes files from this repo. It does not run Godot or Emscripten.

Local steps before push / deploy:
  1) ./build.sh web
  2) Godot → Project → Export → Web → public/index.html
     (or export to build/web/index.html, then run this script)
  3) bash tools/prepare_netlify.sh
  4) git add public/ && git commit && git push

Or deploy from your machine without committing:
  netlify deploy --prod --dir=public
EOF
  exit 1
fi

cp "$HEADERS_SRC" "$PUBLISH/_headers"
echo "Netlify: public/ is ready ($(du -sh "$PUBLISH" | awk '{print $1}'))"
