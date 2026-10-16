extends SceneTree
const Reference=preload("res://scripts/particle_child_view.gd")
var checks=0
var failures=[]
var diagnostics=[]
func _initialize():
	create_timer(45).timeout.connect(func():quit(2));run.call_deferred()
func check(value:bool,label:String):
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func run():
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.8,.7));var texture=ImageTexture.create_from_image(image)
	var render_fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-particle-child-render-reference.json"))
	var geometry_cases=0
	for c in render_fixture.cases:
		for transform in [[Vector2.ZERO,1.0],[Vector2(100.125,-73.6),.5],[Vector2(-.137,12.25),1.3]]:
			var reference:Dictionary=c.input.duplicate(true);reference.texture=texture
			var native=reference.duplicate(true)
			for held_render in range(2):
				var original_groups=Reference.batches(reference,transform[0],transform[1])
				var native_groups=SpiceNative.owned_particle_batches(native,transform[0],transform[1])
				check(var_to_bytes(original_groups)==var_to_bytes(native_groups),"original strip fields converted to exact native group bytes "+str(c.pose))
				check(var_to_bytes(reference)==var_to_bytes(native),"native/reference held render color mutation equality")
				geometry_cases+=1
	var content=root.get_node("Content");var fx_script=load("res://scripts/particle_fx.gd");var live_names=[]
	for name in content.particles.systems:
		var definition:Dictionary=content.particles.systems[name];var child_name=str(definition.get("child_system",""))
		if child_name.is_empty() or not content.particles.systems.has(child_name):continue
		live_names.append(str(name))
		var fx=fx_script.new();fx.reset();fx.emit_system(str(name),Vector2(101.25,203.5))
		check(fx.systems.size()==1 and fx.systems[0].has("owned_tree"),"actual authored resolved root connects ownership "+str(name))
		if fx.systems.is_empty():fx.free();continue
		var sys:Dictionary=fx.systems[0];var tree:Dictionary=sys.owned_tree
		check(sys.particles.size()==int(definition.num_release),"actual authored initial root count")
		check(tree.particles.all(func(p):return not p.child.is_empty() and p.child.particles.is_empty() and p.child.clock_seconds==0),"factory creates empty zero-clock child per parent")
		for frame in range(1,61):
			fx.clock_seconds=Vector2(fx.clock_seconds+Vector2(.03,0).x,0).x;fx.clock_ms=fx.clock_seconds*1000.0
			SpiceNative.advance_systems(fx.systems,fx.clock_ms,fx.emit_system,fx.emit_batch,fx.random,.03)
			check(fx.systems.size()<=1,"owned children never become global systems")
			if frame==1:check(tree.particles.all(func(p):return p.child.particles.is_empty() and Reference.bits(p.child.clock_seconds)==Reference.bits(.03)),"first30ms advances children without premature emission")
			if frame==2:check(tree.particles.all(func(p):return p.child.particles.size()==1 and Reference.bits(p.child.clock_seconds)==Reference.bits(Vector2(.06,0).x)),"strict original child interval releases at60ms")
			if frame==12:
				var before=tree.duplicate(true);var scalar=tree.duplicate(true)
				var groups=SpiceNative.owned_particle_batches(before,Vector2(7.25,-3.125),.85)
				check(var_to_bytes(groups)==var_to_bytes(Reference.batches(scalar,Vector2(7.25,-3.125),.85)),"actual authored live child geometry native/scalar exact")
				check(var_to_bytes(before)==var_to_bytes(scalar),"actual authored live child colors native/scalar exact")
		check(fx.systems.is_empty() and tree.particles.is_empty() and tree.pool.is_empty(),"root expiry clears owned children; no orphan ring")
		fx.free()
	check(live_names.size()==19,"all19resolved authored child edges exercised;2unused obsolete references preserved")
	var report={"checks":checks,"failures":failures,"geometry_cases":geometry_cases,"live_names":live_names,"scope":"Exact serialized native/scalar draw groups and held render mutation from96independent original render cases at3transforms/2renders. Actual ParticleFX for all19resolved authored edges: initial empty child factory,30/60ms strict release, root-only global registry, live geometry/color equality and expiry cleanup. Existing isolated Godot RNG is an adaptation; original resource parser/globalRNG/whole retained owner/room/GPU equivalence not established."}
	var f=FileAccess.open("res://../builds/particle-owned-r138-live-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("PARTICLE_OWNED_LIVE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
