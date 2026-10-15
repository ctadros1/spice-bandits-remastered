extends Control

const Math = preload("res://scripts/particle_math.gd")
class Layer extends Node2D:
	var fx
	var premultiplied=false
	func _draw() -> void:
		var started=Time.get_ticks_usec();fx.draw_layer(self,premultiplied);fx.app.record_qa_time("particle_draw",started)

var app
var systems: Array[Dictionary]=[]
var clock_ms=0.0
var clock_seconds=0.0
var random=RandomNumberGenerator.new()
var layers: Array[Layer]=[]
var serial=0
var timers: Dictionary={}
var reference_emission=false
var reference_rendering=false
var reference_draws=0
var batch_draws=0
var screen_space=false
var clock_multiplier=1.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	random.seed=114
	for premultiplied in [false,true]:
		var layer=Layer.new();layer.fx=self;layer.premultiplied=premultiplied
		if premultiplied:
			var shader=Shader.new()
			shader.code="shader_type canvas_item; render_mode blend_premul_alpha; void fragment(){ COLOR.rgb *= texture(TEXTURE,UV).a; }"
			var material=ShaderMaterial.new();material.shader=shader;layer.material=material
		add_child(layer);layers.append(layer)

func reset() -> void:
	systems.clear();timers.clear();clock_ms=0.0;clock_seconds=0.0;serial=0;random.seed=114

func emit_system(name: String, point: Vector2, variation: String = "", owner: String = "", duration_ms: int = 0, direction: Vector2 = Vector2.ZERO, object_owner: int = -1) -> void:
	var started=Time.get_ticks_usec()
	var definition=Content.particles.systems.get(name,{})
	if definition.is_empty() or str(definition.texture).is_empty():return
	var texture=Content.tex(definition.variations.get(variation,definition.texture))
	if texture==null:return
	emit_definition(name,definition,texture,point,variation,owner,duration_ms,direction,object_owner)
	if is_instance_valid(app):app.record_qa_time("particle_emit_system",started)

func emit_definition(name:String,definition:Dictionary,texture:Texture2D,point:Vector2,variation:String="",owner:String="",duration_ms:int=-1,direction:Vector2=Vector2.ZERO,object_owner:int=-1) -> void:
	serial+=1
	var sys={"id":serial,"name":name,"definition":definition,"native_coefficients":SpiceNative.compile_particle(definition),"texture":texture,"pos":point,"direction":direction,"owner":owner,"object_owner":object_owner,"particles":[],"variation":variation,"born":clock_ms,"released":clock_ms,"until":clock_ms+duration_ms if duration_ms>=0 else -1,"emitting":duration_ms!=0,"phase":0.0}
	systems.append(sys)
	emit_batch(sys)

func emit_batch(sys: Dictionary) -> void:
	var started=Time.get_ticks_usec()
	if reference_emission:reference_emit_batch(sys)
	else:SpiceNative.emit_batch(sys,clock_ms,random)
	if is_instance_valid(app):app.record_qa_time("particle_emit_batch",started)

func reference_emit_batch(sys: Dictionary) -> void:
	var definition=sys.definition
	var number=int(definition.get("num_release",1))
	for i in range(number):
		if sys.particles.size()>=int(definition.get("max_particles",100)):break
		var rectangles=definition.texture_list
		var rect=rectangles[random.randi_range(0,rectangles.size()-1)] if not rectangles.is_empty() else {"x":definition.get("tx",0),"y":definition.get("ty",0),"w":definition.get("tw",sys.texture.get_width()),"h":definition.get("th",sys.texture.get_height())}
		var region=Rect2(float(rect.x),float(rect.y),float(rect.w),float(rect.h))
		var velocity_values=definition.get("velocity",[0,0])
		var velocity=Vector2(float(velocity_values[0]),float(velocity_values[1]))
		var point:Vector2=sys.pos
		if int(definition.get("circled_emission",0)):
			var angle=TAU*i/maxi(1,number)+deg_to_rad(random.randf_range(-float(definition.get("circle_angle_var",0)),float(definition.get("circle_angle_var",0))))
			var heading=Vector2(cos(angle),sin(angle))
			point+=heading*float(definition.get("circle_radius",0))
			velocity=heading*(float(definition.get("circle_vel_amount",0))+random.randf_range(0,float(definition.get("velocity_var",1))))
		else:velocity+=Vector2.from_angle(random.randf()*TAU)*float(definition.get("velocity_var",1))
		var rot_speed=float(definition.get("rot_speed",1.0))
		if random.randi_range(0,99)<int(definition.get("rot_dir_rand",0)):rot_speed*=1 if random.randi()%2 else -1
		var rotation=float(definition.get("rot_angle",0))
		var rot_variation=float(definition.get("rot_angle_var",0))
		rotation+=random.randf_range(-rot_variation/2,rot_variation/2)
		var size_offset=random.randf_range(-float(definition.get("size_init_var",0)),float(definition.get("size_init_var",0)))
		var p={"pos":point,"velocity":velocity,"rotation":rotation,"rot_speed":rot_speed,"alpha":0.0 if float(definition.get("fade_in_time",0))>0 else 1.0,"born":clock_ms,"region":region,"size_offset":size_offset,"child_released":clock_ms}
		sys.particles.push_front(p)
	sys.released=clock_ms

func refresh_owners(sim) -> void:
	var owners={}
	# Preserve emitter order and multiple systems per owner while avoiding a
	# full systems scan for every enemy, missile and bubble each frame.
	var owner_systems={}
	for sys in systems:
		if str(sys.owner).is_empty():continue
		if not owner_systems.has(sys.owner):owner_systems[sys.owner]=[]
		owner_systems[sys.owner].append(sys)
	for e in sim.enemies:
		if e.hp<=0:continue
		var name="creeps/"+str(e.def.filename)
		var bindings=Content.particles.bindings.get(name,{})
		var aliases=[]
		if sim.clock_ms<sim.freeze_until or e.slow<1.0:aliases.append("freeze")
		if sim.clock_ms<e.disco_until:aliases.append("lsd")
		if float(e.get("poison_count",0))>0:
			var radiation=sim.zones.any(func(z):return int(z.type)==5 and not z.has("bubble") and e.pos.distance_to(z.pos)<float(z.def.get("poison_range",0))*float(sim.map.hex_h)/1000.0)
			aliases.append("radiation" if radiation else "poison")
		if e.hp<e.max_hp*0.6000000238418579:aliases.append("smoke")
		if str(e.def.filename) in ["creep5","creep6"]:aliases.append("hover_flow2")
		for alias in aliases:
			var binding=bindings.get(alias,{})
			if binding.is_empty():continue
			var owner="enemy:%d:%s" % [e.id,alias]
			owners[owner]=true
			var found=false
			for sys in owner_systems.get(owner,[]):
				sys.pos=e.get("visual_pos",e.pos);sys.emitting=true;found=true
			if not found:emit_system(str(binding.filename),e.get("visual_pos",e.pos),str(e.def.get("color","")),owner,-1,e.dir)
	for b in sim.bases:
		if b.hp>=b.hpmax*0.5:continue
		var owner="base:%s:%s" % [b.x,b.y]
		owners[owner]=true
		var found=false
		for sys in owner_systems.get(owner,[]):
			sys.pos=b.pos;found=true
		if not found:emit_system("BaseSmoke",b.pos,"",owner,-1)
	for missile in sim.missiles:
		if not bool(missile.get("active",true)):continue
		var owner="tower:%d:missile:%d:%s" % [missile.owner,missile.launch_ms,str(missile.origin)]
		owners[owner]=true
		var found=false
		for sys in owner_systems.get(owner,[]):
			sys.pos=missile.pos;found=true
		if not found:emit_system("MissileNukeRail" if int(missile.type)==5 else "MissileRail",missile.pos,"",owner,-1,Vector2.ZERO,int(missile.owner))
	for bubble in sim.bubbles:
		if not bubble.active:continue
		var owner="tower:%d:bubble" % int(bubble.owner)
		owners[owner]=true
		var found=false
		for sys in owner_systems.get(owner,[]):
			sys.pos=bubble.pos;found=true
		if not found:emit_system("GooBubbleTrail" if int(bubble.type)==8 else "PoisonBubbleTrail",bubble.pos,"",owner,-1,Vector2.ZERO,int(bubble.owner))
	# CPoison::Update0xe1268 creates cloud emitters every80ms, or radiation
	# debris every60ms. Visual randomness is isolated from combat randomness.
	var live_timers={}
	for zone in sim.zones:
		if zone.has("bubble"):continue
		var key="cloud:%d:%d:%s:%d" % [zone.owner,zone.type,str(zone.pos),zone.until]
		live_timers[key]=true
		var interval=60 if int(zone.type)==5 else 80
		if sim.clock_ms-int(timers.get(key,sim.clock_ms-interval))<interval:continue
		timers[key]=sim.clock_ms
		var radius=float(zone.def.get("poison_range",0))*float(sim.map.hex_h)/1000.0
		var point=zone.pos+Vector2.from_angle(random.randf()*TAU)*random.randf_range(radius/6.0,radius/1.5)
		var name="RadiationDebris" if int(zone.type)==5 else "GooCloud" if int(zone.type)==8 else "PoisonCloud"
		if int(zone.type)==5:point.y-=500
		emit_system(name,point,"","",1200,Vector2.ZERO,int(zone.owner))
	for key in timers.keys():
		if not live_timers.has(key):timers.erase(key)
	for sys in systems:
		if not str(sys.owner).is_empty() and not owners.has(sys.owner):sys.emitting=false

func remove_owner(id: int) -> void:
	if id<0:return
	systems=systems.filter(func(sys):return int(sys.object_owner)!=id)

func advance(sim, elapsed_ms: float = -1.0) -> void:
	visible=app.screen=="game"
	position=Vector2(0,35);size=app.view_size()-Vector2(0,95)
	if not visible:return
	var owner_started=Time.get_ticks_usec()
	refresh_owners(sim)
	app.record_qa_time("particle_owners",owner_started)
	if elapsed_ms>=0.0:
		if not sim.paused and sim.outcome=="playing":
			# Original callers pass elapsed milliseconds as f32 seconds. Each
			# system advances once per live frame, independently of room truncation.
			var dt=Math.f32(Math.f32(elapsed_ms)*Math.f32(0.001))
			clock_seconds=Math.f32(clock_seconds+dt)
			clock_ms=clock_seconds*1000.0
			SpiceNative.advance_systems(systems,clock_ms,emit_system,emit_batch,random,dt)
	else:
		while clock_ms+30<=sim.clock_ms:
			clock_ms+=30
			SpiceNative.advance_systems(systems,clock_ms,emit_system,emit_batch,random)
	for layer in layers:layer.queue_redraw()

func advance_ui(elapsed_ms:float) -> void:
	position=Vector2.ZERO;size=app.view_size()
	var dt=Math.f32(Math.f32(elapsed_ms)*Math.f32(0.001))
	clock_seconds=Math.f32(clock_seconds+Math.f32(dt*Math.f32(clock_multiplier)));clock_ms=clock_seconds*1000.0
	if dt>0:SpiceNative.advance_systems(systems,clock_ms,emit_system,emit_batch,random,dt)
	for layer in layers:layer.queue_redraw()

func draw_layer(layer: Layer, premultiplied: bool) -> void:
	if reference_rendering:reference_draws+=1;reference_draw_layer(layer,premultiplied);return
	batch_draws+=1
	if not is_instance_valid(app) or app.screen!="game":return
	var zoom=1.0 if screen_space else app.map_scale()
	var groups=SpiceNative.particle_batches(systems,premultiplied,clock_ms,Vector2.ZERO if screen_space else app.map_origin()-position,zoom)
	layer.set_meta("particle_meshes",draw_groups(layer,groups,zoom))

static func draw_groups(layer:CanvasItem,groups:Array,zoom:float) -> Array:
	var meshes=[]
	for group in groups:
		if group.get("fallback",false):
			layer.draw_set_transform(group.center,group.rotation,Vector2.ONE*zoom)
			layer.draw_texture_rect_region(group.texture,Rect2(-group.shape/2,group.shape),group.region,group.tint)
			layer.draw_set_transform(Vector2.ZERO)
			continue
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=group.vertices;arrays[Mesh.ARRAY_TEX_UV]=group.uvs;arrays[Mesh.ARRAY_COLOR]=group.colors;arrays[Mesh.ARRAY_INDEX]=group.indices
		var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		meshes.append(mesh);layer.draw_mesh(mesh,group.texture)
	return meshes

func reference_draw_layer(layer: Layer, premultiplied: bool) -> void:
	if not is_instance_valid(app) or app.screen!="game":return
	var origin=app.map_origin()-position
	var zoom=app.map_scale()
	for sys in systems:
		var definition=sys.definition
		if (int(definition.get("real_alpha",0))==1)!=premultiplied:continue
		var rgba=definition.get("color",[1,1,1,1])
		for p in sys.particles:
			var age=Math.age(clock_ms,float(p.born))
			var half=Math.f32((float(definition.get("size",1))+float(p.size_offset))*Math.size_factor(age,definition))
			var shape=p.region.size*half if int(definition.get("use_real_size",0)) else Vector2.ONE*half*2
			var tint=Color(rgba[0],rgba[1],rgba[2],float(rgba[3])*maxf(0,float(p.alpha)))
			if premultiplied:tint.r*=p.alpha;tint.g*=p.alpha;tint.b*=p.alpha
			var rotation=float(p.rotation)+PI/2 if int(definition.get("rotational",0)) else 0.0
			layer.draw_set_transform(origin+p.pos*zoom,rotation,Vector2.ONE*zoom)
			layer.draw_texture_rect_region(sys.texture,Rect2(-shape/2,shape),p.region,tint)
	layer.draw_set_transform(Vector2.ZERO)

func reference_advance_tick(dt: float = 0.03) -> void:
	dt=Math.f32(dt)
	var expired={}
	for sys in systems.duplicate():
		var definition=sys.definition
		if float(sys.until)>=0 and clock_ms>=float(sys.until):sys.emitting=false
		var disable=int(definition.get("disable_after",0))
		if disable>0 and clock_ms-float(sys.born)>=disable:sys.emitting=false
		Math.advance_particles(sys.particles,definition,dt,clock_ms)
		var amplitude=float(definition.get("amplifyX_withSin_by",0))
		var child=str(definition.get("child_system",""))
		if amplitude!=0 or not child.is_empty():
			for p in sys.particles:
				if amplitude!=0:
					var old=float(sys.phase);sys.phase=Math.f32(old+Math.f32(float(definition.get("amplification_speed",0))*dt))
					p.pos.x=Math.f32(p.pos.x+Math.f32(Math.f32(sin(sys.phase)-sin(old))*amplitude))
				if not child.is_empty() and clock_ms-float(p.child_released)>50:
					p.child_released=clock_ms;emit_system(child,p.pos,str(sys.variation))
		if sys.emitting and dt<float(definition.get("life_cycle",1)) and clock_ms-float(sys.released)>float(definition.get("release_interval",1))*1000.0:emit_batch(sys)
		if not sys.emitting and sys.particles.is_empty():expired[sys.id]=true
	# Dictionary equality during Array.erase scans whole earlier emitter
	# records. Compact once, preserving live and newly emitted child order.
	if not expired.is_empty():systems=systems.filter(func(sys):return not expired.has(sys.id))
