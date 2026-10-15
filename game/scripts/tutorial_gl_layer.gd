extends Node2D
var app
var phase="terrain"
func _process(_delta:float) -> void:queue_redraw()
func _draw() -> void:
	if is_instance_valid(app):app.TutorialView.draw_phase(app,self,phase)
