extends Node2D

const Math=preload("res://scripts/story_math.gd")
var app
var nodes:Array[Dictionary]=[]
var random=RandomNumberGenerator.new()
var active=false
var story_id=""

func _ready() -> void:
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode blend_add, unshaded;
void fragment(){COLOR=vec4(COLOR.rgb*texture(TEXTURE,UV).a,1.0);}
"""
	var value=ShaderMaterial.new();value.shader=shader;material=value

func prepare() -> void:
	var next=app.screen=="story"
	var key=str(app.story_location.get("id",""))
	if next and (not active or story_id!=key):
		nodes.clear();random.seed=114 if app.test_session else randi()
		var y=0.0
		for i in range(30):
			var point=Vector2(Math.f32(float(random.randi()%100)/100*256),Math.f32(y+Math.f32(float(random.randi()%100)/100*256)))
			var node={"position":point,"start":point,"end":point+(point-app.view_center()).normalized()*100,"scale":random.randf_range(0.3,3),"phase":random.randf(),"alpha":random.randf(),"fade_in":bool(random.randi()&1),"finished":false}
			node.initial_alpha=node.alpha;nodes.append(node);y=Math.f32(y+Math.f32(1024.0/3))
	active=next;story_id=key;visible=active
	if active:queue_redraw()

func advance(dt_ms:float) -> void:
	for node in nodes:
		Math.advance(node,dt_ms)
		if node.finished:
			var point=Vector2(random.randf_range(0,1024),random.randf_range(app.view_center().y-280,app.view_center().y+280))
			node.merge({"position":point,"start":point,"end":point+(point-app.view_center()).normalized()*100,"scale":random.randf_range(0.3,3),"fade_in":true,"finished":false},true)
	queue_redraw()

func _process(delta:float) -> void:
	if active:advance(delta*1000)

func _draw() -> void:
	if not active:return
	var texture=Content.tex("assets/lobby/story_screens/story_screen_add.png")
	for node in nodes:
		var extent=Vector2(64,64)*float(node.scale)
		draw_texture_rect(texture,Rect2(node.position-extent/2,extent),false,Color(node.alpha,node.alpha,node.alpha,node.alpha))
