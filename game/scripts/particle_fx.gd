extends Control

const Math = preload("res://scripts/particle_math.gd")
const Owned=preload("res://scripts/particle_owned_view.gd")
const OwnedReference=preload("res://scripts/particle_child_view.gd")
class Layer extends Node2D:
	var fx
	var premultiplied=false
	func _draw() -> void:
		var started=Time.get_ticks_usec();fx.draw_layer(self,premultiplied);fx.app.record_qa_time("particle_draw",started)

const State=preload("res://scripts/particle_state.gd")
var state=State.new()
var app:
	get:return state.app
	set(value):state.app=value
var systems:Array[Dictionary]:
	get:return state.systems
	set(value):state.replace_systems(value)
var clock_ms:
	get:return state.clock_ms
	set(value):state.clock_ms=value
var clock_seconds:
	get:return state.clock_seconds
	set(value):state.clock_seconds=value
var random:
	get:return state.random
	set(value):state.random=value
var layers: Array[Layer]=[]
var serial:
	get:return state.serial
	set(value):state.serial=value
var owned_serial:
	get:return state.owned_serial
	set(value):state.owned_serial=value
var owned_prepared:
	get:return state.owned_prepared
	set(value):state.owned_prepared=value
var timers: Dictionary={}
var reference_emission:
	get:return state.reference_emission
	set(value):state.reference_emission=value
var reference_rendering=false
var direct_triangles=true
var coalesce_owned=true
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
	state.reset();timers.clear()
	# CanvasItem retains prior commands until its next draw notification.
	for layer in layers:layer.queue_redraw()

func use_state(value) -> void:
	var target=app;state=value;state.app=target

func emit_system(name: String, point: Vector2, variation: String = "", owner: String = "", duration_ms: int = 0, direction: Vector2 = Vector2.ZERO, object_owner: int = -1) -> void:
	state.emit_system(name,point,variation,owner,duration_ms,direction,object_owner)

func emit_creep_death_burst(resource:String,point:Vector2,variation:String="") -> void:
	state.emit_creep_death_burst(resource,point,variation)

func emit_definition(name:String,definition:Dictionary,texture:Texture2D,point:Vector2,variation:String="",owner:String="",duration_ms:int=-1,direction:Vector2=Vector2.ZERO,object_owner:int=-1) -> void:
	state.emit_definition(name,definition,texture,point,variation,owner,duration_ms,direction,object_owner)

func emit_batch(sys: Dictionary) -> void:
	state.emit_batch(sys)

func reference_emit_batch(sys: Dictionary) -> void:
	state.reference_emit_batch(sys)

func refresh_owners(sim) -> void:
	var owners={}
	# Preserve emitter order and multiple systems per owner while avoiding a
	# full systems scan for every enemy, missile and bubble each frame.
	var owner_systems={}
	for sys in systems:
		if str(sys.owner).is_empty():continue
		if not owner_systems.has(sys.owner):owner_systems[sys.owner]=[]
		owner_systems[sys.owner].append(sys)
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
		if bubble.get("managed_bubble",false):continue
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
		if zone.get("managed_cloud",false):continue
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
		if not sys.has("creep_owner") and not str(sys.owner).is_empty() and not owners.has(sys.owner):sys.emitting=false

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
			state.advance_unowned(dt)
	else:
		while clock_ms+30<=sim.clock_ms:
			clock_ms+=30
			state.advance_unowned(.03)
	for layer in layers:layer.queue_redraw()

func advance_ui(elapsed_ms:float) -> void:
	position=Vector2.ZERO;size=app.view_size()
	var dt=Math.f32(Math.f32(elapsed_ms)*Math.f32(0.001))
	clock_seconds=Math.f32(clock_seconds+Math.f32(dt*Math.f32(clock_multiplier)));clock_ms=clock_seconds*1000.0
	if dt>0:state.advance_unowned(dt)
	for layer in layers:layer.queue_redraw()

func draw_layer(layer: Layer, premultiplied: bool) -> void:
	if reference_rendering:reference_draws+=1;reference_draw_layer(layer,premultiplied);return
	batch_draws+=1
	if not is_instance_valid(app) or app.screen!="game":return
	var zoom=1.0 if screen_space else app.map_scale()
	var started=Time.get_ticks_usec()
	var groups=SpiceNative.particle_batches(systems,premultiplied,clock_ms,Vector2.ZERO if screen_space else app.map_origin()-position,zoom,direct_triangles,false,coalesce_owned)
	app.record_qa_time("particle_geometry",started)
	started=Time.get_ticks_usec()
	layer.set_meta("particle_meshes",draw_groups(layer,groups,zoom,direct_triangles))
	app.record_qa_time("particle_submit",started)

static func draw_groups(layer:CanvasItem,groups:Array,zoom:float,direct_triangles:bool=false) -> Array:
	var meshes=[]
	for group in groups:
		if group.get("fallback",false):
			layer.draw_set_transform(group.center,group.rotation,Vector2.ONE*zoom)
			layer.draw_texture_rect_region(group.texture,Rect2(-group.shape/2,group.shape),group.region,group.tint)
			layer.draw_set_transform(Vector2.ZERO)
			continue
		if direct_triangles:
			# Caller supplies the mesh-equivalent RGBA8 color conversion.
			RenderingServer.canvas_item_add_triangle_array(layer.get_canvas_item(),group.indices,group.vertices,group.colors,group.uvs,PackedInt32Array(),PackedFloat32Array(),group.texture.get_rid())
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
		if sys.get("owner_hidden",false):continue
		var definition=sys.definition
		if (int(definition.get("real_alpha",0))==1)!=premultiplied:continue
		if sys.has("owned_tree"):
			layer.draw_set_transform(Vector2.ZERO)
			layer.set_meta("owned_reference_meshes",draw_groups(layer,OwnedReference.batches(sys.owned_tree,origin,zoom),zoom,true))
			continue
		var rgba=definition.get("color",[1,1,1,1])
		for p in sys.particles:
			var age=Math.age(float(sys.get("view_clock_ms",clock_ms)),float(p.born))
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
		if sys.has("owned_tree"):
			if advance_owned_system(sys,dt,true):expired[sys.id]=true
			continue
		var definition=sys.definition
		var system_clock=clock_ms
		if sys.has("local_clock_seconds"):
			sys.local_clock_seconds=Math.f32(float(sys.local_clock_seconds)+dt)
			system_clock=float(sys.local_clock_seconds)*1000.0;sys.view_clock_ms=system_clock
		if float(sys.until)>=0 and system_clock>=float(sys.until):sys.emitting=false
		var disable=int(definition.get("disable_after",0))
		if disable>0 and system_clock-float(sys.born)>=disable:sys.emitting=false
		Math.advance_particles(sys.particles,definition,dt,system_clock)
		var amplitude=float(definition.get("amplifyX_withSin_by",0))
		var child=str(definition.get("child_system",""))
		if amplitude!=0 or not child.is_empty():
			for p in sys.particles:
				if amplitude!=0:
					var old=float(sys.phase);sys.phase=Math.f32(old+Math.f32(float(definition.get("amplification_speed",0))*dt))
					p.pos.x=Math.f32(p.pos.x+Math.f32(Math.f32(sin(sys.phase)-sin(old))*amplitude))
				if not child.is_empty() and system_clock-float(p.child_released)>50:
					p.child_released=system_clock;emit_system(child,p.pos,str(sys.variation))
		if sys.emitting and dt<float(definition.get("life_cycle",1)) and system_clock-float(sys.released)>float(definition.get("release_interval",1))*1000.0:emit_batch(sys)
		if not sys.emitting and sys.particles.is_empty():expired[sys.id]=true
	# Dictionary equality during Array.erase scans whole earlier emitter
	# records. Compact once, preserving live and newly emitted child order.
	if not expired.is_empty():systems=systems.filter(func(sys):return not expired.has(sys.id))

func reference_spawn_particle(sys:Dictionary,i:int) -> Dictionary:
	return state.reference_spawn_particle(sys,i)

func create_owned_tree(name:String,definition:Dictionary,texture:Texture2D,point:Vector2,variation:String) -> Dictionary:
	return state.create_owned_tree(name,definition,texture,point,variation)

func make_owned_child(name:String,texture:Texture2D,variation:String) -> Dictionary:
	return state.make_owned_child(name,texture,variation)

func make_owned_particle(tree:Dictionary,index:int,fresh:bool,old:Dictionary) -> Dictionary:
	return state.make_owned_particle(tree,index,fresh,old)

func advance_owned_system(sys:Dictionary,dt:float,reference:bool=false) -> bool:
	return state.advance_owned_system(sys,dt,reference)
