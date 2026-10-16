extends SceneTree
const Transit=preload("res://scripts/creep_portal_view.gd")
const Sim=preload("res://scripts/simulation.gd")
const Gates=preload("res://scripts/portal_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	create_timer(30).timeout.connect(func():push_error("Creep portal source unit exceeded its bound.");quit(1))
	run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-creep-portal-reference.json")))
	if not reference is Dictionary or reference.get("cases",[]).size()!=58:
		push_error("Original creep portal fixture is missing or incomplete.");quit(1);return
	var frames=0
	for c in reference.cases:
		var source=c.input
		var base=Vector2(source.base[0],source.base[1])
		var pose=Transit.create(base,source.light)
		pose.clock=Transit.f32(source.clock);pose.state=int(source.state)
		for frame in c.frames:
			Transit.advance(pose,frame.dt,base,source.light,source.particle_base);frames+=1
			var expected=frame.output
			for key in ["clock","health_alpha","anim_alpha","anim_color"]:check(pose[key]==Transit.f32(expected[key]),"original exact "+key+":"+str(frames))
			check(pose.state==expected.state,"original portal phase chronology")
			check(pose.particles_visible==expected.visible,"original owned-particle visibility half-interval")
			check(pose.shadow_scale==Transit.f32(expected.particle_scale),"original shadow scale")
			for key in ["scale","secondary_scale"]:check(pose[key]==Vector2(expected[key][0],expected[key][1]),"original exact vector ease "+key+":"+str(frames))
	var transfer=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-portal-transfer-reference.json")))
	if not transfer is Dictionary or transfer.get("cases",[]).size()!=560:
		push_error("Original transfer fixture is missing or incomplete.");quit(1);return
	for c in transfer.cases:
		var entered=c.output.calls.any(func(call):return call.method=="queue")
		check(Transit.can_enter(c.resource_type,c.creep_state,c.portal_state,true,c.progress,c.kind)==entered,"full original entry eligibility across ground/air/state/phase/boundary")
	var content=root.get_node("Content");var profile=root.get_node("Profile").fresh();profile.abilities.m_portal=5
	var mission=content.mission("8");var sim=Sim.new();sim.setup(content.catalog,content.maps[mission.map],mission,profile,114,content.animations);sim.spawn_hold=true
	var e=sim.spawn_enemy(1,0,"",1141,false)
	if e.path.size()<7:push_error("Portal bridge fixture requires a legal path with seven cells.");quit(1);return
	var entry:Vector2i=e.path[2];var exit_cell:Vector2i=e.path[5]
	check(sim.use_ability("m_portal",sim.center(entry.x,entry.y))=="Choose the portal exit.","real bridge places entrance on a legal route")
	check(sim.use_ability("m_portal",sim.center(exit_cell.x,exit_cell.y)).is_empty(),"real bridge connects legal exit")
	var gate_pair=sim.portals[0].presentation
	e.cell=e.path[1];e.next_cell=entry;e.path_at=2;e.move_start=sim.center(e.cell.x,e.cell.y);e.move_progress=0.49;e.speed=0
	e.pos=e.move_start.lerp(sim.center(entry.x,entry.y),0.49)
	sim.advance_frame(30)
	check(not e.has("portal_pose") and gate_pair.queue.is_empty(),"approaching before half-cell marks but does not start transport")
	e.move_progress=0.5;e.pos=e.move_start.lerp(sim.center(entry.x,entry.y),0.5)
	sim.advance_frame(30)
	check(e.portal_pose.state==1 and e.portal_pose.clock==0 and gate_pair.queue==[e.id],"half-cell entrance begins shrink and queues once after creep update")
	check(sim.events.filter(func(event):return event.kind=="teleport").size()==1,"original entry stage emits transport sound once")
	sim.advance_frame(150)
	check(e.portal_pose.health_alpha==0.5 and e.portal_pose.scale==sim.creep_portal_base(e)*0.5 and not e.portal_pose.particles_visible,"real half-shrink retains body alpha while hiding owned particles")
	sim.advance_frame(150)
	check(e.portal_pose.state==3 and e.portal_pose.anim_alpha==0 and gate_pair.queue==[e.id],"fully shrunk creep waits in entrance queue")
	e.cell=entry;e.next_cell=e.path[3];e.path_at=3;e.move_start=sim.center(entry.x,entry.y);e.pos=e.move_start;e.move_progress=0
	sim.advance_frame(30)
	var exit_point=sim.center(exit_cell.x,exit_cell.y)
	check(e.portal_pose.state==2 and e.portal_pose.clock==0 and e.pos==exit_point and e.visual_pos==exit_point and gate_pair.queue.is_empty(),"crossing the entrance pops queue and collapses anchors at exit")
	check(e.portal_marker==Vector2i(-1,-1),"teleport clears entry marker")
	sim.advance_frame(30)
	check(e.pos==exit_point and not e.portal_boundary and e.move_progress==0,"first post-teleport movement consumes boundary without jumping")
	e.speed=1000;var next_point=sim.center(e.next_cell.x,e.next_cell.y)
	sim.advance_frame(30)
	check(e.pos.distance_to(exit_point)>0 and e.pos.distance_to(exit_point)<next_point.distance_to(exit_point),"following update advances from exit toward next legal point")
	sim.advance_frame(240)
	check(e.portal_pose.state==0 and e.portal_pose.anim_alpha==1 and e.portal_pose.particles_visible,"exit completes original 300ms growth and restores normal phase")
	var closing=Gates.create(1000,30);Gates.connect_gates(closing);closing.queue.append(e.id)
	e.portal_pose.state=1;e.portal_pose.clock=150
	for g in closing.gates:g.close_remaining=30
	Gates.advance(closing,30);sim.check_portal_transfers(closing,entry,exit_cell)
	check(closing.queue.is_empty() and e.portal_pose.state==2 and e.pos==exit_point,"closing entrance flushes queued creep before pair removal")
	var fx=load("res://scripts/particle_fx.gd").new();root.add_child(fx);fx.use_state(sim.particle_state)
	e.slow=0.5;e.portal_pose.particles_visible=false
	sim.particle_state.refresh_creep(sim,e)
	var owned=fx.systems.filter(func(system):return str(system.owner).begins_with("enemy:%d:"%int(e.id)))
	check(not owned.is_empty() and owned.all(func(system):return bool(system.get("owner_hidden",false))),"new actual owner systems inherit portal particle visibility")
	var particle_count=owned.reduce(func(total,system):return total+system.particles.size(),0)
	var hidden_groups=SpiceNative.particle_batches(owned,false,fx.clock_ms,Vector2.ZERO,1)
	var hidden_premultiplied=SpiceNative.particle_batches(owned,true,fx.clock_ms,Vector2.ZERO,1)
	check(hidden_groups.is_empty() and hidden_premultiplied.is_empty() and particle_count>0,"hidden owner particles retain live data and submit no native geometry")
	e.portal_pose.particles_visible=true;sim.particle_state.refresh_creep(sim,e)
	check(owned.all(func(system):return not bool(system.owner_hidden)),"exit unhides existing owner systems")
	check(not SpiceNative.particle_batches(owned,false,fx.clock_ms,Vector2.ZERO,1).is_empty() or not SpiceNative.particle_batches(owned,true,fx.clock_ms,Vector2.ZERO,1).is_empty(),"unhidden owner particles resume native geometry without recreation")
	check(owned.reduce(func(total,system):return total+system.particles.size(),0)==particle_count,"visibility does not clear/recreate particles")
	fx.free()
	var report={"checks":checks,"failures":failures,"original_cases":reference.cases.size(),"original_frames":frames,"transfer_cases":transfer.cases.size(),"limit":"Full original ProcessPortal/InterpolateEaseVectors2D/InterpolateEase on supplied mature-creep fields and full CheckForTransfer entry guards with explicit queue/Teleport stubs. Real reconstructed half-cell queue, 300ms shrink/growth, closing flush, no-jump boundary and owner particle geometry visibility checked separately. Original pathfinding/complete registry, complete owner interleaving and animator/GPU equivalence remain open."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-portal-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_PORTAL_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
