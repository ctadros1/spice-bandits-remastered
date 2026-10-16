extends SceneTree
var checks=0
var failures=[]
func _initialize() -> void:run.call_deferred()
func check(value:bool,label:String) -> void:
	checks+=1
	if not value and failures.size()<20:failures.append(label)
func median(values:Array) -> float:
	values.sort();return float(values[values.size()/2])
func compare(systems:Array,clock:float,origin:Vector2,zoom:float,label:String) -> void:
	for premul in [false,true]:
		for quantized in [false,true]:
			var previous=SpiceNative.particle_batches(systems,premul,clock,origin,zoom,quantized,true)
			var prepared=SpiceNative.particle_batches(systems,premul,clock,origin,zoom,quantized,false)
			check(var_to_bytes(previous)==var_to_bytes(prepared),label+str([premul,quantized]))
func run() -> void:
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.8,.7))
	var textures=[ImageTexture.create_from_image(image),ImageTexture.create_from_image(image)]
	var systems=[]
	for i in range(256):
		var particles=[]
		for j in range(12):particles.append({"region":Rect2(0,0,16,16),"born":0.0,"size_offset":float(j%3)-1,"alpha":float(j%7)/6,"rotation":.137+float(i%5)*.17-PI/2,"pos":Vector2(12+(i*13+j*29)%296,12+(i*7+j*17)%216)})
		var definition={"real_alpha":i%2,"color":[.123,.567,.891,.456],"size":12.0,"life_cycle":1.3,"rotational":1,"scalable":1,"scale":.6,"use_real_size":i%3==0}
		systems.append({"definition":definition,"texture":textures[int(i/2)%2],"particles":particles,"owner_hidden":i%17==0})
	for clock in [0.0,30.0,399.99,1000.0]:
		for origin in [Vector2.ZERO,Vector2(120.125,-73.6)]:
			for zoom in [.5,.85,1.0,1.3]:compare(systems,clock,origin,zoom,"dense geometry")
	for i in range(48):
		var definition={} if i%4==0 else {"real_alpha":i%2,"color":[-.1,1.25,.25,1.2],"size":float(i%5)+1,"life_cycle":.3,"scalable":1,"scale":float(i%3),"rotational":i%2,"use_real_size":i%3==0}
		var particle={"region":Rect2(-2,-1,18,19) if i%3==0 else Rect2(0,0,16,16),"born":23.0,"size_offset":.75,"alpha":.25,"rotation":.23,"pos":Vector2(19,24)}
		var sys={"definition":definition,"texture":textures[i%2],"particles":[particle],"view_clock_ms":float(i*9)}
		compare([sys],90,Vector2(10,-3),.7,"fallback/default/clock "+str(i))
		definition.color=[.9,.2,.7,.3];particle.region=Rect2(1,2,9,7);particle.alpha=.8
		compare([sys],90,Vector2(10,-3),1.0,"mutable input "+str(i))
	var phases=[]
	for reference in [true,false,false,true]:
		var samples=[]
		for sample in range(8):
			var started=Time.get_ticks_usec()
			for repeat in range(8):
				for premul in [false,true]:SpiceNative.particle_batches(systems,premul,400,Vector2(120.125,-73.6),.85,true,reference)
			samples.append((Time.get_ticks_usec()-started)/8.0)
		phases.append({"reference_text_keys":reference,"samples":8,"both_layer_pairs_per_sample":8,"median_us_both_layers":median(samples)})
	var report={"checks":checks,"failures":failures,"systems":256,"supplied_particles":3072,"phases":phases,"method":"Headless ABBA fixed geometry comparison: original text-key/native geometry vs interned-key+immutable-white-default path. Exact serialized group dictionaries, indices, UV, RGBA and vertex bytes including fallback/default/mutable definitions and per-owner clocks. No source arithmetic/render order/color quantization change. This bounded CPU result is not original GPU equivalence or a live inter-build speedup."}
	var file=FileAccess.open("res://../builds/particle-keys-benchmark-r128.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PARTICLE_KEYS_BENCHMARK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
