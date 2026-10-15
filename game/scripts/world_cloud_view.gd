extends Node2D
# AddClouds0x8e610; each constructor produces50 systems before the two
# later color overrides. Generator updates occur only inside RenderClouds.
const Math=preload("res://scripts/world_cloud_math.gd")
const ParticleFX=preload("res://scripts/particle_fx.gd")
const GENERATORS=Math.GENERATORS
var app
var generators=[]
var random=RandomNumberGenerator.new()
var definitions={}
var texture
var initialized=false
var pending_ms=0.0
var rendered=[]

func setup(is_qa:bool) -> void:
	if is_qa:random.seed=114
	else:random.randomize()
	var shader=Shader.new()
	shader.code="shader_type canvas_item; render_mode blend_premul_alpha; void fragment(){ COLOR.rgb *= texture(TEXTURE,UV).a; }"
	var material_instance=ShaderMaterial.new();material_instance.shader=shader;material=material_instance
	visible=false

func reset() -> void:
	generators.clear();definitions.clear();initialized=false;pending_ms=0.0;rendered.clear()
	if app.test_session:random.seed=114
	queue_redraw()

func initialize() -> void:
	texture=Content.tex(Content.particles.systems.Cloud.texture)
	for gain in [1.0,0.5]:
		var definition=Content.particles.systems.Cloud.duplicate(true)
		# Native compile caching keys include the definition name. These names
		# distinguish caller overrides of the same preserved Cloud resource.
		definition.name="Cloud:lobby:"+str(gain);definition.disable_after=4000
		definition.color=[0.5*gain,0.5*gain,0.5*gain,0.5*gain]
		definitions[gain]=definition
	for source in GENERATORS:
		var generator={"source":Math.setup_record(source),"timer":0.0,"systems":[]}
		generators.append(generator)
		var initial_source=generator.source.duplicate(true)
		initial_source.color_override=false;initial_source.color_gain=1.0
		for i in range(50):create_system(generator,true,initial_source)
	initialized=true

func create_system(generator:Dictionary,initial:bool,source:Dictionary={}) -> void:
	if source.is_empty():source=generator.source
	var direction=Vector2.from_angle(random.randf()*TAU)
	var pose=Math.produce(source,direction,int(random.randi()&0x7fffffff),random.randf_range(0.7,1.0),initial)
	var gain=1.0 if not source.color_override else float(source.color_gain)
	var definition=definitions[gain]
	var system={"id":1,"name":"Cloud","definition":definition,"native_coefficients":SpiceNative.compile_particle(definition),"texture":texture,"pos":pose.position,"direction":Vector2.ZERO,"owner":"","object_owner":-1,"particles":[],"variation":"","born":0.0,"released":0.0,"until":pose.emission_seconds*1000.0,"emitting":true,"phase":0.0}
	var record={"systems":[system],"clock_seconds":0.0,"clock_ms":0.0,"ratio":pose.clock_ratio}
	generator.systems.append(record);generator.timer=0.0
	if initial:SpiceNative.emit_batch(system,0.0,random)

func advance(dt_ms:float) -> void:pending_ms=dt_ms

func prepare() -> void:
	visible=app.screen=="world"
	if not visible:pending_ms=0.0;return
	if not initialized:initialize()
	var started=Time.get_ticks_usec()
	rendered.clear()
	for generator in generators:
		if not Math.intersects(generator.source,app.world_zoom,app.world_origin(),app.view_size()):continue
		rendered.append(generator)
		var step=Math.spawn_step(generator.timer,generator.systems.size(),int(generator.source.capacity),pending_ms)
		generator.timer=step.timer
		if step.spawn:create_system(generator,false)
		var dt=Math.particle_step(generator.source.rate,pending_ms)
		# UpdateParticles removes systems already dead before calling Update;
		# a system that expires during this call occupies its slot until the
		# next render, including the earlier capacity check in Update.
		generator.systems=generator.systems.filter(func(record):return not record.systems.is_empty())
		# Each original particle system has a separate clock multiplier;
		# velocities/gravity use the unscaled generator timestep.
		for record in generator.systems:
			record.clock_seconds=Math.f32(record.clock_seconds+Math.f32(dt*record.ratio))
			record.clock_ms=record.clock_seconds*1000.0
			if dt>0:SpiceNative.advance_systems(record.systems,record.clock_ms,Callable(),Callable(),random,dt)
	pending_ms=0.0
	app.record_qa_time("world_cloud_update",started)
	queue_redraw()

func _draw() -> void:
	if not visible:return
	var started=Time.get_ticks_usec();var systems=[]
	for generator in rendered:
		for record in generator.systems:
			for system in record.systems:system.view_clock_ms=record.clock_ms;systems.append(system)
	var groups=SpiceNative.particle_batches(systems,true,0.0,app.world_origin(),app.world_zoom)
	set_meta("particle_meshes",ParticleFX.draw_groups(self,groups,app.world_zoom))
	app.record_qa_time("world_cloud_draw",started)
