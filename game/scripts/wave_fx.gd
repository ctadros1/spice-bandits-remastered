extends Node2D

var app
var layers:Array=[]
var just_started=false

func _ready() -> void:
	for i in range(4):
		var layer=preload("res://scripts/particle_fx.gd").new();layer.app=app;layer.screen_space=true
		add_child(layer);layers.append(layer)

func reset() -> void:
	for layer in layers:layer.reset()
	just_started=false

func launch() -> void:
	# ProcessWaves0xd3bf8 creates four independent systems, warming the first
	# three with ten50ms updates and Sparks with one50ms update.
	reset()
	var names=["WaveSplash","WaveExplode","WaveExplode","WaveSparks"]
	var points=[Vector2(15,10),Vector2(15,10),Vector2(15,20),Vector2(3,28)]
	for i in range(4):
		layers[i].size=app.view_size()
		layers[i].emit_system(names[i],points[i],"","",-1)
		for j in range(1 if i==3 else 10):layers[i].advance_ui(50)
	just_started=true

func advance(ms:float) -> void:
	visible=app.screen=="game"
	if not visible or app.sim==null or app.sim.paused or app.sim.outcome!="playing":return
	if just_started:just_started=false;return
	for layer in layers:
		layer.size=app.view_size();layer.advance_ui(ms)
