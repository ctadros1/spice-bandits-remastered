extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failure_count=0
var failures=[]
func _initialize() -> void:
	create_timer(60).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failure_count+=1
		if failures.size()<20:failures.append(label)
func bits(value:float) -> int:return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
func number(value:int) -> float:return PackedInt32Array([value]).to_byte_array().decode_float(0)
func run() -> void:
	var fixture_path="res://../tests/fixtures/native-creep-state-reference.json"
	check(FileAccess.get_sha256(fixture_path)=="e90885520e9cd6c11606f62ce53daa1a9ccfdc2f08eb0381f454ee910984fb37","unchanged independently repeated original fixture")
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(fixture_path));var s=Sim.new()
	for row in fixture.cases:
		var input=row.input
		var actor={"state":int(input.old),"hover_when_idle":int(input.hover348),"hover_while_moving":int(input.hover349),"hover_active":int(input.initial_hover34a),"smoke_idle_multiplier":float(input.smoke_multiplier),"smoke_work_interval":number(int(input.interval_bits)),"particle_roots":[{"creep_alias":"smoke"}] if input.smoke_present else [],"state_sound_flags":input.sound_flags}
		# The actual simulation transition is checked, including same-state calls.
		var calls=[]
		s.set_disco_creep_state(int(input.new),actor,func():calls.append("CSound.Stop-stub"))
		check(calls==row.calls,"original conditional sound Stop request")
		check(int(actor.state)==int(row.after.state),"original state byte")
		check(int(actor.hover_active)==int(row.after.hover34a),"original hover selection")
		check(bits(float(actor.smoke_work_interval))==int(row.after.interval_bits),"original float32 smoke interval")
	# Actual resource flags are initialized by the normal spawn path, rather
	# than inferred from creep class, filename or a copied fixture lookup.
	var content=root.get_node("Content");var config=content.mission("8").duplicate(true);config.waves=[]
	s.setup(content.catalog.duplicate(true),content.maps[config.map],config,root.get_node("Profile").fresh(),114,content.animations);s.spawn_hold=true
	for row in fixture.constructors:
		var resource=str(row.resource).trim_prefix("creeps/");var type=-1
		for i in content.catalog.tower_creeps.size():
			if content.catalog.tower_creeps[i].get("filename","")==resource:type=i;break
		if type<0:
			# creep7 is preserved art but absent from all populated game entries.
			# Supply an explicit definition through a private catalog; this is
			# constructor coverage, not a claim that the campaign uses creep7.
			check(resource=="creep7","only preserved unused creep7 needs a supplied definition")
			var supplied:Dictionary=s.catalog.tower_creeps[1].duplicate(true)
			supplied.filename=resource;type=s.catalog.tower_creeps.size();s.catalog.tower_creeps.append(supplied)
		var actor=s.spawn_enemy(type,0,"",9001,false)
		check(int(actor.get("hover_when_idle",-1))==int(row.hover348),"constructor shouldHoverWhenIdle flag")
		check(int(actor.get("hover_while_moving",-1))==int(row.hover349),"constructor shouldHoverWhileMoving flag")
		check(int(actor.get("hover_active",-1))==int(row.hover34a),"constructor initial hover state")
		s.particle_state.destroy_creep(actor)
	var report={"checks":checks,"failure_count":failure_count,"failures":failures,"original_cases":fixture.cases.size(),"constructor_records":fixture.constructors.size(),"scope":"Actual Disco transition: full original SetState/hover selection and float32 working interval on supplied records; nine populated resources plus explicit unused creep7 through a private catalog/spawn path. Original movement/hover tail, sound backend and constructor smoke interval correction remain separate."}
	var suffix="postport" if "--postport" in OS.get_cmdline_user_args() else "preport"
	var f=FileAccess.open("res://../builds/creep-state-r165-"+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("CREEP_STATE ",JSON.stringify(report));quit(1 if failure_count else 0)
