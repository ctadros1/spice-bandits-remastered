extends Control

# Reconstruct the native content-layer transition beneath stationary chrome.
# Native requests/duration are independently probed; Core Animation's pixel
# compositor/default easing and interrupted-animation blending remain open.
var app
var previous:Texture2D
var incoming:Texture2D
var request:Dictionary={}
var age=0.0
var active=false
var incoming_world=false

func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=500;clip_contents=true

func clear():
	if is_instance_valid(app) and is_instance_valid(app.ui):
		for control in app.ui.get_children():
			if control.has_meta("menu_chrome"):control.z_index=0
			elif control.has_meta("guidance_view"):control.z_index=1001
	active=false;previous=null;incoming=null;request.clear();queue_redraw()

func start(old:Texture2D,new:Texture2D,properties:Dictionary):
	previous=old;incoming=new;request=properties.duplicate();age=0.0
	active=true;incoming_world=app.screen=="world";size=app.view_size();queue_redraw()
	for control in app.ui.get_children():
		if control.has_meta("menu_chrome"):control.z_index=1000
		elif control.has_meta("guidance_view"):control.z_index=1001

func advance(seconds:float):
	if not active or incoming==null:return
	age+=seconds
	if age>=float(request.duration):clear()
	else:queue_redraw()

func _draw():
	if not active:return
	if incoming==null:
		if not incoming_world:draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
		draw_texture_rect(previous,Rect2(Vector2.ZERO,size),false)
		return
	var progress=clampf(age/float(request.duration),0,1)
	if request.type=="fade":
		# Live incoming content is already below this outgoing layer.
		draw_texture_rect(previous,Rect2(Vector2.ZERO,size),false,Color(1,1,1,1-progress))
	else:
		if not incoming_world:draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
		var direction=1.0 if request.subtype=="fromRight" else -1.0
		draw_texture_rect(previous,Rect2(Vector2(-direction*size.x*progress,0),size),false)
		draw_texture_rect(incoming,Rect2(Vector2(direction*size.x*(1-progress),0),size),false)
