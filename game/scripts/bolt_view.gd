extends RefCounted

# CBolt constructor0xdcfe0: seven points,10px perturbation, two ribbon
# buffers; Update0xddc5c retains150ms then fades over200ms. The source
# global random stream and exact two-pass blending remain comparison gaps.
static func f32(value:float) -> float:return Vector2(value,0).x
static func clock() -> Dictionary:return {"enabled":true,"alive":true,"age":0.0,"fade":0.0,"opacity":1.0}

static func reset_clock(state:Dictionary) -> void:
	# ResetVisibility0xdd720 intentionally leaves the fade accumulator intact.
	state.age=0.0;state.opacity=1.0;state.alive=true

static func advance_clock(state:Dictionary,delta_ms:float) -> void:
	if not state.enabled or not state.alive:return
	delta_ms=f32(delta_ms)
	state.age=f32(state.age+delta_ms)
	if state.age<150:return
	state.fade=f32(state.fade+delta_ms)
	state.opacity=clampf(f32(1.0-f32(state.fade/200.0)),0,1)
	if state.opacity<=0:state.alive=false;state.fade=0.0

static func source_point(center:Vector2,offset:Vector2=Vector2.ZERO) -> Vector2:
	return Vector2(f32(center.x+offset.x),f32(f32(center.y-7)+offset.y))

static func opacity(effect:Dictionary,clock_ms:int) -> float:
	if effect.has("bolt_clock"):return effect.bolt_clock.opacity if effect.bolt_clock.alive else 0.0
	var age=clock_ms-int(effect.born)
	return 1.0 if age<150 else clampf(1.0-float(age-150)/200.0,0,1)
static func construct(start:Vector2,end:Vector2,vectors:PackedVector2Array,scatter:bool=false) -> PackedVector2Array:
	var target=end
	var offset=0
	if scatter:
		target=Vector2(f32(end.x+f32(vectors[0].x*8)),f32(end.y+f32(vectors[0].y*8)));offset=1
	var step=Vector2(f32(f32(target.x-start.x)/6),f32(f32(target.y-start.y)/6))
	var point=start
	var result=PackedVector2Array()
	for i in range(7):
		var jitter=Vector2.ZERO if i in [0,6] else vectors[offset+i-1]
		result.append(Vector2(f32(point.x+f32(jitter.x*10)),f32(point.y+f32(jitter.y*10))))
		point=Vector2(f32(point.x+step.x),f32(point.y+step.y))
	return result

static func caller_flags(type:int,active_defense:bool) -> Dictionary:
	# Original CTower call suffixes0xe497a/0xe6402/0xe6850.
	return {"scatter":active_defense or type==12,"ball":not active_defense and type in [10,12]}

static func texture_path(parameters:Dictionary,type:int,active_defense:bool) -> String:
	var path="sfx/electric_bolt_red.png" if active_defense else str(parameters.get("custom_bolt","sfx/laser_beam_yellow.png" if type==11 else "sfx/electric_bolt.png"))
	return path if path.begins_with("res://") or path.begins_with("assets/") else "assets/"+path

static func ball_rect(source:Vector2,size:Vector2i=Vector2i(64,64)) -> Rect2:
	# Render0xddd1a halves integer content dimensions, truncating toward zero.
	return Rect2(Vector2(f32(source.x-int(size.x/2.0)),f32(source.y-int(size.y/2.0))),Vector2(size))

static func ball_uv(flip_h:bool,flip_v:bool) -> PackedVector2Array:
	var a=Vector2(1 if flip_h else 0,1 if flip_v else 0)
	var b=Vector2(0 if flip_h else 1,0 if flip_v else 1)
	return PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)])

static func sample(start:Vector2,end:Vector2,seed_value:int,scatter:bool,ball:bool) -> Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	# Construct recalculates normal UVs before each independent random flip.
	# This separate visual stream does not claim the original global RNG order.
	var flips=Vector2i.ZERO
	if ball:flips=Vector2i(int(rng.randi()%2==0),int(rng.randi()%2==0))
	var vectors=PackedVector2Array()
	for i in range(6 if scatter else 5):vectors.append(SpiceNative.projected_random_vector(rng.randi_range(0,0x7fffffff),rng.randi_range(0,0x7fffffff)))
	return {"points":construct(start,end,vectors,scatter),"ball_flip":flips}

static func points(start: Vector2, end: Vector2, seed_value: int) -> PackedVector2Array:
	return sample(start,end,seed_value,false,false).points

static func draw_balls(canvas:CanvasItem,effects:Array,clock_ms:int) -> void:
	var texture=Content.tex("assets/sfx/bolt_ball3_small.png")
	for effect in effects:
		if effect.kind!="shot" or not effect.get("ball",false):continue
		var alpha=opacity(effect,clock_ms)
		var rect=ball_rect(effect.ball_source)
		var p=rect.position;var s=rect.size
		var flips:Vector2i=effect.ball_flip
		canvas.draw_primitive(PackedVector2Array([p,p+Vector2(s.x,0),p+s,p+Vector2(0,s.y)]),PackedColorArray([Color(1,1,1,alpha)]),ball_uv(flips.x!=0,flips.y!=0),texture)

static func draw(canvas: CanvasItem, path: PackedVector2Array, texture: Texture2D, age_ms: int, half_width: float = 3.0) -> void:
	if texture==null or path.size()<2:return
	var opacity=1.0 if age_ms<150 else clampf(1.0-float(age_ms-150)/200.0,0,1)
	var uvs=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	for i in range(path.size()-1):
		if path[i].distance_squared_to(path[i+1])<0.000001:continue
		var current=(path[i+1]-path[i]).normalized().orthogonal()
		var previous=(path[i]-path[i-1]).normalized().orthogonal() if i>0 else current
		var following=(path[i+2]-path[i+1]).normalized().orthogonal() if i+2<path.size() else current
		var a=(current+previous).normalized()*half_width
		var b=(current+following).normalized()*half_width
		var vertices=[path[i]+a,path[i]-a,path[i+1]-b,path[i+1]+b]
		var color=PackedColorArray([Color(1,1,1,opacity)])
		# Native triangle strips can fold at a short/reversed segment. Submit
		# explicit triangles; polygon ear clipping rejects those valid strips.
		canvas.draw_primitive(PackedVector2Array([vertices[0],vertices[1],vertices[2]]),color,PackedVector2Array([uvs[0],uvs[1],uvs[2]]),texture)
		canvas.draw_primitive(PackedVector2Array([vertices[0],vertices[2],vertices[3]]),color,PackedVector2Array([uvs[0],uvs[2],uvs[3]]),texture)

static func ribbon(path:PackedVector2Array, pass_id:int, opacity:float=1.0) -> Dictionary:
	return SpiceNative.bolt_ribbon(path,pass_id,opacity)

static func reference_ribbon(path:PackedVector2Array, pass_id:int, opacity:float=1.0) -> Dictionary:
	# Original FillBuffer0xdd748 uses the following segment's normal at each
	# joint averaged with the incoming direction, decreasing integer widths
	# and transparent caps. The earlier uniform3px quads omitted this taper.
	var vertices=PackedVector2Array();var uvs=PackedVector2Array();var colors=PackedColorArray()
	var count=path.size()-1
	if count<2:return {"vertices":vertices,"uvs":uvs,"colors":colors,"indices":PackedInt32Array()}
	var divisor=count-1
	var intensity=1.0 if pass_id==1 else float(int(opacity*255.0*0.25))/255.0
	var alpha=opacity if pass_id==1 else intensity
	var first_width=int((count+1)*(12 if pass_id==1 else 24)/divisor)
	var normal=-(path[1]-path[0]).normalized().orthogonal()
	vertices.append_array(PackedVector2Array([path[0]+normal*first_width,path[0]-normal*first_width]))
	uvs.append_array(PackedVector2Array([Vector2(0,0),Vector2(1,0)]))
	var cap_color=Color(1,1,1,0) if pass_id==1 else Color(0,0,0,0)
	colors.append_array(PackedColorArray([cap_color,cap_color]))
	var width=first_width
	for i in range(divisor):
		width=int((count+1-i)*(12 if pass_id==1 else 24)/divisor)
		var incoming=(path[i+1]-path[i]).normalized()
		var outgoing=(path[i+2]-path[i+1]).normalized()
		normal=-((incoming+outgoing)*0.5).normalized().orthogonal()
		var a=path[i+1]+normal*width
		var b=path[i+1]-normal*width
		vertices.append_array(PackedVector2Array([a,b,a,b]))
		uvs.append_array(PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)]))
		var color=Color(intensity,intensity,intensity,alpha)
		colors.append_array(PackedColorArray([color,color,color,color]))
	normal=-(path[-1]-path[-2]).normalized().orthogonal()
	vertices.append_array(PackedVector2Array([path[-1]+normal*width,path[-1]-normal*width]))
	uvs.append_array(PackedVector2Array([Vector2(0,1),Vector2(1,1)]))
	colors.append_array(PackedColorArray([cap_color,cap_color]))
	var indices=PackedInt32Array()
	for i in range(vertices.size()-2):
		if i%2==0:indices.append_array(PackedInt32Array([i,i+1,i+2]))
		else:indices.append_array(PackedInt32Array([i+1,i,i+2]))
	return {"vertices":vertices,"uvs":uvs,"colors":colors,"indices":indices}

static func draw_batch(canvas: CanvasItem, effects: Array, clock_ms: int, pass_id:int=1) -> void:
	var groups={}
	for effect in effects:
		if effect.kind!="shot":continue
		if effect.has("bolt_clock") and not effect.bolt_clock.alive:continue
		var type=int(effect.type)
		var texture=str(effect.get("texture","assets/sfx/laser_beam_yellow.png" if type==11 else "assets/sfx/electric_bolt_orange.png" if type==12 else "assets/sfx/electric_bolt.png"))
		if not groups.has(texture):groups[texture]={"vertices":PackedVector2Array(),"uvs":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}
		var group=groups[texture]
		var path:PackedVector2Array=effect.points
		# Construct snapshots opacity into both vertex arrays. Update changes
		# only the source ball's scalar until the next Construct call.
		var color=Color(1,1,1,float(effect.get("ribbon_alpha",opacity(effect,clock_ms))))
		if type!=11:
			var strip=ribbon(path,pass_id,color.a)
			var at=group.vertices.size()
			group.vertices.append_array(strip.vertices);group.uvs.append_array(strip.uvs);group.colors.append_array(strip.colors)
			for index in strip.indices:group.indices.append(at+index)
			continue
		if pass_id==2:continue
		var width=30.0
		for i in range(path.size()-1):
			if path[i].distance_squared_to(path[i+1])<0.000001:continue
			var normal=(path[i+1]-path[i]).normalized().orthogonal()
			var previous=(path[i]-path[i-1]).normalized().orthogonal() if i>0 else normal
			var following=(path[i+2]-path[i+1]).normalized().orthogonal() if i+2<path.size() else normal
			var a=(normal+previous).normalized()*width
			var b=(normal+following).normalized()*width
			var at=group.vertices.size()
			group.vertices.append_array(PackedVector2Array([path[i]+a,path[i]-a,path[i+1]-b,path[i+1]+b]))
			group.uvs.append_array(PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]))
			group.colors.append_array(PackedColorArray([color,color,color,color]))
			group.indices.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
	for texture in groups:
		var group=groups[texture]
		if group.vertices.is_empty():continue
		var resource=Content.tex(texture)
		if resource==null:
			push_error("Missing authored beam texture: "+texture)
			continue
		# Submit the same explicit strip triangles as canvas geometry. Creating
		# a GPU ArrayMesh for each bolt/pass/frame prevents canvas batching and
		# adds resource allocation/retirement to dense electrical combat.
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),group.indices,group.vertices,group.colors,group.uvs,PackedInt32Array(),PackedFloat32Array(),resource.get_rid())

static func draw_ribbon(canvas:CanvasItem,effect:Dictionary,clock_ms:int,pass_id:int,strip:Dictionary={}) -> void:
	var resource=Content.tex(effect.texture)
	if resource==null:push_error("Missing authored beam texture: "+str(effect.texture));return
	if strip.is_empty():strip=ribbon(effect.points,pass_id,float(effect.get("ribbon_alpha",opacity(effect,clock_ms))))
	if strip.vertices.is_empty():return
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),strip.indices,strip.vertices,strip.colors,strip.uvs,PackedInt32Array(),PackedFloat32Array(),resource.get_rid())
