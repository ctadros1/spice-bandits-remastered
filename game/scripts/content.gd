extends Node

var catalog: Dictionary
var maps: Dictionary
var animations: Dictionary
var static_resources: Dictionary
var menu_layout: Dictionary
var tutorial_layout: Dictionary
var tutorial_gl_layout: Dictionary
var mode_text: Dictionary
var interface_layouts: Dictionary
var interface_tutorials: Dictionary
var particles: Dictionary
var texture_cache: Dictionary = {}
var source_image_cache: Dictionary = {}
var screen_textures:Dictionary
var frame_cache: Dictionary = {}
var frame_lookup_tables:Dictionary={}
var reference_frame_lookup=false
var probe_frame_lookup=false
var frame_lookup_usage={"cached":0,"reference":0}
var interface_materials: Dictionary = {}

func interface_material(variant:String) -> ShaderMaterial:
	if not interface_materials.has(variant):
		var shader=Shader.new()
		# ShopItemView0x52498 uses UIImage imageWithColor:whiteColor for
		# unavailable branches, preserving alpha, and grayscale for level locks.
		shader.code="shader_type canvas_item; void fragment(){COLOR.rgb="+("vec3(1.0)" if variant=="silhouette" else "vec3(dot(COLOR.rgb,vec3(0.299,0.587,0.114)))")+";}"
		var material=ShaderMaterial.new();material.shader=shader
		interface_materials[variant]=material
	return interface_materials[variant]

func _ready() -> void:
	catalog = read_json("res://data/catalog.json")
	maps = read_json("res://data/maps.json")
	animations = read_json("res://data/animations.json")
	screen_textures = read_json("res://data/screen_textures.json")
	static_resources = read_json("res://data/static_resources.json")
	menu_layout = read_json("res://data/menu_layout.json")
	tutorial_layout = read_json("res://data/tutorial_layout.json")
	tutorial_gl_layout = read_json("res://data/tutorial_gl_layout.json")
	mode_text = read_json("res://data/mode_text.json")
	interface_layouts = read_json("res://data/interface_layouts.json")
	interface_tutorials = read_json("res://data/interface_tutorials.json")
	particles = read_json("res://data/particles.json")

func read_json(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func tex(path: String) -> Texture2D:
	if path.is_empty(): return null
	var full = path if path.begins_with("res://") else "res://" + path
	if not texture_cache.has(full):
		texture_cache[full] = load(full) if ResourceLoader.exists(full) else null
	return texture_cache[full]

func source_image(path: String) -> Image:
	# Read an atlas back from the GPU once. Repeating this for every new
	# animation frame stalls dense battles even when frame textures cache.
	var full=path if path.begins_with("res://") else "res://"+path
	if not source_image_cache.has(full):
		var texture=tex(full)
		source_image_cache[full]=texture.get_image() if texture!=null else null
	return source_image_cache[full]

func mission(id: String) -> Dictionary:
	for c in catalog.offlineConfigs:
		if str(c.configid) == id: return c
	return {}

func location(id: String) -> Dictionary:
	for item in catalog.tower_locations:
		if int(item.id) == int(id): return item
	return {}

func tower(type: int, level: int) -> Dictionary:
	var form = catalog.tower_towers[type].duplicate(true)
	var entry = form.levels[level - 1]
	form.erase("levels")
	form.merge(entry, true)
	form.type = type
	form.level = level
	return form

func tower_presentation(definition: Dictionary, angle: float, elapsed_ms: int) -> Dictionary:
	var source = animations.get("towers/"+str(definition.filename), {})
	var states = source.get("states", {})
	if states.has("Rot"):
		# CTower::UpdateTurret 0xe7a08 truncates degrees/9, with40 wrapping to0.
		var index = int(PackedFloat32Array([angle/9.0])[0])
		if int(definition.type) in [14, 15]:
			var points = source.get("params", {}).get("shoot_points", {})
			var keys = points.keys()
			keys.sort() # Native std::map lexical order controls strict ties.
			var best = INF
			for key in keys:
				var direction = points[key].get("Dir", [])
				if direction.size() != 2: continue
				var radians = -99999.0
				if direction[0] == 0 and direction[1] != 0:
					radians = 1.570796012878418 if direction[1] > 0 else -1.570796012878418
				elif direction[0] != 0:
					radians = PackedFloat32Array([atan(PackedFloat32Array([direction[1]/direction[0]])[0])])[0]
					if direction[0] < 0: radians = PackedFloat32Array([radians+(3.141592025756836 if direction[1] > 0 else -3.141592025756836)])[0]
				var raw_degrees = PackedFloat32Array([PackedFloat32Array([radians*57.295780181884766])[0]+90.0])[0]
				var degrees = PackedFloat32Array([float(int(raw_degrees*182.04444444444445)&65535)*0.0054931640625])[0]
				var distance = minf(absf(angle-degrees), absf(angle-(degrees+360.0)))
				if distance < best: best = distance; index = int(key)
		return {"state": "Rot", "frame": 0 if index == 40 else index}
	var state = states.get("Idle", {})
	var count = maxi(1, state.get("resolved_frames", []).size())
	var index = int(elapsed_ms*float(state.get("speed", 1))/1000.0)
	if int(state.get("loop", 0)) == 0: index = mini(index, count-1)
	return {"state": "Idle", "frame": posmod(index, count)}

func tower_foundation(theme: String, cell: Vector2i, elapsed_ms: int) -> Array[Dictionary]:
	var names = []
	match theme:
		"snow": names = ["maps/themes/snow/tower_snow_building", "maps/themes/snow/tower_snow_alpha_building"]
		"forest": names = ["maps/themes/forest/tower_grass_building"+str((cell.x+cell.y)%6+1)]
		"jungle": names = ["maps/themes/jungle/tower_jungle_building"+str((cell.x+cell.y)%2+1)]
	var result: Array[Dictionary] = []
	for name in names:
		var state = animations[name].states.Building
		var count = maxi(1, state.resolved_frames.size())
		var progress = elapsed_ms*float(state.speed)/1000.0
		var alpha = 1.0
		if int(state.get("alpha_anim", 0)):
			alpha = lerpf(float(state.get("alpha_anim_from", 0)), float(state.get("alpha_anim_to", 1)), clampf(progress/count, 0, 1))
		if alpha > 0: result.append({"name": name, "frame": mini(int(progress), count-1), "alpha": alpha})
	return result

func extra_frame(set_name: String, name: String, variation: String = "") -> Dictionary:
	var key = "extra:%s:%s:%s" % [set_name, name, variation]
	if frame_cache.has(key): return frame_cache[key]
	var source = animations.get(set_name, static_resources.get(set_name, {})).get("textures", {}).get(name, {})
	if source.is_empty(): return {}
	var path=str(source.get("variations", {}).get(variation, source.texture))
	var texture = tex(path)
	if texture == null: return {}
	var size = Vector2i(int(source.get("frame_width", texture.get_width())), int(source.get("frame_height", texture.get_height())))
	var region = Rect2i(int(source.get("x", 0)), int(source.get("y", 0)), size.x, size.y)
	var image_data = source_image(path).get_region(region)
	if int(source.get("fliph", 0)): image_data.flip_x()
	if int(source.get("flipv", 0)): image_data.flip_y()
	var value = {"texture": ImageTexture.create_from_image(image_data), "offset": Vector2(float(source.get("offset_x", 0)), float(source.get("offset_y", 0))), "params": source.get("params", {})}
	frame_cache[key] = value
	return value

func frame(set_name: String, state_name: String, index: int = 0, variation: String = "", screen_pass:bool=false) -> Dictionary:
	if reference_frame_lookup:
		if probe_frame_lookup:frame_lookup_usage.reference+=1
		return frame_reference(set_name,state_name,index,variation,screen_pass)
	# Imported animation declarations are immutable during a running game.
	# Retain their normalized-index lookup once; textures remain lazily loaded
	# by the original resolver and the returned frame Dictionary is unchanged.
	var lookup_key=set_name+"@screen" if screen_pass else set_name
	var group=frame_lookup_tables.get(lookup_key)
	if group==null:group={};frame_lookup_tables[lookup_key]=group
	var states=group.get(state_name)
	if states==null:states={};group[state_name]=states
	var descriptor=states.get(variation)
	if descriptor==null:
		if not animations.has(set_name):return {}
		var source=animations[set_name]
		var state=source.states.get(state_name,source.states.get("Idle",{}))
		if state.is_empty():return {}
		var added=state.get("resolved_frames",state.get("added_frames",[]))
		var count=maxi(1,added.size() if not added.is_empty() else int(state.get("frames",1)))
		var frames=[];frames.resize(count)
		descriptor={"frames":frames,"count":count};states[variation]=descriptor
	var wrapped=posmod(index,int(descriptor.count))
	var value=descriptor.frames[wrapped]
	if value==null:
		value=frame_reference(set_name,state_name,index,variation,screen_pass)
		descriptor.frames[wrapped]=value
	if probe_frame_lookup:frame_lookup_usage.cached+=1
	return value

func frame_reference(set_name: String, state_name: String, index: int = 0, variation: String = "", screen_pass:bool=false) -> Dictionary:
	if not animations.has(set_name): return {}
	var source = animations[set_name]
	var state = source.states.get(state_name, source.states.get("Idle", {}))
	if state.is_empty(): return {}
	var added = state.get("resolved_frames", state.get("added_frames", []))
	var count = maxi(1, added.size() if not added.is_empty() else int(state.get("frames", 1)))
	# A long-running loop must reuse the same texture for the same authored frame.
	index = posmod(index, count)
	var cache_key = "%s:%s:%d:%s" % [set_name, state.get("name", state_name), index, variation]
	if screen_pass:cache_key+="@screen"
	if frame_cache.has(cache_key): return frame_cache[cache_key]
	var resource = source.resources.get(str(int(state.get("res_id", 1))), {})
	var path = resource.get("variations", {}).get(variation, resource.get("texture", ""))
	if screen_pass:path=screen_textures.get(path,"")
	var texture = tex(path)
	if texture == null: return {}
	var fw = int(resource.get("frame_width", texture.get_width()))
	var fh = int(resource.get("frame_height", texture.get_height()))
	var rect: Rect2i
	var offset = Vector2(float(state.get("offset_x", 0)), float(state.get("offset_y", 0)))
	var image_data: Image
	if not added.is_empty():
		var f = added[posmod(index, added.size())]
		if f.has("res_id"):
			resource = source.resources.get(str(int(f.res_id)), resource)
			path = resource.get("variations", {}).get(variation, resource.get("texture", ""))
			if screen_pass:path=screen_textures.get(path,"")
			texture = tex(path)
			if texture == null: return {}
			fw = int(resource.get("frame_width", texture.get_width()))
			fh = int(resource.get("frame_height", texture.get_height()))
		var w = int(f.get("f_width", fw))
		var h = int(f.get("f_height", fh))
		var rotated = int(f.get("rot_90", 0)) == 1
		rect = Rect2i(int(f.get("x", 0)), int(f.get("y", 0)), h if rotated else w, w if rotated else h)
		image_data = source_image(path).get_region(rect)
		if rotated: image_data.rotate_90(COUNTERCLOCKWISE)
		offset = Vector2(float(f.get("offset_x", 0)), float(f.get("offset_y", 0)))
		# RenderFrame0x10f1c4 ORs the animation's flip with the frame flip.
		if int(f.get("fliph", 0)) or int(state.get("fliph", 0)): image_data.flip_x()
		if int(f.get("flipv", 0)): image_data.flip_y()
	else:
		var columns = maxi(1, int(texture.get_width() / fw))
		var n = (int(state.get("raw", 1)) - 1) * columns + int(state.get("column", 1)) - 1 + posmod(index, count)
		rect = Rect2i((n % columns) * fw, int(n / columns) * fh, fw, fh)
		image_data = source_image(path).get_region(rect)
		if int(state.get("fliph", 0)): image_data.flip_x()
	var value = {"texture": ImageTexture.create_from_image(image_data), "offset": offset,
		"speed": float(state.get("speed", 1)), "canvas_size": Vector2(fw, fh)}
	frame_cache[cache_key] = value
	return value
