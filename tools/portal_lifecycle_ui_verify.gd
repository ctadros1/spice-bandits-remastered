extends SceneTree
const Portal=preload("res://scripts/portal_view.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func same(actual:Dictionary,expected:Dictionary,label:String) -> void:
	for key in ["remaining","connected","deleted","permanent","transfer_checks"]:
		check(actual[key]==(Portal.f32(expected[key]) if key=="remaining" else expected[key]),label+":"+key)
	for index in range(2):
		for key in ["state","active","scale","opening","open_remaining","close_remaining"]:
			var value=expected.gates[index][key]
			if key in ["scale","open_remaining","close_remaining"]:value=Portal.f32(value)
			check(actual.gates[index][key]==value,label+":"+str(index)+":"+key)
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-portal-lifecycle-reference.json")))
	if not reference is Dictionary or reference.get("cases",[]).size()!=17:
		push_error("Original portal lifecycle fixture is missing or incomplete.");quit(1);return
	var frames=0
	for c in reference.cases:
		var settings=c.config
		var duration=Portal.f32(float(settings.duration)*float(settings.get("upgrade",1)))
		var pair=Portal.create(settings.reload,duration)
		same(pair,c.initial,"full original constructor")
		pair.permanent=settings.get("permanent",false)
		for g in pair.gates:g.active=settings.get("active",true)
		if settings.get("connect",true):Portal.connect_gates(pair,settings.get("active",true))
		same(pair,c.connected,"full original connection")
		for frame in c.frames:
			Portal.advance(pair,frame.dt);frames+=1
			same(pair,frame.output,"full original float32 update "+str(frames))
	var content=root.get_node("Content");var profile=root.get_node("Profile").fresh();profile.abilities.m_portal=5
	var mission=content.mission("8");var sim=Sim.new();sim.setup(content.catalog,content.maps[mission.map],mission,profile,114,content.animations);sim.spawn_hold=true
	var start=sim.center(8,9);var finish=sim.center(12,9)
	check(sim.use_ability("m_portal",start)=="Choose the portal exit.","real entry placement creates pending gate")
	var pair=sim.portals[0].presentation
	check(pair.gates[0].scale==Portal.f32(0.3) and not pair.connected,"pending gate keeps original stopped preview size")
	sim.advance_frame(250)
	check(pair.remaining==sim.duration("portal_duration") and pair.gates[0].scale==Portal.f32(0.3),"unconnected pair waits without lifetime/growth updates")
	check(sim.use_ability("m_portal",finish).is_empty() and sim.abilities.m_portal==4,"second gate connects and consumes exactly once")
	sim.advance_frame(250)
	check(pair.gates[0].scale==0.75 and pair.gates[1].scale==0.75,"both real gates grow through source half-reload interval")
	var before=pair.duplicate(true);sim.paused=true;sim.advance_frame(250)
	check(pair==before,"pause retains exact portal lifecycle state")
	sim.paused=false;pair.remaining=250
	sim.advance_frame(250)
	check(pair.gates[0].state==4 and pair.gates[0].scale==0.75 and sim.portals.size()==2,"expired pair shrinks and stays registered")
	sim.advance_frame(500)
	check(pair.gates[0].scale==0.25 and not pair.deleted,"closing keeps original reload clock")
	sim.advance_frame(250)
	check(pair.deleted and pair.gates[0].state==3 and pair.gates[0].scale==0 and sim.portals.size()==2,"zero-size source gate hides before manager removal")
	sim.advance_frame(30)
	check(sim.portals.is_empty(),"real manager removes deleted pair on following update")
	for candidate in content.catalog.offlineConfigs:
		if candidate.get("settings",{}).get("teleports",[]).is_empty():continue
		var authored=Sim.new();authored.setup(content.catalog,content.maps[candidate.map],candidate,profile,114,content.animations);authored.spawn_hold=true
		var permanent=authored.static_portals[0].presentation
		check(permanent.permanent and permanent.connected and permanent.gates[0].scale==Portal.f32(0.3),"authored static pair starts at original constructor scale")
		authored.advance_frame(500)
		check(permanent.gates[0].scale==1 and permanent.remaining==float(content.catalog.tower_magic.portal_duration),"authored permanent gate grows without lifetime debit")
		break
	var report={"checks":checks,"failures":failures,"original_cases":reference.cases.size(),"original_frames":frames,"limit":"Full constructor/Connect/Portal.Update/Gates.Update/Interpolate against supplied effect metadata and stubbed transfer/animation/sound. Exact float32 lifecycle fields; real pending/connected/pause/expiry/next-update deletion and static pair bridge. No original transfer internals, animator clock/raster, full room registry or GPU equivalence."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/portal-lifecycle-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PORTAL_LIFECYCLE_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
