extends RefCounted

# TutorialView showTutorial0x650dc/removeTutorial0x66d3c request500ms,
# delay0/options0 and alpha0->1 /1->0. Notification is immediate; removal
# and afterClose happen on completion. UIKit's compositor is not executed.
const DURATION=0.5
var app
var layers:Array=[]
var serial=0

static func f32(value:float) -> float:return PackedFloat32Array([value])[0]

static func tap_allowed(start:Vector2,finish:Vector2,inside:bool) -> bool:
	var dx=f32(start.x-finish.x);var dy=f32(start.y-finish.y)
	return inside and f32(sqrt(f32(f32(dx*dx)+f32(dy*dy))))<20.0

static func after_close_menu(kind:int) -> int:
	return 103 if kind==5 else 104 if kind==6 else 0

func on_close(key:String,action:Callable) -> void:
	for layer in layers:
		if layer.key==key and not layer.closing:
			layer.after_close=action
			return

static func curve(progress:float) -> float:
	# UIKit's named ease-in/out cubic. Invert x for the elapsed-time fraction.
	var p=clampf(progress,0,1)
	var low=0.0;var high=1.0
	for i in range(24):
		var t=(low+high)/2.0;var inv=1-t
		var x=3*inv*inv*t*0.42+3*inv*t*t*0.58+t*t*t
		if x<p:low=t
		else:high=t
	var t=(low+high)/2.0
	return 3*(1-t)*t*t+t*t*t

func alpha(layer:Dictionary) -> float:
	return 1-curve(layer.age/DURATION) if layer.closing else curve(layer.age/DURATION)

func sync(layout:Dictionary,key:String,caption:String,action:Callable) -> void:
	var live=layers.filter(func(l):return not l.closing)
	if not live.is_empty() and live[0].key==key:
		return # Rebuilding the HUD never restarts a UIKit-style view animation.
	for layer in live:layer.closing=true;layer.age=0.0
	if key.is_empty():apply();return
	serial+=1
	var layer={"id":serial,"key":key,"age":0.0,"closing":false,"controls":[]}
	for item in layout.images:
		if item.get("uikit",false):layer.controls.append(app.image_control(app.ui,item.path,item.rect))
	for hint in layout.labels:
		if not hint.get("uikit",false):continue
		var label=app.label(app.ui,hint.value,hint.rect,hint.size,hint.color)
		label.autowrap_mode=TextServer.AUTOWRAP_OFF
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("line_spacing",int(hint.get("line_spacing",0)))
		label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		label.set_meta("portrait_text",true)
		layer.controls.append(label)
	if not caption.is_empty():
		var gesture={"start":Vector2.ZERO,"allowed":true}
		var button=app.invisible_button(app.ui,caption,layout.hit_rect,func():if gesture.allowed:action.call())
		button.set_meta("suppress_generic_click",true)
		button.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed:gesture.start=event.position;gesture.allowed=true
				else:gesture.allowed=tap_allowed(gesture.start,event.position,Rect2(Vector2.ZERO,button.size).has_point(event.position))
			elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:gesture.allowed=tap_allowed(gesture.start,event.position,true))
		layer.controls.append(button)
	for control in layer.controls:
		control.set_meta("uikit_portrait",serial);control.set_meta("guidance_view",true)
		control.z_index=1001
	layers.append(layer);apply()

func apply() -> void:
	for layer in layers:
		var opacity=alpha(layer)
		for control in layer.controls:
			control.modulate.a=opacity
			if control is Button:control.disabled=layer.closing or layer.age<DURATION

func advance(seconds:float) -> void:
	for layer in layers:layer.age+=seconds
	var completed=layers.filter(func(l):return l.closing and l.age>=DURATION)
	for layer in completed:
		# Native completion calls afterClose before removeFromSuperview. Menu
		# navigation can rebuild the HUD, so release by identity afterwards.
		var action=layer.get("after_close",Callable())
		layer.erase("after_close")
		if action.is_valid():action.call()
		if not layers.has(layer):continue
		for control in layer.controls:
			app.ui.remove_child(control);control.queue_free()
		layers.erase(layer)
	apply()

func clear() -> void:
	for layer in layers:
		for control in layer.controls:
			app.ui.remove_child(control);control.queue_free()
	layers.clear()
