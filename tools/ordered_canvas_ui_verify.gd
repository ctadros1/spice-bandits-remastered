extends SceneTree
const Ordered=preload("res://scripts/ordered_canvas_view.gd")
var checks=0
var failures=[]
var owned_textures:Array=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	create_timer(30).timeout.connect(func():push_error("Ordered canvas proof exceeded30 seconds");quit(1))
	run.call_deferred()
func raw_texture(color:Color) -> Texture2D:
	var data=Image.create(8,8,false,Image.FORMAT_RGBA8);data.fill(color)
	var texture=ImageTexture.create_from_image(data);owned_textures.append(texture);return texture
func run() -> void:
	var viewport=SubViewport.new();viewport.size=Vector2i(256,128);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stream=Ordered.new();viewport.add_child(stream)
	var base=Color(50.0/255,80.0/255,110.0/255,1)
	var cover=Color(150.0/255,100.0/255,50.0/255,1)
	var texture=raw_texture(Color(60.0/255,30.0/255,15.0/255,128.0/255))
	var commands=[{"draw":func(canvas):canvas.draw_rect(Rect2(0,0,256,128),base)},
		{"additive":true,"draw":func(canvas):canvas.draw_texture_rect(texture,Rect2(0,0,128,128),false)},
		{"draw":func(canvas):canvas.draw_rect(Rect2(64,0,64,64),cover)}]
	stream.prepare(commands)
	await process_frame;await process_frame;RenderingServer.force_draw(true)
	var image=viewport.get_texture().get_image()
	var expected=base+Color(12.0/255,6.0/255,3.0/255,0)
	var actual=image.get_pixel(32,32)
	for channel in range(3):check(absf(actual[channel]-expected[channel])*255<=1.0,"original ONE/ONE raw premul RGB channel "+str(channel))
	check(image.get_pixel(96,32)==cover,"later opaque owner covers earlier additive flash exactly")
	check(image.get_pixel(192,32)==base,"additive source stays within owner geometry")
	check(stream.spans.size()==3,"normal/additive/normal spans retain owner submission order")
	# Reusing the same pool must drop hidden spans when returning to no-hit.
	stream.prepare([{"draw":func(canvas):canvas.draw_rect(Rect2(0,0,256,128),base)}])
	await process_frame;await process_frame;RenderingServer.force_draw(true)
	var cleared=viewport.get_texture().get_image()
	check(cleared.get_pixel(32,32)==base and cleared.get_pixel(96,32)==base,"next no-hit frame removes both stale flash and old occluder")
	check(not stream.spans[1].visible and not stream.spans[2].visible,"unused pooled spans hidden")
	image.save_png("res://../builds/ordered-canvas-r120.png");cleared.save_png("res://../builds/ordered-canvas-r120-cleared.png")
	var report={"checks":checks,"failures":failures,"actual_additive_rgb":[actual.r,actual.g,actual.b],"expected_additive_rgb":[expected.r,expected.g,expected.b],"scope":"Isolated native ordered-canvas prototype. Fixed supplied premultiplied texture, same ONE/ONE RGB equation and later-owner opaque coverage; not Main integration or original GPU raster equivalence."}
	var out=FileAccess.open("res://../builds/ordered-canvas-r120-verification.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("ORDERED_CANVAS ",JSON.stringify(report));viewport.free();quit(0 if failures.is_empty() else 1)
