extends SceneTree
const Disco=preload("res://scripts/creep_disco_view.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func _initialize() -> void:
	create_timer(45).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<40:failures.append(label)
func run() -> void:
	var content=root.get_node("Content")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-creep-lsd-timer-reference.json"))
	for c in fixture.timer_cases:
		var states=[];var stop_count=0;var active=false
		for count in c.input.counts:
			active=active or int(count)>0
			var state=Disco.initial();state.remaining=int(count);Disco.advance_timer(state,float(c.input.delta));states.append(state)
			if state.stop_sound:stop_count+=1
		for i in states.size():check(int(states[i].remaining)==int(c.counts[i]),"original independent player timer")
		check(stop_count==c.calls.filter(func(x):return x.call=="StopLsdSound-stub").size(),"original stop requests per player")
		check((not active and not states.is_empty())==not c.calls.filter(func(x):return x.call=="SetCanUseLsd-full").is_empty(),"original delayed manager reset")
	for c in fixture.cases:
		var state=Disco.initial();state.remaining=int(c.activation.counts[0])
		if int(c.input.initial_counter)<=0:
			check(Disco.duration(int(c.input.base_duration),int(c.input.levels.up_pharm),int(c.input.levels.up_wizard))==int(c.activation.counts[0]),"original pharmaceutical then Wizard float32 order")
		for frame in c.frames:
			Disco.advance_timer(state,float(frame.supplied_delta))
			check(int(state.remaining)==int(frame.counts[0]),"original joined countdown")
			check(state.stop_sound==not frame.player_calls.filter(func(x):return x.call=="StopLsdSound-stub").is_empty(),"original joined sound stop request")
			check(state.reset_admission==not frame.player_calls.filter(func(x):return x.call=="SetCanUseLsd-full").is_empty(),"original joined delayed reset")

	for c in fixture.cases:
		var a=c.input
		if int(a.actor.state)!=0 or int(a.initial_counter)!=0:continue
		var s=Sim.new();var config=content.mission("8").duplicate(true);config.waves=[]
		s.setup(content.catalog.duplicate(true),content.maps[config.map],config,root.get_node("Profile").fresh(),114,content.animations)
		s.spawn_hold=true;s.clock_ms=1000;s.abilities.m_lsd=1
		s.catalog.tower_magic.lsd_duration=int(a.base_duration);s.upgrades=a.levels.duplicate(true)
		var e=s.spawn_enemy(1,0,"",9001,false)
		check(s.use_ability("m_lsd").is_empty(),"actual activation "+str(a))
		check(maxi(0,s.disco_until-s.clock_ms)==int(c.activation.counts[0]),"actual original duration "+str(a))
		for frame in c.frames:
			# Suppress unrelated combat/wave/outcome changes while advancing the
			# actual room/player/creep phases and the original supplied deltas.
			e.hp=e.max_hp;s.outcome="playing";s.next_wave_ms=s.clock_ms+100000
			s.advance_frame(float(frame.supplied_delta))
			check(maxi(0,s.disco_until-s.clock_ms)==int(frame.counts[0]),"actual countdown "+str(a)+" dt"+str(frame.supplied_delta))
			if int(frame.counts[0])<=0:check(int(e.disco_until)==0,"actual expiry detaches actor")
		var prior=s.disco_until;s.paused=true;s.advance_frame(30)
		check(s.disco_until==prior,"pause retains shared counter")
	var report={"checks":checks,"failures":failures,"fixture_cases":fixture.cases.size(),"scope":"Actual simulation activation/duration/player-countdown/expiry on supplied source deltas. Full actor admission/state/pathfinder/room/GPU remain separate."}
	var f=FileAccess.open("res://../builds/creep-disco-timer-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("CREEP_DISCO_TIMER ",JSON.stringify({"checks":checks,"failures":failures.slice(0,8),"failure_count":failures.size()}));quit(1 if not failures.is_empty() else 0)
