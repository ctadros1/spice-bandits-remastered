extends Node2D
const POINTS=[Vector2(955,1368),Vector2(917,1385),Vector2(945,1417),Vector2(891,1419),Vector2(925,1447)]
var angles=[]
var speeds=[]
var items=[]
static func f32(value:float) -> float:return PackedFloat32Array([value])[0]
static func geometry(point:Vector2,offset:Vector2=Vector2.ZERO) -> PackedVector2Array:
	var p=point+offset
	return PackedVector2Array([p+Vector2(0,-10),p+Vector2(32,10),p+Vector2(0,22),p+Vector2(32,42)])
static func advance_angles(values:Array,ratios:Array,dt_ms:float) -> void:
	for i in range(values.size()):values[i]=f32(values[i]+f32(f32(f32(dt_ms)/6.0)*f32(ratios[i])))
func setup(is_qa:bool) -> void:
	var random=RandomNumberGenerator.new()
	if is_qa:random.seed=114
	else:random.randomize()
	var shader=Shader.new()
	# Native RenderBlades rotates the texture matrix around UV0.5,0.5;
	# its world quad stays sheared. Do not rotate or stretch the whole image.
	shader.code="shader_type canvas_item; uniform float angle=0.0; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){float c=cos(angle);float s=sin(angle);vec2 p=UV-vec2(0.5);vec2 uv=vec2(c*p.x-s*p.y,s*p.x+c*p.y)+vec2(0.5);COLOR=texture(TEXTURE,uv)*tint;}"
	for point in POINTS:
		angles.append(float(random.randi()%360))
		speeds.append(f32(f32(float(random.randi()%8)/10.0)+f32(0.7)))
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=geometry(point)
		arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)])
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,2,1,3])
		var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var item=MeshInstance2D.new();item.mesh=mesh;item.texture=load("res://assets/lobby/blades.png")
		var material=ShaderMaterial.new();material.shader=shader;item.material=material
		add_child(item);items.append(item)
	visible=false
func advance(dt_ms:float) -> void:advance_angles(angles,speeds,dt_ms)
func prepare(app) -> void:
	visible=app.screen=="world"
	if not visible:return
	position=app.world_origin();scale=Vector2.ONE*app.world_zoom
	for i in range(items.size()):items[i].material.set_shader_parameter("angle",deg_to_rad(angles[i]))
