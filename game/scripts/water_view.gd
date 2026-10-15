extends Node2D

# Original CWater::Render0x95dd8 is a single additive strip after the map
# segments and before actors. Recovered float32 math supplies its vertices.
var settings:Dictionary={}
var source:Dictionary={}
var table:Dictionary={}
var mesh:ArrayMesh
var last_phase=-1.0

func _ready() -> void:
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode blend_add, unshaded;
uniform sampler2D water_texture : repeat_enable, filter_linear;
uniform sampler2D mask_texture : repeat_disable, filter_linear;
uniform vec2 mask_multiplier;
uniform float mask_v_origin;
varying vec2 mask_coord;
void vertex(){mask_coord=VERTEX*mask_multiplier+vec2(0.0,mask_v_origin);}
void fragment(){
    vec4 water=texture(water_texture,UV);
    vec4 mask=texture(mask_texture,mask_coord);
    // CgBI imports have straight alpha. Native GL samples premultiplied RGB
    // and uses ONE,ONE, so apply alpha here and keep additive source alpha1.
    COLOR=vec4(water.rgb*water.a*mask.rgb*mask.a*0.6,1.0);
}"""
	var value=ShaderMaterial.new();value.shader=shader;material=value

func prepare(definition:Dictionary,phase:float,origin:Vector2,map_scale:float) -> void:
	visible=not definition.is_empty()
	if not visible:return
	if source!=definition:
		source=definition.duplicate(true)
		settings=definition.duplicate(true)
		settings.plane=Vector2(definition.plane[0],definition.plane[1])
		settings.segments=Vector2(definition.segments[0],definition.segments[1])
		table=SpiceNative.water_table(int(definition.seed));last_phase=-1.0
		material.set_shader_parameter("water_texture",Content.tex(definition.texture))
		material.set_shader_parameter("mask_texture",Content.tex(definition.mask))
		var uv=definition.mask_uv;var factor=float(definition.mask_scale)
		material.set_shader_parameter("mask_multiplier",Vector2((uv[1]-uv[0])*factor/settings.plane.y,(uv[3]-uv[2])*factor/settings.plane.x))
		material.set_shader_parameter("mask_v_origin",float(uv[2]))
	# CMap::Load adds25 to hexes, objects and water for the iPad HUD. This
	# renderer keeps map-local coordinates before that common translation.
	position=origin+Vector2(definition.offset[0],definition.offset[1]-25)*map_scale
	scale=Vector2.ONE*map_scale
	if last_phase!=phase:
		var data=SpiceNative.water_vertices(table,settings,phase)
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_TEX_UV]=data.uvs
		mesh=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		last_phase=phase;queue_redraw()

func _draw() -> void:
	if mesh!=null:draw_mesh(mesh,null)
