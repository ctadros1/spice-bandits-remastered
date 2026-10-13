extends Node

var catalog: Dictionary
var maps: Dictionary
var animations: Dictionary
var menu_layout: Dictionary
var texture_cache: Dictionary = {}
var frame_cache: Dictionary = {}

func _ready() -> void:
	catalog = read_json("res://data/catalog.json")
	maps = read_json("res://data/maps.json")
	animations = read_json("res://data/animations.json")
	menu_layout = read_json("res://data/menu_layout.json")

func read_json(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func tex(path: String) -> Texture2D:
	if path.is_empty(): return null
	var full = path if path.begins_with("res://") else "res://" + path
	if not texture_cache.has(full):
		texture_cache[full] = load(full) if ResourceLoader.exists(full) else null
	return texture_cache[full]

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

func frame(set_name: String, state_name: String, index: int = 0, variation: String = "") -> Dictionary:
	var cache_key = "%s:%s:%d:%s" % [set_name, state_name, index, variation]
	if frame_cache.has(cache_key): return frame_cache[cache_key]
	if not animations.has(set_name): return {}
	var source = animations[set_name]
	var state = source.states.get(state_name, source.states.get("Idle", {}))
	if state.is_empty(): return {}
	var resource = source.resources.get(str(int(state.get("res_id", 1))), {})
	var path = resource.get("variations", {}).get(variation, resource.get("texture", ""))
	var texture = tex(path)
	if texture == null: return {}
	var fw = int(resource.get("frame_width", texture.get_width()))
	var fh = int(resource.get("frame_height", texture.get_height()))
	var rect: Rect2i
	var offset = Vector2(float(state.get("offset_x", 0)), float(state.get("offset_y", 0)))
	var added = state.get("added_frames", [])
	var image_data: Image
	if not added.is_empty():
		var f = added[posmod(index, added.size())]
		if f.has("res_id"):
			resource = source.resources.get(str(int(f.res_id)), resource)
			path = resource.get("variations", {}).get(variation, resource.get("texture", ""))
			texture = tex(path)
			if texture == null: return {}
		var w = int(f.get("f_width", fw))
		var h = int(f.get("f_height", fh))
		var rotated = int(f.get("rot_90", 0)) == 1
		rect = Rect2i(int(f.get("x", 0)), int(f.get("y", 0)), h if rotated else w, w if rotated else h)
		image_data = texture.get_image().get_region(rect)
		if rotated: image_data.rotate_90(COUNTERCLOCKWISE)
		offset += Vector2(float(f.get("offset_x", 0)), float(f.get("offset_y", 0)))
	else:
		var count = maxi(1, int(state.get("frames", 1)))
		var columns = maxi(1, int(texture.get_width() / fw))
		var n = (int(state.get("raw", 1)) - 1) * columns + int(state.get("column", 1)) - 1 + posmod(index, count)
		rect = Rect2i((n % columns) * fw, int(n / columns) * fh, fw, fh)
		image_data = texture.get_image().get_region(rect)
	if int(state.get("fliph", 0)): image_data.flip_x()
	var value = {"texture": ImageTexture.create_from_image(image_data), "offset": offset,
		"speed": float(state.get("speed", 1)), "canvas_size": Vector2(fw, fh)}
	frame_cache[cache_key] = value
	return value
