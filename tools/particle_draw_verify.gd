extends SceneTree
var checks=0
var failures=[]
var captures=[]

class Canvas extends Node2D:
	var groups=[]
	var direct=false
	var meshes=[]
	var fx
	var draw_calls=0
	func _draw() -> void:
		meshes=fx.draw_groups(self,groups,1.0,direct)
		draw_calls+=1

func _initialize() -> void:run.call_deferred()

func run() -> void:
	create_timer(20).timeout.connect(func():push_error("Particle draw experiment timed out.");quit(1))
	var output=ProjectSettings.globalize_path("res://../builds/particle-triangle-experiment-r94")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(384,288)
	var viewport=SubViewport.new();viewport.size=Vector2i(96,96);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop=ColorRect.new();backdrop.size=Vector2(96,96);backdrop.color=Color(0.12,0.23,0.34,1);viewport.add_child(backdrop)
	var canvas=Canvas.new();canvas.fx=load("res://scripts/particle_fx.gd");canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;viewport.add_child(canvas)
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):image.set_pixel(x,y,Color(float(x)/15,float(y)/15,0.6,float((x+y)%7+1)/7))
	var texture=ImageTexture.create_from_image(image)
	for mode in ["straight","premultiplied"]:
		if mode=="premultiplied":
			var shader=Shader.new();shader.code="shader_type canvas_item; render_mode blend_premul_alpha; void fragment(){ COLOR.rgb *= texture(TEXTURE,UV).a; }"
			var material=ShaderMaterial.new();material.shader=shader;canvas.material=material
		for pose in ["opaque","fractional-alpha","rotated-overlap","clipped-fallback","vertex-ramp","clamped-hdr","alpha-boundaries","native-alpha","native-hdr","native-overlap"]:
			canvas.groups=[]
			for index in range(3 if pose=="rotated-overlap" else 1):
				var center=Vector2(39.375+index*7,41.125+index*5)
				var points=PackedVector2Array()
				for corner in [Vector2(-24,-21),Vector2(24,-21),Vector2(24,21),Vector2(-24,21)]:points.append(center+corner.rotated(index*0.33+0.137))
				var color=Color.WHITE if pose=="opaque" else Color(0.123,0.567,0.891,0.456)
				var colors=PackedColorArray([color,color,color,color])
				if pose=="vertex-ramp":colors=PackedColorArray([Color(0.0039215,0.499999,0.91,0.8),Color(0.1,0.9,0.2,0.8),Color(0.987,0.011,0.532,0.8),Color(0.765,0.432,0.123,0.8)])
				elif pose=="clamped-hdr":colors=PackedColorArray([Color(-0.1,1.25,0.25,1.2),Color(-0.1,1.25,0.25,1.2),Color(-0.1,1.25,0.25,1.2),Color(-0.1,1.25,0.25,1.2)])
				elif pose=="alpha-boundaries":colors=PackedColorArray([Color(1,0.3,0.2,0.0039),Color(1,0.3,0.2,0.004),Color(1,0.3,0.2,0.5),Color(1,0.3,0.2,0.999)])
				canvas.groups.append({"texture":texture,"vertices":points,"uvs":PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]),"colors":colors,"indices":PackedInt32Array([0,1,2,0,2,3])})
			if pose=="clipped-fallback":canvas.groups.append({"fallback":true,"texture":texture,"center":Vector2(24,25),"shape":Vector2(35,37),"region":Rect2(-2,-1,18,19),"rotation":0.3,"tint":Color(1,0.8,0.6,0.5)})
			var reference:Image
			for direct in [false,true]:
				if pose.begins_with("native-"):
					var rgba=[-0.1,1.25,0.25,1.2] if pose=="native-hdr" else [0.123,0.567,0.891,0.456]
					var definition={"real_alpha":int(mode=="premultiplied"),"color":rgba,"size":24,"life_cycle":1,"rotational":1}
					var particles=[]
					for i in range(3 if pose=="native-overlap" else 1):particles.append({"region":Rect2(-2,-1,18,19) if i==2 else Rect2(0,0,16,16),"born":0,"size_offset":0,"alpha":0.75+i*0.1,"rotation":0.137+i*0.33-PI/2,"pos":Vector2(39.375+i*7,41.125+i*5)})
					canvas.groups=SpiceNative.particle_batches([{"definition":definition,"texture":texture,"particles":particles}],mode=="premultiplied",0,Vector2.ZERO,1,direct)
				elif direct:
					# Mesh upload truncates/clamps each channel to RGBA8. The
					# direct path must preserve that existing numerical contract.
					for group in canvas.groups:
						if group.get("fallback",false):continue
						for i in range(group.colors.size()):
							var c=group.colors[i]
							group.colors[i]=Color(float(int(clampf(c.r*255,0,255)))/255,float(int(clampf(c.g*255,0,255)))/255,float(int(clampf(c.b*255,0,255)))/255,float(int(clampf(c.a*255,0,255)))/255)
				var before=canvas.draw_calls
				canvas.direct=direct;canvas.queue_redraw()
				await process_frame;await process_frame;RenderingServer.force_draw(true)
				var captured=viewport.get_texture().get_image()
				var name=mode+"-"+pose+("-triangles" if direct else "-mesh")
				checks+=1
				if captured==null or captured.save_png(output.path_join(name+".png"))!=OK:failures.append(name+" capture failed");continue
				captures.append(name)
				checks+=1
				if canvas.draw_calls<=before or captured.get_pixel(40,40)==captured.get_pixel(95,95):failures.append(name+" did not draw a visible test group")
				if not direct:reference=captured
				else:
					checks+=1
					if captured.get_data()!=reference.get_data():failures.append(mode+" "+pose+" differs in decoded RGBA")
	viewport.queue_free();await process_frame
	var report={"checks":checks,"failures":failures,"captures":captures,"method":"Source Godot4.7.2 native OpenGL, frozen96px geometry and native particle_batches including fallback; original renderer and whole-game performance outside scope. Mesh and direct RGBA compare after preserving existing reconstructed mesh RGBA8 conversion. This source-engine experiment does not verify a packaged app or original device."}
	var file=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PARTICLE_DRAW_EXPERIMENT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
