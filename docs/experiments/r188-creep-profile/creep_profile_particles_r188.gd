extends "res://scripts/particle_state.gd"
var detail={}
func add_sample(name:String,start:int) -> void:
	var value=detail.get(name,{"calls":0,"us":0});value.calls+=1;value.us+=Time.get_ticks_usec()-start;detail[name]=value
func refresh_creep(sim,e:Dictionary) -> void:
	var start=Time.get_ticks_usec();super.refresh_creep(sim,e);add_sample("refresh",start)
func update_creep_fields(e:Dictionary,aim:Vector2,direction:Vector2,heavy:bool=false) -> void:
	var start=Time.get_ticks_usec();super.update_creep_fields(e,aim,direction,heavy);add_sample("particle_fields",start)
func advance_creep(e:Dictionary,dt_ms:float) -> void:
	var start=Time.get_ticks_usec();super.advance_creep(e,dt_ms);add_sample("particle_advance",start)
func stop_creep_smoke(e:Dictionary) -> void:
	var start=Time.get_ticks_usec();super.stop_creep_smoke(e);add_sample("death_stop_smoke",start)
func make_owned_particle(tree:Dictionary,index:int,fresh:bool,old:Dictionary) -> Dictionary:
	var start=Time.get_ticks_usec();var value=super.make_owned_particle(tree,index,fresh,old);add_sample("factory_particle_nested",start);return value
func make_owned_child(name:String,texture:Texture2D,variation:String) -> Dictionary:
	var start=Time.get_ticks_usec();var value=super.make_owned_child(name,texture,variation);add_sample("factory_child_nested",start);return value
