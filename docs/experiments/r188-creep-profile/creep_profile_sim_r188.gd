extends "res://scripts/simulation.gd"
var detail={}
func add_sample(name:String,start:int) -> void:
	var value=detail.get(name,{"calls":0,"us":0});value.calls+=1;value.us+=Time.get_ticks_usec()-start;detail[name]=value
func update_living_enemy(e:Dictionary) -> void:
	var start=Time.get_ticks_usec();super.update_living_enemy(e);add_sample("living",start)
func advance_creep_hover(e:Dictionary,dt_ms:float) -> void:
	var start=Time.get_ticks_usec();super.advance_creep_hover(e,dt_ms);add_sample("hover",start)
func creep_animation(e:Dictionary) -> String:
	var start=Time.get_ticks_usec();var value=super.creep_animation(e);add_sample("animation_selector",start);return value
