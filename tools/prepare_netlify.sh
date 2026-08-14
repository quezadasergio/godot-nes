#!/usr/bin/env bash
# Prepare the Netlify publish directory (public/).
# Netlify cannot compile Godot/WASM; export locally, then:
#   netlify deploy --prod --dir=public
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBLISH="$ROOT/public"
EXPORT="$ROOT/build/web"
HEADERS_SRC="$ROOT/deploy/netlify/_headers"

mkdir -p "$PUBLISH"

# Prefer a fresh Godot export from build/web when present (local workflow).
if [[ -f "$EXPORT/index.html" ]]; then
  echo "Syncing build/web → public/"
  cp -R "$EXPORT"/. "$PUBLISH"/
fi

if [[ ! -f "$PUBLISH/index.html" ]]; then
  cat <<'EOF'
WARNING: public/index.html is missing.

Export locally, then deploy with the Netlify CLI (do not rely on git push):
  1) ./build.sh web
  2) Godot → Project → Export → Web → public/index.html
  3) bash tools/prepare_netlify.sh
  4) netlify deploy --prod --dir=public
EOF
  exit 1
fi

cp "$HEADERS_SRC" "$PUBLISH/_headers"
echo "Netlify: public/ is ready ($(du -sh "$PUBLISH" | awk '{print $1}'))"
echo "Deploy: netlify deploy --prod --dir=public"
