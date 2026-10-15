extends Node2D
var app
func _process(_delta:float) -> void:queue_redraw()
func _draw() -> void:
	if is_instance_valid(app) and app.screen=="game" and app.sim!=null:app.ClassicUI.draw_hud(app,self)
