#!/usr/bin/env python3
"""Run isolated QA and bind its evidence to the exact packaged resources."""
import argparse
import hashlib
import json
import platform
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'builds'
APP = BUILD / 'Spice Bandits Remastered.app'
EXE = APP / 'Contents/MacOS/Spice Bandits Remastered'
PACK = APP / 'Contents/Resources/Spice Bandits Remastered.pck'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def native_libraries():
    return {str(path.relative_to(APP)): digest(path) for path in sorted((APP / 'Contents/Frameworks').glob('*.dylib'))}


def app_processes():
    """Record running game instances without launching or controlling them."""
    result = subprocess.run(['ps', '-axo', 'pid=,ppid=,args='], capture_output=True, text=True, check=True)
    rows = []
    for line in result.stdout.splitlines():
        fields = line.strip().split(None, 2)
        if len(fields) != 3:
            continue
        command = fields[2]
        if re.match(r'^(?:/|work/toolchain/)[^\n]*\.app/Contents/MacOS/(?:Spice Bandits Remastered|Godot)(?: |$)', command):
            rows.append({'pid': int(fields[0]), 'parent_pid': int(fields[1]), 'command': command})
    return rows


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--tutorial', action='store_true')
    mode.add_argument('--campaign', action='store_true')
    mode.add_argument('--towers', action='store_true')
    mode.add_argument('--desert', action='store_true')
    mode.add_argument('--projectiles', action='store_true')
    mode.add_argument('--audio', action='store_true')
    mode.add_argument('--turns', action='store_true')
    mode.add_argument('--menus', action='store_true')
    mode.add_argument('--performance', action='store_true')
    mode.add_argument('--presentation', action='store_true')
    mode.add_argument('--screen', choices=['menu', 'world', 'shop', 'spicery', 'upgrades', 'career', 'medals', 'dress', 'settings', 'credits'])
    args = parser.parse_args()
    name = 'presentation' if args.presentation else 'tutorial' if args.tutorial else 'campaign' if args.campaign else 'towers' if args.towers else 'desert' if args.desert else 'projectiles' if args.projectiles else 'audio' if args.audio else 'turns' if args.turns else 'menus' if args.menus else 'performance' if args.performance else 'screen-' + args.screen
    started_ns = time.time_ns()
    record = {'started_utc': datetime.now(timezone.utc).isoformat(), 'host': platform.platform(),
              'host_architecture': platform.machine(), 'pck_sha256': digest(PACK),
              'executable_sha256': digest(EXE), 'native_libraries_sha256': native_libraries(), 'qa_profile_isolated': True}
    normal = Path.home() / 'Library/Application Support/Godot/app_userdata/Spice Bandits Remastered/profile.json'
    protected = [normal, normal.with_name('profile.json.bak')]
    profile_before = {str(p): digest(p) if p.exists() else None for p in protected}
    snapshots = BUILD / 'qa-save-snapshots' / (name + '-' + str(started_ns))
    snapshots.mkdir(parents=True, exist_ok=True)
    for path in protected:
        if path.exists(): (snapshots / path.name).write_bytes(path.read_bytes())
    record['normal_profile_before'] = profile_before
    record['save_snapshots'] = str(snapshots.relative_to(ROOT))
    record['process_observations'] = []
    prior = app_processes()
    if prior:
        record.update(preflight_blocked=True, process_observations=prior, passed=False,
                      errors=['Another game/engine instance is running; QA was not launched.'])
        (BUILD / (name + '-package-audit.json')).write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record), flush=True)
        raise SystemExit(1)
    if args.presentation:
        directory = BUILD / 'presentation-gallery'
        options = ['--qa-presentation', '--capture-root=' + str(directory)]
        record['fixture'] = 'Native viewport drag events, rejected/canceled drops, original tray geometry, loading stages, forced XP/result stages, mode fan and electric ribbons; no earned rewards or original whole-game equivalence.'
    elif args.tutorial:
        directory = BUILD / 'tutorial-gallery'
        options = ['--qa-run-tutorial', '--qa-tutorial-capture-root=' + str(directory)]
    elif args.campaign:
        directory = BUILD / 'campaign-gallery'
        options = ['--qa-render-all', '--capture-root=' + str(directory)]
    elif args.projectiles:
        directory = BUILD / 'projectile-gallery'
        options = ['--qa-projectile-gallery', '--capture-root=' + str(directory)]
        record['fixture'] = 'Four source projectile/effect stages with synthetic tower technology and stationary targets; renderer coverage, not campaign parity.'
    elif args.audio:
        directory = BUILD / 'audio-gallery'
        options = ['--qa-audio', '--qa-audio-root=' + str(directory)]
        record['fixture'] = 'Native app mixer PCM, effects/music/loop/mute and forced8XP growth/stop/spice/medal sound checks before the muted app master; no earned XP, microphone or original-device mix parity.'
    elif args.turns:
        directory = BUILD / 'turn-gallery'
        options = ['--qa-turn-gallery', '--capture-root=' + str(directory)]
        record['fixture'] = 'Five synthetic aircraft/tank corner poses, projected positions and blended original animation frames; not an original-device capture.'
    elif args.performance:
        directory = BUILD / 'performance-gallery'
        options = ['--qa-performance', '--qa-performance-root=' + str(directory)]
        record['fixture'] = 'Synthetic native dense renderer,54 tower forms/200 initial enemies and inflated base health;1x/2x/4x real-time frame sampling, no earned campaign results.'
    elif args.menus:
        directory = BUILD / 'menu-gallery'
        options = ['--qa-menus', '--qa-menu-capture-root=' + str(directory)]
        record['fixture'] = 'Native menu actions, synthetic purchasing funds and forced outcome presentations; no campaign victory or original-device parity.'
    else:
        directory = None
        options = (['--qa-tower-fixture'] if args.towers else ['--mission=8', '--qa-demo'] if args.desert else ['--qa-fresh-profile', '--screen=' + args.screen]) + ['--capture=' + str(BUILD / (name + '.png')), '--smoke-quit']
        if args.towers: record['fixture'] = '54 original tower forms, synthetic placements and technology; presentation audit, not a legal campaign result.'
        if args.desert: record['fixture'] = 'Desert Freighter, legal200 battle budget and pre-owned T1L3 technology; short renderer check, not a fresh-profile unlock result.'
    record['arguments'] = ['--qa'] + options
    # Retina image readback and PNG encoding for148 frames exceed the short
    # single-scenario bound on this host; keep a bounded corpus-specific limit.
    timeout = 900 if args.campaign else 300
    record['timeout_seconds'] = timeout
    log = BUILD / (name + '-packaged.log')
    with log.open('w') as stream:
        process = subprocess.Popen([str(EXE), '--'] + record['arguments'], cwd=ROOT,
                                   stdout=stream, stderr=subprocess.STDOUT)
        record['qa_process_id'] = process.pid
        observed = set()
        deadline = time.monotonic() + timeout
        while process.poll() is None:
            for row in app_processes():
                identity = (row['pid'], row['command'])
                if identity not in observed:
                    observed.add(identity)
                    row['observed_utc'] = datetime.now(timezone.utc).isoformat()
                    record['process_observations'].append(row)
            if time.monotonic() >= deadline:
                record['timeout'] = True
                process.kill()
                process.wait()
                break
            time.sleep(1)
        record['exit_code'] = process.returncode
    record['resources_unchanged_during_run'] = digest(PACK) == record['pck_sha256'] and digest(EXE) == record['executable_sha256'] and native_libraries() == record['native_libraries_sha256']
    record['normal_profile_after'] = {str(p): digest(p) if p.exists() else None for p in protected}
    record['normal_profile_unchanged'] = profile_before == record['normal_profile_after']
    for path in protected:
        if path.exists(): (snapshots / ('after-' + path.name)).write_bytes(path.read_bytes())
    record['other_game_processes'] = [row for row in record['process_observations'] if row['pid'] != process.pid]
    record['errors'] = re.findall(r'^.*(?:SCRIPT ERROR|^ERROR:|ObjectDB instances were leaked|Leaked instance).*$', log.read_text(), re.M)
    contexts = re.findall(r'^QA_CONTEXT (\{.*\})$', log.read_text(), re.M)
    record['runtime_qa_contexts'] = [json.loads(c) for c in contexts]
    record['runtime_isolation_verified'] = bool(contexts) and all(c['test_session'] and c['verification_context'] and c['profile_path'] != 'user://profile.json' for c in record['runtime_qa_contexts'])
    record['signature_verified'] = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(APP)], capture_output=True).returncode == 0
    fresh = False
    if directory and (directory / 'manifest.json').exists():
        manifest_path = directory / 'manifest.json'
        fresh = manifest_path.stat().st_mtime_ns >= started_ns
        manifest = json.loads(manifest_path.read_text())
        record['captures'] = len(manifest['captures'])
        record['capture_errors'] = [c for c in manifest['captures'] if c['error'] != 0]
        record['fixture_failures'] = manifest.get('failures', [])
        fresh = fresh and all((directory / c['path']).stat().st_mtime_ns >= started_ns for c in manifest['captures'])
        if fresh:
            for capture in manifest['captures']:
                capture['sha256'] = digest(directory / capture['path'])
            manifest['pck_sha256'] = record['pck_sha256']
            if not args.audio and not args.performance:
                manifest['method'] = 'Packaged app OpenGL frames with QA engine actions; not an OS input recording or original-device parity.'
            manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
        if 'verification' in manifest: record['verification'] = manifest['verification']
        elif 'checks' in manifest: record['verification'] = {'checks': manifest['checks'], 'failures': manifest.get('failures', [])}
        fresh = fresh and record['captures'] == (98 if args.presentation else 20 if args.tutorial else 4 if args.projectiles else 23 if args.audio else 5 if args.turns else 55 if args.menus else 4 if args.performance else 148)
        if args.menus:
            posed=[c for c in manifest['captures'] if c['name'].startswith('main-menu-')]
            record['main_menu_distinct_pose_images']=len({c['sha256'] for c in posed})
            fresh=fresh and len(posed)==11 and record['main_menu_distinct_pose_images']>=10
            promotion = {c['name']: c for c in manifest['captures'] if c['name'].startswith('level-up')}
            expected = {'level-up-opening-175': .25, 'level-up-opening-350': .5,
                        'level-up-settled': 1, 'level-up-closing-175': .75, 'level-up-closing-350': .5}
            fresh = fresh and all(key in promotion and promotion[key].get('promotion_state', {}).get('alpha') == alpha and promotion[key].get('pending_promotions') == 1 for key, alpha in expected.items())
            fresh = fresh and any(c['name'] == 'world-observed-level2' and c.get('profile_pose', {}).get('xp') == 31 for c in manifest['captures'])
        if args.presentation:
            required = {'water-training-000','water-training-200','water-814-000','water-814-200','drag-preview','drag-preview-045','drag-placed','tutorial-tray','tutorial-fade-020','active-defense','desert-modes','mode-opening-015','mode-text-035','mode-closing-015','desert-story','desert-story-050','desert-story-125','result-400','result-spice-555','result-medal-growing','result-medal-first','wave-early-015','wave-early-045','wave-scroll-050','wave-launch-000','wave-launch-050','magic-opening-025','magic-inventory','magic-refilled','magic-closing-025'}
            required.update({'electricity','electricity-fading','electricity-gateway','electricity-gateway-reenter','electricity-drawn-aim','electricity-tower10_2','electricity-tower10_3','electricity-tower12_2','electricity-tower12_3'})
            required.update({'electricity-overlap','electricity-overlap-reversed','electricity-window-wide','electricity-window-tall','electricity-window-restored'})
            required.update({'tower-depth-overlap','tower-depth-reversed-input'})
            required.update({'base-depth-overlap','base-depth-reversed-input','base-depth-damaged'})
            required.update({'air-depth-overlap','air-depth-reversed-input','air-depth-lifted-ground'})
            required.update({'selection-range-ground','selection-range-fading'})
            required.update({'creep-depth-overlap','creep-depth-reversed-input'})
            required.update({'mine-preview','mine-arming-000','mine-arming-250','mine-armed','portal-preview-entry','portal-preview-exit'})
            required.update({'world-scenery-000','world-scenery-moving'})
            required.update({'world-windmills-000','world-windmills-025'})
            required.update({'world-clouds-000','world-clouds-200','world-clouds-800','world-clouds-wide'})
            required.update({'result-fractional-xp','world-xp-footer'})
            required.add('world-camera-minimum')
            required.update({'desert-modes-completed','mode-pulse-071','hud-wide-wallet','hud-money-flash-red','hud-money-flash-expired'})
            required.update({'result-spice-entering','result-spice-growing'})
            fresh = fresh and required.issubset({c['name'] for c in manifest['captures']})
    elif not directory:
        capture = BUILD / (name + '.png')
        fresh = capture.exists() and capture.stat().st_mtime_ns >= started_ns
        if fresh: record['capture_sha256'] = digest(capture)
    record['fresh_complete_capture_set'] = fresh
    valid = (record['exit_code'] == 0 and not record['other_game_processes'] and record['resources_unchanged_during_run'] and record['normal_profile_unchanged'] and record['runtime_isolation_verified']
             and not record['errors'] and not record.get('capture_errors', []) and record['signature_verified']
             and fresh and not record.get('verification', {}).get('failures', []) and not record.get('fixture_failures', []))
    record['passed'] = valid
    (BUILD / (name + '-package-audit.json')).write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record), flush=True)
    raise SystemExit(0 if valid else 1)


if __name__ == '__main__':
    main()
