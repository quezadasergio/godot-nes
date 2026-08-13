#!/usr/bin/env bash
# Copy Netlify headers into the Godot web export.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/build/web"
HEADERS_SRC="$ROOT/deploy/netlify/_headers"

if [[ ! -f "$DEST/index.html" ]]; then
  echo "Web export not found at build/web/index.html."
  echo "1) ./build.sh web"
  echo "2) In Godot: Project → Export → Web → build/web/index.html"
  echo "3) Deploy again (netlify deploy --prod --dir=build/web)"
  exit 1
fi

cp "$HEADERS_SRC" "$DEST/_headers"
echo "Netlify: copied headers to build/web/_headers"
