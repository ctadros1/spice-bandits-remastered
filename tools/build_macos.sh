#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
godot_bin="${SPICE_GODOT:-$task_root/work/toolchain/Godot.app/Contents/MacOS/Godot}"
python_bin="${SPICE_PYTHON:-python3}"
if ! "$python_bin" -c 'import PIL' >/dev/null 2>&1; then
  python_bin="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
fi
[[ -x "$godot_bin" ]] || { print 'Pinned Godot is missing. See docs/BUILD.md.'; exit 1; }
[[ "$("$godot_bin" --version)" == '4.7.2.stable.official.ed1daf0bf' ]] || { print 'Godot version mismatch.'; exit 1; }
mkdir -p builds
"$python_bin" tools/verify_originals.py
"$python_bin" tools/importers/import_original.py
"$godot_bin" --headless --editor --path game --quit > builds/editor-import.log 2>&1
"$godot_bin" --headless --path game --script res://scripts/verify.gd -- --qa > builds/verification.log 2>&1
"$godot_bin" --headless --path game --script res://scripts/ui_verify.gd -- --qa > builds/ui-verification.log 2>&1
if rg -n 'SCRIPT ERROR|^ERROR:|Leaked instance|ObjectDB instances were leaked' builds/editor-import.log builds/verification.log builds/ui-verification.log; then
  print 'Godot reported an error or leaked QA resources. Package was not exported.'
  exit 1
fi
"$godot_bin" --headless --path game --export-release macOS "$task_root/builds/Spice Bandits Remastered.app" > builds/export.log 2>&1
if rg -n 'SCRIPT ERROR|^ERROR:' builds/export.log; then
  print 'Godot reported an export error.'
  exit 1
fi
codesign --verify --deep --strict "$task_root/builds/Spice Bandits Remastered.app"
lipo -info "$task_root/builds/Spice Bandits Remastered.app/Contents/MacOS/Spice Bandits Remastered"
print 'Local package built. Launch and inspect it before treating packaging as verified.'
