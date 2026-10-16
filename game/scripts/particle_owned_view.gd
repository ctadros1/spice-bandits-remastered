extends RefCounted
## Native execution of the independently checked owned-particle fields.
const Reference=preload("res://scripts/particle_child_view.gd")
static func initialize(definition:Dictionary,texture_present:bool,texture_homogeneous:bool,texture_list_nonempty:bool,info:Variant=null,found:bool=true) -> Dictionary:
	return Reference.initialize(definition,texture_present,texture_homogeneous,texture_list_nonempty,info,found)
static func bits(value:float) -> int:return Reference.bits(value)
static func emit(system:Dictionary,count:int,make_particle:Callable,make_child:Callable) -> void:SpiceNative.owned_particle_emit(system,count,make_particle,make_child)
static func advance(system:Dictionary,dt:float,make_particle:Callable,make_child:Callable,interval_scale:float=1.0) -> void:SpiceNative.owned_particle_advance(system,dt,make_particle,make_child,interval_scale)
static func restart(system:Dictionary) -> void:SpiceNative.owned_particle_restart(system)
static func destroy(system:Dictionary,deleted:Array) -> void:SpiceNative.owned_particle_destroy(system,deleted)
static func render(system:Dictionary,homogeneous:bool) -> Dictionary:return SpiceNative.owned_particle_render(system,homogeneous)
