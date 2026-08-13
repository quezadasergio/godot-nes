# Godot Web export for Netlify

Export the project here so GitHub → Netlify can publish it.

```text
Godot → Project → Export → Web → public/index.html
```

Or export to `build/web/` and run `bash tools/prepare_netlify.sh` (copies into this folder).

Commit the resulting files (`index.html`, `.wasm`, `.pck`, `bin/web/`, etc.) and push.
Netlify cannot build Godot or Emscripten in CI.
