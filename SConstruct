#!/usr/bin/env python
import os
import platform
import subprocess
import sys

from methods import print_error

libname = "gdsnes"
projectdir = "."
api_version = "4.7"

# Apple Silicon: avoid universal linking against an arm64-only snes9x.
if "arch" not in ARGUMENTS and sys.platform == "darwin" and platform.machine() == "arm64":
	ARGUMENTS["arch"] = "arm64"

localEnv = Environment(tools=["default"], PLATFORM="")

customs = ["custom.py"]
customs = [os.path.abspath(path) for path in customs]

opts = Variables(customs, ARGUMENTS)
opts.Update(localEnv)

Help(opts.GenerateHelpText(localEnv))

env = localEnv.Clone()

if not (os.path.isdir("thirdparty/godot-cpp") and os.listdir("thirdparty/godot-cpp")):
    print_error(
        """godot-cpp is not available. Run:
  git submodule update --init --recursive"""
    )
    sys.exit(1)

if not (os.path.isdir("thirdparty/snes9x") and os.listdir("thirdparty/snes9x")):
    print_error(
        """snes9x is not available. Run:
  git submodule update --init --recursive"""
    )
    sys.exit(1)

env = SConscript(
    "thirdparty/godot-cpp/SConstruct",
    {"env": env, "customs": customs, "api_version": api_version},
)

env.Append(CPPPATH=["src/", "thirdparty/snes9x/libretro/"])
sources = Glob("src/*.cpp")


def _snes9x_output(env):
    libretro_dir = "thirdparty/snes9x/libretro"
    if env["platform"] == "web":
        return os.path.join(libretro_dir, "snes9x_libretro_emscripten.bc")
    return os.path.join(libretro_dir, "snes9x_libretro.a")


def build_snes9x(target, source, env):
    libretro_dir = Dir("thirdparty/snes9x/libretro").abspath
    jobs = str(GetOption("num_jobs"))
    cc = str(env.get("CC", "cc"))
    cxx = str(env.get("CXX", "c++"))
    ar = str(env.get("AR", "ar"))

    cmd = ["make", "-C", libretro_dir, f"-j{jobs}", "LTO="]
    if env["platform"] == "web":
        cmd += [
            "platform=emscripten",
            "STATIC_LINKING=0",
            "STATIC_LINKING_LINK=1",
            f"CC={cc}",
            f"CXX={cxx}",
            f"AR={ar}",
        ]
    elif env["platform"] == "macos":
        cmd += [
            "platform=osx",
            "STATIC_LINKING=0",
            "STATIC_LINKING_LINK=1",
            "TARGET=snes9x_libretro.a",
        ]
        if platform.machine() == "arm64":
            cmd.append("arch=arm")
    elif env["platform"] == "windows":
        cmd += [
            "platform=win",
            "STATIC_LINKING=0",
            "STATIC_LINKING_LINK=1",
            "TARGET=snes9x_libretro.a",
        ]
    else:
        cmd += [
            "platform=unix",
            "STATIC_LINKING=0",
            "STATIC_LINKING_LINK=1",
            "TARGET=snes9x_libretro.a",
        ]

    print("Building snes9x_libretro:", " ".join(cmd))
    completed = subprocess.run(cmd)
    if completed.returncode != 0:
        return completed.returncode
    produced = _snes9x_output(env)
    wanted = str(target[0])
    if os.path.abspath(produced) != os.path.abspath(wanted) and os.path.exists(produced):
        env.Execute(Copy(wanted, produced))
    return 0


snes9x_lib = env.Command(
    _snes9x_output(env),
    [
        "thirdparty/snes9x/libretro/Makefile",
        "thirdparty/snes9x/libretro/libretro.cpp",
        "thirdparty/snes9x/libretro/libretro.h",
    ],
    build_snes9x,
)

if env["platform"] == "web":
    sources.append(snes9x_lib)
else:
    env.Append(LIBS=[snes9x_lib])
    env.Append(LIBPATH=["thirdparty/snes9x/libretro"])

if env["target"] in ["editor", "template_debug"]:
    try:
        doc_data = env.GodotCPPDocData("src/gen/doc_data.gen.cpp", source=Glob("doc_classes/*.xml"))
        sources.append(doc_data)
    except AttributeError:
        pass

suffix = env["suffix"].replace(".dev", "").replace(".universal", "")
lib_filename = "{}{}{}{}".format(env.subst("$SHLIBPREFIX"), libname, suffix, env.subst("$SHLIBSUFFIX"))

library = env.SharedLibrary(
    "bin/{}/{}".format(env["platform"], lib_filename),
    source=sources,
)
env.Depends(library, snes9x_lib)
Default(library)
