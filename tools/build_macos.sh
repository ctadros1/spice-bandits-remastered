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
"$python_bin" tools/verify_status_assets.py
swift tools/render_mode_text.swift "$task_root" > builds/mode-text-derivation.log 2>&1
tools/build_native.sh > builds/native-build.log 2>&1
"$godot_bin" --headless --editor --path game --quit > builds/editor-import.log 2>&1
if rg -n 'SCRIPT ERROR|^ERROR:' builds/editor-import.log; then
  print 'Godot reported an import or script error. Verification and export were not started.'
  exit 1
fi
"$godot_bin" --headless --path game --script res://scripts/verify.gd -- --qa > builds/verification.log 2>&1
if rg -n 'SCRIPT ERROR|^ERROR:|Leaked instance|ObjectDB instances were leaked' builds/verification.log; then
  print 'Godot reported a simulation verification error. Package was not exported.'
  exit 1
fi
"$godot_bin" --headless --path game --script res://scripts/ui_verify.gd -- --qa > builds/ui-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/menu_ui_verify.gd" -- --qa > builds/menu-ui-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/menu_navigation_ui_verify.gd" -- --qa > builds/menu-navigation-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/portrait_ui_verify.gd" -- --qa > builds/portrait-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/tutorial_arrow_ui_verify.gd" -- --qa > builds/tutorial-arrow-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/tutorial_layout_ui_verify.gd" -- --qa > builds/tutorial-layout-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/hud_wallet_ui_verify.gd" -- --qa > builds/hud-wallet-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/hud_plate_ui_verify.gd" -- --qa > builds/hud-plate-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/build_hex_ui_verify.gd" -- --qa > builds/build-hex-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/bolt_construct_ui_verify.gd" -- --qa > builds/bolt-construct-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/bolt_appearance_ui_verify.gd" -- --qa > builds/bolt-appearance-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/bolt_ribbon_ui_verify.gd" -- --qa > builds/bolt-ribbon-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/bolt_order_ui_verify.gd" -- --qa > builds/bolt-order-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/map_depth_ui_verify.gd" -- --qa > builds/map-depth-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_depth_ui_verify.gd" -- --qa > builds/creep-depth-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/runtime_scripts_ui_verify.gd" -- --qa > builds/runtime-scripts-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/animator_ui_verify.gd" -- --qa > builds/animator-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_animation_ui_verify.gd" -- --qa > builds/creep-animation-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_status_ui_verify.gd" -- --qa > builds/creep-status-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_light_ui_verify.gd" -- --qa > builds/creep-light-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_health_ui_verify.gd" -- --qa > builds/creep-health-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/air_pass_ui_verify.gd" -- --qa > builds/air-pass-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_owner_ui_verify.gd" -- --qa > builds/creep-owner-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_missile_ui_verify.gd" -- --qa > builds/creep-missile-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/magic_depth_ui_verify.gd" -- --qa > builds/magic-depth-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/frame_lookup_ui_verify.gd" -- --qa > builds/frame-lookup-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/portal_lifecycle_ui_verify.gd" -- --qa > builds/portal-lifecycle-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/creep_portal_ui_verify.gd" -- --qa > builds/creep-portal-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/selection_ui_verify.gd" -- --qa > builds/selection-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/bolt_clock_ui_verify.gd" -- --qa > builds/bolt-clock-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/magic_view_ui_verify.gd" -- --qa > builds/magic-view-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/map_animation_ui_verify.gd" -- --qa > builds/map-animation-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/world_blade_ui_verify.gd" -- --qa > builds/world-blade-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/world_cloud_ui_verify.gd" -- --qa > builds/world-cloud-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/xp_ui_verify.gd" -- --qa > builds/xp-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/world_camera_ui_verify.gd" -- --qa > builds/world-camera-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/message_ui_verify.gd" -- --qa > builds/message-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/promotion_ui_verify.gd" -- --qa > builds/promotion-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/upgrade_ui_verify.gd" -- --qa > builds/upgrade-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/main_menu_ui_verify.gd" -- --qa > builds/main-menu-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/menu_bubble_ui_verify.gd" -- --qa > builds/menu-bubble-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/menu_float_ui_verify.gd" -- --qa > builds/menu-float-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/menu_motion_ui_verify.gd" -- --qa > builds/menu-motion-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/input_profile_ui_verify.gd" -- --qa --qa-input-rewards > builds/input-profile-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/transition_ui_verify.gd" -- --qa > builds/transition-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/water_ui_verify.gd" -- --qa > builds/water-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/story_ui_verify.gd" -- --qa > builds/story-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/wave_ui_verify.gd" -- --qa > builds/wave-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/magic_panel_ui_verify.gd" -- --qa > builds/magic-panel-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/tutorial_fade_ui_verify.gd" -- --qa > builds/tutorial-fade-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/mode_item_ui_verify.gd" -- --qa > builds/mode-item-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/mode_effect_ui_verify.gd" -- --qa > builds/mode-effect-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/reward_clock_ui_verify.gd" -- --qa > builds/reward-clock-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/result_lifecycle_ui_verify.gd" -- --qa > builds/result-lifecycle-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/xp_chronology_ui_verify.gd" -- --qa > builds/xp-chronology-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/reward_geometry_ui_verify.gd" -- --qa > builds/reward-geometry-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/reward_spice_ui_verify.gd" -- --qa > builds/reward-spice-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/tower_preview_ui_verify.gd" -- --qa > builds/tower-preview-verification.log 2>&1
"$godot_bin" --headless --path game --script "$task_root/tools/wave_collapse_ui_verify.gd" -- --qa > builds/wave-collapse-verification.log 2>&1
if rg -n 'SCRIPT ERROR|^ERROR:|Leaked instance|ObjectDB instances were leaked' builds/editor-import.log builds/verification.log builds/ui-verification.log builds/menu-ui-verification.log builds/menu-navigation-verification.log builds/portrait-verification.log builds/tutorial-arrow-verification.log builds/tutorial-layout-verification.log builds/hud-wallet-verification.log builds/hud-plate-verification.log builds/build-hex-verification.log builds/bolt-construct-verification.log builds/bolt-appearance-verification.log builds/bolt-clock-verification.log builds/bolt-order-verification.log builds/map-depth-verification.log builds/creep-depth-verification.log builds/air-pass-verification.log builds/selection-verification.log builds/bolt-ribbon-verification.log builds/magic-view-verification.log builds/map-animation-verification.log builds/world-blade-verification.log builds/world-cloud-verification.log builds/xp-verification.log builds/world-camera-verification.log builds/message-verification.log builds/promotion-verification.log builds/upgrade-verification.log builds/main-menu-verification.log builds/menu-bubble-verification.log builds/menu-float-verification.log builds/menu-motion-verification.log builds/input-profile-verification.log builds/transition-verification.log builds/water-verification.log builds/story-verification.log builds/wave-verification.log builds/magic-panel-verification.log builds/tutorial-fade-verification.log builds/mode-item-verification.log builds/mode-effect-verification.log builds/reward-clock-verification.log builds/reward-geometry-verification.log builds/reward-spice-verification.log builds/tower-preview-verification.log builds/wave-collapse-verification.log builds/creep-light-verification.log builds/creep-status-verification.log builds/animator-verification.log builds/creep-animation-verification.log builds/runtime-scripts-verification.log builds/creep-health-verification.log builds/creep-owner-verification.log builds/creep-missile-verification.log builds/magic-depth-verification.log builds/frame-lookup-verification.log builds/portal-lifecycle-verification.log builds/creep-portal-verification.log builds/result-lifecycle-verification.log builds/xp-chronology-verification.log; then
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
