extends Node2D

const Bolt=preload("res://scripts/bolt_view.gd")
var app
var active=false
var slots:Array=[]
var product:SubViewport
var white:ColorRect
var prepared_frame=-1
var pixel_scale=Vector2.ONE
var canvas_pixels=Vector2.ZERO
var additive_material:ShaderMaterial
var product_material:ShaderMaterial
var remaining_material:ShaderMaterial
var screen_ink_material:ShaderMaterial

class RibbonCanvas extends Node2D:
	var slot
	var pass_id=1
	func _draw() -> void:
		if not slot.visible:return
		var started=Time.get_ticks_usec()
		var owner_app=slot.renderer.app
		var origin=owner_app.map_origin()
		var scale_value=Vector2.ONE*owner_app.map_scale()
		if pass_id==2:
			origin=origin*slot.pixel_scale-slot.pixel_origin+slot.atlas_rect.position
			scale_value*=slot.pixel_scale
		draw_set_transform(origin,0,scale_value)
		if pass_id==0:Bolt.draw_balls(self,[slot.effect],owner_app.sim.clock_ms)
		elif int(slot.effect.type)==11:Bolt.draw_batch(self,[slot.effect],owner_app.sim.clock_ms,pass_id)
		else:Bolt.draw_ribbon(self,slot.effect,owner_app.sim.clock_ms,pass_id,slot.broad_strip if pass_id==2 else slot.core_strip)
		if owner_app.has_method("record_qa_time"):owner_app.record_qa_time("bolt_draw",started)

class ScreenCanvas extends Node2D:
	var slot
	func _draw() -> void:
		if slot.visible and slot.has_broad:
			draw_texture_rect_region(slot.product.get_texture(),slot.screen_rect,slot.atlas_rect)

class BoltSlot extends Node2D:
	var renderer
	var effect:Dictionary
	var product:SubViewport
	var glow:RibbonCanvas
	var ball:RibbonCanvas
	var remaining:ScreenCanvas
	var ink:ScreenCanvas
	var core:RibbonCanvas
	var pixel_scale=Vector2.ONE
	var pixel_origin=Vector2.ZERO
	var screen_rect=Rect2()
	var atlas_rect=Rect2()
	var needed=Vector2i.ZERO
	var has_broad=false
	var broad_strip={}
	var core_strip={}
	var cached_points=PackedVector2Array()
	var cached_alpha=-1.0
	var cached_type=-1
	var cached_texture=""
	var cached_origin=Vector2.INF
	var cached_scale=-1.0
	var geometry_changed=true
	var map_changed=true
	func _init(owner_renderer) -> void:
		renderer=owner_renderer
		product=renderer.product
		glow=RibbonCanvas.new();glow.slot=self;glow.pass_id=2;glow.material=renderer.product_material
		renderer.product.add_child(glow)
		# CBolt::Render0xddce8 completes one ball/broad/core sequence before
		# CTower::RenderAfter0xe8028 renders its next bolt. The two quads
		# implement D*(1-B)+B without reading/copying the main framebuffer.
		ball=RibbonCanvas.new();ball.slot=self;ball.pass_id=0;ball.material=renderer.additive_material;add_child(ball)
		remaining=ScreenCanvas.new();remaining.slot=self;remaining.material=renderer.remaining_material;add_child(remaining)
		ink=ScreenCanvas.new();ink.slot=self;ink.material=renderer.screen_ink_material;add_child(ink)
		remaining.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;ink.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		core=RibbonCanvas.new();core.slot=self;core.pass_id=1;core.material=renderer.additive_material;add_child(core)

	func hide_slot() -> void:
		visible=false;glow.visible=false

	func prepare(value:Dictionary) -> void:
		effect=value;visible=true;has_broad=int(effect.type)!=11
		ball.visible=bool(effect.get("ball",false))
		var alpha=float(effect.get("ribbon_alpha",Bolt.opacity(effect,renderer.app.sim.clock_ms)))
		geometry_changed=cached_type!=int(effect.type) or cached_texture!=str(effect.texture) or cached_alpha!=alpha or cached_points!=effect.points
		var next_pixel_scale=renderer.pixel_scale
		var origin=renderer.app.map_origin();var scale_value=renderer.app.map_scale()
		map_changed=cached_origin!=origin or cached_scale!=scale_value or pixel_scale!=next_pixel_scale
		pixel_scale=next_pixel_scale;cached_origin=origin;cached_scale=scale_value
		if has_broad:
			# Original Construct stores both ribbon buffers; an Update that only
			# changes source-ball opacity must not regenerate their saved ink.
			if geometry_changed:
				broad_strip=Bolt.ribbon(effect.points,2,alpha);core_strip=Bolt.ribbon(effect.points,1,alpha)
			var bounds=broad_strip.vertices
			if bounds.is_empty():hide_slot();return
			if geometry_changed or map_changed:
				var region:Rect2=broad_strip.bounds
				var box=Rect2((origin+region.position*scale_value)*pixel_scale,region.size*scale_value*pixel_scale)
				box=box.grow(2).intersection(Rect2(Vector2.ZERO,renderer.canvas_pixels))
				needed=Vector2i.ZERO
				if box.has_area():
					pixel_origin=box.position.floor();needed=Vector2i((box.end-pixel_origin).ceil())
					screen_rect=Rect2(pixel_origin/pixel_scale,Vector2(needed)/pixel_scale)
			if needed==Vector2i.ZERO:has_broad=false
		cached_points=effect.points;cached_alpha=alpha;cached_type=int(effect.type);cached_texture=str(effect.texture)
		glow.visible=has_broad
		if ball.visible:ball.queue_redraw()
		if geometry_changed or map_changed:core.queue_redraw()

func material(code:String) -> ShaderMaterial:
	var shader=Shader.new();shader.code=code
	var result=ShaderMaterial.new();result.shader=shader;return result

func _ready() -> void:
	product=SubViewport.new();product.disable_3d=true;product.transparent_bg=false;product.size=Vector2i(2,2)
	product.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(product)
	white=ColorRect.new();white.color=Color.WHITE;white.mouse_filter=Control.MOUSE_FILTER_IGNORE;product.add_child(white)
	# Broad strip ONE,ONE_MINUS_SRC_COLOR: accumulate(1-B) against white
	# in a cropped per-bolt target, including folded/overlapping triangles.
	product_material=material("""shader_type canvas_item;
render_mode blend_mul, unshaded;
varying vec4 ribbon_color;
void vertex() { ribbon_color = COLOR; }
void fragment() {
    vec4 texel = texture(TEXTURE, UV);
    COLOR = vec4(vec3(1.0) - texel.rgb * texel.a * ribbon_color.rgb, 1.0);
}""")
	remaining_material=material("""shader_type canvas_item;
render_mode blend_mul, unshaded;
void fragment() { COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0); }
""")
	screen_ink_material=material("""shader_type canvas_item;
render_mode blend_add, unshaded;
void fragment() { COLOR = vec4(vec3(1.0) - texture(TEXTURE, UV).rgb, 1.0); }
""")
	additive_material=material("""shader_type canvas_item;
render_mode blend_add, unshaded;
varying vec4 ribbon_color;
void vertex() { ribbon_color = COLOR; }
void fragment() {
    vec4 texel = texture(TEXTURE, UV);
    // LoadTextureFromFile0x1267b8 uses premultiplied bitmapInfo0x4001.
    COLOR = vec4(texel.rgb * texel.a * ribbon_color.rgb, texel.a * ribbon_color.a);
}""")

func prepare() -> void:
	prepared_frame=Engine.get_process_frames()
	var started=Time.get_ticks_usec()
	# Root ViewportTexture.get_size applies stretch again in this Godot
	# build: at1280x960 it reports1600x1200, but readback is1280x960.
	# Use the actual canvas stretch, excluding window letterbox offsets.
	pixel_scale=app.get_viewport().get_stretch_transform().get_scale()
	canvas_pixels=(app.view_size()*pixel_scale).round()
	active=app.screen=="game" and app.sim!=null
	visible=active
	var count=0
	if active:
		for effect in app.effects:
			if effect.kind!="shot" or (effect.has("bolt_clock") and not effect.bolt_clock.alive):continue
			if count==slots.size():
				var slot=BoltSlot.new(self);slots.append(slot);add_child(slot)
			slots[count].prepare(effect);count+=1
	for i in range(count,slots.size()):slots[i].hide_slot()
	# Independent broad products share one render target. Atlas tiles never
	# overlap; their later main-canvas ball/broad/core sequences still do.
	# This avoids an FBO/viewport switch for every live beam in dense battles.
	var area=0;var width=product.size.x
	for slot in slots:
		if slot.visible and slot.has_broad:
			area+=(slot.needed.x+4)*(slot.needed.y+4);width=maxi(width,slot.needed.x+4)
	var ideal=128
	while ideal*ideal<area and ideal<4096:ideal*=2
	width=maxi(width,ideal)
	var x=2;var y=2;var row_height=0
	for slot in slots:
		if slot.visible and slot.has_broad:
			if x+slot.needed.x+2>width:x=2;y+=row_height+4;row_height=0
			var previous_rect=slot.atlas_rect
			slot.atlas_rect=Rect2(Vector2(x,y),Vector2(slot.needed))
			x+=slot.needed.x+4;row_height=maxi(row_height,slot.needed.y)
			if previous_rect!=slot.atlas_rect or slot.geometry_changed or slot.map_changed:slot.glow.queue_redraw()
		slot.remaining.queue_redraw();slot.ink.queue_redraw()
	if area>0:
		product.size=Vector2i(width,maxi(product.size.y,int(ceil((y+row_height+2)/128.0))*128));white.size=product.size
	product.render_target_update_mode=SubViewport.UPDATE_ALWAYS if area>0 else SubViewport.UPDATE_DISABLED
	if not active and not slots.is_empty():
		for slot in slots:slot.glow.queue_free();slot.queue_free()
		slots.clear()
		product.size=Vector2i(2,2)
	active=active and count>0
	if app.has_method("record_qa_time"):app.record_qa_time("bolt_prepare",started)

func _process(_delta:float) -> void:
	if prepared_frame!=Engine.get_process_frames():prepare()
