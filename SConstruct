#!/usr/bin/env python
import os
import platform
import subprocess
import sys

from methods import print_error

libname = "gdsnes"
projectdir = "."
api_version = "4.7"

# Apple Silicon desktop: avoid universal linking against an arm64-only snes9x.
# Do not force arch when targeting web (must be wasm32).
_platform = ARGUMENTS.get("platform", "")
if (
	"arch" not in ARGUMENTS
	and sys.platform == "darwin"
	and platform.machine() == "arm64"
	and _platform not in ("web", "javascript")
):
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
	# Always use a real .a name so linkers treat it as a static library.
	return os.path.join(libretro_dir, "libsnes9x_libretro.a")


def build_snes9x(target, source, env):
	libretro_dir = Dir("thirdparty/snes9x/libretro").abspath
	jobs = str(GetOption("num_jobs"))
	cc = str(env.get("CC", "cc"))
	cxx = str(env.get("CXX", "c++"))
	ar = str(env.get("AR", "ar"))
	wanted = str(target[0])

	cmd = ["make", "-C", libretro_dir, f"-j{jobs}", "LTO=", "TARGET=libsnes9x_libretro.a"]
	if env["platform"] == "web":
		cmd += [
			"platform=emscripten",
			"STATIC_LINKING=0",
			"STATIC_LINKING_LINK=1",
			"fpic=-fPIC",
			f"CC={cc}",
			f"CXX={cxx}",
			f"AR={ar}",
		]
	elif env["platform"] == "macos":
		cmd += [
			"platform=osx",
			"STATIC_LINKING=0",
			"STATIC_LINKING_LINK=1",
		]
		if platform.machine() == "arm64":
			cmd.append("arch=arm")
	elif env["platform"] == "windows":
		cmd += [
			"platform=win",
			"STATIC_LINKING=0",
			"STATIC_LINKING_LINK=1",
		]
	else:
		cmd += [
			"platform=unix",
			"STATIC_LINKING=0",
			"STATIC_LINKING_LINK=1",
		]

	print("Building snes9x_libretro:", " ".join(cmd))
	completed = subprocess.run(cmd)
	if completed.returncode != 0:
		return completed.returncode

	candidates = [
		os.path.join(libretro_dir, "libsnes9x_libretro.a"),
		os.path.join(libretro_dir, "snes9x_libretro.a"),
		os.path.join(libretro_dir, "snes9x_libretro_emscripten.bc"),
	]
	produced = next((path for path in candidates if os.path.exists(path)), None)
	if produced is None:
		print_error("snes9x archive was not produced")
		return 1
	if os.path.abspath(produced) != os.path.abspath(wanted):
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

env.Append(LIBPATH=["thirdparty/snes9x/libretro"])
if env["platform"] == "web":
	# SIDE_MODULE: force every snes9x object into the wasm (do not pass the .a as a "source").
	env.Append(
		LINKFLAGS=[
			"-Wl,--whole-archive",
			"thirdparty/snes9x/libretro/libsnes9x_libretro.a",
			"-Wl,--no-whole-archive",
		]
	)
else:
	env.Append(LIBS=[snes9x_lib])

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
