extends Node

# Captures the app's AudioServer mix, before the master volume. This uses
# the native output backend, no microphone, and never changes system volume.
signal completed(status: int)
var app
var capture: AudioEffectCapture
var checks = 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var directory = ""

func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name); push_error(name)

func stop_voices() -> void:
	for voice in app.voices: voice.stop()

func record(name: String, seconds: float, cue: String = "", refresh: bool = false, action:Callable=Callable()) -> Dictionary:
	await get_tree().create_timer(0.08).timeout
	capture.clear_buffer()
	var samples = PackedVector2Array()
	var start = Time.get_ticks_msec()
	var last = -1000
	if action.is_valid():action.call()
	while Time.get_ticks_msec()-start < int(seconds*1000):
		if not cue.is_empty() and (last < 0 or (refresh and Time.get_ticks_msec()-last >= 90)):
			app.sound(cue)
			last = Time.get_ticks_msec()
		await get_tree().process_frame
		var count = capture.get_frames_available()
		if count > 0: samples.append_array(capture.get_buffer(count))
	var total = 0.0
	var peak = 0.0
	var pcm = PackedByteArray()
	pcm.resize(samples.size()*4)
	for i in range(samples.size()):
		var value = samples[i]
		total += value.x*value.x+value.y*value.y
		peak = maxf(peak, maxf(absf(value.x), absf(value.y)))
		pcm.encode_s16(i*4, int(clampf(value.x, -1, 1)*32767))
		pcm.encode_s16(i*4+2, int(clampf(value.y, -1, 1)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = int(AudioServer.get_mix_rate())
	stream.data = pcm
	var path = name+".wav"
	var error = stream.save_to_wav(directory.path_join(path))
	var row = {"name": name, "path": path, "error": error, "frames": samples.size(), "mix_rate": stream.mix_rate,
		"rms": sqrt(total/maxi(1, samples.size()*2)), "peak": peak,
		"cue": cue, "gain": app.sound_definition(cue).gain if not cue.is_empty() else null,
		"voices": app.voices.filter(func(v): return v.playing).size()}
	rows.append(row)
	check(error == OK and samples.size() >= int(seconds*stream.mix_rate*0.6), "native audio frames for "+name)
	return row

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-audio-root="): directory = arg.trim_prefix("--qa-audio-root=")
	if directory.is_empty(): completed.emit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	var profile = get_node("/root/Profile")
	check(app.test_session and profile.path != "user://profile.json", "audio replay uses an isolated profile")
	profile.data = profile.fresh()
	profile.data.settings.music = false
	profile.data.settings.sound = false
	app.music.stop()
	stop_voices()
	app.navigate("menu")
	# Master volume is applied after effects. We inspect the mixed signal
	# without playing the entire diagnostic cue sequence through speakers.
	var previous_master = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, -80)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	var silent = await record("muted-menu", 0.35)
	check(silent.rms < 0.000001, "music and effects muted yield silence")
	profile.data.settings.music = true
	app.play_music()
	var menu = await record("menu-music", 1.2)
	check(menu.rms > 0.0001 and app.music.playing, "preserved music reaches the native mixer")
	check(is_equal_approx(db_to_linear(app.music.volume_db), 0.2), "native music gain0.2")
	var track = app.music.stream
	var position = app.music.get_playback_position()
	app.start_mission("8", true, false)
	app.sim.paused = true
	var battle = await record("battle-music", 0.65)
	check(battle.rms > 0.0001 and app.music.stream == track and app.music.get_playback_position() > position, "music continues across menu and battle")
	profile.data.settings.music = false
	app.play_music()
	var mute = await record("muted-music", 0.35)
	check(mute.rms < 0.000001 and not app.music.playing, "music setting stops the mix")
	profile.data.settings.sound = true
	for cue in ["tower_place", "missile_explosion", "freeze_activation-mono", "nuke_1", "active_defense_on-mono", "level_won"]:
		stop_voices()
		var effect = await record("game-"+cue, 0.4, cue)
		check(effect.rms > 0.00001, "preserved effect reaches mixer: "+cue)
	stop_voices()
	var loop = await record("machine-gun-loop", 0.75, "machine_gun_1", true)
	check(loop.rms > 0.00001 and loop.voices == 1, "machine gun loop is renewed and honors max_play1")
	var stopped = await record("machine-gun-expired", 0.4)
	# The first180ms can contain the final renewed tail; verify the actual
	# voice has stopped rather than treating the whole tail as silence.
	check(stopped.voices == 0, "loop stops after shooting ceases")
	stop_voices()
	# Forced result amount verifies the original loop's actual lifecycle;
	# these8XP are a mixer fixture and are never awarded/saved as play.
	profile.data.xp=8;app.battle_initial_xp=0;app.sim.outcome="victory"
	app.pose_result(2.2);app.result_previous_xp=app.ClassicUI.result_xp(app)
	var xp_grow=await record("result-xp-grow",0.4)
	var xp_voices=app.voices.filter(func(v):return v.playing and v.get_meta("cue","")=="xp_bar_grow")
	check(xp_grow.rms>0.00001 and xp_voices.size()==1 and is_equal_approx(float(xp_voices[0].get_meta("definition").gain),0.1),"growing XP uses one preserved loop at native gain0.1")
	app.pose_result(4.1)
	var xp_stop=await record("result-xp-stopped",0.4)
	check(xp_stop.rms<0.000001 and not app.voices.any(func(v):return v.playing and v.get_meta("cue","")=="xp_bar_grow"),"XP loop stops as soon as the meter stops growing")
	stop_voices();app.reset_reward_bursts();app.pose_result(5.55)
	var spice_boom=await record("result-spice-boom",0.4)
	var boom=app.voices.filter(func(v):return v.get_meta("cue","")=="obj_boom")
	check(spice_boom.rms>0.00001 and app.reward_spice_burst and boom.any(func(v):return v.get_meta("definition").gain==1 and v.get_meta("definition").layer==4),"spice reveal plays preserved obj_boom at native gain1/layer4")
	stop_voices();app.battle_medals=[app.get_node("/root/Content").catalog.tower_medals[0]];app.pose_result(8.1)
	var medal_boom=await record("result-medal-boom",0.4)
	check(medal_boom.rms>0.00001 and app.reward_medal_bursts.size()==1,"medal reveal plays its once-only object burst sound")
	app.battle_medals.clear();app.reset_reward_bursts()
	profile.data.xp=0;app.sim.outcome="playing";app.result_started=-1;app.reward_fx.reset()
	app.play_ambient()
	var ambient = await record("desert-ambient", 0.65)
	check(ambient.rms > 0.00001 and app.ambient.playing and app.ambient.stream.resource_path.ends_with("TD_ambience_sand-loop-mono-vbr.mp3"), "Desert Freighter uses the preserved sand ambience")
	check(is_equal_approx(db_to_linear(app.ambient.volume_db), 0.2), "native environment loop gain0.2")
	app.navigate("menu")
	stop_voices()
	var quiet = await record("ambient-exit", 0.35)
	check(quiet.rms < 0.000001 and not app.ambient.playing, "leaving a battle stops the environment loop")
	var click = await record("lobby-click", 0.4, "UI_click")
	check(click.rms > 0.00001 and is_equal_approx(click.gain, 0.5), "lobby click uses its separate max_volume2 bank")
	stop_voices()
	app.navigate("world");stop_voices()
	var input=preload("res://scripts/tutorial_verify.gd").new();input.app=app;input.root=get_tree().root
	var tab=await record("lobby-tab-change",0.4,"",false,func():input.press("Career"))
	var tab_voices=app.voices.filter(func(v):return v.get_meta("cue","")=="UI_tab_select_and_move-mono")
	check(tab.rms>0.00001 and app.screen=="career" and tab_voices.any(func(v):return v.get_meta("definition").layer==4 and is_equal_approx(v.get_meta("definition").gain,0.25)),"actual Career tab uses preserved tab sound at gain0.25/layer4")
	stop_voices()
	var same_tab=await record("lobby-tab-unchanged",0.4,"",false,func():input.press("Career"))
	check(same_tab.rms<0.000001,"reselecting the current tab does not add a generic click or reload sound")
	stop_voices();app.offer_guidance(24,true);app.refresh_controls();app.portrait_view.advance(0.5)
	var portrait=await record("portrait-dismiss",0.4,"",false,func():input.press("Dismiss guidance"))
	check(portrait.rms<0.000001 and app.guidance_type==0,"the native-style tutorial view adds no generic button sound on dismissal")
	input.free()
	app.sound("menu_hum_and_buzz_loop")
	profile.data.settings.sound = false
	var muted_effects = await record("muted-effects", 0.35)
	check(muted_effects.rms < 0.000001 and muted_effects.voices == 0, "sound setting stops active effects")
	check(capture.get_discarded_frames() == 0, "audio capture did not overflow")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	AudioServer.set_bus_volume_db(0, previous_master)
	var file = FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "Native AudioServer stereo PCM before the muted app master volume; no microphone or hardware listening claim.",
		"captures": rows, "verification": {"checks": checks, "failures": failures}, "display_server": DisplayServer.get_name()}, "\t"))
	file.close()
	print("AUDIO_VERIFICATION ", JSON.stringify({"checks": checks, "failures": failures, "stages": rows.size()}))
	completed.emit(0 if failures.is_empty() else 1)
