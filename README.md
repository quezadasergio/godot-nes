# Godot SNES

A Super Nintendo frontend built with **Godot 4.7**. Games run through a **C++ GDExtension** that implements the **Libretro** API and a statically linked **snes9x** core. You can play in the Godot editor (desktop) or ship to the browser (HTML5/WASM), including Netlify.

```
Godot 4.7 (UI / input / audio)
   ↓
GDExtension C++  →  LibretroHost
   ↓
Libretro API
   ↓
snes9x (static)
   ↓
ROM (.sfc / .smc)  →  Texture2D + AudioStreamGenerator
```

## Technologies

| Layer | Technology |
| --- | --- |
| Engine / UI | Godot **4.7**, GDScript |
| Native bridge | **GDExtension** (C++ via [godot-cpp](https://github.com/godotengine/godot-cpp)) |
| Emulation API | [Libretro](https://docs.libretro.com/) |
| SNES core | [snes9x](https://github.com/libretro/snes9x) (statically linked) |
| Build | SCons, Python 3.9+ |
| Desktop | macOS / Linux / Windows shared libraries |
| Web | Emscripten → WASM, Godot Web export (`dlink_enabled`) |
| Hosting | Netlify (`netlify.toml` + COOP/COEP headers) |
| Saves (web) | Godot `user://` → browser IndexedDB |

## Add games

Place files in the project (rescanned on start / when returning to the menu):

| Folder | Contents |
| --- | --- |
| `roms/` | ROMs: `.sfc`, `.smc`, `.fig` (extensionless files also work) |
| `game-images/` | Cover art with the **same basename** as the ROM |

Example: `roms/SuperMarioWorld.sfc` + `game-images/SuperMarioWorld.webp`.

This repo does not ship copyrighted ROMs. Use dumps you own.

## Prerequisites

```bash
git clone --recurse-submodules <repo-url>
cd godot-nes
# or: git submodule update --init --recursive
```

Install:

- **Godot 4.7**
- **Python 3.9+** and **SCons 4.4+** (`pip install scons`)
- A **C++ toolchain** (Xcode CLT on macOS, or GCC/Clang on Linux)

For web builds also install:

- [Emscripten](https://emscripten.org) (version must match your Godot export templates)
- Custom Godot Web templates built with `dlink_enabled=yes` (stock templates **cannot** load GDExtensions)

## Run locally (desktop)

1. Build the GDExtension for your OS:

   ```bash
   ./build.sh macos          # Apple Silicon debug
   # ./build.sh linux
   # ./build.sh macos-release
   ```

2. Put ROMs and covers in `roms/` and `game-images/`.

3. Open the project in **Godot 4.7** and press **F5** (or Play).

   The editor loads `bin/gdsnes.gdextension` → `bin/macos/libgdsnes.*.dylib` (or Linux/Windows equivalents).

If Godot shows that `LibretroHost` is missing, rebuild with `./build.sh` and reload the project.

### Manual build

```bash
scons platform=macos target=template_debug api_version=4.7 arch=arm64 -j8
```

## Run on the web

### 1. Build the WASM GDExtension

```bash
source path/to/emsdk_env.sh   # emcc must be on PATH
./build.sh web
```

Produces something like `bin/web/libgdsnes.web.template_release.wasm32.nothreads.wasm`.

### 2. Custom Godot Web templates (once)

```bash
# From a Godot 4.7 source tree, same Emscripten as above:
scons platform=web dlink_enabled=yes target=template_release threads=no
scons platform=web dlink_enabled=yes target=template_debug threads=no
```

In Godot: **Editor → Export → Manage Export Templates** (or Export preset custom templates) and point to the `*_dlink*` zips.

### 3. Export the project

In Godot: **Project → Export → Web**

- Enable **Extensions Support**
- Export path: `build/web/index.html`

### 4. Play locally in the browser

```bash
bash tools/prepare_netlify.sh   # copies COOP/COEP headers
python3 tools/serve_web.py
```

Open [http://127.0.0.1:8060/](http://127.0.0.1:8060/).  
Use this helper (or any server that sends COOP/COEP); opening `index.html` as a file will fail.

### 5. Deploy to Netlify

```bash
npm install -g netlify-cli
netlify login

./build.sh web
# Export Web in Godot → build/web/index.html
bash tools/prepare_netlify.sh
netlify deploy --prod --dir=build/web
```

`netlify.toml` already sets `publish = "build/web"`, disables JS minification (it breaks Godot), and sends isolation headers.

Do **not** add a catch-all redirect `/* → /index.html` (it breaks `.wasm` / `.pck`).  
Building Godot + Emscripten on Netlify’s CI is not practical: export locally, then deploy `build/web`.

## Controls

| SNES | Keyboard | Gamepad |
| --- | --- | --- |
| D-pad | Arrow keys | D-pad / left stick |
| B / A / Y / X | Z / X / A / S | A / B / X / Y (Xbox layout) |
| L / R | Q / W | LB / RB |
| Start / Select | Enter / Shift | Start / Back |
| In-game menu | Tab, Esc, or Start+Select | — |
| Quick save / load (slot 1) | F5 / F9 | — |

## Features

- Cover menu from `roms/` + `game-images/`
- Video scaled to the window (4:3), touch pad, remappable input
- Save states, battery SRAM, CRT/scanline shaders
- Web saves under `user://` (IndexedDB in the browser)

## License

This repository is MIT. **snes9x** and **godot-cpp** have their own licenses; a binary that statically links snes9x must comply with the snes9x license.
