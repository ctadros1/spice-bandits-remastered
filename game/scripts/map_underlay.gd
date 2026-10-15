extends Node2D

var app
var water
var story
var active = false

func _ready() -> void:
	water=preload("res://scripts/water_view.gd").new();add_child(water)
	story=preload("res://scripts/story_glow.gd").new();story.app=app;add_child(story)
	var tutorial=preload("res://scripts/tutorial_gl_layer.gd").new();tutorial.app=app;tutorial.phase="terrain";add_child(tutorial)

func _process(_delta:float) -> void:
	prepare()

func prepare() -> void:
	active=(app.screen=="game" and app.sim!=null) or app.screen=="story"
	visible=active
	story.prepare()
	water.visible=false
	if not active:return
	queue_redraw()
	if app.screen=="game":
		# TouchGameplay Training has the stable painted-water pattern. Retain
		# the later1.14 animated-water port as a separately marked QA fixture.
		if str(app.sim.map.background).get_file()!="map_1.png" or app.qa_water:
			water.prepare(app.sim.map.get("water",{}),app.sim.water_phase,app.map_origin(),app.map_scale())

func _draw() -> void:
	if not active:return
	if app.screen=="story":
		draw_rect(Rect2(Vector2.ZERO,app.view_size()),Color.BLACK)
		draw_texture_rect(Content.tex("assets/lobby/story_screens/"+str(app.story_location.story_img).get_basename()+".png"),app.story_image_rect(),false)
		return
	draw_set_transform(app.map_origin(),0,Vector2.ONE*app.map_scale())
	draw_texture_rect(Content.tex(app.sim.map.background),Rect2(0,0,app.sim.map.width_pixels,app.sim.map.height_pixels),false)
