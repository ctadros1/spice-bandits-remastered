#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
bindings="$task_root/work/toolchain/godot-cpp"
python_env="$task_root/work/toolchain/cpp-build-python"
bindings_commit=b8530af7546a3fcae80cef2477526569fd42ffc2
if [[ ! -d "$bindings/.git" ]]; then
  git clone https://github.com/godotengine/godot-cpp.git "$bindings"
  git -C "$bindings" checkout --detach "$bindings_commit"
fi
[[ "$(git -C "$bindings" rev-parse HEAD)" == "$bindings_commit" ]] || { print 'Godot C++ bindings do not match the pinned commit.'; exit 1; }
if [[ ! -x "$python_env/bin/scons" ]]; then
  python3 -m venv "$python_env"
  "$python_env/bin/pip" install scons==4.10.1
fi
[[ "$("$python_env/bin/python3" -c 'import SCons; print(SCons.__version__)')" == '4.10.1' ]] || { print 'SCons version mismatch.'; exit 1; }
mkdir -p game/native/bin
"$python_env/bin/scons" -C native platform=macos arch=universal target=template_release build_profile="$task_root/native/build-profile.json" -j8
lipo game/native/bin/libspice_hotpaths.dylib -verify_arch x86_64 arm64
