extends SceneTree
const Bubble=preload("res://scripts/bubble_lifecycle.gd")
const Bridge=preload("res://scripts/cloud_particles.gd")
const State=preload("res://scripts/particle_state.gd")
var checks=0
var key_checks=0
var failures=[]
var timelines=[]
class Context extends RefCounted:
	var state
	var bridge
	var target=Vector2(340,400)
	var bubble={}
	func parameter(_name):return 50
	func lookup(_id):return target
	func texture(name:String,crop:Vector2i,size:Vector2i,slot:int) -> Dictionary:return {"name":name,"crop":crop,"size":size,"slot":slot}
	func texture_destroy(_value):pass
	func blend(_source,_destination):pass
	func color(_alpha):pass
	func quad(_texture,_pos):pass
	func render_particle(_system):pass
	func adapters() -> Dictionary:return {"parameter":parameter,"lookup":lookup,"texture":texture,"texture_destroy":texture_destroy,"factory":bridge.factory.bind(43),"advance":bridge.advance,"destroy":bridge.destroy,"blend":blend,"color":color,"quad":quad,"particle_render":render_particle}
func _initialize() -> void:
	create_timer(180).timeout.connect(func():quit(2));run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func canonical(value):
	if value is Dictionary:
		var result={}
		for key in value:
			key_checks+=2
			if not (key is String or key is StringName):check(false,"dictionary key is text")
			if result.has(str(key)):check(false,"key text unique")
			result[str(key)]=canonical(value[key])
		return result
	if value is Array:
		var result=value.duplicate(false)
		for i in value.size():result[i]=canonical(value[i])
		return result
	return value
func context(slow:bool,reference:bool,follow:int) -> Context:
	var ctx=Context.new();ctx.state=State.new();ctx.state.reset();ctx.state.reference_emission=reference;ctx.bridge=Bridge.new(ctx.state)
	ctx.bubble=Bubble.construct({},Vector2(250,320),77,follow,slow,ctx.adapters())
	return ctx
func validate(ctx:Context,label:String) -> void:
	check(ctx.bubble.roots.size()==ctx.state.systems.size(),label+" retained roots registered exactly")
	check(ctx.state.cloud_roots.size()==ctx.bubble.roots.size(),label+" caller registry size")
	for root_system in ctx.bubble.roots:
		var system:Dictionary=root_system.system;var tree:Dictionary=system.owned_tree
		check(ctx.state.systems.any(func(s):return is_same(s,system)),label+" real renderer dictionary")
		check(is_same(ctx.state.cloud_roots[int(system.id)],root_system),label+" actual caller wrapper")
		check(is_same(system.particles,tree.particles),label+" actual retained particle alias")
		check(int(root_system.active_count)==tree.particles.size(),label+" actual active count")
		check(bool(root_system.first_release)==bool(tree.first_release),label+" actual first-release state")
		check(int(root_system.rate)==int(tree.rate),label+" actual retained rate")
		check(system.pos==root_system.pos and tree.pos==root_system.pos,label+" caller position reaches renderer and physics")
		check(system.cloud_managed and int(system.object_owner)==43,label+" manager exclusion and owner")
func test_context(slow:bool,follow:int) -> void:
	var native=context(slow,false,follow);var reference=context(slow,true,follow);var label=str([slow,follow]);var pattern=[0,.001,16.667,30,100,133.333];var clock=0.0;var inactive=-1.0;var saw_particles=false;var saw_tail=false;var saw_dormant=false;var maximum_roots=0
	for i in 150:
		var delta=float(pattern[i%pattern.size()]);clock+=delta
		if follow and i%7==0:native.target+=Vector2(1,-1);reference.target=native.target
		Bubble.update(native.bubble,delta,native.adapters());Bubble.update(reference.bubble,delta,reference.adapters())
		check(var_to_bytes(canonical(native.bubble))==var_to_bytes(canonical(reference.bubble)),label+" complete native/reference bubble/root/tree bytes "+str(i))
		check(var_to_bytes(canonical(native.state.systems))==var_to_bytes(canonical(reference.state.systems)),label+" complete native/reference renderer bytes "+str(i))
		check(native.state.random.state==reference.state.random.state,label+" isolated spawn RNG exact "+str(i))
		validate(native,label+"/"+str(i));maximum_roots=maxi(maximum_roots,native.bubble.roots.size())
		var count=0
		for root_system in native.bubble.roots:count+=int(root_system.active_count)
		if count>0:saw_particles=true
		if not native.bubble.active:
			if inactive<0:inactive=clock
			if count>0:saw_tail=true
			elif native.bubble.roots.size()>0:saw_dormant=true
		var before=var_to_bytes(native.state.systems);native.state.advance_unowned(Bubble.f32(delta*.001))
		check(var_to_bytes(native.state.systems)==before,label+" no duplicate presentation update/removal "+str(i))
		before=var_to_bytes(native.bubble);Bubble.render(native.bubble,native.adapters());check(var_to_bytes(native.bubble)==before,label+" draw callbacks do not mutate state "+str(i))
		if i==25:
			var held=native.state.systems.duplicate(true);native.state.replace_systems(held);validate(native,label+" held restore")
	check(inactive>=0,label+" actual flight reaches inactive")
	check(saw_particles and saw_tail,label+" actual authored particles and inactive tail observed")
	check(saw_dormant,label+" raw disable-zero roots retained after visible particles finish")
	var remaining=[]
	for system in native.bubble.roots:remaining.append({"name":system.system.definition.name,"disable_after_seconds":system.disable_after_seconds,"rate":system.rate,"active_count":system.active_count})
	timelines.append({"slow":slow,"follow_target":follow,"frames":150,"inactive_at_ms":inactive,"maximum_roots":maximum_roots,"actual_particles_observed":saw_particles,"actual_inactive_tail_observed":saw_tail,"dormant_disable_zero_roots_retained":saw_dormant,"remaining":remaining})
	Bubble.destroy(native.bubble,native.adapters());Bubble.destroy(reference.bubble,reference.adapters())
	check(native.bubble.roots.is_empty() and native.state.systems.is_empty() and native.state.cloud_roots.is_empty(),label+" actual owner destruction unregisters every root")
	native.state.reset();reference.state.reset()
func mixed_held_restore() -> void:
	var state=State.new();state.reset();var content=root.get_node("Content")
	var name="PoisonBubbleTrail";var definition:Dictionary=content.particles.systems[name].duplicate(true);var texture=content.tex(definition.texture)
	for i in 3:state.emit_definition(name,definition.duplicate(true),texture,Vector2(10+i,20),"","",-1,Vector2.ZERO,-1,i<2)
	var actor={"id":99,"particle_roots":[]};state.owners[99]=actor
	state.systems[0].creep_owner=99;state.systems[0].creep_alias="lsd";state.systems[0].retain_for_owner=true
	var frozen=state.systems.duplicate(true);var serialized=var_to_bytes(frozen);var old_system=state.systems[0];var plain_particles=frozen[2].particles
	state.replace_systems(frozen)
	check(var_to_bytes(state.systems)==serialized,"held restore preserves all serialized values")
	check(not is_same(state.systems[0],old_system),"held restore actually replaces dictionaries")
	for i in 2:check(is_same(state.systems[i].particles,state.systems[i].owned_tree.particles),"mixed owned renderer alias restored immediately "+str(i))
	check(is_same(state.systems[2].particles,plain_particles),"legacy flat particles array identity preserved")
	check(is_same(actor.particle_roots[0],state.systems[0]),"creep owner rebound to actual restored system")
	check(is_same(actor.disco_root,state.systems[0].owned_tree),"disco alias rebound to actual restored tree")
	state.reset()
func run() -> void:
	mixed_held_restore()
	var content=root.get_node("Content");var definitions=var_to_bytes(content.particles.systems)
	for slow in [false,true]:
		for follow in [0,1]:test_context(slow,follow)
	check(var_to_bytes(content.particles.systems)==definitions,"shared definitions unchanged")
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	check(not output.is_empty() and not FileAccess.file_exists(output),"fresh explicit output")
	var report={"checks":checks,"key_representation_checks":key_checks,"failures":failures,"passed":failures.is_empty(),"contexts":timelines,"full_state_frame_pairs":600,"scope":"Pure bubble controller using real authored retained particles/native-reference trees/status and isolated RNG; no Simulation/Main or original factory/parser/global RNG/GPU/audio identity claim"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n");print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
