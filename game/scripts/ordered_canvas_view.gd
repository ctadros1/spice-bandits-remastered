extends Node2D
# Ordered contiguous draw spans. Each callback executes while its own CanvasItem
# is drawing, so a per-owner additive span can precede later normal owners.
class Span extends Node2D:
	var commands:Array=[]
	var before_draw:Callable
	var after_draw:Callable
	var pass_canvas=true
	func _draw() -> void:
		if before_draw.is_valid():before_draw.call(self)
		for command in commands:
			if pass_canvas:command.call(self)
			else:command.call()
		if after_draw.is_valid():after_draw.call(self)
var before_draw:Callable
var after_draw:Callable
var pass_canvas=true
var spans:Array[Span]=[]
var premultiplied_material:ShaderMaterial
var additive_material:ShaderMaterial
func _init() -> void:
	var shader=Shader.new()
	# The source ONE/ONE pass samples preserved premultiplied RGB. The app's
	# opaque canvas keeps destination alpha; raw source alpha must not be
	# multiplied into RGB a second time by Godot's additive SRC_ALPHA path.
	shader.code="shader_type canvas_item; render_mode blend_add, unshaded; void fragment(){ COLOR=vec4(texture(TEXTURE,UV).rgb*0.2,1.0); }"
	additive_material=ShaderMaterial.new();additive_material.shader=shader
	var premultiplied=Shader.new()
	premultiplied.code="shader_type canvas_item; render_mode blend_premul_alpha; void fragment(){ COLOR.rgb *= texture(TEXTURE,UV).a; }"
	premultiplied_material=ShaderMaterial.new();premultiplied_material.shader=premultiplied
func prepare(commands:Array) -> void:
	var count=0
	var previous_mode=-1
	for entry in commands:
		var mode=1 if bool(entry.get("additive",false)) else 2 if bool(entry.get("premultiplied",false)) else 0
		if count==0 or mode!=previous_mode:
			if count==spans.size():
				var span=Span.new();add_child(span);spans.append(span)
			var span=spans[count]
			span.before_draw=before_draw;span.after_draw=after_draw;span.pass_canvas=pass_canvas;span.commands.clear();span.material=additive_material if mode==1 else premultiplied_material if mode==2 else null;span.visible=true
			count+=1;previous_mode=mode
		spans[count-1].commands.append(entry.draw)
	for i in spans.size():
		if i<count:spans[i].queue_redraw()
		else:spans[i].commands.clear();spans[i].visible=false
