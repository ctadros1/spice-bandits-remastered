extends "res://../tools/particle_child_ui_verify.gd"
func _initialize():
	View=preload("res://scripts/particle_owned_view.gd")
	report_path="res://../builds/particle-owned-r138-verification.json"
	super._initialize()
