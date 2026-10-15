extends Node2D
var app
func _draw() -> void:
	if is_instance_valid(app):app.draw_battle_overlays(self)
