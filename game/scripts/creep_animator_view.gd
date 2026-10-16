extends RefCounted
const Animator=preload("res://scripts/animator_view.gd")
static func initial(name:String,definition:Dictionary) -> Dictionary:
	var value=Animator.initial()
	Animator.play(value,name,definition)
	value.was_attacking=false
	return value
static func prepare(state:Dictionary,name:String,definition:Dictionary,divisor:float,multiplier:float,attacking:bool) -> void:
	# Creep ctor clears both reset-on-name-change flags. A walking turn keeps
	# its phase; the attack branch explicitly stops and sets frame/phase0.
	if state.name!=name or (state.was_attacking and not attacking):Animator.play(state,name,definition)
	state.divisor=divisor;state.multiplier=multiplier
	if attacking:state.stopped=true;state.phase=0.0;state.frame=0
	state.was_attacking=attacking
static func render_tick(state:Dictionary,dt_ms:float,paused:bool=false) -> void:
	Animator.advance(state,dt_ms,0,false,paused)
