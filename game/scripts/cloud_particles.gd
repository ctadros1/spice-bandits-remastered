extends RefCounted
# Real retained particle adapters for CloudLifecycle. Simulation binding is
# separate; no particle count, tail length or expiry is estimated here.
const Math=preload("res://scripts/particle_math.gd")
const Owned=preload("res://scripts/particle_owned_view.gd")
const Reference=preload("res://scripts/particle_child_view.gd")
var state
func _init(particle_state) -> void:state=particle_state

func factory(name:String,owner:int=-1) -> Dictionary:
	var definition:Dictionary=state.content.particles.systems.get(name,{}).duplicate(true)
	assert(not definition.is_empty(),"Missing original cloud particle definition: "+name)
	var texture=state.content.tex(definition.texture)
	assert(texture!=null,"Missing original cloud particle texture: "+name)
	state.emit_definition(name,definition,texture,Vector2.ZERO,"","",-1,Vector2.ZERO,owner,true,false)
	var system:Dictionary=state.systems[-1]
	system.cloud_managed=true
	system.view_clock_ms=0.0
	var tree:Dictionary=system.owned_tree
	return {"system":system,"rate":int(tree.rate),"interval":Math.f32(float(definition.release_interval)),"disable_after_seconds":Math.f32(float(definition.get("disable_after",0))/1000.0),"pos":Vector2.ZERO,"alpha":Math.f32(float(definition.color[3])),"active_count":0,"first_release":bool(tree.first_release)}

func advance(root:Dictionary,seconds:float) -> void:
	var system:Dictionary=root.system
	var tree:Dictionary=system.owned_tree
	tree.pos=root.pos;system.pos=root.pos
	tree.rate=int(root.rate);tree.interval_seconds=Math.f32(float(root.interval))
	tree.disable_after_seconds=Math.f32(float(root.disable_after_seconds))
	# Each factory copied its definition; caller alpha never edits the shared
	# imported resource or another cloud's system.
	tree.definition.color[3]=Math.f32(float(root.alpha))
	if state.reference_emission:Reference.advance(tree,seconds,state.make_owned_particle,state.make_owned_child.bind(system.texture,str(system.variation)))
	else:SpiceNative.owned_particle_advance(tree,seconds,state.make_owned_particle,state.make_owned_child.bind(system.texture,str(system.variation)),1.0,state.owned_prepared)
	system.particles=tree.particles;system.phase=float(tree.get("phase",0))
	system.view_clock_ms=float(tree.clock_seconds)*1000.0
	system.emitting=int(tree.rate)!=0
	root.rate=int(tree.rate);root.active_count=tree.particles.size();root.first_release=bool(tree.first_release)

func destroy(root:Dictionary) -> void:
	var system:Dictionary=root.system
	Owned.destroy(system.owned_tree,[])
	state.systems.erase(system)
