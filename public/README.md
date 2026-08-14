# Godot Web export for Netlify

Netlify does **not** compile Godot or Emscripten. Build locally, then deploy the folder:

```bash
./build.sh web
# Godot → Project → Export → Web → public/index.html
# (or: Godot --headless --path . --export-release "Web" public/index.html)
bash tools/prepare_netlify.sh
netlify deploy --prod --dir=public
```

Do not commit `index.html` / `.pck` / `.wasm` here (too large for GitHub). Only this README is tracked.
