#!/usr/bin/env python3
"""Run isolated QA and bind its evidence to the exact packaged resources."""
import argparse
import hashlib
import json
import platform
import re
import struct
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
    if directory and (directory / 'manifest.json').exists() and (directory / 'manifest.json').stat().st_mtime_ns >= started_ns:
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
        fresh = fresh and record['captures'] == (235 if args.presentation else 20 if args.tutorial else 4 if args.projectiles else 23 if args.audio else 5 if args.turns else 55 if args.menus else 4 if args.performance else 148)
        if args.presentation:
            # The thirteen R184 captures are required independently of the
            # total count. Their native fields must agree with immutable
            # original inputs; no expected pose is injected into the actor.
            expected=json.loads((ROOT/'game/data/qa-normal-poses.json').read_text())
            normal={c['name']:c for c in manifest['captures'] if c['name'].startswith('creep-normal-')}
            wanted={'creep-normal-'+r['name'] for r in expected['poses']}|{'creep-normal-portal-enter','creep-normal-portal-exit','creep-normal-portal-boundary'}
            exact=set(normal)==wanted and len({c['name'] for c in manifest['captures']})==record['captures']
            decode=lambda words:struct.unpack('<2f',struct.pack('<2I',*map(int,words)))
            encode=lambda xy:list(struct.unpack('<2I',struct.pack('<2f',*xy)))
            for row in expected['poses']:
                actual=normal.get('creep-normal-'+row['name'],{}).get('normal_pose',{})
                exact=exact and actual.get('original_fixture')==row['original_fixture'] and actual.get('original_sha256')==row['original_sha256']
                fields=actual.get('actual',{})
                for key,value in fields.items():
                    if key=='primary' and not row['primary_name_verified']:continue
                    exact=exact and value==row['expected'].get(key)
                exact=exact and len(fields)==14
                pos=decode(row['expected']['position_bits']);offset=decode(row['expected']['offset_bits'])
                exact=exact and actual.get('body_bits')==encode([pos[i]+offset[i] for i in range(2)]) and actual.get('health_bits')==encode([pos[0]-16,pos[1]+16])
                exact=exact and actual.get('native_scale_bits')==actual.get('authored_scale_bits')
                canvas=normal.get('creep-normal-'+row['name'],{}).get('canvas_stretch',[])
                exact=exact and len(canvas)==2 and canvas[0]==canvas[1]
            exit_fields=normal.get('creep-normal-portal-exit',{}).get('normal_pose',{}).get('actual',{})
            boundary=normal.get('creep-normal-portal-boundary',{}).get('normal_pose',{}).get('actual',{})
            exact=exact and exit_fields.get('logical_bits')==boundary.get('logical_bits') and exit_fields.get('next_cell')==boundary.get('cell')
            exact=exact and exit_fields.get('progress_bits')==1065353216 and boundary.get('progress_bits')==0
            record['normal_original_input_pose_fields_and_portal_bridge_exact']=bool(exact)
            record['normal_pose_capture_count']=len(normal)
            fresh=fresh and exact
        if args.performance:
            owned_comparisons=manifest.get('owned_group_comparisons',[])
            record['owned_group_comparisons']=owned_comparisons
            fresh=fresh and len(owned_comparisons)==3 and {c.get('speed') for c in owned_comparisons}=={1,2,4}
            for comparison in owned_comparisons:
                fresh=fresh and comparison.get('exact_rgba') is True and comparison.get('error')==0 and comparison.get('visible_owned_roots',0)>0
                fresh=fresh and comparison.get('coalesced_error')==0 and comparison.get('injected_owned_roots',0)>=2 and comparison.get('injected_visible_change') is True and comparison.get('caller_state_restored') is True
                fresh=fresh and 0<comparison.get('coalesced_groups',0)<comparison.get('unmerged_groups',0)
                paths=[directory/comparison[k] for k in ['unmerged','coalesced']]
                fresh=fresh and all(p.is_file() and p.stat().st_mtime_ns>=started_ns for p in paths)
                if all(p.is_file() for p in paths):
                    hashes=[digest(p) for p in paths]
                    fresh=fresh and hashes[0]==hashes[1]
                    comparison['unmerged_sha256'],comparison['coalesced_sha256']=hashes
            key_comparisons=manifest.get('particle_key_comparisons',[])
            record['particle_key_comparisons']=key_comparisons
            fresh=fresh and len(key_comparisons)==12
            fresh=fresh and {(c.get('speed'),c.get('premultiplied'),c.get('quantized')) for c in key_comparisons}=={(s,p,q) for s in [1,2,4] for p in [False,True] for q in [False,True]}
            fresh=fresh and all(c.get('exact_geometry_bytes') is True and c.get('groups',0)>0 and c.get('systems',0)>0 for c in key_comparisons)
            frame_comparisons=manifest.get('frame_lookup_comparisons',[])
            record['frame_lookup_comparisons']=frame_comparisons
            fresh=fresh and len(frame_comparisons)==3
            for comparison in frame_comparisons:
                usage=comparison.get('usage',{})
                fresh=fresh and comparison.get('exact_rgba',False) and comparison.get('reference_error')==0 and comparison.get('prepared_error')==0
                fresh=fresh and min(usage.get('cached',0),usage.get('reference',0))>0
                for key in ['reference','prepared']:
                    path=directory/comparison[key]
                    fresh=fresh and path.exists() and path.stat().st_mtime_ns>=started_ns
                    if path.exists():comparison[key+'_sha256']=digest(path)
            decal_comparisons=manifest.get('decal_render_comparisons',[])
            record['decal_render_comparisons']=decal_comparisons
            fresh=fresh and len(decal_comparisons)==3
            for comparison in decal_comparisons:
                usage=comparison.get('usage',{})
                fresh=fresh and comparison.get('exact_rgba',False) and comparison.get('reference_error')==0 and comparison.get('prepared_error')==0
                fresh=fresh and min(usage.get('cached_frames',0),usage.get('reference_frames',0))>0
                if comparison.get('decals',0)>0:fresh=fresh and min(usage.get('cached',0),usage.get('reference',0))>=comparison['decals']
                for key in ['reference','prepared']:
                    path=directory/comparison[key]
                    fresh=fresh and path.exists() and path.stat().st_mtime_ns>=started_ns
                    if path.exists():comparison[key+'_sha256']=digest(path)
            comparisons=manifest.get('creep_layer_comparisons',[])
            record['creep_layer_comparisons']=comparisons
            fresh=fresh and len(comparisons)==3
            for comparison in comparisons:
                usage=comparison.get('usage',{})
                fresh=fresh and comparison.get('exact_rgba',False) and comparison.get('legacy_error')==0 and comparison.get('prepared_error')==0
                fresh=fresh and min(usage.get('cached',0),usage.get('reference',0))>=max(1,comparison.get('enemies',0))
                for key in ['legacy','prepared']:
                    path=directory/comparison[key]
                    fresh=fresh and path.exists() and path.stat().st_mtime_ns>=started_ns
                    if path.exists():comparison[key+'_sha256']=digest(path)
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
            animator_expected = {'animator-mine-000': 0, 'animator-mine-025': .25, 'animator-mine-050': .5, 'animator-mine-075': .75, 'animator-mine-100': 1, 'animator-mine-loop': 0, 'animator-portal-stopped': 0, 'animator-portal-025': .25, 'animator-portal-loop': 0, 'animator-nuke-000': 0, 'animator-nuke-025': .25, 'animator-nuke-075': .75}
            required.update(animator_expected)
            animator_poses = {c['name']: c for c in manifest['captures'] if c['name'] in animator_expected}
            for pose, phase in animator_expected.items():
                states = animator_poses.get(pose, {}).get('animators', [])
                relevant = [a for a in states if a['key'] == ('nuke-lights' if 'nuke' in pose else 'portal' if 'portal' in pose else 'lights')]
                fresh = fresh and len(relevant) == (2 if pose in ('animator-portal-025', 'animator-portal-loop') else 1) and all(a['phase'] == phase and a['stopped'] == (pose == 'animator-portal-stopped') for a in relevant)
            creep_sequence = json.loads((ROOT / 'tests/fixtures/native-creep-animation-sequence-reference.json').read_text())
            creep_expected = {'creep-clock-' + row['input']['name']: row['clocks'] for row in creep_sequence['rows']}
            required.update(creep_expected)
            creep_poses = {c['name']: c for c in manifest['captures'] if c['name'] in creep_expected}
            # Compare raw float32 bits from the full original owner/animator
            # sequence, rather than rounded JSON phases or a new tolerance.
            fresh = fresh and all(creep_poses.get(pose, {}).get('creep_clocks') == clocks for pose, clocks in creep_expected.items())
            record['creep_clock_original_sequence_exact'] = all(creep_poses.get(pose, {}).get('creep_clocks') == clocks for pose, clocks in creep_expected.items())
            hover_path=ROOT/'tests/fixtures/native-creep-authored-hover-reference.json'
            hover_fixture=json.loads(hover_path.read_text())
            fresh=fresh and digest(hover_path)=='a04db89611a085fe6f0108e590fef4ab47ede915607a5f3d31d53a22e632153a'
            hover_sequence=next(s for s in hover_fixture['sequences'] if s['resource']=='creeps/creep5' and s['delta']==100)
            hover_frames={'creep-hover-000':-1,'creep-hover-moving':6,'creep-hover-frozen':13,'creep-hover-paused':13,'creep-hover-expiry':14,'creep-hover-resume':15}
            required.update(hover_frames)
            hover_poses={c['name']:c.get('creep_hover',{}) for c in manifest['captures'] if c['name'] in hover_frames}
            def float_bits(v):return struct.unpack('<I',struct.pack('<f',v))[0]
            def from_bits(v):return struct.unpack('<f',struct.pack('<I',v))[0]
            hover_exact=len(hover_poses)==6
            for pose,frame in hover_frames.items():
                actual=hover_poses.get(pose,{})
                original=hover_sequence['frames'][frame]['after'] if frame>=0 else {'phase_bits':hover_sequence['initial_phase_bits'],'offset_y_bits':hover_sequence['initial_offset_bits'][1]}
                offset=[hover_sequence['initial_offset_bits'][0],original['offset_y_bits']]
                raw=actual.get('raw_position',[])
                hover_exact=hover_exact and actual.get('resource')=='creep5' and actual.get('phase_bits')==original['phase_bits'] and actual.get('offset_bits')==offset and len(raw)==2
                if len(raw)==2:
                    hover_exact=hover_exact and actual.get('body_bits')==[float_bits(raw[i]+from_bits(offset[i])) for i in range(2)] and actual.get('health_bits')==[float_bits(raw[0]-16),float_bits(raw[1]+16)]
                frozen=pose in ('creep-hover-frozen','creep-hover-paused','creep-hover-expiry')
                hover_exact=hover_exact and actual.get('multiplier_bits')==(0 if frozen else 1065353216) and actual.get('paused')==(pose=='creep-hover-paused') and actual.get('freeze_attached')==(pose in ('creep-hover-frozen','creep-hover-paused'))
            hover_exact=hover_exact and next((c.get('paused_battle_rgba_exact') for c in manifest['captures'] if c['name']=='creep-hover-paused'),False) is True
            record['creep_hover_original_phase_offset_health_exact']=hover_exact
            fresh=fresh and hover_exact
            burst_frames={'death-burst-0000':0,'death-burst-0150':5,'death-burst-0300':10,'death-burst-0600':20,'death-burst-paused':20,'death-burst-0930':31,'death-burst-1350':45}
            required.update(burst_frames)
            burst_poses={c['name']:c for c in manifest['captures'] if c['name'] in burst_frames}
            burst_fixture=json.loads((ROOT/'tests/fixtures/native-creep-death-tail-reference.json').read_text())
            burst_case=next(c for c in burst_fixture['cases'] if c['resource']=='creeps/creep1' and c['dt_ms']==30)
            burst_rows={r['frame']:r['output']['systems'] for r in burst_case['frames']}
            burst_exact=len(burst_poses)==7
            for pose,frame in burst_frames.items():
                actual=burst_poses.get(pose,{}).get('death_burst',{})
                expected=burst_rows[frame]
                burst_exact=burst_exact and actual.get('clock_bits')==expected[0]['clock_bits']
                burst_exact=burst_exact and actual.get('parents')==[{'name':r['name'],'active':r['active'],'released_bits':0} for r in expected]
                burst_exact=burst_exact and actual.get('paused')==(pose=='death-burst-paused')
                burst_exact=burst_exact and actual.get('global_systems')==8
            fresh=fresh and burst_exact
            record['death_burst_original_parent_counts_clocks_exact']=burst_exact
            removed=next((c for c in manifest['captures'] if c['name']=='death-burst-1380-removed'),{}).get('death_burst',{})
            required.add('death-burst-1380-removed')
            retained=all(burst_poses.get(pose,{}).get('death_burst',{}).get('owner_retained') is True and burst_poses[pose]['death_burst'].get('owner_state')==(2 if pose=='death-burst-1350' else 3) for pose in burst_frames)
            removed_exact=removed.get('owner_retained') is False and removed.get('owner_state')==2 and removed.get('global_systems')==0
            fresh=fresh and retained and removed_exact
            record['retained_death_owner_state_and_next_pass_destruction_exact']=retained and removed_exact
            splash_fixture=json.loads((ROOT/'tests/fixtures/native-creep-splash-mid-reference.json').read_text())
            splash_case=next(c for c in splash_fixture['cases'] if c['resource']=='creeps/creep1')
            splash_exact=True
            for pose,key in [('death-burst-0000','zero_delta'),('death-burst-0150','mid_150ms')]:
                expected=splash_case[key]
                fields=[{**{k:sp[k] for k in ('life_bits','scale_bits','rgba_bits')},'size_bits':draw['size_bits']} for sp,draw in zip(expected['sprites'],expected['draws'])]
                splash_exact=splash_exact and burst_poses.get(pose,{}).get('death_burst',{}).get('splashes')==fields
            fresh=fresh and splash_exact
            record['death_splash_original_mid_flash_fields_exact']=splash_exact
            decal_names = {'background', 'tower-only', 'ground-000', 'ground-tower-cover', 'ground-large', 'ground-density', 'ground-density-next', 'ground-hold', 'ground-fade', 'ground-expired'}
            decal_names = {'decal-' + n for n in decal_names}
            required.update(decal_names)
            decal_poses = {c['name']: c for c in manifest['captures'] if c['name'] in decal_names}
            decal_exact = len(decal_poses) == 10
            if decal_exact:
                fresh_decal = decal_poses['decal-ground-000']['decals'][0]
                hold_decal = decal_poses['decal-ground-hold']['decals'][0]
                fade_decal = decal_poses['decal-ground-fade']['decals'][0]
                decal_exact = fresh_decal['clock_bits'] == 0 and fresh_decal['alpha_bits'] == 1065353216
                decal_exact = decal_exact and hold_decal['clock_bits'] == 1165582336 and hold_decal['alpha_bits'] == 1065353216 and not hold_decal['fading']
                decal_exact = decal_exact and fade_decal['clock_bits'] == 1157316608 and fade_decal['fading']
                decal_exact = decal_exact and decal_poses['decal-ground-large']['decals'][0]['scale_bits'] == 1070386381
                decal_exact = decal_exact and len(decal_poses['decal-ground-density']['decals']) == 5 and sum(d['deleted'] for d in decal_poses['decal-ground-density']['decals']) == 1
                decal_exact = decal_exact and len(decal_poses['decal-ground-density-next']['decals']) == 4 and not decal_poses['decal-ground-expired']['decals']
            fresh = fresh and decal_exact
            record['decal_original_fields_and_manager_bridge_exact'] = decal_exact
            hit_names = {'normal', '000', '060', 'paused', 'expired', 'poison-first', 'poison-suppressed', 'secondary', 'status', 'tower-cover', 'air', 'air-status'}
            hit_names = {'creep-hit-' + n for n in hit_names}
            required.update(hit_names)
            hit_poses = {c['name']: c for c in manifest['captures'] if c['name'] in hit_names}
            hit_exact = len(hit_poses) == 12
            for hit_name, pose in hit_poses.items():
                state = pose.get('hit_fields', [{}])[0]
                active = hit_name not in {'creep-hit-normal', 'creep-hit-expired', 'creep-hit-poison-suppressed'}
                hit_exact = hit_exact and state.get('active') == active and pose.get('ordered_canvas') == active
                if active: hit_exact = hit_exact and pose.get('ordered_spans') == [False, True, False]
                if hit_name in {'creep-hit-060', 'creep-hit-paused'}: hit_exact = hit_exact and state.get('elapsed_bits') == 1114636288
                if hit_name == 'creep-hit-paused': hit_exact = hit_exact and pose.get('paused') is True
                if hit_name in {'creep-hit-air', 'creep-hit-air-status'}: hit_exact = hit_exact and state.get('native_air') is True and state.get('last_kind') == 2
                if hit_name in {'creep-hit-status', 'creep-hit-air-status'}: hit_exact = hit_exact and state.get('freeze_remaining') == 1000
            fresh = fresh and hit_exact
            record['creep_hit_fields_and_ordered_spans_exact'] = hit_exact
            status_expected = {'creep-status-background', 'creep-status-tower-only', 'creep-status-blend-plate', 'creep-status-normal-030', 'creep-status-freeze-030', 'creep-status-freeze-100', 'creep-status-slow-030', 'creep-status-zero-primary', 'creep-status-secondary', 'creep-status-tower-cover'}
            required.update(status_expected)
            status_poses = {c['name']: c for c in manifest['captures'] if c['name'] in status_expected}
            formula = status_poses.get('creep-status-blend-plate', {}).get('screen_formula', {})
            fresh = fresh and formula.get('sampled_rgb_channels') == 192 and formula.get('maximum_formula_byte_error', 999) <= 1.0 and formula.get('later_actor_exact_cover') is True
            overlap = status_poses.get('creep-status-tower-only', {}).get('status_overlap', {})
            fresh = fresh and all(overlap.get(k, 0) >= 10 for k in ('overlapping_pixels', 'covered_pixels'))
            for status_name in status_expected - {'creep-status-background', 'creep-status-tower-only', 'creep-status-blend-plate'}:
                states = status_poses.get(status_name, {}).get('status', [])
                fresh = fresh and len(states) == 1 and states[0]['active'] == (status_name != 'creep-status-normal-030')
                fresh = fresh and states[0]['layers'] == (2 if status_name == 'creep-status-secondary' else 1)
            required.update({'creep-light-ground-030','creep-light-ground-100','creep-light-air-030','creep-light-air-100'})
            light_poses = {c['name']:c.get('creep_lights', []) for c in manifest['captures'] if c['name'].startswith('creep-light-')}
            for pose, value in [('creep-light-ground-030', 0.3),('creep-light-ground-100', 1),('creep-light-air-030', 1),('creep-light-air-100', 1)]:
                entries = light_poses.get(pose, [])
                fresh = fresh and len(entries) == 1 and all(abs(channel-value) < 0.000001 for channel in entries[0]['tint'][:3])
            health_expected = {'creep-health-ground-025': (8, 1), 'creep-health-empty': (0, 1), 'creep-health-full': (None, 0), 'creep-health-lifted-025': (8, 1), 'creep-health-growing-025': (8, .5), 'creep-health-air-050': (16, 1)}
            required.update(health_expected)
            health_poses = {c['name']: c.get('creep_health', []) for c in manifest['captures'] if c['name'].startswith('creep-health-')}
            for pose, (width, alpha) in health_expected.items():
                entries = health_poses.get(pose, [])
                fresh = fresh and len(entries) == 1
                if entries:
                    health = entries[0]
                    fresh = fresh and health['visible'] == (width is not None) and health['alpha'] == alpha
                    if width is not None:
                        fresh = fresh and health['fill_size'] == [width, 16]
            required.update({'air-missile-background','air-missile-body-only','air-missile-projectiles-only','air-missile-under-body'})
            overlap = next((c.get('overlap_probe', {}) for c in manifest['captures'] if c['name'] == 'air-missile-under-body'), {})
            fresh = fresh and all(overlap.get(key, 0) >= 10 for key in ('overlapping_pixels','covered_pixels','visible_pixels'))
            required.update({'air-missile-owner-body','air-missile-owner-cleared'})
            owner_poses = {c['name']: c for c in manifest['captures'] if c['name'].startswith('air-missile-owner-')}
            for pose, body_count, before_count in [('air-missile-owner-body', 2, 0), ('air-missile-owner-cleared', 0, 2)]:
                entry = owner_poses.get(pose, {})
                fresh = fresh and entry.get('owner_body_count') == body_count and entry.get('before_air_count') == before_count
            fresh = fresh and owner_poses.get('air-missile-owner-body', {}).get('owner_overlap_pixels', 0) >= 10
            placement_expected = {'placement-phase-background': 'none', 'placement-phase-preview-only': 'tower', 'placement-phase-air-only': 'none', 'placement-phase-air-preview': 'tower', 'placement-phase-air-preview-grid': 'tower-grid'}
            required.update(placement_expected)
            placement_reference = json.loads((ROOT / 'tests/fixtures/native-placement-pass-reference.json').read_text())
            placement_poses = {c['name']: c for c in manifest['captures'] if c['name'].startswith('placement-phase-')}
            for pose, case_name in placement_expected.items():
                source = next(c for c in placement_reference['cases'] if c['name'] == case_name)
                trace = []
                for call in source['output']['calls']:
                    if call.get('pass') == 'body' and call.get('label') == 0:
                        trace.append('ground-bodies')
                    elif call.get('method') in ('selection', 'preview-hexes', 'grid', 'tower-preview', 'air-manager'):
                        trace.append(call['method'])
                fresh = fresh and placement_poses.get(pose, {}).get('draw_trace') == trace
            preview_overlap = placement_poses.get('placement-phase-air-preview', {}).get('preview_overlap', {})
            fresh = fresh and all(preview_overlap.get(key, 0) >= 10 for key in ('overlapping_pixels', 'covered_pixels'))
            magic_expected = {'magic-depth-background': [], 'magic-depth-tower-only': ['tower'], 'magic-depth-mine-only': ['mine'], 'magic-depth-mine-front': ['tower','mine'], 'magic-depth-mine-back': ['mine','tower'], 'magic-depth-mine-preview': ['tower','mine'], 'magic-depth-portal-preview': ['tower']}
            required.update(magic_expected)
            magic_poses = {c['name']: c for c in manifest['captures'] if c['name'].startswith('magic-depth-')}
            for pose, order in magic_expected.items():
                fresh = fresh and [o['kind'] for o in magic_poses.get(pose, {}).get('body_order', [])] == order
            mine_overlap = magic_poses.get('magic-depth-mine-front', {}).get('mine_overlap', {})
            fresh = fresh and all(mine_overlap.get(key, 0) >= 10 for key in ('overlapping_pixels', 'covered_pixels'))
            portals = magic_poses.get('magic-depth-portal-preview', {}).get('portal_before', [])
            fresh = fresh and len(portals) == 1 and portals[0]['preview']
            lifecycle_expected = {'portal-lifecycle-pending': (1, 0, .3), 'portal-lifecycle-connected-000': (2, 2, .3), 'portal-lifecycle-open-250': (2, 2, .75), 'portal-lifecycle-open-500': (2, 2, 1), 'portal-lifecycle-closing-250': (2, 4, .75), 'portal-lifecycle-closing-750': (2, 4, .25), 'portal-lifecycle-hidden-1000': (2, 3, 0), 'portal-lifecycle-removed': (0, None, None)}
            required.update(lifecycle_expected)
            lifecycle_poses = {c['name']: c for c in manifest['captures'] if c['name'].startswith('portal-lifecycle-')}
            for pose, (count, state, scale) in lifecycle_expected.items():
                entry = lifecycle_poses.get(pose, {})
                fresh = fresh and entry.get('registered_gates') == count
                gates = entry.get('lifecycle', {}).get('gates', [])
                rendered = entry.get('rendered_gates', [])
                if state is not None:
                    fresh = fresh and len(gates) == 2 and all(g['state'] == state and abs(g['scale']-scale) < 1e-6 for g in gates)
                if state == 3 or count == 0:
                    fresh = fresh and not rendered
                else:
                    fresh = fresh and len(rendered) == 2 and all(abs(g['scale']-scale) < 1e-6 for g in rendered)
            required.update({'result-room-%03d' % age for age in [50,72,90,150,240,300,360,420,480,540,600]})
            transit_expected = {'portal-creep-normal': (0, 1, 1, True), 'portal-creep-enter-075': (1, .896484375, .75, True), 'portal-creep-enter-150': (1, .5, .5, False), 'portal-creep-enter-300': (3, 0, 0, False), 'portal-creep-exit-075': (2, .103515625, .25, True), 'portal-creep-exit-150': (2, .5, .5, True), 'portal-creep-exit-300': (0, 1, 1, True)}
            required.update(transit_expected)
            transit_poses = {c['name']:c.get('portal_creep',{}) for c in manifest['captures'] if c['name'].startswith('portal-creep-')}
            for pose, (state, factor, alpha, visible) in transit_expected.items():
                entry = transit_poses.get(pose, {})
                fresh = fresh and entry.get('state') == state and entry.get('alpha') == alpha and entry.get('particles_visible') == visible
                scale,base_scale=entry.get('scale',[]),entry.get('base_scale',[])
                fresh = fresh and len(scale)==2 and len(base_scale)==2 and all(abs(s/b-factor)<1e-6 for s,b in zip(scale,base_scale))
                fresh = fresh and entry.get('systems')==5 and entry.get('particles',0)>0
                fresh = fresh and ((entry.get('hidden_systems')==0 and entry.get('native_groups',0)>0) if visible else (entry.get('hidden_systems')==entry.get('systems') and entry.get('native_groups')==0))
            result_sequence = [c for c in manifest['captures'] if c['name'].startswith('result-room-')]
            fresh = fresh and len(result_sequence) == 11 and all(c.get('initial_delay') == 3 and abs(c.get('result_age', -1) - int(c['name'].rsplit('-',1)[1])/100) < 0.001 for c in result_sequence)
            fresh = fresh and all(c.get('xp_render_count', 0) > 0 and abs(c.get('xp_render_age', -1) - c.get('result_age', -2)) < 0.001 for c in result_sequence)
            required.update({'mine-preview','mine-arming-000','mine-arming-250','mine-armed','portal-preview-entry','portal-preview-exit'})
            required.update({'world-scenery-000','world-scenery-moving'})
            required.update({'world-windmills-000','world-windmills-025'})
            required.update({'world-clouds-000','world-clouds-200','world-clouds-800','world-clouds-wide'})
            required.update({'result-fractional-xp','world-xp-footer'})
            required.add('world-camera-minimum')
            required.update({'desert-modes-completed','mode-pulse-071','hud-wide-wallet','hud-money-flash-red','hud-money-flash-expired'})
            required.update({'result-spice-entering','result-spice-growing'})
            fresh = fresh and required.issubset({c['name'] for c in manifest['captures']})
    elif directory and (directory / 'manifest.json').exists():
        record['captures'] = 0
        record['ignored_stale_manifest'] = True
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
