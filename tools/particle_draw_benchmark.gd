extends SceneTree

class Canvas extends Node2D:
	var fx
	var systems=[]
	var premultiplied=false
	var direct=false
	var measuring=false
	var samples=[]
	var meshes=[]
	func _draw() -> void:
		var begin=Time.get_ticks_usec()
		var groups=SpiceNative.particle_batches(systems,premultiplied,0,Vector2.ZERO,1,direct)
		var prepared=Time.get_ticks_usec()
		meshes=fx.draw_groups(self,groups,1.0,direct)
		if measuring:samples.append({"prepare":prepared-begin,"draw":Time.get_ticks_usec()-prepared,"groups":groups.size()})

func _initialize() -> void:run.call_deferred()
func median(values:Array) -> float:
	values.sort();return float(values[values.size()/2]) if not values.is_empty() else 0.0
func frame(canvases:Array) -> void:
	for canvas in canvases:canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	create_timer(60).timeout.connect(func():push_error("Fixed particle benchmark timed out.");quit(1))
	var output=ProjectSettings.globalize_path("res://../builds/particle-fixed-benchmark-r95")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(384,288)
	var viewport=SubViewport.new();viewport.size=Vector2i(320,240);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var backdrop=ColorRect.new();backdrop.size=Vector2(320,240);backdrop.color=Color(0.12,0.23,0.34,1);viewport.add_child(backdrop)
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):image.set_pixel(x,y,Color(float(x)/15,float(y)/15,0.6,float((x+y)%7+1)/7))
	var textures=[ImageTexture.create_from_image(image),ImageTexture.create_from_image(image)]
	var systems=[]
	for i in range(64):
		var particles=[]
		for j in range(8):particles.append({"region":Rect2(0,0,16,16),"born":0,"size_offset":0,"alpha":0.75,"rotation":0.137+float(i%5)*0.17-PI/2,"pos":Vector2(12+(i*13+j*29)%296,12+(i*7+j*17)%216)})
		systems.append({"definition":{"real_alpha":i%2,"color":[0.123,0.567,0.891,0.456],"size":12,"life_cycle":1,"rotational":1},"texture":textures[int(i/2)%2],"particles":particles})
	var canvases=[]
	for premultiplied in [false,true]:
		var canvas=Canvas.new();canvas.fx=load("res://scripts/particle_fx.gd");canvas.systems=systems;canvas.premultiplied=premultiplied;canvas.visible=false;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		if premultiplied:
			var shader=Shader.new();shader.code="shader_type canvas_item; render_mode blend_premul_alpha; void fragment(){ COLOR.rgb *= texture(TEXTURE,UV).a; }"
			var material=ShaderMaterial.new();material.shader=shader;canvas.material=material
		viewport.add_child(canvas);canvases.append(canvas)
	await frame(canvases);await frame(canvases)
	var blank=viewport.get_texture().get_image().get_data()
	for canvas in canvases:canvas.visible=true
	var phases=[];var failures=[];var reference:PackedByteArray
	for phase in range(4):
		var direct=phase in [1,2]
		for canvas in canvases:canvas.direct=direct;canvas.measuring=false
		for i in range(10):await frame(canvases)
		for canvas in canvases:canvas.samples.clear();canvas.measuring=true
		var started=Time.get_ticks_usec()
		for i in range(60):await frame(canvases)
		var elapsed=Time.get_ticks_usec()-started
		for canvas in canvases:canvas.measuring=false
		var captured=viewport.get_texture().get_image()
		var name=("direct" if direct else "mesh")+"-"+str(phase)
		if captured.save_png(output.path_join(name+".png"))!=OK:failures.append(name+" capture failed")
		if captured.get_data()==blank:failures.append(name+" was blank")
		if phase==0:reference=captured.get_data()
		elif captured.get_data()!=reference:failures.append(name+" differs from the first mesh RGBA frame")
		var layers=[]
		for canvas in canvases:
			if canvas.samples.size()<50:failures.append(name+" missing draw samples")
			layers.append({"premultiplied":canvas.premultiplied,"samples":canvas.samples.size(),"groups":canvas.samples[0].groups if not canvas.samples.is_empty() else 0,"prepare_median_us":median(canvas.samples.map(func(s):return s.prepare)),"draw_median_us":median(canvas.samples.map(func(s):return s.draw))})
		phases.append({"backend":"direct" if direct else "mesh","elapsed_ms":elapsed/1000.0,"layers":layers})
	viewport.queue_free();await process_frame
	var report={"passed":failures.is_empty(),"failures":failures,"systems":64,"particles":512,"phases":phases,"method":"Source Godot4.7.2, fixed512-particle/64-group ABBA renderer-only comparison, same RGBA required. Native preparation/draw CPU measured separately; wall time includes scheduling/vsync. No simulation, live FPS or original-device performance claim."}
	var file=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PARTICLE_FIXED_BENCHMARK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
