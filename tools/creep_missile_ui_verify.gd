extends SceneTree
const Owner=preload("res://scripts/creep_owner_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-missile-reference.json")))
	if not reference is Dictionary or not reference.has("boundaries"):
		push_error("Creep missile fixture is missing its completed boundary records; regenerate before verification.")
		quit(1);return
	for c in reference.cases:
		var input=Vector2(c.point[0],c.point[1]);var target=Vector2(c.target[0],c.target[1])
		var origin=SpiceNative.creep_missile_origin(input,target)
		check(origin==Vector2(c.initial.pos[0],c.initial.pos[1]),"original constructor reciprocal-normalized ten-pixel launch")
		var p={"pos":origin,"previous":input,"start":origin,"destination":target,"velocity":Vector2.ZERO,"acceleration":Vector2.ZERO,"body_flag":true}
		for frame in c.frames:
			SpiceNative.creep_missile_tick(p,c.dt,3000)
			for pair in [["pos","pos"],["previous","previous"],["velocity","velocity"],["acceleration","integral"]]:
				for axis in range(2):check(p[pair[0]][axis]==Vector2(frame[pair[1]][axis],0).x,"original exact float32 recurrence"+pair[0])
			check(p.body_flag==frame.body_flag,"original body routing flag chronology")
	for c in reference.boundaries:
		var b=c.before
		var p={"pos":Vector2(b.pos[0],b.pos[1]),"start":Vector2(b.start[0],b.start[1]),"destination":Vector2(c.destination[0],c.destination[1]),"velocity":Vector2.ZERO,"acceleration":Vector2.ZERO,"body_flag":b.body_flag}
		SpiceNative.creep_missile_tick(p,30,3000)
		check(p.body_flag==c.after.body_flag,"original strict thirty-pixel boundary "+str(c.delta))
	var body=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-body-reference.json")))
	for c in body.cases:
		var missiles=[]
		for i in range(c.missile_flags_a0.size()):missiles.append({"owner":10,"type":int(c.resource_type),"label":i,"body_flag":c.missile_flags_a0[i]})
		var passes=Owner.missile_passes([{"id":10}],missiles,[{}, {"class":"ground"},{"class":"air"}])
		var actual=passes.body.get(10,[]).map(func(m):return int(m.label))
		var expected=c.calls.filter(func(call):return call.method=="missile").map(func(call):return int(call.label))
		check(actual==expected,"full original body routes flagged missiles in insertion order, including hidden-body states")
	var content=root.get_node("Content");var sim=load("res://scripts/simulation.gd").new()
	var mission=content.mission("1");sim.setup(content.catalog,content.maps[mission.map],mission,{},114,content.animations);sim.spawn_hold=true
	var enemy=sim.spawn_enemy(2,0,"",1001,false);enemy.base=0;enemy.visual_pos=Vector2(200,250)
	sim.launch_enemy_missiles(enemy)
	check(sim.enemy_missiles.size()==2,"real simulation launches its preserved missile count")
	var expected_origin=SpiceNative.creep_missile_origin(sim.enemy_visual_aim_point(enemy),sim.bases[0].pos)
	check(sim.enemy_missiles.all(func(m):return m.pos==expected_origin and m.start==expected_origin and m.previous==sim.enemy_visual_aim_point(enemy) and m.body_flag),"real spawn bridge retains original drawn anchor/start/flag")
	var phases=Owner.missile_passes(sim.enemies,sim.enemy_missiles,content.catalog.tower_creeps)
	check(phases.body[1001].size()==2 and phases.before_air.is_empty(),"new live-owner missiles move into body pass exactly once")
	sim.enemy_missiles[0].body_flag=false
	phases=Owner.missile_passes(sim.enemies,sim.enemy_missiles,content.catalog.tower_creeps)
	check(phases.body[1001].size()==1 and phases.before_air.size()==1,"one cleared flag moves only that missile before aircraft")
	var report={"checks":checks,"failures":failures,"original_sequences":reference.cases.size(),"original_frames":1000,"boundaries":reference.boundaries.size(),"body_cases":body.cases.size(),"limit":"Constructor/nonimpact float32 motion and live-owner body routing. Original collisions/explosion/owner death/particles/GPU and repeated ground After interleaving remain open. Existing orphan lifetime retained."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-missile-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_MISSILE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
