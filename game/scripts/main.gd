extends Node2D

const Simulation = preload("res://scripts/simulation.gd")
const TUTORIAL_CELLS = [Vector2i(7, 4), Vector2i(8, 6), Vector2i(6, 7), Vector2i(11, 3)]
var screen = "menu"
var sim: BanditSimulation
var ui: Control
var font: Font
var bold: Font
var camera = Vector2(440, 350)
var world_camera = Vector2(920, 1530)
var zoom = 1.0
var world_zoom = 0.46
var build_type = 0
var magic_placement = ""
var selected_tower = -1
var selected_location = ""
var drag_start = Vector2.ZERO
var drag_last = Vector2.ZERO
var dragging = false
var moved = false
var speed = 1
var frame_remainder = 0.0
var show_grid = false
var notice = ""
var notice_until = 0
var effects: Array[Dictionary] = []
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var audio_cache: Dictionary = {}
var last_sound: Dictionary = {}
var tutorial_step = 0
var tutorial_wait_until = 0
var elapsed_ui = 0.0
var qa_capture = ""
var qa_capture_done = false
var result_saved = false
var test_session = false
var qa_demo = false
var story_location: Dictionary = {}
var story_mission = ""
var qa_state_path = ""
var qa_state_at = 0

func _ready() -> void:
	font = load("res://assets/fonts/Kautiva Pro.otf")
	bold = load("res://assets/fonts/Kautiva Pro Bold.otf")
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in range(20):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	get_viewport().size_changed.connect(refresh_controls)
	var args = OS.get_cmdline_user_args()
	test_session = "--qa" in args
	qa_demo = test_session and "--qa-demo" in args
	for arg in args:
		if arg.begins_with("--capture="): qa_capture = arg.trim_prefix("--capture=")
		if test_session and arg.begins_with("--qa-state-file="): qa_state_path = arg.trim_prefix("--qa-state-file=")
	refresh_controls()
	play_music()
	for arg in args:
		if arg.begins_with("--mission="): start_mission(arg.trim_prefix("--mission="), test_session)
		elif arg.begins_with("--screen="): navigate(arg.trim_prefix("--screen="))
	if not Profile.recovery_message.is_empty(): message(Profile.recovery_message)
	if test_session and "--qa-render-all" in args: render_campaign_gallery.call_deferred()

func view_size() -> Vector2:
	return get_viewport_rect().size

func view_center() -> Vector2:
	return view_size()/2.0

func map_scale() -> float:
	if sim == null: return 1.0
	return minf(view_size().x/1024.0, view_size().y/768.0)*zoom

func map_origin() -> Vector2:
	return view_center()-camera*map_scale()

func mouse_world(pos: Vector2) -> Vector2:
	return (pos-map_origin())/map_scale()

func world_origin() -> Vector2:
	return view_center()-world_camera*world_zoom

func clear_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()

func atlas(path: String, region: Rect2) -> AtlasTexture:
	var a = AtlasTexture.new()
	a.atlas = Content.tex(path)
	a.region = region
	return a

func button(parent: Control, text_value: String, rect: Rect2, action: Callable, icon: Texture2D = null, disabled: bool = false) -> Button:
	var b = Button.new()
	b.text = text_value
	b.position = rect.position
	b.size = rect.size
	b.disabled = disabled
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color("#fff396"))
	var style = StyleBoxTexture.new()
	style.texture = atlas("assets/gui/ingame_menus.png", Rect2(0, 232, 94, 60))
	style.texture_margin_left = 12
	style.texture_margin_right = 12
	style.texture_margin_top = 12
	style.texture_margin_bottom = 12
	b.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.modulate_color = Color(1.2, 1.2, 1.2)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", style)
	var dim = style.duplicate()
	dim.modulate_color = Color(0.45, 0.5, 0.55)
	b.add_theme_stylebox_override("disabled", dim)
	if icon != null:
		b.icon = icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(rect.size.y - 16))
	b.pressed.connect(action)
	b.pressed.connect(func(): sound("UI_click"))
	parent.add_child(b)
	return b

func label(parent: Control, value: String, rect: Rect2, size: int = 17, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = value
	l.position = rect.position
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	# Set the final box after font/wrapping; otherwise the default unwrapped
	# text minimum can enlarge the Control before wrapping is enabled.
	l.size = rect.size
	return l

func refresh_controls() -> void:
	if ui == null: return
	clear_ui()
	var size = view_size()
	if screen == "menu":
		menu_controls()
	elif screen == "story":
		var rect = Rect2(view_center()-Vector2(460, 335), Vector2(920, 670))
		label(ui, str(story_location.story_desc), Rect2(rect.position+Vector2(40, 414), Vector2(840, 185)), 25)
		button(ui, "Continue", Rect2(view_center().x-125, rect.end.y-58, 250, 48), func(): start_mission(story_mission, false, false))
	elif screen == "game":
		button(ui, "%dx" % speed, Rect2(4, 2, 52, 30), cycle_speed)
		button(ui, "Menu", Rect2(size.x-94, 2, 90, 30), toggle_pause)
		button(ui, "Next wave", Rect2(62, 2, 112, 30), func(): sim.next_wave(); queue_redraw(), null, sim.wave_index >= sim.config.waves.size() or str(sim.config.configid) == "1")
		for i in range(6):
			var type = Simulation.ROOT_TYPES[i]
			var def = sim.tower_data(type, 1)
			var icon = Content.tex("assets/towers/tower%d_icon.png" % type)
			var b = button(ui, "", Rect2(size.x/2.0-270+i*62, size.y-57, 60, 54), select_build.bind(type), null, not sim.can_unlock(def))
			b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
			b.tooltip_text = "%s\n%s\nPress %d" % [def.name, def.get("description", ""), i+1]
		for i in range(5):
			var keys = ["m_freeze", "m_lsd", "m_actdef", "m_mine", "m_portal"]
			var key = keys[i]
			var b = button(ui, "", Rect2(size.x/2.0+110+i*58, size.y-57, 56, 54), magic.bind(key), null, int(sim.abilities.get(key, 0)) <= 0)
			b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
			b.tooltip_text = ["Freeze", "Disco Magic", "Active Defense", "Mines", "Portals"][i]
		if selected_tower >= 0:
			var t = sim.find_tower(selected_tower)
			if not t.is_empty():
				var y = size.y-142
				var sell_allowed = str(sim.config.configid) != "1" or (tutorial_step == 4 and t.cell == Vector2i(11, 3))
				button(ui, "Sell $%d" % sim.sell_price(t), Rect2(size.x/2.0-240, y, 122, 46), func():
					message(sim.sell(t.id))
					if str(sim.config.configid) == "1": tutorial_step = 5; sim.next_wave()
					selected_tower = -1
					refresh_controls(), null, not sell_allowed)
				for i in range(sim.upgrade_options(t).size()):
					var option = sim.upgrade_options(t)[i]
					var def = sim.tower_data(option[0], option[1])
					button(ui, "%s $%d" % [def.name, int(def.price)], Rect2(size.x/2.0-108+i*216, y, 208, 46), func(): message(sim.upgrade_tower(t.id, option[0], option[1])); refresh_controls(), null, not sim.can_unlock(def) or (str(sim.config.configid) == "1" and (tutorial_step != 3 or int(t.level) >= 2)))
				for i in range(3):
					var target = ["fastest", "strongest", "weakest"][i]
					button(ui, ["F", "S", "W"][i], Rect2(size.x/2.0-80+i*55, size.y-88, 50, 28), func(): t.targeting = target; sim.record("target", {"id": t.id, "mode": target}); queue_redraw())
		if sim.paused: pause_controls()
		elif sim.outcome != "playing": results_controls()
		elif str(sim.config.configid) == "1": tutorial_controls()
	else:
		button(ui, "Home", Rect2(8, 8, 86, 42), func(): navigate("menu"))
		var tabs = [["World", "world"], ["Career", "career"], ["Tech Shop", "shop"], ["Upgrades", "upgrades"], ["Medals", "medals"], ["Dress", "dress"]]
		for i in range(tabs.size()):
			button(ui, tabs[i][0], Rect2(102+i*122, 8, 116, 42), navigate.bind(tabs[i][1]))
		match screen:
			"world": world_controls()
			"shop": shop_controls()
			"spicery": spicery_controls()
			"upgrades": upgrades_controls()
			"career": career_controls()
			"medals": medals_controls()
			"dress": dress_controls()
			"settings": settings_controls()
			"credits": credits_controls()
	queue_redraw()

func navigate(value: String) -> void:
	screen = value
	selected_location = ""
	refresh_controls()
	play_music()

func menu_scale() -> float:
	return minf(view_size().x/1024.0, view_size().y/768.0)

func menu_origin() -> Vector2:
	return view_center()-Vector2(512, 384)*menu_scale()

func menu_descendant(entry: Dictionary, ancestor: int) -> bool:
	for value in entry.ancestors:
		if int(value) == ancestor: return true
	return false

func menu_rect(entry: Dictionary) -> Rect2:
	var r = entry.rect
	var offset = Vector2.ZERO
	# Retain the authored iPad art sizes. Anchor the tube at the right edge;
	# center the square sky/character canvases in the landscape desktop view.
	if menu_descendant(entry, 118) or int(entry.id) == 118: offset.x = 256
	elif menu_descendant(entry, 180) or int(entry.id) == 180: offset.y = -128
	elif menu_descendant(entry, 448) or int(entry.id) == 448: offset.y = -128
	return Rect2(Vector2(r[0], r[1])+offset, Vector2(r[2], r[3]))

func menu_entry(outlet: String) -> Dictionary:
	for entry in Content.menu_layout.entries:
		if entry.outlet == outlet: return entry
	return {}

func menu_controls() -> void:
	var menus = [["playButton", "Play", "world", 60], ["careerButton", "Career", "career", 42],
		["tech_shopButton", "Tech shop", "shop", 42], ["upgradesButton", "Upgrades", "upgrades", 42], ["spiceryButton", "Spicery", "spicery", 42]]
	for item in menus:
		var r = menu_rect(menu_entry(item[0]))
		r = Rect2(menu_origin()+r.position*menu_scale(), r.size*menu_scale())
		var b = button(ui, item[1], r, navigate.bind(item[2]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", bold)
		b.add_theme_font_size_override("font_size", int(item[3]*menu_scale()))
		for style in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var extra = [["Settings", "settings"], ["Credits", "credits"]]
	for i in range(extra.size()):
		var r = Rect2(menu_origin()+Vector2(28+i*112, 710)*menu_scale(), Vector2(102, 36)*menu_scale())
		button(ui, extra[i][0], r, navigate.bind(extra[i][1]))
	var music_rect = menu_rect(menu_entry("musicButtonView"))
	var music_button = button(ui, "", Rect2(menu_origin()+music_rect.position*menu_scale(), music_rect.size*menu_scale()), func():
		Profile.data.settings.music = not Profile.data.settings.music
		if not test_session: Profile.save_profile()
		play_music()
		queue_redraw())
	for style in ["normal", "hover", "pressed"]: music_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())

func world_controls() -> void:
	if selected_location.is_empty(): return
	var size = view_size()
	var loc = Content.location(selected_location)
	var x = size.x-320
	label(ui, loc.name, Rect2(x+20, 90, 280, 45), 27)
	label(ui, loc.get("story_desc", ""), Rect2(x+20, 145, 280, 205), 18)
	var row = 0
	for mode in ["1", "3", "6"]:
		for c in Content.catalog.offlineConfigs:
			if c.location != selected_location or c.gametype != mode or c.waves.is_empty(): continue
			var unlocked = Profile.available(c)
			var name = {"1": "Normal", "3": "Sudden Death", "6": "Air Attack"}[mode]
			var stars = int(Profile.data.completed.get(c.configid, 0))
			var caption = "%s  %s" % [name, "★".repeat(stars)]
			var b = button(ui, caption, Rect2(x+16, 365+row*64, 288, 55), start_mission.bind(c.configid), null, not unlocked)
			b.tooltip_text = "%d waves" % c.waves.size() if unlocked else "Unlock the preceding campaign mission."
			row += 1
	label(ui, "Cooperative · Competition · Camps\nMultiplayer restoration is pending.", Rect2(x+20, 580, 280, 70), 16, Color("#bcd3da"))
	button(ui, "Close", Rect2(x+16, 660, 288, 45), func(): selected_location = ""; refresh_controls())

func scroll_area() -> Control:
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(32, 105)
	scroll.size = view_size()-Vector2(64, 178)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	var content = Control.new()
	content.custom_minimum_size = Vector2(scroll.size.x-24, 0)
	scroll.add_child(content)
	return content

func shop_controls() -> void:
	var area = scroll_area()
	var items = []
	for item in Content.catalog.shopList:
		if int(item.itemtype) != 2: items.append(item)
	var columns = maxi(2, int((view_size().x-90)/290))
	var width = (view_size().x-90)/columns
	for i in range(items.size()):
		var item = items[i]
		var x = (i%columns)*width
		var y = int(i/columns)*154
		label(area, item.itemname, Rect2(x+8, y+2, width-20, 28), 22)
		label(area, item.itemdescription if not item.itemdescription.is_empty() else "Original tower technology", Rect2(x+8, y+36, width-20, 48), 16)
		var icon_path = "assets/"+str(item.unlockstring)+".png" if int(item.itemtype) == 1 else "assets/"+str(item.tag)+".png"
		button(area, "%s spice · level %s" % [item.pricespice, item.levellock], Rect2(x+8, y+91, width-20, 48), func(): message(Profile.purchase(item)); refresh_controls(), Content.tex(icon_path), not str(item.unlockstring).is_empty() and Profile.unlocked(item.unlockstring))
	area.custom_minimum_size.y = ceil(float(items.size())/columns)*154

func spicery_controls() -> void:
	var c = view_center()
	label(ui, "Spicery", Rect2(c.x-210, 145, 420, 70), 46)
	label(ui, "%d spice" % int(Profile.data.spice), Rect2(c.x-210, 255, 420, 60), 36, Color("#fff0b1"))
	label(ui, "Earn spice from campaign victories. Visit the tech shop for tower technology, magic and costumes.", Rect2(c.x-210, 340, 420, 120), 24)
	button(ui, "Tech shop", Rect2(c.x-170, 505, 340, 55), navigate.bind("shop"))

func upgrades_controls() -> void:
	var offer = Content.catalog.tower_pu_exchange
	button(ui, "%d spice → %d points" % [int(offer.spice_cost), int(offer.pu_award)], Rect2(view_size().x-265, 61, 232, 38), func(): message(Profile.exchange_points()); refresh_controls(), null, Profile.data.spice < int(offer.spice_cost))
	var area = scroll_area()
	var keys = Content.catalog.tower_upgrades.keys()
	var columns = 3
	var width = (view_size().x-90)/columns
	for i in range(keys.size()):
		var key = keys[i]
		var item = Content.catalog.tower_upgrades[key]
		var level = int(Profile.data.upgrades.get(key, 0))
		var x = (i%columns)*width
		var y = int(i/columns)*172
		label(area, "%s  %d/10" % [item.name, level], Rect2(x+8, y, width-20, 32), 22)
		var amount = item.get("tower_percent", item.get("percent", 0))
		label(area, str(item.description).replace("%@", str(abs(amount))).replace("%%", "%"), Rect2(x+8, y+40, width-20, 68), 16)
		button(area, "Upgrade · %s points" % Content.catalog.tower_upgrade_costs.get(str(level+1), "—"), Rect2(x+8, y+112, width-20, 45), func(): message(Profile.upgrade(key)); refresh_controls(), Content.tex("assets/"+key+"_1.png"), level >= 10 or key == "up_friends")
	area.custom_minimum_size.y = ceil(float(keys.size())/columns)*172

func career_controls() -> void:
	var size = view_size()
	label(ui, Profile.data.name, Rect2(size.x/2.0-200, 155, 400, 60), 40)
	label(ui, "Level %d\nXP: %.1f\nSpice: %d\nUpgrade points: %d\nVictories: %d\nEnemies defeated: %d\nTowers built: %d" % [int(Profile.data.level), Profile.data.xp, int(Profile.data.spice), int(Profile.data.specpoints), int(Profile.data.stats.wins), int(Profile.data.stats.kills), int(Profile.data.stats.towers)], Rect2(size.x/2.0+30, 235, 440, 350), 27)
	button(ui, "Upgrades yard", Rect2(size.x/2.0-160, size.y-155, 320, 54), navigate.bind("upgrades"))

func medals_controls() -> void:
	var area = scroll_area()
	var columns = 3
	var width = (view_size().x-90)/columns
	for i in range(Content.catalog.tower_medals.size()):
		var m = Content.catalog.tower_medals[i]
		var x = (i%columns)*width
		var y = int(i/columns)*125
		var texture = TextureRect.new()
		texture.texture = Content.tex("assets/"+str(m.image))
		texture.position = Vector2(x+8, y+8)
		texture.size = Vector2(60, 60)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture.modulate = Color.WHITE if m.image in Profile.data.medals else Color(0.65, 0.65, 0.65)
		area.add_child(texture)
		label(area, m.name, Rect2(x+76, y+4, width-85, 32), 21)
		label(area, m.description, Rect2(x+76, y+38, width-85, 77), 16)
	area.custom_minimum_size.y = ceil(float(Content.catalog.tower_medals.size())/columns)*125

func dress_controls() -> void:
	var area = scroll_area()
	area.get_parent().size.x = view_size().x-380
	var columns = 3
	var width = (view_size().x-400)/columns
	for i in range(Content.catalog.tower_dress.size()):
		var d = Content.catalog.tower_dress[i]
		var x = (i%columns)*width
		var y = int(i/columns)*140
		var item = {}
		for s in Content.catalog.shopList:
			if s.tag == d.tag: item = s; break
		var own = Profile.unlocked(str(d.needsunlock))
		var caption = "Wear" if own else "%s spice" % item.get("pricespice", "?")
		label(area, d.title, Rect2(x+5, y, width-10, 38), 19)
		button(area, caption, Rect2(x+5, y+42, width-10, 80), func():
			if not own:
				if item.is_empty(): message("This costume depended on the original service."); return
				message(Profile.purchase(item))
			else:
				var before = Profile.data.dress.duplicate()
				Profile.data.dress["s"+str(d.slot)] = int(d.id)
				if not Profile.save_profile(): Profile.data.dress = before; message("Could not save the costume.")
			refresh_controls(), Content.tex("assets/cosmetics/previews/"+str(d.tURL).get_file()))
	area.custom_minimum_size.y = ceil(float(Content.catalog.tower_dress.size())/columns)*140

func settings_controls() -> void:
	var c = view_center()
	for i in range(3):
		var key = ["music", "sound", "fullscreen"][i]
		var caption = ["Music", "Sound effects", "Fullscreen"][i]+(": On" if Profile.data.settings[key] else ": Off")
		button(ui, caption, Rect2(c.x-180, c.y-130+i*65, 360, 54), func():
			Profile.data.settings[key] = not Profile.data.settings[key]
			Profile.save_profile()
			if key == "fullscreen": set_fullscreen(bool(Profile.data.settings.fullscreen))
			play_music()
			refresh_controls())
	label(ui, "Click to place and select. Drag to pan. Scroll or pinch to zoom.\n1–6 select towers · N launches the next wave · Space pauses\nEscape cancels · G shows the hex grid · F11 toggles fullscreen", Rect2(c.x-300, c.y+100, 600, 160), 21)

func credits_controls() -> void:
	var c = view_center()
	label(ui, "Spice Bandits\nOriginal game by On5 · Published by Chillingo\n\nOriginal art, music, sound and authored content preserved from version 1.14.\n\nmacOS reconstruction in Godot 4.7.2\nGodot Engine © Juan Linietsky, Ariel Manzur and contributors (MIT).\n\nThis local build does not connect to the discontinued original services.", Rect2(c.x-340, c.y-220, 680, 430), 25)

func start_mission(id: String, bypass_unlock: bool = false, show_story: bool = true) -> void:
	var c = Content.mission(id)
	if c.is_empty() or c.waves.is_empty(): message("This mission has no recovered offline schedule."); return
	if not bypass_unlock and not Profile.available(c): message("Unlock the preceding campaign mission first."); return
	var loc = Content.location(str(c.location))
	if show_story and not test_session and not Profile.data.completed.has(id) and not loc.is_empty() and not str(loc.story_img).is_empty():
		story_location = loc
		story_mission = id
		screen = "story"
		refresh_controls()
		return
	sim = Simulation.new()
	sim.setup(Content.catalog, Content.maps[c.map], c, Profile.data)
	screen = "game"
	build_type = 0
	magic_placement = ""
	selected_tower = -1
	tutorial_step = 0
	tutorial_wait_until = 0
	speed = 1
	zoom = 1.0
	camera = Vector2(float(sim.map.width_pixels)/2.0, float(sim.map.height_pixels)/2.0)
	if c.settings.has("cam_x"): camera = Vector2(float(c.settings.cam_x), float(c.settings.cam_y))
	effects.clear()
	result_saved = false
	if qa_demo and id == "8":
		sim.unlocks.append("T1L3")
		for cell in [Vector2i(15, 8), Vector2i(15, 7), Vector2i(15, 9), Vector2i(16, 7), Vector2i(14, 7)]: sim.build(cell, 1)
		sim.advance(1020)
		for tower in sim.towers: sim.upgrade_tower(tower.id, 1, 2)
		sim.advance(1020)
		for tower in sim.towers: sim.upgrade_tower(tower.id, 1, 3)
		sim.next_wave()
		sim.advance(21000)
		sim.events.clear()
	refresh_controls()
	play_music()

func select_build(type: int) -> void:
	if sim.paused or sim.outcome != "playing": return
	if str(sim.config.configid) == "1" and (type != 1 or tutorial_step != 1):
		message("You are not supposed to do that in the training area!")
		return
	build_type = type
	magic_placement = ""
	selected_tower = -1
	refresh_controls()

func magic(key: String) -> void:
	if str(sim.config.configid) == "1":
		var permitted = (tutorial_step == 5 and key == "m_lsd" and sim.clock_ms >= tutorial_wait_until) or (tutorial_step == 6 and key == "m_actdef") or (tutorial_step == 7 and key == "m_mine")
		if not permitted:
			message("You are not supposed to do that in the training area!")
			return
		if key != "m_mine" and sim.enemies.is_empty(): message("Wait for the earthlings to appear."); return
	if key in ["m_mine", "m_portal"]:
		magic_placement = key
		build_type = 0
		message("Choose an open hex.")
	else:
		var result = sim.use_ability(key)
		message(result)
		if str(sim.config.configid) == "1":
			if result.is_empty() and key == "m_lsd": tutorial_wait_until = sim.disco_until
			elif result.is_empty() and key == "m_actdef": tutorial_step = 7
		refresh_controls()

func cycle_speed() -> void:
	speed = 2 if speed == 1 else 4 if speed == 2 else 1
	refresh_controls()

func toggle_pause() -> void:
	if sim.outcome != "playing": return
	sim.paused = not sim.paused
	refresh_controls()

func pause_controls() -> void:
	var c = view_center()
	label(ui, "Paused", Rect2(c.x-160, c.y-170, 320, 60), 40)
	button(ui, "Resume", Rect2(c.x-160, c.y-90, 320, 55), toggle_pause)
	button(ui, "Restart", Rect2(c.x-160, c.y-25, 320, 55), func(): start_mission(sim.config.configid, test_session))
	button(ui, "To the map", Rect2(c.x-160, c.y+40, 320, 55), func(): navigate("world"))

func results_controls() -> void:
	var c = view_center()
	label(ui, "Victory!" if sim.outcome == "victory" else "Defeat", Rect2(c.x-210, c.y-180, 420, 66), 46, Color("#fff4a4"))
	var phrase = sim.config.get("msgwin" if sim.outcome == "victory" else "msglost", "")
	label(ui, phrase, Rect2(c.x-210, c.y-112, 420, 90), 23)
	label(ui, "%d enemies defeated\nScore: %.1f · Base health: %d%%" % [sim.kills, sim.score, int(sim.base_fraction()*100)], Rect2(c.x-210, c.y-20, 420, 70), 23)
	button(ui, "Replay", Rect2(c.x-210, c.y+85, 200, 55), func(): start_mission(sim.config.configid, test_session))
	button(ui, "To the map!", Rect2(c.x+10, c.y+85, 200, 55), func(): navigate("world"))

func tutorial_controls() -> void:
	if tutorial_step >= 8: return
	var prompts = ["Welcome to the camp, cadet! You build defensive towers, and they do the shooting.",
		"Now build 4 minigun towers in the designated locations.",
		"Every time you kill an earthling you get some money. You can spend money to build new towers or upgrade the existing ones.",
		"You can upgrade or sell your towers. Let's upgrade our towers!",
		"That tower never fired a round. Let's sell it and get a part of the money back.",
		"Let's apply Disco Magic to these humans. It will disorient them.",
		"Now let's try Active Defense. All towers will be damaging all enemies in their range with electricity.",
		"There's more to magic. If you don't want an enemy to pass somewhere, place a mine."]
	label(ui, prompts[mini(tutorial_step, prompts.size()-1)], Rect2(170, 72, 390, 122), 19, Color("#172b36"))
	if tutorial_step in [0, 2]:
		button(ui, "Continue", Rect2(176, 190, 150, 40), func():
			tutorial_step += 1
			refresh_controls())

func message(value: String) -> void:
	if value.is_empty(): return
	notice = value
	notice_until = Time.get_ticks_msec()+4000
	queue_redraw()

func play_music() -> void:
	if music == null: return
	if not Profile.data.settings.music: music.stop(); return
	var path = "res://assets/music/spice_pirates_theme_v8.mp3" if screen != "game" else "res://assets/music/spice_pirates_theme_v7.mp3"
	if music.stream != null and music.stream.resource_path == path and music.playing: return
	music.stream = load(path)
	if music.stream is AudioStreamMP3: music.stream.loop = true
	music.volume_db = -17
	music.play()

func sound(name: String) -> void:
	if not Profile.data.settings.sound: return
	if Time.get_ticks_msec()-int(last_sound.get(name, -10000)) < 80: return
	var definition = Content.catalog.soundbank.get(name, {})
	var count = 0
	for voice in voices:
		if voice.playing and voice.get_meta("cue", "") == name:
			count += 1
			if int(definition.get("loop", 0)) == 1: voice.set_meta("until", Time.get_ticks_msec()+180)
	if count > 0 and int(definition.get("loop", 0)) == 1: return
	if count >= int(definition.get("max_play", 20)): return
	var path = "res://assets/sounds/"+name+".wav"
	if not audio_cache.has(path): audio_cache[path] = load(path) if ResourceLoader.exists(path) else null
	if audio_cache[path] == null: return
	for v in voices:
		if not v.playing:
			v.stream = audio_cache[path]
			if v.stream is AudioStreamWAV: v.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if int(definition.get("loop", 0)) else AudioStreamWAV.LOOP_DISABLED
			v.volume_db = linear_to_db(float(definition.get("volume", 1))*0.1)
			v.set_meta("cue", name)
			v.set_meta("loop", int(definition.get("loop", 0)) == 1)
			v.set_meta("until", Time.get_ticks_msec()+180)
			v.play()
			last_sound[name] = Time.get_ticks_msec()
			break

func _process(delta: float) -> void:
	elapsed_ui += delta
	for voice in voices:
		if voice.playing and (not Profile.data.settings.sound or (voice.get_meta("loop", false) and Time.get_ticks_msec() >= int(voice.get_meta("until", 0)))): voice.stop()
	if screen == "game" and sim != null and not sim.paused and sim.clock_ms < sim.disco_until: sound("magic_lsd")
	if not qa_state_path.is_empty() and Time.get_ticks_msec() >= qa_state_at:
		qa_state_at = Time.get_ticks_msec()+250
		var state = {"screen": screen, "fps": Engine.get_frames_per_second(), "window": [view_size().x, view_size().y], "fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "sound": Profile.data.settings.sound, "music": Profile.data.settings.music}
		if sim != null:
			var tower_cells = []
			for tower in sim.towers: tower_cells.append([tower.cell.x, tower.cell.y])
			state.merge({"config": sim.config.configid, "paused": sim.paused, "speed": speed, "ms": sim.clock_ms, "money": sim.money, "towers": sim.towers.size(), "tower_cells": tower_cells, "enemies": sim.enemies.size(), "camera": [camera.x, camera.y], "zoom": zoom, "tutorial_step": tutorial_step, "build_type": build_type, "selected_tower": selected_tower, "magic_placement": magic_placement, "outcome": sim.outcome})
		var state_file = FileAccess.open(qa_state_path, FileAccess.WRITE)
		if state_file: state_file.store_string(JSON.stringify(state)); state_file.close()
	if screen == "game" and sim != null:
		frame_remainder += delta*1000.0*speed
		var ms = int(frame_remainder)
		frame_remainder -= ms
		sim.advance(ms)
		for event in sim.events: handle_event(event)
		sim.events.clear()
		if str(sim.config.configid) == "1" and tutorial_step == 1 and sim.towers.size() >= 4:
			tutorial_step = 2
			build_type = 0
			sim.next_wave()
			refresh_controls()
		if str(sim.config.configid) == "1" and tutorial_step == 3:
			var all_upgraded = sim.towers.size() == 4
			for tower in sim.towers: all_upgraded = all_upgraded and int(tower.level) == 2
			if all_upgraded:
				tutorial_step = 4
				selected_tower = int(sim.tower_at(Vector2i(11, 3)).get("id", -1))
				refresh_controls()
		if str(sim.config.configid) == "1" and tutorial_step == 5 and tutorial_wait_until > 0 and sim.clock_ms >= tutorial_wait_until:
			tutorial_step = 6
			if sim.enemies.is_empty(): sim.next_wave()
			refresh_controls()
		if sim.outcome != "playing" and not result_saved:
			if not test_session:
				if not Profile.settle(sim): message("The result could not be saved. Your previous profile is intact.")
			result_saved = true
			refresh_controls()
		for effect in effects.duplicate():
			if effect.until < Time.get_ticks_msec(): effects.erase(effect)
	queue_redraw()
	if not qa_capture.is_empty() and not qa_capture_done and elapsed_ui > 2.0:
		qa_capture_done = true
		capture.call_deferred()
	if "--smoke-quit" in OS.get_cmdline_user_args() and elapsed_ui > 3.0: get_tree().quit()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	var err = im.save_png(qa_capture)
	print("CAPTURE ", qa_capture, " ", err, " screen=", screen)
	print("QA_AUDIT ", JSON.stringify({"screen": screen, "capture": err, "fps": Performance.get_monitor(Performance.TIME_FPS), "frame_ms": Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, "architecture": "arm64" if OS.has_feature("arm64") else "x86_64", "viewport": [get_viewport_rect().size.x, get_viewport_rect().size.y], "engine": Engine.get_version_info().string, "seed": 114}))

func render_campaign_gallery() -> void:
	var output = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="): output = arg.trim_prefix("--capture-root=")
	if output.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var captures = []
	for mission in Content.catalog.offlineConfigs:
		if mission.waves.is_empty(): continue
		start_mission(str(mission.configid), true)
		tutorial_step = 7
		refresh_controls()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path = output.path_join("config-"+str(mission.configid)+".png")
		var error = get_viewport().get_texture().get_image().save_png(path)
		captures.append({"config": mission.configid, "map": mission.map, "mode": mission.gametype, "error": error, "path": path.get_file()})
	var file = FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "captures": captures}, "\t"))
	file.close()
	print("CAMPAIGN_GALLERY ", captures.size())
	get_tree().quit()

func handle_event(event: Dictionary) -> void:
	match event.kind:
		"build":
			sound("tower_place")
			if not test_session and not Profile.record_build(int(event.type)): message("The construction statistics could not be saved.")
		"upgrade": sound("tower_upgrade")
		"sell": sound("TD_sell_tower_mono_03")
		"wave": sound("wave_launch_early-mono" if event.early else "wave_launch-mono")
		"shot":
			var params = Content.animations.get("towers/"+str(event.get("filename", "")), {}).get("params", {})
			var cues = params.get("shoot_sound_list", [])
			if not cues.is_empty(): sound(cues[posmod(int(event.ms/30), cues.size())])
			elif params.has("shoot_sound"): sound(str(params.shoot_sound))
			effects.append({"kind": "shot", "from": event.from, "to": event.to, "type": event.type, "until": Time.get_ticks_msec()+95})
		"beam": effects.append({"kind": "shot", "from": event.from, "to": event.to, "type": event.type, "until": Time.get_ticks_msec()+40})
		"kill":
			sound("marine_explosion_1")
			effects.append({"kind": "explosion", "pos": event.pos, "radius": 15.0, "until": Time.get_ticks_msec()+350})
		"explosion":
			sound("nuke_explosion_1" if event.type == 5 else "missile_explosion")
			effects.append({"kind": "explosion", "pos": event.pos, "radius": float(event.radius)*55.0, "type": event.type, "until": Time.get_ticks_msec()+600})
		"base_hit": sound("base_under_attack_alert-mono")
		"teleport": sound("portal_teleport-mono")
		"blocked": message("You cannot block every path. The tower cost was returned.")
		"magic":
			if not test_session and str(sim.config.configid) != "1" and not Profile.consume_magic(str(event.key)):
				sim.paused = true
				message("The magic item could not be saved. The game is paused to preserve your profile.")
				refresh_controls()
			sound({"m_freeze": "freeze_activation-mono", "m_lsd": "magic_lsd", "m_actdef": "active_defense_on-mono"}.get(event.key, "UI_click"))
		"victory": sound("level_won")
		"defeat": sound("level_lost")

func draw_image(path: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var t = Content.tex(path)
	if t != null: draw_texture_rect(t, rect, false, tint)

func text(pos: Vector2, value: String, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(bold, pos+Vector2.ONE, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	draw_string(bold, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func sprite(set_name: String, state: String, pos: Vector2, index: int = 0, color_name: String = "", tint: Color = Color.WHITE, lift: float = 0.0, native_scale: Vector2 = Vector2.ONE) -> void:
	var f = Content.frame(set_name, state, index, color_name)
	if not f.is_empty():
		var t: Texture2D = f.texture
		draw_texture_rect(t, Rect2(pos+(-t.get_size()/2.0+f.offset)*native_scale+Vector2(0, lift), t.get_size()*native_scale), false, tint)

func extra_sprite(set_name: String, name: String, pos: Vector2, variation: String = "") -> bool:
	var source = Content.animations.get(set_name, {}).get("textures", {}).get(name, {})
	if source.is_empty(): return false
	var texture = Content.tex(source.get("variations", {}).get(variation, source.texture))
	if texture == null: return false
	var dimensions = Vector2(float(source.get("frame_width", texture.get_width())), float(source.get("frame_height", texture.get_height())))
	var region = Rect2(float(source.get("x", 0)), float(source.get("y", 0)), dimensions.x, dimensions.y)
	var offset = Vector2(float(source.get("offset_x", 0)), float(source.get("offset_y", 0)))
	draw_texture_rect_region(texture, Rect2(pos-dimensions/2.0+offset, dimensions), region)
	return true

func draw_avatar(rect: Rect2) -> void:
	# AvatarDrawer::sortArray (0x490f8) sorts sN by length then lexical order;
	# for the recovered s1..s11 keys this is ascending numeric slot order.
	for slot in range(1, 12):
		var key = "s"+str(slot)
		if not Profile.data.dress.has(key): continue
		for costume in Content.catalog.tower_dress:
			if int(costume.slot) == slot and int(costume.id) == int(Profile.data.dress[key]):
				draw_image("assets/cosmetics/"+str(costume.URL).get_file(), rect)
				break

func _draw() -> void:
	if font == null: return
	var size = view_size()
	if screen == "game" and sim != null: draw_game()
	elif screen == "story":
		draw_rect(Rect2(Vector2.ZERO, size), Color("#05131d"))
		var rect = Rect2(view_center()-Vector2(460, 335), Vector2(920, 670))
		draw_image("assets/lobby/story_screens/"+str(story_location.story_img).get_basename()+".png", Rect2(rect.position, Vector2(920, 405)))
		draw_image("assets/lobby/story_screens/bottom_line.png", Rect2(rect.position+Vector2(0, 405), Vector2(920, 265)))
	elif screen == "world": draw_world()
	elif screen == "menu": draw_menu()
	else:
		var background = {"shop": "tech_shop_bg", "spicery": "spiceshop_bg", "upgrades": "tech_shop_bg", "career": "career_bg", "medals": "medalsViewController_bg", "dress": "career_bg", "settings": "career_bg", "credits": "career_bg"}.get(screen, "career_bg")
		draw_image("assets/"+background+".png", Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(22, 94, size.x-44, size.y-155), Color(0.015, 0.08, 0.12, 0.52))
		if screen == "career": draw_avatar(Rect2(size.x/2.0-460, 180, 440, 440))
		elif screen == "dress": draw_avatar(Rect2(size.x-360, 160, 350, 350))
	if screen != "game" and screen != "menu":
		draw_image("assets/menu_nakladka_top.png", Rect2(0, 0, size.x, 72))
		draw_image("assets/menu_nakladka_bottom.png", Rect2(0, size.y-59, size.x, 59))
		text(Vector2(32, size.y-20), "%s · Level %d · %.1f XP" % [Profile.data.name, int(Profile.data.level), Profile.data.xp], 21)
		text(Vector2(size.x-290, size.y-20), "%d spice · %d points" % [int(Profile.data.spice), int(Profile.data.specpoints)], 21, Color("#fff0b1"))
	if Time.get_ticks_msec() < notice_until:
		draw_rect(Rect2(26, size.y-225, size.x-52, 48), Color(0.02, 0.05, 0.08, 0.93))
		text(Vector2(42, size.y-194), notice, 19, Color("#ffed9b"))

func draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, view_size()), Color("#06121b"))
	draw_set_transform(menu_origin(), 0, Vector2.ONE*menu_scale())
	for entry in Content.menu_layout.entries:
		if int(entry.id) in [64, 246]:
			if int(entry.id) == 64: draw_avatar(menu_rect(entry))
			else: draw_image("assets/sound_icon_1.png", menu_rect(entry), Color.WHITE if Profile.data.settings.music else Color(0.4, 0.4, 0.4))
		if not entry.has("image"): continue
		# Friends/service placeholders and the offscreen obsolete Spice Pirates mark
		# are not visible in the offline main menu.
		if menu_descendant(entry, 263) or int(entry.id) == 300 or menu_descendant(entry, 110): continue
		var r = menu_rect(entry)
		var angle = 0.0
		var tint = Color.WHITE
		var image_path = str(entry.image)
		match entry.outlet:
			"gear1ImageView": angle = TAU*elapsed_ui/15.0
			"gear2ImageView": angle = -TAU*elapsed_ui/6.0
			"gear3ImageView": angle = TAU*elapsed_ui/20.0
			"spinnerImageView": angle = TAU*elapsed_ui/0.5
			"logoFastRotateView": angle = 0.636619746685028*elapsed_ui/0.05000000074505806
			"logoRocket1", "logoRocket2":
				image_path = "assets/logo_rocket_%d.png" % (1+int(elapsed_ui/0.075)%4)
				if entry.outlet == "logoRocket2": angle = PI
			"logoTextLightView", "logoWiresLightView", "logoLightView": tint.a = 0.35+0.45*(0.5+0.5*sin(elapsed_ui*3.0))
		if int(entry.id) == 221: continue # native startLogoAnimations hides the fourth eye
		if angle != 0.0:
			draw_set_transform(menu_origin()+r.get_center()*menu_scale(), angle, Vector2.ONE*menu_scale())
			draw_image(image_path, Rect2(-r.size/2.0, r.size), tint)
			draw_set_transform(menu_origin(), 0, Vector2.ONE*menu_scale())
		else: draw_image(image_path, r, tint)
	var name_rect = menu_rect(menu_entry("nameLabel"))
	text(name_rect.position+Vector2(0, 30), Profile.data.name, 30)
	text(menu_rect(menu_entry("howdy")).position+Vector2(0, 28), "Ahoy!", 27)
	text(Vector2(904, 163), "xp: %.0f" % Profile.data.xp, 18)
	text(Vector2(904, 188), "%d spice" % int(Profile.data.spice), 18)
	draw_set_transform(Vector2.ZERO)

func draw_world() -> void:
	var origin = world_origin()
	draw_set_transform(origin, 0, Vector2.ONE*world_zoom)
	draw_image(Content.maps.lobby_map.background, Rect2(0, 0, 4096, 3072))
	for loc in Content.catalog.tower_locations:
		if int(loc.id) >= 1000: continue
		var available = false
		var stars = 0
		for c in Content.catalog.offlineConfigs:
			if int(c.location) == int(loc.id) and c.gametype == "1" and not c.waves.is_empty():
				available = Profile.available(c)
				stars = int(Profile.data.completed.get(c.configid, 0))
		var p = Vector2(float(loc.x), float(loc.y))
		draw_circle(p, 22.0/world_zoom, Color(0.02, 0.05, 0.04, 0.75))
		draw_circle(p, 17.0/world_zoom, Color("#abd647") if available else Color("#77868b"))
		text(p+Vector2(-9.0/world_zoom, 6.0/world_zoom), "★" if stars else "▶" if available else "×", int(19.0/world_zoom))
		text(p+Vector2(-38, 45.0/world_zoom), loc.name, int(17.0/world_zoom), Color.WHITE if available else Color("#c6d1d5"))
	draw_set_transform(Vector2.ZERO)
	if not selected_location.is_empty():
		draw_rect(Rect2(view_size().x-320, 72, 320, view_size().y-135), Color(0.02, 0.07, 0.12, 0.94))

func draw_game() -> void:
	var scale = map_scale()
	draw_set_transform(map_origin(), 0, Vector2.ONE*scale)
	draw_image(sim.map.background, Rect2(0, 0, sim.map.width_pixels, sim.map.height_pixels))
	if show_grid or build_type > 0 or not magic_placement.is_empty():
		for y in range(int(sim.map.hex_height)):
			for x in range(int(sim.map.hex_width)):
				if int(sim.map.cells[y*int(sim.map.hex_width)+x].b) == 1:
					draw_hex(sim.center(x, y), Color(0.05, 0.1, 0.05, 0.28))
	for z in sim.zones:
		draw_circle(z.pos, float(z.def.get("poison_range", 1500))/1000.0*40.0, Color(0.4, 0.75, 0.05, 0.22))
	for mine in sim.mines: sprite("sfx/mine", "Idle", mine.pos)
	for portal in sim.portals:
		sprite("sfx/portals", "Blue" if portal == sim.portals[0] else "Red", portal.pos, int(sim.clock_ms/100))
	for pair in sim.static_portals:
		sprite("sfx/portals", "Blue", sim.center(pair["in"].x, pair["in"].y), int(sim.clock_ms/100))
		sprite("sfx/portals", "Red", sim.center(pair.out.x, pair.out.y), int(sim.clock_ms/100))
	for b in sim.bases:
		var pct = int(b.hp/b.hpmax*100)
		var state = "Idle-%d" % (int(ceil(pct/20.0))*20)
		sprite("bases/base"+str(b.type), state, b.pos, 0, "", Color.WHITE, -32)
		draw_rect(Rect2(b.pos.x-24, b.pos.y+19, 48, 5), Color("#2c271e"))
		draw_rect(Rect2(b.pos.x-24, b.pos.y+19, 48*b.hp/b.hpmax, 5), Color("#81cf55"))
	var objects = []
	for layer in sim.map.get("foreground", []): objects.append({"y": float(layer.y)+float(layer.tile.get("depth_pos", layer.tile.get("h", 0))), "layer": layer})
	for t in sim.towers: objects.append({"y": t.pos.y, "tower": t})
	for e in sim.enemies: objects.append({"y": e.pos.y, "enemy": e})
	objects.sort_custom(func(a, b): return a.y < b.y)
	for object in objects:
		if object.has("layer"):
			var layer = object.layer
			var tile = layer.tile
			var texture = Content.tex(layer.texture)
			if texture != null:
				draw_texture_rect_region(texture, Rect2(float(layer.x)+float(tile.get("offset_x", 0)), float(layer.y)+float(tile.get("offset_y", 0)), float(tile.w), float(tile.h)), Rect2(float(tile.get("sx", 0)), float(tile.get("sy", 0)), float(tile.w), float(tile.h)))
		elif object.has("tower"):
			var t = object.tower
			var set_name = "towers/"+str(t.def.filename)
			var animation = Content.animations.get(set_name, {}).get("states", {}).get("Rot", {})
			var frames = animation.get("added_frames", []).size()
			var frame = posmod(int(round((t.angle/TAU+0.25)*maxi(1, frames))), maxi(1, frames))
			extra_sprite(set_name, "pad1", t.pos)
			sprite(set_name, "Rot", t.pos, frame, "", Color(1, 1, 1, 0.6) if sim.clock_ms < t.ready_ms else Color.WHITE, -17)
			if t.id == selected_tower:
				var radius = float(t.def.get("range", 0))/1000.0
				paint_ellipse(t.pos, sim.range_axes(radius), Color(0.2, 0.8, 0.1, 0.22))
				text(t.pos+Vector2(-22, -70), "Lv %d · %s" % [t.level, str(t.targeting)[0].to_upper()], 16)
		else:
			var e = object.enemy
			var dir: Vector2 = e.dir
			var state = "RunDown" if dir.y > 0.5 else "RunUp" if dir.y < -0.5 else "RunDownRight" if dir.x > 0 else "RunDownLeft"
			if e.def.get("class") == "air": state = "RunDownRight" if dir.x > 0 else "RunDownLeft"
			var set_name = "creeps/"+str(e.def.filename)
			var states = Content.animations.get(set_name, {}).get("states", {})
			if not states.has(state): state = "Idle" if states.has("Idle") else str(states.keys()[0])
			var rate = float(states[state].get("speed", 17))
			var frame = int(float(sim.clock_ms-e.born_ms)/1000.0*rate)
			if str(e.def.filename) == "creep10": sprite("creeps/creep10_shadow", state, e.pos, frame)
			else: extra_sprite(set_name, "shadow", e.pos, str(e.def.get("color", "")))
			var tint = Color(0.55, 0.9, 1.0) if sim.clock_ms < sim.freeze_until else Color.WHITE
			var scale_values = e.def.traits.get("scale", [1, 1])
			var offset_values = e.def.traits.get("offset", [0, 0])
			var native_scale = Vector2(scale_values[0], scale_values[1])
			var native_offset = Vector2(offset_values[0], offset_values[1])
			sprite(set_name, state, e.pos+native_offset, frame, str(e.def.get("color", "")), tint, -30 if sim.clock_ms < e.float_until else 0, native_scale)
			if e.hp < e.max_hp:
				draw_rect(Rect2(e.pos.x-12, e.pos.y-27, 24, 3), Color("#52211b"))
				draw_rect(Rect2(e.pos.x-12, e.pos.y-27, 24*e.hp/e.max_hp, 3), Color("#a4d944"))
	for missile in sim.missiles:
		if sim.clock_ms < missile.launch_ms: continue
		draw_image("assets/towers/missile.png", Rect2(missile.pos-Vector2(5, 8), Vector2(10, 16)))
	for effect in effects:
		var remaining = float(effect.until-Time.get_ticks_msec())
		if effect.kind == "shot":
			var color = Color("#b5eaff") if effect.type in [10, 12] else Color("#fff098")
			draw_line(effect.from+Vector2(0, -20), effect.to, color, 2.0, true)
		else:
			var state = "towers/nuke_explosion" if int(effect.get("type", 0)) == 5 else "sfx/mine_explosion"
			sprite(state, "Explosion", effect.pos, int((600.0-remaining)/45.0), "", Color(1, 1, 1, clampf(remaining/300.0, 0, 1)))
	if build_type > 0:
		var cell = sim.nearest(mouse_world(get_global_mouse_position()))
		var pos = sim.center(cell.x, cell.y)
		var def = sim.tower_data(build_type, 1)
		var okay = sim.within(cell) and int(sim.map.cells[sim.cell_index(cell)].b) == 1 and sim.tower_at(cell).is_empty()
		draw_hex(pos, Color(0.3, 1.0, 0.2, 0.6) if okay else Color(1.0, 0.15, 0.08, 0.6))
		sprite("towers/"+str(def.filename), "Idle", pos, 0, "", Color(1, 1, 1, 0.75), -17)
	if str(sim.config.configid) == "1" and tutorial_step == 1:
		for c in TUTORIAL_CELLS:
			if sim.tower_at(c).is_empty(): draw_hex(sim.center(c.x, c.y), Color(0.5, 1, 0.1, 0.7))
	draw_set_transform(Vector2.ZERO)
	var size = view_size()
	draw_rect(Rect2(0, 0, size.x, 35), Color("#171c21"))
	draw_image("assets/menu_nakladka_top.png", Rect2(size.x-280, 0, 280, 35))
	text(Vector2(186, 24), "%d / %d  ·  %ds" % [sim.wave_index, sim.config.waves.size(), maxi(0, int((sim.next_wave_ms-sim.clock_ms)/1000))], 18)
	text(Vector2(size.x-274, 24), "$%d · %d spice" % [int(sim.money), int(Profile.data.spice)], 19)
	draw_image("assets/menu_nakladka_bottom.png", Rect2(0, size.y-60, size.x, 60))
	for i in range(6):
		var type = Simulation.ROOT_TYPES[i]
		var def = sim.tower_data(type, 1)
		var tint = Color.WHITE if sim.can_unlock(def) else Color(0.45, 0.5, 0.55)
		draw_image("assets/towers/tower%d_icon.png" % type, Rect2(size.x/2.0-261+i*62, size.y-60, 46, 46), tint)
		text(Vector2(size.x/2.0-254+i*62, size.y-5), "$%d" % int(def.price), 15, tint)
	for i in range(5):
		var key = ["m_freeze", "m_lsd", "m_actdef", "m_mine", "m_portal"][i]
		draw_image("assets/"+key+".png", Rect2(size.x/2.0+119+i*58, size.y-53, 34, 34), Color.WHITE if int(sim.abilities.get(key, 0)) > 0 else Color(0.45, 0.5, 0.55))
		text(Vector2(size.x/2.0+133+i*58, size.y-5), str(sim.abilities.get(key, 0)), 15)
	if sim.paused or sim.outcome != "playing":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.035, 0.77))
		draw_image("assets/gui/pause_menu_bg.png", Rect2(view_center()-Vector2(275, 235), Vector2(550, 430)))
	elif str(sim.config.configid) == "1" and tutorial_step < 8:
		draw_image("assets/tutorial/bubble1.png", Rect2(143, 55, 435, 180))
		draw_image("assets/tutorial/SPCBRD1.png", Rect2(12, 58, 147, 198))

func paint_ellipse(pos: Vector2, axes: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(49): points.append(pos+Vector2(cos(i*TAU/48.0)*axes.x, sin(i*TAU/48.0)*axes.y))
	draw_colored_polygon(points, color)

func draw_hex(pos: Vector2, color: Color) -> void:
	var b = float(sim.map.hex_base)/2.0
	var side = float(sim.map.hex_side)
	var h = float(sim.map.hex_h)/2.0
	var pts = PackedVector2Array([pos+Vector2(-b-side, 0), pos+Vector2(-b, -h), pos+Vector2(b, -h), pos+Vector2(b+side, 0), pos+Vector2(b, h), pos+Vector2(-b, h), pos+Vector2(-b-side, 0)])
	draw_polyline(pts, color, 1.2, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif screen == "game":
			if event.keycode == KEY_SPACE: toggle_pause()
			elif event.keycode == KEY_N and str(sim.config.configid) != "1": sim.next_wave()
			elif event.keycode == KEY_G: show_grid = not show_grid
			elif event.keycode >= KEY_1 and event.keycode <= KEY_6: select_build(Simulation.ROOT_TYPES[event.keycode-KEY_1])
			elif event.keycode == KEY_ESCAPE:
				if build_type > 0 or not magic_placement.is_empty() or selected_tower >= 0:
					build_type = 0
					magic_placement = ""
					sim.cancel_portal_placement()
					selected_tower = -1
					refresh_controls()
				else: toggle_pause()
	if screen not in ["game", "world"]: return
	if event is InputEventPanGesture:
		pan(event.delta*-8.0)
	elif event is InputEventMagnifyGesture:
		zoom_at(event.position, event.factor)
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			zoom_at(event.position, 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.1)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			build_type = 0
			magic_placement = ""
			sim.cancel_portal_placement()
			selected_tower = -1
			refresh_controls()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				drag_start = event.position
				drag_last = event.position
				dragging = true
				moved = false
			else:
				dragging = false
				if not moved and event.button_index == MOUSE_BUTTON_LEFT: click_map(event.position)
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(drag_start) > 8: moved = true
		if moved: pan(event.position-drag_last)
		drag_last = event.position

func pan(delta: Vector2) -> void:
	if screen == "world": world_camera -= delta/world_zoom
	elif sim != null: camera -= delta/map_scale()

func set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	Profile.data.settings.fullscreen = enabled
	if not test_session and not Profile.save_profile(): message("The window preference could not be saved.")
	refresh_controls()

func zoom_at(pos: Vector2, factor: float) -> void:
	if screen == "world":
		var before = (pos-world_origin())/world_zoom
		world_zoom = clampf(world_zoom*factor, 0.2, 1.2)
		world_camera += before-(pos-world_origin())/world_zoom
	elif sim != null:
		var before = mouse_world(pos)
		zoom = clampf(zoom*factor, 0.55, 2.6)
		camera += before-mouse_world(pos)

func click_map(pos: Vector2) -> void:
	if screen == "world":
		if not selected_location.is_empty() and pos.x > view_size().x-320: return
		for loc in Content.catalog.tower_locations:
			var point = world_origin()+Vector2(float(loc.x), float(loc.y))*world_zoom
			if point.distance_to(pos) < 25:
				selected_location = str(int(loc.id))
				refresh_controls()
				return
	elif screen == "game" and not sim.paused and sim.outcome == "playing":
		var world = mouse_world(pos)
		if not magic_placement.is_empty():
			if str(sim.config.configid) == "1" and sim.nearest(world) != Vector2i(7, 6): message("Place a mine here, cadet."); return
			var result = sim.use_ability(magic_placement, world)
			message(result)
			if result.is_empty():
				magic_placement = ""
				if str(sim.config.configid) == "1": tutorial_step = 8; sim.tutorial_finished = true; sim.next_wave()
		elif build_type > 0:
			var cell = sim.nearest(world)
			if str(sim.config.configid) == "1" and (tutorial_step != 1 or cell not in TUTORIAL_CELLS): message("You are not supposed to do that in the training area!")
			else: message(sim.build(cell, build_type))
		else:
			var t = sim.tower_at(sim.nearest(world))
			selected_tower = int(t.get("id", -1))
		refresh_controls()
