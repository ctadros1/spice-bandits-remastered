extends Node2D

const Simulation = preload("res://scripts/simulation.gd")
const Startup = preload("res://scripts/startup.gd")
const TutorialFlow = preload("res://scripts/tutorial.gd")
const TutorialView = preload("res://scripts/tutorial_view.gd")
const PortraitView = preload("res://scripts/portrait_view.gd")
const BuildHexView = preload("res://scripts/build_hex_view.gd")
const MagicView = preload("res://scripts/magic_view.gd")
const MapAnimationView=preload("res://scripts/map_animation_view.gd")
const WorldCameraView=preload("res://scripts/world_camera_view.gd")
const MessageView=preload("res://scripts/message_view.gd")
const PromotionView=preload("res://scripts/promotion_view.gd")
const UpgradeView=preload("res://scripts/upgrade_view.gd")
const MainMenuView=preload("res://scripts/main_menu_view.gd")
const MenuBubbleView=preload("res://scripts/menu_bubble_view.gd")
const MenuFloatView=preload("res://scripts/menu_float_view.gd")
const MenuMotionView=preload("res://scripts/menu_motion_view.gd")
const AudioMix = preload("res://scripts/audio_mix.gd")
const ClassicUI = preload("res://scripts/classic_ui.gd")
const MagicPanelView = preload("res://scripts/magic_panel_view.gd")
const RewardClockView = preload("res://scripts/reward_clock_view.gd")
const RewardView = preload("res://scripts/reward_view.gd")
const XPEmitterView = preload("res://scripts/xp_emitter_view.gd")
const CreepLight = preload("res://scripts/creep_light_view.gd")
const CreepStatus = preload("res://scripts/creep_status_view.gd")
const Animator=preload("res://scripts/animator_view.gd")
const CreepAnimator=preload("res://scripts/creep_animator_view.gd")
var creep_animation_owners:Dictionary={}
var animation_epoch=0
var animation_delta_ms=0.0
const TowerPreview = preload("res://scripts/tower_preview_view.gd")
const MenuNavigation=preload("res://scripts/menu_navigation.gd")
const MapDepth=preload("res://scripts/map_depth.gd")
var tower_depth_cache:Dictionary={}
var base_depth_cache:Dictionary={}
var creep_depth_cache:Dictionary={}
var reference_creep_layers=false
var probe_creep_layers=false
var creep_layer_usage={"cached":0,"reference":0}
var probe_placement_order=false
var placement_draw_trace:Array=[]
const TUTORIAL_CELLS = [Vector2i(7, 4), Vector2i(8, 6), Vector2i(6, 7), Vector2i(11, 3)]
var main_menu_view=MainMenuView.new()
var menu_bubbles=MenuBubbleView.new()
var menu_floats=MenuFloatView.new()
var menu_motion=MenuMotionView.new()
var screen = "menu"
var spicery_catalog_fixture=false
var menu_navigation_request:Dictionary={}
var menu_transition
var menu_content_capture=false
var qa_menu_motion=false
var menu_navigation_token=0
var portrait_view
var desired_portrait:Dictionary={}
var fan_opened=-1.0
var world_camera_from=Vector2.ZERO
var world_camera_to=Vector2.ZERO
var mode_animation_key=""
var mode_states:Dictionary={}
var fan_closing=false
var fan_close_phase=0.0
var sim: BanditSimulation
var ui: Control
var font: Font
var bold: Font
var handwriting:Font
var camera = Vector2(440, 350)
var world_camera = Vector2(920, 1530)
var zoom = 1.0
var world_zoom = 1.0
var build_type = 0
var tower_preview_state:Dictionary={}
var tower_preview_animation="Idle"
var tower_preview_facing=0.0
var build_hex_view=BuildHexView.new()
var magic_placement = ""
var magic_preview_position=Vector2.ZERO
var world_decor=MapAnimationView.new()
var world_decor_dt_ms=0.0
var world_blades
var world_clouds
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
var continuous_beams: Dictionary={}
var qa_timings:Dictionary={}
var qa_performance_active="--qa-performance" in OS.get_cmdline_user_args()

func record_qa_time(key:String,started:int) -> void:
	if not qa_performance_active:return
	var value=qa_timings.get(key,{"total_usec":0,"calls":0})
	value.total_usec+=Time.get_ticks_usec()-started;value.calls+=1;qa_timings[key]=value
var particle_fx
var battle_overlay
var bolt_renderer
var reward_fx
var reward_burst_fx
var reward_spice_burst=false
var reward_medal_bursts:Dictionary={}
var wave_fx
var wave_collapse:Dictionary={}
var magic_panel_root:Control
var hud_layer
var hud_money_flash=ClassicUI.Wallet.flash_initial()
var music: AudioStreamPlayer
var ambient: AudioStreamPlayer
var audio_mix = AudioMix.new()
var music_path = ""
var voices: Array[AudioStreamPlayer] = []
var audio_cache: Dictionary = {}
var last_sound: Dictionary = {}
var tutorial_step = 0
var tutorial
var tutorial_layout: Dictionary = {"images": [], "labels": []}
var pending_sale = -1
var sale_started = 0.0
var pending_technology: Dictionary = {}
var pending_abandon = ""
var question_key=""
var question_alpha=0.0
var question_dim=0.0
var question_closing=false
var question_root
var promotions: Array[Dictionary] = []
var promotion_open = false
var promotion_was_paused = false
var promotion_state:Dictionary={}
var guidance_type = 0
var selected_shop = ""
var selected_upgrade = ""
var upgrade_view_states:Dictionary={}
var upgrade_scroll_y=0.0
var upgrade_scroll_from=0.0
var upgrade_scroll_to=0.0
var upgrade_scroll_age=0.3
var selected_medal: Dictionary = {}
var dress_group = 0
var dress_preview: Dictionary = {}
var menu_scroll = 0
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
var startup: Control
var qa_intro_variant = 0
var qa_real_seconds = -1.0
var pending_xp: Array[Dictionary] = []
var credited_score = 0.0
var credited_kills = 0
var battle_initial_xp = 0
var next_xp_save = 0
var next_result_retry = 0
var qa_persist_progress = false
var quit_pending = false
var qa_gallery = false
var qa_water = false
var tower_drag = false
var tower_drag_moved = false
var suppress_tower_release=false
var tower_drag_position = Vector2.ZERO
var magic_inventory_open = false
var magic_panel_state=MagicPanelView.initial()
var magic_shortcuts:Array=["m_freeze","m_lsd","m_actdef","m_mine"]
var magic_last_use:Dictionary={}
var tower_panel_close_at=-1.0
var hovered_tower_type=0

func tower_panel_alpha() -> float:
	return clampf(1.0-(elapsed_ui-tower_panel_close_at)/0.4,0,1) if tower_panel_close_at>=0 else 1.0
var loading_name = ""
var loading_started = 0.0
var loading_token = 0
var result_started = -1.0
var battle_spice_reward=0
var battle_medals:Array=[]
var loading_kind="arrival"
var reward_bar_emitting=false
var reward_bar_releasing=false
var reward_bar_previous_tip=Vector2.ZERO
var qa_result_render_count=0
var qa_result_render_age=-1.0
var result_previous_xp=0.0
var result_clock:Dictionary={}
var result_clock_age=0.0
var result_closed_delay=0.0
var result_initial_delay=0.0
var transition
var map_underlay

func original_transitions_enabled() -> bool:
	return not test_session or "--qa-loading" in OS.get_cmdline_user_args()

func cover_scene() -> void:
	if transition.phase==2:await transition.revealed
	if transition.phase==3:transition.open()
	if transition.phase==0:await transition.covered

func _ready() -> void:
	reset_main_menu_presentation()
	font = load("res://assets/fonts/Kautiva Pro.otf")
	bold = load("res://assets/fonts/Kautiva Pro Bold.otf")
	handwriting=load("res://assets/fonts/AlphaMackAOE.ttf")
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	portrait_view=preload("res://scripts/portrait_view.gd").new();portrait_view.app=self
	menu_transition=preload("res://scripts/menu_transition.gd").new();menu_transition.app=self;add_child(menu_transition)
	map_underlay=preload("res://scripts/map_underlay.gd").new();map_underlay.app=self
	map_underlay.show_behind_parent=true;add_child(map_underlay)
	var transition_layer=CanvasLayer.new();transition_layer.layer=100;add_child(transition_layer)
	transition=preload("res://scripts/transition_view.gd").new();transition_layer.add_child(transition)
	particle_fx = preload("res://scripts/particle_fx.gd").new()
	particle_fx.app = self
	add_child(particle_fx)
	move_child(particle_fx, 0)
	bolt_renderer=preload("res://scripts/bolt_renderer.gd").new()
	bolt_renderer.app=self
	add_child(bolt_renderer)
	move_child(bolt_renderer,0)
	battle_overlay = preload("res://scripts/battle_overlay.gd").new()
	battle_overlay.app = self
	add_child(battle_overlay)
	move_child(battle_overlay,2)
	reward_fx=preload("res://scripts/particle_fx.gd").new();reward_fx.app=self;reward_fx.screen_space=true
	add_child(reward_fx);move_child(reward_fx,3)
	reward_burst_fx=preload("res://scripts/particle_fx.gd").new();reward_burst_fx.app=self;reward_burst_fx.screen_space=true
	reward_burst_fx.clock_multiplier=RewardView.f32(1.6)
	add_child(reward_burst_fx);move_child(reward_burst_fx,4)
	wave_fx=preload("res://scripts/wave_fx.gd").new();wave_fx.app=self;add_child(wave_fx);move_child(wave_fx,3)
	# RenderGUI0xd5738 places the inventory under the tower dock. Keep
	# both below outcome/tutorial chrome, which lives in the later layers.
	magic_panel_root=Control.new();magic_panel_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(magic_panel_root);move_child(magic_panel_root,2)
	hud_layer=preload("res://scripts/hud_layer.gd").new();hud_layer.app=self;add_child(hud_layer);move_child(hud_layer,3)
	var tutorial_before_hud=preload("res://scripts/tutorial_gl_layer.gd").new();tutorial_before_hud.app=self;tutorial_before_hud.phase="before_hud";add_child(tutorial_before_hud);move_child(tutorial_before_hud,2)
	music = AudioStreamPlayer.new()
	add_child(music)
	ambient = AudioStreamPlayer.new()
	add_child(ambient)
	for i in range(20):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	get_viewport().size_changed.connect(refresh_window_layout)
	var args = OS.get_cmdline_user_args()
	test_session = "--qa" in args or bool(get_meta("qa_fixture", false))
	if test_session:
		Profile.verification_context = true
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_title("Spice Bandits Remastered — Verification %d"%OS.get_process_id())
		if Profile.path == "user://profile.json": Profile.path = "user://qa/profile.json"
		print("QA_CONTEXT ", JSON.stringify({"test_session": test_session, "profile_path": Profile.path, "verification_context": Profile.verification_context}))
	world_blades=preload("res://scripts/world_blade_view.gd").new();add_child(world_blades);move_child(world_blades,0);world_blades.setup(test_session)
	world_clouds=preload("res://scripts/world_cloud_view.gd").new();world_clouds.app=self;add_child(world_clouds);move_child(world_clouds,1);world_clouds.setup(test_session)
	# CMusicPlayer::CreatePlayList/Play chooses one preserved track and loops
	# it across scenes. It does not assign separate menu/battle themes.
	music_path = "res://assets/music/spice_pirates_theme_v%d.mp3" % (7 if test_session else randi_range(7, 8))
	qa_persist_progress = test_session and ("--qa-persist-progress" in args or "--qa-input-rewards" in args)
	if test_session and "--qa-fresh-profile" in args:
		Profile.data = Profile.fresh()
		Profile.data.settings.music = false
		Profile.data.settings.sound = false
	get_tree().auto_accept_quit = false
	qa_demo = test_session and "--qa-demo" in args
	qa_water = test_session and "--qa-water" in args
	for arg in args:
		if arg.begins_with("--capture="): qa_capture = arg.trim_prefix("--capture=")
		if test_session and arg.begins_with("--qa-state-file="): qa_state_path = arg.trim_prefix("--qa-state-file=")
	if bool(Profile.data.settings.fullscreen): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	collect_promotions(0)
	refresh_controls()
	play_music()
	for arg in args:
		if arg.begins_with("--mission="): start_mission(arg.trim_prefix("--mission="), test_session)
		elif arg.begins_with("--screen="): navigate(arg.trim_prefix("--screen="))
	if not Profile.recovery_message.is_empty(): message(Profile.recovery_message)
	qa_gallery = test_session and "--qa-render-all" in args
	if qa_gallery: render_campaign_gallery.call_deferred()
	if test_session and "--qa-projectile-gallery" in args:
		qa_gallery = true
		render_projectile_gallery.call_deferred()
	if test_session and "--qa-turn-gallery" in args:
		qa_gallery = true
		render_turn_gallery.call_deferred()
	for arg in args:
		if test_session and arg.begins_with("--qa-intro-variant="):
			qa_intro_variant = clampi(int(arg.trim_prefix("--qa-intro-variant=")), 1, 2)
	if screen == "menu" and (not test_session or "--qa-intro" in args): show_startup()
	if test_session and "--qa-run-tutorial" in args:
		var driver = load("res://scripts/tutorial_verify.gd").new()
		driver.app = self
		add_child(driver)
		driver.completed.connect(func(status: int): get_tree().quit(status))
		get_tree().create_timer(60.0).timeout.connect(func():
			if not driver.finished: push_error("Tutorial QA did not complete within60 seconds."); get_tree().quit(1))
		driver.run.call_deferred()
	if test_session and "--qa-audio" in args:
		var driver = load("res://scripts/audio_verify.gd").new()
		driver.app = self
		add_child(driver)
		driver.completed.connect(func(status: int): get_tree().quit(status))
		driver.run.call_deferred()
	if test_session and "--qa-menus" in args:
		var driver = load("res://scripts/menu_verify.gd").new()
		driver.app = self
		add_child(driver)
		driver.completed.connect(func(status: int): get_tree().quit(status))
		get_tree().create_timer(60.0).timeout.connect(func():
			if not driver.finished: push_error("Menu QA did not complete within60 seconds.");get_tree().quit(1))
		driver.run.call_deferred()
	if test_session and "--qa-presentation" in args:
		var driver=load("res://scripts/presentation_verify.gd").new();driver.app=self;add_child(driver)
		driver.completed.connect(func(status:int):get_tree().quit(status))
		get_tree().create_timer(60.0).timeout.connect(func():if not driver.finished:push_error("Presentation QA exceeded60 seconds.");get_tree().quit(1))
		driver.run.call_deferred()
	if test_session and "--qa-performance" in args:
		var driver=load("res://scripts/performance_verify.gd").new();driver.app=self;add_child(driver)
		get_tree().create_timer(60.0).timeout.connect(func():push_error("Performance QA exceeded60 seconds.");get_tree().quit(1))
		driver.run.call_deferred()
	if test_session and "--qa-exit-xp-fixture" in args:
		# Synthetic quit-save case: two50-score kills, no battle completion.
		Profile.path = "user://verification/quit-xp-profile.json"
		Profile.data = Profile.fresh()
		Profile.read_only = false
		Profile.data.settings.music = false
		Profile.data.settings.sound = false
		for medal in Content.catalog.tower_medals: Profile.data.medals.append(Profile.medal_id(medal))
		if not Profile.save_profile(): push_error("Could not initialize isolated quit fixture.")
		qa_persist_progress = true
		start_mission("8", true, false)
		sim.score = 100.0
		sim.kills = 2
		handle_event({"kind": "kill", "id": 100, "pos": Vector2.ZERO, "type": 1, "reward": 50.0, "ms": 0})
		handle_event({"kind": "kill", "id": 101, "pos": Vector2.ZERO, "type": 1, "reward": 50.0, "ms": 0})
		next_xp_save = Time.get_ticks_msec()+600000
	if test_session and "--qa-tower-fixture" in args:
		# Renderer-only atlas fixture; never credit placements or campaign progress.
		start_mission("8", true, false)
		qa_gallery = true
		sim.clock_ms = 1200
		for type in range(1, 19):
			for level in range(1, 4):
				var index = (type-1)*3+level-1
				var cell = Vector2i(6+index%9, 4+int(index/9)*2)
				sim.towers.append({"id": index+1, "type": type, "level": level, "cell": cell,
					"pos": sim.center(cell.x, cell.y), "def": sim.tower_data(type, level), "angle": float(index%9)*40,
					"ready_ms": 0, "born_ms": 0, "foundation_ms": 0, "targeting": "fastest", "receipts": []})
		camera = sim.center(10, 9)
		zoom = 0.85
		refresh_controls()

func show_startup() -> void:
	if is_instance_valid(startup): return
	startup = Startup.new()
	startup.variant = qa_intro_variant if qa_intro_variant > 0 else randi_range(1, 2)
	music.stop()
	startup.finished.connect(func(): startup = null; play_music())
	# A dedicated top layer prevents startup taps reaching menu controls.
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(startup)
	startup.finished.connect(layer.queue_free)

func refresh_window_layout() -> void:
	menu_navigation_token+=1;menu_transition.clear()
	portrait_view.clear()
	refresh_controls()
	queue_redraw()
	if DisplayServer.get_name()=="headless":return
	# macOS can retain the previous surface while a window is covered during
	# fullscreen transitions. Draw the resized canvas after scene notifications.
	await get_tree().process_frame
	RenderingServer.force_draw(true)

func view_size() -> Vector2:
	return get_viewport_rect().size

func view_center() -> Vector2:
	return view_size()/2.0

func map_scale() -> float:
	if sim == null: return 1.0
	return minf(view_size().x/1024.0, view_size().y/768.0)*zoom

func map_origin() -> Vector2:
	return view_center()-camera*map_scale()

func bound_camera() -> void:
	if sim==null or qa_gallery:return
	# CMap::BoundOffset0x1081d8 clamps the translated map after initial
	# camera selection and during navigation. Use the desktop HUD/dock
	# play rectangle for the corresponding bounds. Small maps center.
	var scale=map_scale()
	var area=Rect2(Vector2(0,35),view_size()-Vector2(0,95))
	var extent=Vector2(float(sim.map.width_pixels),float(sim.map.height_pixels))*scale
	var origin=map_origin()
	for axis in range(2):
		if extent[axis]<=area.size[axis]:origin[axis]=area.position[axis]+(area.size[axis]-extent[axis])/2.0
		else:origin[axis]=clampf(origin[axis],area.end[axis]-extent[axis],area.position[axis])
	camera=(view_center()-origin)/scale

func mouse_world(pos: Vector2) -> Vector2:
	return (pos-map_origin())/map_scale()

func world_origin() -> Vector2:
	return view_center()-world_camera*world_zoom

func bound_world_camera() -> void:
	var origin=WorldCameraView.bound_origin(world_origin(),world_zoom,view_size())
	world_camera=(view_center()-origin)/world_zoom

func clear_ui() -> void:
	for child in ui.get_children():
		if child.has_meta("uikit_portrait"):continue
		ui.remove_child(child)
		child.queue_free()
	if is_instance_valid(magic_panel_root):
		for child in magic_panel_root.get_children():
			magic_panel_root.remove_child(child);child.queue_free()

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
	# Callbacks rebuild the controls. Mark the input handled before removing
	# the pressed button, so its release cannot also become a battlefield tap.
	b.pressed.connect(func(): get_viewport().set_input_as_handled(); action.call())
	b.pressed.connect(func(): if not b.has_meta("native_menu_navigation") and not b.get_meta("suppress_generic_click",false):sound("UI_click"))
	parent.add_child(b)
	return b

func label(parent: Control, value: String, rect: Rect2, size: int = 17, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = rect.position
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	# Give wrapping a real width before assigning text. A zero-width Label
	# can retain its initial thousands-pixel minimum height after reflow.
	l.size = rect.size
	l.text = value
	return l

func refresh_controls() -> void:
	if screen=="game":bound_camera()
	if ui == null: return
	if is_instance_valid(particle_fx):particle_fx.visible=screen=="game"
	if reward_fx != null:
		reward_fx.visible = (screen=="game" and sim!=null and sim.outcome!="playing") or (screen=="loading" and loading_kind=="departure")
		reward_burst_fx.visible=screen=="game" and sim!=null and sim.outcome!="playing"
	clear_ui()
	desired_portrait={}
	tutorial_layout = {"images": [], "labels": []}
	var size = view_size()
	if screen == "menu":
		menu_controls()
	elif screen == "loading":
		pass
	elif screen == "story":
		var image=story_image_rect()
		var caption=label(ui,str(story_location.story_desc),Rect2(17,view_center().y+floor(image.size.y/2)+20,990,100),24,Color(1,1,1,0.35))
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		var prompt=label(ui,"Tap to continue",Rect2(0,view_center().y+floor(image.size.y/2)+117,view_size().x,26),14,Color(1,1,1,0.5))
		prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		invisible_button(ui,"Continue",Rect2(Vector2.ZERO,view_size()),func():start_mission(story_mission,false,false))
	elif screen == "game":
		invisible_button(ui,"%dx"%speed,Rect2(0,0,72,38),cycle_speed)
		invisible_button(ui,"Menu",Rect2(size.x-71,0,71,45),toggle_pause)
		if not promotions.is_empty(): promotion_indicator(Rect2(size.x-515,2,90,30))
		invisible_button(ui,"Next wave",Rect2(75,0,180,30),func():
			if tutorial==null:request_wave_launch();queue_redraw())
		for i in range(6):
			var type=Simulation.ROOT_TYPES[i]
			var definition=sim.tower_data(type,1)
			var control=invisible_button(ui,"Build "+str(definition.name),ClassicUI.tower_rect(self,i),select_build.bind(type))
			control.mouse_entered.connect(func():hovered_tower_type=type;queue_redraw())
			control.mouse_exited.connect(func():if hovered_tower_type==type:hovered_tower_type=0;queue_redraw())
			control.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
					begin_tower_drag(type,get_global_mouse_position()))
		invisible_button(ui,"Magic",Rect2(ClassicUI.dock_origin(self)+Vector2(387,15),Vector2(44,44)),toggle_magic_inventory)
		var shortcut_keys=ClassicUI.shortcuts(self)
		for i in range(shortcut_keys.size()):
			var key=shortcut_keys[i]
			invisible_button(ui,str(ClassicUI.magic_offer(key).get("itemname",key)),ClassicUI.magic_rect(self,i),magic.bind(key))
		if magic_panel_state.visible: magic_inventory_controls()
		if selected_tower >= 0:
			var t = sim.find_tower(selected_tower)
			if not t.is_empty():
				tower_controls(t)
		if promotion_open: pass
		elif sim.paused: pause_controls()
		elif sim.outcome != "playing": results_controls()
		elif tutorial != null: tutorial_controls()
		if pending_sale >= 0 and not sim.paused and sim.outcome == "playing": sale_controls()
		if not pending_technology.is_empty() and not sim.paused and sim.outcome == "playing": technology_controls()
	else:
		if screen not in ["world","spicery","career", "shop", "upgrades", "credits", "medals", "dress"]:
			button(ui, "Home", Rect2(8, 8, 86, 42), func(): navigate("menu"))
			if screen not in ["world","spicery"]:
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
	if screen in ["world","career","dress","shop","upgrades","spicery"]:original_tabs()
	if quit_pending: quit_controls()
	if screen != "game" and not promotions.is_empty(): promotion_indicator(Rect2(size.x-140,7,100,43))
	if promotion_open and not promotions.is_empty(): promotion_controls()
	if guidance_type>0:guidance_controls()
	if desired_portrait.is_empty():portrait_view.sync({},"","",Callable())
	else:portrait_view.sync(desired_portrait.layout,desired_portrait.key,desired_portrait.caption,desired_portrait.action)
	queue_redraw()
	if is_instance_valid(battle_overlay): battle_overlay.queue_redraw()

func tower_popup_rects(t: Dictionary) -> Dictionary:
	# CTowerPanel::Update 0xee200: fixed tablet pixels after map projection.
	var point = (map_origin()+(t.pos+Vector2(0, -7))*map_scale()).floor()
	var size = view_size()
	var sell = Vector2(maxf(0, point.x-124), maxf(30, point.y-111))
	var options = sim.upgrade_options(t)
	var first = Vector2(point.x+31, maxf(30, point.y-111))
	if sell.x > point.x-124: first.x = sell.x+115
	first.x = minf(first.x, size.x-97)
	var upgrades: Array[Rect2] = []
	if options.size() == 2:
		first = Vector2(point.x-2, maxf(30, point.y-141))
		if sell.x > point.x-124: first.x = sell.x+97
		var second = first+Vector2(52, 61)
		if second.x+96 > size.x: second.x = size.x-96; first.x = second.x
		upgrades = [Rect2(first+Vector2(4, 4), Vector2(96, 71)), Rect2(second+Vector2(4, 4), Vector2(96, 71))]
	elif not options.is_empty(): upgrades = [Rect2(first, Vector2(97, 74))]
	# RenderSettingButtons 0xf1bf0: W/S/F at -71/0/+71, Y+65.
	var settings = Vector2(clampf(point.x, 103, size.x-103), clampf(point.y+65, 30, size.y-82))
	return {"sell": Rect2(sell, Vector2(97, 74)), "upgrades": upgrades, "settings": settings}

func picture_button(value: String, rect: Rect2, action: Callable, normal: Rect2, hover: Rect2, disabled: bool = false) -> Button:
	var b = button(ui, value, rect, action, null, disabled)
	# Keep the semantic label for keyboard/accessibility and the QA driver.
	# The preserved artwork supplies the visible label, without stretching it.
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 1)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]: b.add_theme_color_override(state, Color.TRANSPARENT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style = StyleBoxTexture.new()
		style.texture = atlas("assets/gui/ingame_menus.png", hover if state in ["hover", "pressed"] else normal)
		if disabled: style.modulate_color = Color(1, 1, 1, 1.0/3.0)
		b.add_theme_stylebox_override(state, style)
	b.tooltip_text = ""
	b.size = rect.size # Reapply after replacing the full-size semantic label.
	return b

func tower_controls(t: Dictionary) -> void:
	var first_child=ui.get_child_count()
	# The native sale expansion overlays these widgets; keep their artwork
	# visible while sale_controls' foreground blocker consumes all input.
	var rects = tower_popup_rects(t)
	var sell_allowed = tutorial == null or (tutorial.page in [10, 11] and t.cell == Vector2i(11, 3))
	picture_button("Sell $%d" % sim.sell_price(t), rects.sell, request_sale.bind(int(t.id)), Rect2(0, 75, 97, 74), Rect2(0, 149, 97, 74), not sell_allowed)
	var options = sim.upgrade_options(t)
	var branch_art = {2: [Vector2(691, 96), Vector2(557, 8)], 3: [Vector2(758, 96), Vector2(624, 8)],
		5: [Vector2(758, 140), Vector2(624, 52)], 6: [Vector2(691, 140), Vector2(557, 52)],
		8: [Vector2(691, 184), Vector2(557, 96)], 9: [Vector2(758, 184), Vector2(624, 96)],
		11: [Vector2(758, 8), Vector2(557, 140)], 12: [Vector2(758, 52), Vector2(624, 140)],
		14: [Vector2(98, 224), Vector2(557, 184)], 15: [Vector2(165, 224), Vector2(624, 184)],
		17: [Vector2(165, 268), Vector2(691, 52)], 18: [Vector2(98, 268), Vector2(691, 8)]}
	for i in range(options.size()):
		var option = options[i]
		var def = sim.tower_data(option[0], option[1])
		var disabled = (sim.can_unlock(def) and sim.money < float(def.price)) or (tutorial != null and int(t.level) >= 2)
		var action = func():
			if not sim.can_unlock(def): request_technology(def); return
			var result=sim.upgrade_tower(t.id,option[0],option[1])
			message(result)
			# SwitchPage8 requests CTowerPanel's400ms time-close. Closing
			# removes its hit areas so they cannot cover the next tutorial tower.
			if result.is_empty() and tutorial!=null:tower_panel_close_at=elapsed_ui
			update_tutorial();refresh_controls()
		var value = "%s $%d" % [def.name, int(def.price)]
		if options.size() == 1: picture_button(value, rects.upgrades[i], action, Rect2(97, 75, 97, 74), Rect2(97, 149, 97, 74), disabled)
		else:
			var b = picture_button(value, rects.upgrades[i], action, Rect2(0, 224, 96, 71), Rect2(0, 224, 96, 71), disabled)
			var icon = TextureRect.new()
			icon.texture = atlas("assets/gui/ingame_menus.png", Rect2(branch_art[int(option[0])][0], Vector2(65, 43)))
			icon.position = Vector2(16, 15)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if disabled: icon.modulate.a = 1.0/3.0
			b.add_child(icon)
			b.mouse_entered.connect(func(): icon.texture = atlas("assets/gui/ingame_menus.png", Rect2(branch_art[int(option[0])][1], Vector2(65, 43))))
			b.mouse_exited.connect(func(): icon.texture = atlas("assets/gui/ingame_menus.png", Rect2(branch_art[int(option[0])][0], Vector2(65, 43))))
	var setting_art = [[Rect2(452, 460, 64, 52), Rect2(516, 460, 64, 52)], [Rect2(449, 104, 64, 52), Rect2(449, 156, 64, 52)], [Rect2(386, 75, 64, 52), Rect2(386, 127, 64, 51)]]
	for i in range(3):
		var target = ["fastest", "strongest", "weakest"][i]
		var active = t.targeting == target
		var rect = Rect2(rects.settings+Vector2(71-i*71-32, 0), Vector2(64, 52))
		picture_button(target.capitalize(), rect, func(): t.targeting = target; sim.record("target", {"id": t.id, "mode": target}); refresh_controls(), setting_art[i][0 if active else 1], setting_art[i][0])
	for i in range(first_child,ui.get_child_count()):
		var control=ui.get_child(i);control.set_meta("tower_panel",true);control.modulate.a=tower_panel_alpha()

func navigate(value: String, show_transition:bool=true) -> void:
	if not flush_pending_xp() or not save_result(): return
	if screen==value:return
	var old_menu=int(MenuNavigation.IDS.get(screen,0))
	var new_menu=int(MenuNavigation.IDS.get(value,0))
	menu_navigation_request=MenuNavigation.request(old_menu,new_menu)
	menu_navigation_token+=1
	var navigation_token=menu_navigation_token
	var animate_menu=show_transition and old_menu>=100 and old_menu<=105 and new_menu>=100 and new_menu<=105 and menu_navigation_request.animation and DisplayServer.get_name()!="headless" and (not test_session or qa_menu_motion)
	var previous_content:Texture2D=null
	if animate_menu:previous_content=capture_menu_content()
	menu_transition.clear()
	if show_transition and screen=="game" and value in ["world","credits"] and original_transitions_enabled():
		await cover_scene()
		loading_token+=1
		var token=loading_token
		loading_kind="departure";loading_started=elapsed_ui
		screen="loading"
		ambient.stop()
		reward_fx.reset()
		reset_reward_bursts()
		start_departure_particles()
		refresh_controls()
		transition.close()
		await transition.revealed
		await get_tree().create_timer(3.0).timeout
		if loading_token==token and screen=="loading":
			await cover_scene()
			navigate(value,false)
			transition.close()
		return
	screen = value
	if screen=="menu":reset_main_menu_presentation()
	upgrade_view_states.clear();selected_upgrade="";upgrade_scroll_y=0.0;upgrade_scroll_to=0.0;upgrade_scroll_age=0.3
	guidance_type=0
	notice_until = 0
	selected_medal={}
	if screen != "dress": dress_preview.clear()
	menu_scroll = 0
	pending_technology.clear()
	if screen != "game":
		reward_fx.reset()
		reset_reward_bursts()
		reward_bar_emitting = false
		reward_bar_releasing=false;reward_bar_previous_tip=Vector2.ZERO
		ambient.stop()
		for voice in voices: voice.stop()
		audio_mix = AudioMix.new()
	selected_location = ""
	var guide={"world":2 if not Profile.unlocked("tut") else 3 if not Profile.unlocked("mo1_sp") else 0,"shop":7,"career":22,"dress":23,"upgrades":21,"spicery":24}.get(screen,0)
	if guide>0:offer_guidance(guide)
	refresh_controls()
	play_music()
	if new_menu>=100 and new_menu<=105 and menu_navigation_request.sound:sound("UI_tab_select_and_move-mono")
	if animate_menu:
		# Keep the outgoing frame until the new CanvasItem commands and
		# controls have rendered. Capturing during the same callback retains
		# the old backdrop on Godot's deferred draw queue.
		menu_transition.start(previous_content,null,menu_navigation_request)
		await get_tree().process_frame
		if menu_navigation_token==navigation_token and screen==value:
			menu_transition.start(previous_content,capture_menu_content(),menu_navigation_request)

func capture_menu_content() -> Texture2D:
	# The GL map sits outside the native viewContentContainer. A tab's
	# content snapshot must not move it, the user-info bars or tutorial views.
	if screen=="world":
		var empty=Image.create(1,1,false,Image.FORMAT_RGBA8);empty.fill(Color.TRANSPARENT)
		return ImageTexture.create_from_image(empty)
	var hidden=[]
	for control in ui.get_children():
		if control.visible and (control.has_meta("menu_chrome") or control.has_meta("guidance_view")):
			hidden.append(control);control.hide()
	var transition_visible=menu_transition.visible;menu_transition.hide()
	menu_content_capture=true;queue_redraw();RenderingServer.force_draw(true)
	var picture=get_viewport().get_texture().get_image()
	# canvas_items/keep may add borders when resized; crop the viewport's
	# aspect-fit content without changing any authored asset proportions.
	var image_size=Vector2(picture.get_size());var factor=minf(image_size.x/view_size().x,image_size.y/view_size().y)
	var content_size=view_size()*factor
	picture=picture.get_region(Rect2i((image_size-content_size)/2,content_size))
	menu_content_capture=false
	for control in hidden:control.show()
	menu_transition.visible=transition_visible;queue_redraw()
	return ImageTexture.create_from_image(picture)

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

func reset_main_menu_presentation() -> void:
	var seed_value=114 if "--qa" in OS.get_cmdline_user_args() else -1
	main_menu_view.reset(seed_value)
	var sources:Array=[]
	var float_entries:Array=[]
	var fly_entries:Array=[]
	var note_entries:Array=[]
	var fly_frame=Rect2()
	var note_frame=Rect2()
	var bubble_frame=Rect2()
	for entry in Content.menu_layout.entries:
		if int(entry.id)==268:bubble_frame=menu_rect(entry)
		if int(entry.id)==394:fly_frame=menu_rect(entry)
		if int(entry.id)==110:note_frame=menu_rect(entry)
		if not entry.ancestors.is_empty() and int(entry.ancestors[-1])==394:fly_entries.append(entry)
		if not entry.ancestors.is_empty() and int(entry.ancestors[-1])==110:note_entries.append(entry)
		if not entry.ancestors.is_empty() and int(entry.ancestors[-1])==77:
			sources.append(menu_rect(entry));float_entries.append({"id":int(entry.id),"rect":menu_rect(entry)})
	menu_bubbles.reset(sources,bubble_frame,seed_value)
	menu_floats.reset(float_entries,768.0,seed_value)
	menu_motion.reset(fly_entries,fly_frame,note_entries,note_frame,seed_value)

func advance_main_menu_presentation(seconds:float) -> void:
	main_menu_view.advance(seconds);menu_bubbles.advance(seconds);menu_floats.advance(seconds)
	menu_motion.advance(seconds,bool(Profile.data.settings.music))
	update_menu_float_controls()

func update_menu_float_controls() -> void:
	if screen!="menu" or not is_instance_valid(ui):return
	for control in ui.get_children():
		if not control.has_meta("menu_float_id"):continue
		var state=menu_floats.pose(int(control.get_meta("menu_float_id")))
		var rect:Rect2=control.get_meta("menu_float_rect")
		control.pivot_offset=rect.size*menu_scale()/2
		control.position=menu_origin()+(rect.position+state.translation)*menu_scale()
		control.rotation=state.rotation

func menu_controls() -> void:
	var menus = [["playButton", "Play", "world", 60], ["careerButton", "Career", "career", 42],
		["tech_shopButton", "Tech shop", "shop", 42], ["upgradesButton", "Upgrades", "upgrades", 42], ["spiceryButton", "Spicery", "spicery", 42]]
	for item in menus:
		var entry=menu_entry(item[0])
		var source_rect=menu_rect(entry)
		var r = source_rect
		r = Rect2(menu_origin()+r.position*menu_scale(), r.size*menu_scale())
		var b = button(ui, item[1], r, navigate.bind(item[2]))
		b.set_meta("menu_float_id",int(entry.id));b.set_meta("menu_float_rect",source_rect)
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
	update_menu_float_controls()

func location_visible(loc: Dictionary) -> bool:
	if int(loc.id) == 1000: return not Profile.unlocked("pass7_af") and Profile.available(Content.mission("322"))
	return Content.catalog.offlineConfigs.any(func(c):return int(c.location)==int(loc.id) and not c.waves.is_empty() and Profile.available(c))

func world_controls() -> void:
	if selected_location.is_empty(): return
	var size = view_size()
	var loc = Content.location(selected_location)
	var x = size.x-320
	if int(loc.id) == 1000:
		label(ui,loc.name,Rect2(x+20,90,280,45),27)
		label(ui, "Continue your conquest in Africa.", Rect2(x+20,145,280,90),24)
		for i in range(2):
			var tag = str(loc.pass_free_tag if i else loc.pass_tag)
			var offers = Content.catalog.shopList.filter(func(o):return str(o.tag)==tag)
			if offers.is_empty(): continue
			var offer = offers[0]
			var caption = "Free pass · level %s" % offer.levellock if i else "Africa pass · %s spice" % offer.pricespice
			button(ui,caption,Rect2(x+16,280+i*75,288,60),func():transaction_feedback(Profile.purchase(offer));selected_location="";refresh_controls(),null,int(Profile.data.level)<int(offer.levellock) or int(Profile.data.spice)<int(offer.pricespice))
		button(ui,"Close",Rect2(x+16,660,288,45),func():selected_location="";refresh_controls())
		return
	ClassicUI.modes_controls(self)

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

func interface_entry(layout: String, value: String) -> Dictionary:
	for entry in Content.interface_layouts[layout].entries:
		if str(entry.outlet) == value: return entry
	return {}

func entry_rect(entry: Dictionary, origin: Vector2 = Vector2.ZERO, factor: float = 1.0) -> Rect2:
	var r = entry.rect
	return Rect2(origin+Vector2(r[0], r[1])*factor, Vector2(r[2], r[3])*factor)

func image_control(parent: Control, path: String, rect: Rect2, tint: Color = Color.WHITE) -> TextureRect:
	var image = TextureRect.new()
	# Disable the texture's minimum size before assigning the authored rect.
	# Otherwise Godot clamps small atlas/preview views to source pixel size.
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = Content.tex(path)
	image.position = rect.position
	image.size = rect.size
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.modulate = tint
	parent.add_child(image)
	return image

func image_button(parent: Control, value: String, rect: Rect2, action: Callable, normal: String, hover: String = "", disabled: bool = false, show_title: bool = false) -> Button:
	var b = button(parent, value, rect, action, null, disabled)
	if not show_title:
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 1)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]: b.add_theme_color_override(state, Color.TRANSPARENT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style = StyleBoxTexture.new()
		style.texture = Content.tex(hover if not hover.is_empty() and state in ["hover", "pressed"] else normal)
		if disabled: style.modulate_color.a = 0.35
		b.add_theme_stylebox_override(state, style)
	b.size = rect.size
	b.tooltip_text = ""
	return b

func invisible_button(parent: Control, value: String, rect: Rect2, action: Callable) -> Button:
	var b = button(parent, value, rect, action)
	b.add_theme_font_size_override("font_size", 1)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]: b.add_theme_color_override(state, Color.TRANSPARENT)
	b.size = rect.size
	b.tooltip_text = ""
	return b

func original_tabs() -> void:
	var first=ui.get_child_count()
	image_control(ui,"assets/menu_podlozhka.png",Rect2(0,0,view_size().x,75))
	ClassicUI.chrome_controls(self)
	for i in range(first,ui.get_child_count()):
		ui.get_child(i).set_meta("menu_chrome",true)
		ui.get_child(i).z_index=1000 if menu_transition.active else 0

func offer_guidance(kind:int,force:bool=false) -> void:
	if not force and test_session and "--qa-guidance" not in OS.get_cmdline_user_args():return
	if Profile.data.settings.get("guidance_seen",{}).get(str(kind),false):return
	if not Content.interface_tutorials.get("texts",{}).has(str(kind)):return
	guidance_type=kind

func guidance_controls() -> void:
	var layout=TutorialView.portrait(self,str(Content.interface_tutorials.texts[str(guidance_type)]),false)
	# The first world-map invitation remains until Training is selected.
	desired_portrait={"layout":layout,"key":"guidance/"+str(guidance_type),"caption":"Dismiss guidance" if guidance_type!=2 else "","action":dismiss_guidance}

func dismiss_guidance() -> void:
	if guidance_type==0 or guidance_type==2:return
	var kind=guidance_type
	var before=Profile.data.duplicate(true)
	if not Profile.data.settings.has("guidance_seen"):Profile.data.settings.guidance_seen={}
	Profile.data.settings.guidance_seen[str(kind)]=true
	if not test_session and not Profile.save_profile():Profile.data=before;message("Could not save tutorial progress.");return
	if PortraitView.after_close_menu(kind)!=0:portrait_view.on_close("guidance/"+str(kind),guidance_after_close.bind(kind))
	guidance_type=0
	if kind==7 and not Profile.unlocked("T4L1"):offer_guidance(8,true)
	refresh_controls()

func guidance_after_close(kind:int) -> void:
	if not dismiss_promotion(false):return # Keep the earned notice when its save fails.
	var destination=PortraitView.after_close_menu(kind)
	if destination!=0:navigate("shop" if destination==103 else "upgrades")

func interface_back(destination: String = "menu") -> void:
	if screen in ["world","career","shop","upgrades","spicery"]:return
	image_button(ui, "Home" if destination == "menu" else "Back", Rect2(8, 7, 79, 43), navigate.bind(destination), "assets/done_btn_0.png", "assets/done_btn_1.png")

func interface_scroll(rect: Rect2, dimensions: Vector2) -> Control:
	var scroll = ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	var area = Control.new()
	area.custom_minimum_size = dimensions
	scroll.add_child(area)
	scroll.scroll_vertical = menu_scroll
	scroll.get_v_scroll_bar().value_changed.connect(func(value): menu_scroll = int(value))
	return area

func shop_controls() -> void:
	interface_back()
	var factor = menu_scale()
	var width = 768.0*factor
	var area = interface_scroll(Rect2(view_center().x-width/2, 71*factor, width+18, view_size().y-146*factor), Vector2(width, 6*234*factor))
	# ShopBlockView::blockView0x51e10 populates tags110..118 with the root
	# and its two branches, three levels per form. Six234px strips follow.
	for block in range(6):
		var root_type = Simulation.ROOT_TYPES[block]
		var origin = Vector2(0, block*234)*factor
		for entry in Content.interface_layouts.shop_block.entries:
			if entry.has("image"): image_control(area, str(entry.image), entry_rect(entry, origin, factor))
			if entry.has("text"):
				label(area, str(Content.catalog.tower_towers[root_type].name), entry_rect(entry, origin, factor), int(22*factor))
			if entry.has("tag") and int(entry.tag) in range(110, 119):
				var slot = int(entry.tag)-110
				shop_item_controls(area, entry_rect(entry, origin, factor).position, root_type+slot/3, 1+slot%3, factor)
	var offer = Content.catalog.shopList.filter(func(i): return str(i.unlockstring) == selected_shop)
	if not selected_shop.is_empty():
		var item = offer[0] if not offer.is_empty() else {}
		var definition = {}
		for type in range(1, 19):
			for level in range(1, 4):
				if str(Content.tower(type, level).get("unlock", "")) == selected_shop or selected_shop == "T%dL%d" % [type, level]: definition = Content.tower(type, level)
		var origin = Vector2(view_center().x-209.5*factor, view_size().y-208*factor)
		image_control(ui, "assets/info_panel.png", Rect2(origin+Vector2(0, 42)*factor, Vector2(419, 110)*factor))
		image_control(ui, "assets/"+selected_shop+".png", Rect2(origin+Vector2(0, 31.5)*factor, Vector2(100, 100)*factor))
		label(ui, str(definition.get("name", selected_shop)), Rect2(origin+Vector2(100, 49)*factor, Vector2(237, 22)*factor), int(22*factor))
		label(ui, str(definition.get("description", "")), Rect2(origin+Vector2(100, 68)*factor, Vector2(237, 43)*factor), int(16*factor))
		var owned = item.is_empty() or Profile.unlocked(str(item.unlockstring))
		label(ui, "Unlocked" if owned else "%s sp" % item.pricespice, Rect2(origin+Vector2(199, 114)*factor, Vector2(120, 29)*factor), int(22*factor))
		if not owned:
			image_button(ui, "Unlock " + str(definition.get("name", selected_shop)), Rect2(origin+Vector2(86, 101)*factor, Vector2(115, 49)*factor), func(): transaction_feedback(Profile.purchase(item)); refresh_controls(), "assets/unlock_btn_0.png", "assets/unlock_btn_1.png", int(Profile.data.level)<int(item.levellock) or not Profile.unlocked(str(item.needsunlock)))

func shop_item_controls(parent: Control, origin: Vector2, type: int, level: int, factor: float) -> void:
	var code = "T%dL%d" % [type, level]
	var definition = Content.tower(type, level)
	var offers = Content.catalog.shopList.filter(func(i): return str(i.unlockstring) == code)
	var item = offers[0] if not offers.is_empty() else {}
	var owned = item.is_empty() or Profile.unlocked(code)
	var prior = owned or Profile.unlocked(str(item.needsunlock))
	for entry in Content.interface_layouts.shop_item.entries:
		var rect = entry_rect(entry, origin, factor)
		match str(entry.outlet):
			"itemImageView":
				var icon=image_control(parent,"assets/"+code+".png",rect,Color(1,1,1,shop_item_alpha(code)))
				if not owned:icon.material=Content.interface_material("grayscale" if prior else "silhouette")
			"itemSelectedImageView":
				if selected_shop == code: image_control(parent, str(entry.image), rect)
			"itemPriceBadgeImageView":
				if not owned and prior and int(Profile.data.level) >= int(item.levellock):
					image_control(parent, str(entry.image), rect)
					var l = label(parent, "%s sp" % item.pricespice, Rect2(rect.position+Vector2(10, 24)*factor, Vector2(70, 27)*factor), int(18*factor)); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			"itemLevelLockImageView":
				if prior and not owned and int(Profile.data.level) < int(item.levellock): image_control(parent, str(entry.image), rect)
			"itemLeveLockLabel":
				if prior and not owned and int(Profile.data.level) < int(item.levellock): label(parent, "lvl %s" % item.levellock, rect, int(15*factor))
			"itemLockLabel":
				if not prior:
					var rgba=entry.color
					var question=label(parent,"?",rect,int(entry.font_size*factor),Color(rgba[0],rgba[1],rgba[2],rgba[3]))
					question.add_theme_font_override("font",bold);question.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;question.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;question.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
			"itemNameLabel":
				if prior:
					var l = label(parent, str(definition.name), rect, int(14*factor)); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	invisible_button(parent, str(definition.name)+" level "+str(level), Rect2(origin, Vector2(100, 114)*factor), func(): selected_shop = code; refresh_controls())

func shop_item_alpha(code:String) -> float:
	var offers=Content.catalog.shopList.filter(func(i):return str(i.unlockstring)==code)
	if offers.is_empty() or Profile.unlocked(code):return 1.0
	var previous=str(offers[0].needsunlock)
	# Native unavailable-branch alpha is previousItem.alpha minus0.15.
	return maxf(0,shop_item_alpha(previous)-0.15) if not previous.is_empty() and not Profile.unlocked(previous) else 1.0

func spicery_controls() -> void:
	var factor=menu_scale()
	var origin=Vector2(view_center().x-384*factor,0)
	var catalog_visible=test_session and spicery_catalog_fixture
	var copy=Content.interface_tutorials.spicery_texts
	var italic=load("res://assets/fonts/Kautiva Pro Bold Italic.otf")
	for entry in Content.interface_layouts.spicery.entries:
		var id=int(entry.id);var tag=int(entry.get("tag",0))
		var product_pane=entry.ancestors.any(func(value):return int(value)==34)
		# Anonymous viewDidLoad hides the StoreKit-dependent product pane.
		# The gallery can pose the preserved catalog with all actions disabled;
		# localized store prices are absent, so NIB sample prices stay hidden.
		if id==108 or id==103 or id==52 or id==199:continue
		if product_pane and not catalog_visible:continue
		if product_pane and tag%10 in [3,6,7]:continue
		if id==92 and catalog_visible:continue
		var r=entry.rect
		var rect=Rect2(origin+Vector2(r[0],r[1])*factor,Vector2(r[2],r[3])*factor)
		if entry.has("image"):
			var art=image_control(ui,entry.image,rect);art.set_meta("spicery_source",id)
		elif entry.has("text"):
			var value=str(entry.text)
			if id==246:value=str(copy.header)
			elif id==78:value=str(copy.social).replace("%i",str(int(Content.catalog.tower_rewards.post_first)))
			elif id==63:value=str(copy.ads)
			elif product_pane and tag%10 in [1,2]:
				var offer=Content.catalog.tower_inapp[int(tag/10)-1]
				value=str(offer.description) if tag%10==1 else "%dsp"%int(offer.spice)
			var face=italic if id in [125,80] else bold if entry.bold else font
			var points=int(float(entry.font_size)*factor)
			if int(entry.get("line_count",1))==1:
				var width=maxf(rect.size.x,face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x)
				rect.position.x-=(width-rect.size.x)*0.5;rect.size.x=width
			var text_label=label(ui,value,rect,points)
			text_label.add_theme_font_override("font",face);text_label.horizontal_alignment=int(entry.alignment);text_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			if int(entry.get("line_count",1))==1:text_label.autowrap_mode=TextServer.AUTOWRAP_OFF
			text_label.set_meta("spicery_source",id)
		elif entry.has("button_images") and not str(entry.button_images.get("0","")).is_empty():
			var title=str(copy.gift) if id==222 else str(entry.button_titles.get("0",""))
			var service=image_button(ui,title,rect,func():pass,entry.button_images["0"],entry.button_images.get("1",entry.button_images["0"]),false,true)
			service.add_theme_font_size_override("font_size",int(float(entry.button_font_size)*factor))
			service.add_theme_font_override("font",bold if entry.button_bold else font)
			service.add_theme_stylebox_override("disabled",service.get_theme_stylebox("normal"))
			service.add_theme_color_override("font_disabled_color",Color.WHITE)
			service.disabled=true;service.set_meta("spicery_source",id)

func select_upgrade(key:String) -> void:
	var next="" if selected_upgrade==key else key
	for existing in upgrade_view_states:
		var state=upgrade_view_states[existing]
		state.from=state.alpha;state.to=0.0;state.age=0.0
	if not next.is_empty():
		var alpha=float(upgrade_view_states.get(next,{}).get("alpha",0.0))
		upgrade_view_states[next]={"alpha":alpha,"from":alpha,"to":1.0,"age":0.0}
	selected_upgrade=next
	if not next.is_empty():
		var keys=Content.catalog.tower_upgrades.keys()
		keys.sort_custom(func(a,b):return int(Content.catalog.tower_upgrades[a].level)<int(Content.catalog.tower_upgrades[b].level))
		upgrade_scroll_from=upgrade_scroll_y
		upgrade_scroll_to=UpgradeView.selection_scroll(UpgradeView.tablet(keys.find(next)).position.y,upgrade_scroll_y/menu_scale(),view_size().y/menu_scale())*menu_scale()
		upgrade_scroll_age=0.0
	refresh_controls()

func advance_upgrade_presentation(delta:float) -> void:
	upgrade_scroll_age+=delta
	upgrade_scroll_y=lerpf(upgrade_scroll_from,upgrade_scroll_to,ClassicUI.interpolate_ease(clampf(upgrade_scroll_age/0.3,0,1)))
	var removed=false
	for key in upgrade_view_states.keys():
		var state=upgrade_view_states[key]
		state.age+=delta
		# Original CATransitionFade duration is0.30000001192092896.
		# UIKit's compositor is unavailable; use the shared default ease curve.
		state.alpha=lerpf(state.from,state.to,ClassicUI.interpolate_ease(clampf(state.age/0.3,0,1)))
		if state.to==0 and state.age>=0.3:upgrade_view_states.erase(key);removed=true
	for node in ui.find_children("*","Control",true,false):
		if node.has_meta("original_upgrade_grid"):node.position.y=-upgrade_scroll_y
		if node.has_meta("upgrade_detail"):
			var key=str(node.get_meta("upgrade_detail"))
			node.modulate.a=float(upgrade_view_states.get(key,{}).get("alpha",1.0 if selected_upgrade==key else 0.0))
	if removed:refresh_controls()

func upgrade_item_label(parent:Control,value:String,outlet:String,pose:Dictionary,factor:float) -> Label:
	var entry=interface_entry("upgrade_item",outlet)
	var rect=entry_rect(entry,Vector2.ZERO,factor)
	if outlet=="itemPanelNameLabel":rect.position.x=pose.name_x*factor
	elif outlet=="costLabel":rect.position.x=pose.cost_x*factor
	elif outlet=="itemPanelDescriptionLabel":rect.position.x=pose.description_x*factor
	var caption=label(parent,value,rect,int(float(entry.font_size)*factor))
	caption.horizontal_alignment=int(entry.alignment)
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if int(entry.get("line_count",1))==1:
		caption.autowrap_mode=TextServer.AUTOWRAP_OFF
		caption.clip_text=true
		caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.set_meta("upgrade_outlet",outlet)
	return caption

func upgrade_detail_control(node:Control,key:String) -> void:
	node.set_meta("upgrade_detail",key)
	node.modulate.a=float(upgrade_view_states.get(key,{}).get("alpha",1.0))

func upgrades_controls() -> void:
	interface_back()
	var offer = Content.catalog.tower_pu_exchange
	var factor = menu_scale()
	var width = 768.0*factor
	var header_origin=Vector2(view_center().x-width/2,0)
	var header_entry=interface_entry("upgrades","upgradePointsLabel")
	var header=label(ui,Content.interface_tutorials.upgrades_texts.header%int(Profile.data.specpoints),entry_rect(header_entry,header_origin,factor),int(float(header_entry.font_size)*factor))
	header.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	header.add_theme_constant_override("line_spacing",0)
	header.set_meta("original_upgrade_header",true)
	var exchange_entry=interface_entry("upgrades","buyPUPointsButton")
	var exchange=image_button(ui,Content.interface_tutorials.upgrades_texts.exchange%[int(offer.pu_award),int(offer.spice_cost)],entry_rect(exchange_entry,header_origin,factor),func():transaction_feedback(Profile.exchange_points());refresh_controls(),"assets/long_btn_0.png","assets/long_btn_1.png",Profile.data.spice<int(offer.spice_cost),true)
	exchange.add_theme_font_size_override("font_size",int(float(exchange_entry.button_font_size)*factor))
	var keys = Content.catalog.tower_upgrades.keys()
	keys.sort_custom(func(a,b): return int(Content.catalog.tower_upgrades[a].level)<int(Content.catalog.tower_upgrades[b].level))
	var scroll_area=interface_scroll(Rect2(header_origin.x,164*factor,width,view_size().y-164*factor),Vector2(width,ceilf(keys.size()/5.0)*137*factor))
	var area=Control.new();area.position.y=-upgrade_scroll_y;area.size=scroll_area.size;area.mouse_filter=Control.MOUSE_FILTER_IGNORE;scroll_area.add_child(area)
	area.set_meta("original_upgrade_grid",true)
	for i in range(keys.size()):
		var key = str(keys[i])
		var item = Content.catalog.tower_upgrades[key]
		var level = int(Profile.data.upgrades.get(key, 0))
		var pose=UpgradeView.tablet(i)
		var tile=Control.new();tile.position=pose.position*factor;area.add_child(tile)
		tile.mouse_filter=Control.MOUSE_FILTER_IGNORE
		tile.set_meta("upgrade_key",key);tile.set_meta("upgrade_index",i)
		tile.z_index=2 if selected_upgrade==key else (1 if upgrade_view_states.has(key) else 0)
		var details=selected_upgrade==key or upgrade_view_states.has(key)
		if details:
			var panel=image_control(tile,"assets/upgrades_panel.png",Rect2(Vector2(pose.panel_x,23)*factor,Vector2(478,146)*factor))
			panel.flip_h=pose.mirrored;upgrade_detail_control(panel,key)
		image_button(tile,str(item.name),Rect2(Vector2(12,28)*factor,Vector2(143,130)*factor),select_upgrade.bind(key),"assets/upgrade_btn_0.png","assets/upgrade_btn_1.png")
		var icon=Content.tex("assets/"+key+"_0.png")
		var icon_size=icon.get_size() if icon!=null else Vector2(120,100)
		var icon_origin=Vector2(83,83)-icon_size/2
		image_control(tile,"assets/"+key+"_0.png",Rect2(icon_origin*factor,icon_size*factor))
		if level>0:
			var fill_size=Vector2(icon_size.x,floor(icon_size.y*mini(level,10)/10.0))
			var fill=TextureRect.new();fill.texture=atlas("assets/"+key+"_1.png",Rect2(Vector2(0,icon_size.y-fill_size.y),fill_size));fill.position=(icon_origin+Vector2(0,icon_size.y-fill_size.y))*factor;fill.size=fill_size*factor;fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;tile.add_child(fill)
		upgrade_item_label(tile,str(item.name),"itemNameLabel",pose,factor)
		upgrade_item_label(tile,"Level %d/10"%level,"itemCountLabel",pose,factor)
		if int(Profile.data.level)<int(item.level):
			image_control(tile,"assets/level_locked.png",entry_rect(interface_entry("upgrade_item","levelLockImageView"),Vector2.ZERO,factor))
			upgrade_item_label(tile,"lvl %d"%int(item.level),"levelLockLabel",pose,factor)
		elif details:
			if key!="up_friends" and level<10:
				var plus=image_button(tile,"+ "+str(item.name),entry_rect(interface_entry("upgrade_item","plusButton"),Vector2.ZERO,factor),func():transaction_feedback(Profile.upgrade(key));refresh_controls(),"assets/upgrade_plus_btn_0.png","assets/upgrade_plus_btn_1.png")
				upgrade_detail_control(plus,key);plus.disabled=selected_upgrade!=key
				if plus.disabled:plus.mouse_filter=Control.MOUSE_FILTER_IGNORE
			if key!="up_friends" and level>0:
				var minus=image_button(tile,"Refund "+str(item.name),entry_rect(interface_entry("upgrade_item","minusButton"),Vector2.ZERO,factor),func():transaction_feedback(Profile.refund_upgrade(key));refresh_controls(),"assets/upgrade_minus_btn_0.png","assets/upgrade_minus_btn_1.png")
				upgrade_detail_control(minus,key);minus.disabled=selected_upgrade!=key
				if minus.disabled:minus.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if details:
			var amount=int(item.get("tower_percent",item.get("percent",0)))
			if amount==0:amount=int(item.get("percent",0))
			var description=str(item.description).replace("%@",str(absi(amount))).replace("%%","%")
			for pair in [[str(item.name),"itemPanelNameLabel"],["%dup"%int(Content.catalog.tower_upgrade_costs.get(str(level+1),0)) if level<10 and key!="up_friends" else "","costLabel"],[description,"itemPanelDescriptionLabel"]]:
				upgrade_detail_control(upgrade_item_label(tile,pair[0],pair[1],pose,factor),key)
			var hit_x=pose.panel_x+20 if pose.mirrored else 159
			var close=invisible_button(tile,"Close "+str(item.name)+" description",Rect2(Vector2(hit_x,46)*factor,Vector2(304,103)*factor),select_upgrade.bind(key))
			close.disabled=selected_upgrade!=key
			if close.disabled:close.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Godot z_index controls drawing, not mouse dispatch. UIKit brings the
	# selected item and its description forward in the actual sibling order.
	for tile in area.get_children():
		if tile.get_meta("upgrade_key","")==selected_upgrade:area.move_child(tile,area.get_child_count()-1)

func career_controls() -> void:
	var progress = Profile.career_progress()
	var values = {"nameLabel": Profile.data.name, "rankLabel": PromotionView.rank_name(int(Profile.data.level)),
		"levelLabel": str(int(Profile.data.level)), "towersBuiltLabel": str(int(Profile.data.stats.towers)), "creepsKilledLabel": str(int(Profile.data.stats.kills)),
		"moneySpentLabel": "$%d" % int(Profile.data.stats.get("money_spent", 0)), "towersUnlockedLabel": "%d%%" % progress.towers, "locationsUnlocksLabel": "%d%%" % progress.locations}
	for entry in Content.interface_layouts.career.entries:
		if not career_entry_visible(entry): continue
		var rect = career_rect(entry)
		if entry.has("text"):
			var value = str(values.get(str(entry.outlet), entry.text))
			if int(entry.id) == 224 and not Profile.data.upgrades.is_empty(): value = "Upgrades yard"
			var rgba = entry.color
			var l = label(ui, value, rect, int(float(entry.font_size)*menu_scale()), Color(rgba[0], rgba[1], rgba[2], rgba[3]))
			l.horizontal_alignment = int(entry.alignment)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if entry.bold: l.add_theme_font_override("font", bold)
		if entry.has("button_images") and int(entry.id) in [55, 104]:
			var b = button(ui, "Fitting room" if int(entry.id) == 55 else "Home", rect, navigate.bind("dress" if int(entry.id) == 55 else "menu"))
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 1)
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(state, Color.TRANSPARENT)
			for state in ["normal", "hover", "pressed"]:
				var style = StyleBoxTexture.new()
				style.texture = Content.tex(entry.button_images.get("1" if state != "normal" else "0", entry.button_images.get("0", "")))
				b.add_theme_stylebox_override(state, style)
			b.size = rect.size
	for outlet in ["upgradesLabelView", "medalsView"]:
		var entries = Content.interface_layouts.career.entries.filter(func(e): return e.outlet == outlet)
		if entries.is_empty(): continue
		var b = button(ui, "Upgrades yard" if outlet == "upgradesLabelView" else "Medals", career_rect(entries[0]), navigate.bind("upgrades" if outlet == "upgradesLabelView" else "medals"))
		for state in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(state, Color.TRANSPARENT)

func career_entry_visible(entry: Dictionary) -> bool:
	var skip = [10, 16, 59, 63, 73, 104, 121, 207, 260]
	# openFittingRoom0x2d100 hides the fitting button and its two title labels.
	if screen=="dress" and (int(entry.id)==55 or int(entry.get("tag",0)) in [126,127]):return false
	if entry.hidden or int(entry.id) in skip: return false
	for ancestor in entry.ancestors:
		if int(ancestor) in skip: return false
	if int(entry.id) == 138 and not Profile.data.medals.is_empty(): return false
	return true

func career_rect(entry: Dictionary) -> Rect2:
	var r = entry.rect
	var position = Vector2(r[0], r[1])
	if int(entry.id) in [39, 179] or menu_descendant(entry, 179): position.x += 128
	if int(entry.id) == 188: position.x += 60 # Landscape clearance beside the fitting-room control.
	if int(entry.id) == 20 or menu_descendant(entry, 20): position.y += 5.0*(1.0-cos(elapsed_ui*PI/2.0))
	return Rect2(menu_origin()+position*menu_scale(), Vector2(r[2], r[3])*menu_scale())

func draw_career() -> void:
	for entry in Content.interface_layouts.career.entries:
		if not career_entry_visible(entry): continue
		var rect = career_rect(entry)
		if str(entry.outlet) == "avatarImageView": draw_avatar(rect)
		elif entry.has("image"):
			var path = str(entry.image)
			if int(entry.id) == 140:
				path = PromotionView.observed_rank(int(Profile.data.level))
				if path.is_empty():continue # Later service rank thresholds remain unknown.
			elif int(entry.id) == 157: path = "assets/pad_%d.png" % (int(elapsed_ui*30)%3)
			draw_image(path, rect)
	var medals = Content.catalog.tower_medals.filter(func(m): return Profile.has_medal(m))
	for i in range(mini(6, medals.size())):
		draw_image("assets/"+str(medals[i].image), Rect2(menu_origin()+Vector2(498+i*52, 314)*menu_scale(), Vector2(50, 50)*menu_scale()))

func centered_interface_origin(layout: String) -> Vector2:
	var canvas = Content.interface_layouts[layout].source_canvas
	return view_center()-Vector2(canvas[0], canvas[1])*menu_scale()/2.0

func medals_controls() -> void:
	var factor = menu_scale()
	var origin = centered_interface_origin("medals")
	for entry in Content.interface_layouts.medals.entries:
		var rect = entry_rect(entry, origin, factor)
		if entry.has("image"): image_control(ui, str(entry.image), rect)
		if entry.has("text"):
			var l = label(ui, "Click a medal to see its description" if int(entry.id)==50 else str(entry.text), rect, int(float(entry.font_size)*factor)); l.horizontal_alignment=int(entry.alignment)
		if entry.has("button_images"): image_button(ui, "Back", rect, navigate.bind("career"),entry.button_images["0"],entry.button_images["1"])
	var groups = [[], [], []]
	for medal in Content.catalog.tower_medals:
		groups[2 if int(medal.get("secret",0))==1 else 1 if int(medal.global)==1 else 0].append(medal)
	for category in range(3):
		var entry = interface_entry("medals","medalsView%d" % (category+1))
		var rect = entry_rect(entry,origin,factor)
		for i in range(groups[category].size()):
			var medal = groups[category][i]
			var own = Profile.has_medal(medal)
			var spot = Rect2(rect.position+Vector2((i%14)*54, int(i/14)*54)*factor,Vector2(54,54)*factor)
			image_control(ui,"assets/"+str(medal.image),spot,Color.WHITE if own else Color(1,1,1,0.3))
			invisible_button(ui, str(medal.name), spot,func(): selected_medal=medal.duplicate(true);refresh_controls())
			if own and int(medal.global)==0 and Profile.medal_count(medal)>1: label(ui,str(Profile.medal_count(medal)),Rect2(spot.position+Vector2(27,31)*factor,Vector2(23,19)*factor),int(14*factor))
	if not selected_medal.is_empty():
		var rect = Rect2(view_center()-Vector2(250,90)*factor,Vector2(500,180)*factor)
		image_control(ui,"assets/gui/medal_popup_add.png",rect)
		image_control(ui,"assets/"+str(selected_medal.image),Rect2(rect.position+Vector2(20,25)*factor,Vector2(65,65)*factor))
		label(ui,str(selected_medal.name),Rect2(rect.position+Vector2(100,15)*factor,Vector2(375,40)*factor),int(27*factor))
		var description = "Discover this secret spice medal." if int(selected_medal.get("secret",0))==1 and not Profile.has_medal(selected_medal) else str(selected_medal.description)
		label(ui,description,Rect2(rect.position+Vector2(100,55)*factor,Vector2(375,95)*factor),int(21*factor))
		invisible_button(ui,"Close medal description",rect,func():selected_medal.clear();refresh_controls())

func dress_controls() -> void:
	var factor = menu_scale()
	# The fitting room is a525x365 native panel over the Career view.
	career_controls()
	var blocker = invisible_button(ui,"Close fitting room",Rect2(Vector2.ZERO,view_size()),func():dress_preview.clear();navigate("career"))
	# Tablet controller inserts its525x365 view beside the original button,
	# in that button's parent coordinates, with the traced(-1,-3) adjustment.
	var origin = career_rect(interface_entry("career","fittingRoomButton")).position+Vector2(-1,-3)*factor
	for entry in Content.interface_layouts.dress.entries:
		var rect = entry_rect(entry,origin,factor)
		if entry.has("image"):
			if str(entry.outlet)=="tabSelectorImageView":
				var tab = Content.interface_layouts.dress.entries.filter(func(e):return int(e.get("tag",0))==dress_group+10)[0]
				rect.position.x=entry_rect(tab,origin,factor).get_center().x-rect.size.x/2
			image_control(ui,str(entry.image),rect)
		if entry.has("button_images"):
			if int(entry.id)==29: image_button(ui,"Back",rect,func():dress_preview.clear();navigate("career"),entry.button_images["0"],entry.button_images["1"])
			elif entry.has("tag"):
				var group = int(entry.tag)-10
				var b = invisible_button(ui,str(entry.get("button_titles",{}).get("0",["Body","Hats","Wear","Accessories","Pants"][group])),rect,func():dress_group=group;menu_scroll=0;refresh_controls())
				var title=label(b,b.text,Rect2(Vector2.ZERO,rect.size),int(17*factor));title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;title.modulate.a=1.0 if group==dress_group else 0.5
	var scroll_rect=entry_rect(interface_entry("dress","dressScrollView"),origin,factor)
	var costumes=Content.catalog.tower_dress.filter(func(d):return int(d.group)==dress_group)
	# Original comparator0x4ab50 treats owned items as zero cost, then orders
	# by price. Preserve catalog order when costs tie.
	var costume_prices={}
	for offer in Content.catalog.shopList:
		if int(offer.itemtype)==2:costume_prices[str(offer.tag)]=int(offer.pricespice)
	costumes.sort_custom(func(a,b):return (0 if Profile.unlocked(str(a.needsunlock)) else int(costume_prices.get(str(a.tag),0)))<(0 if Profile.unlocked(str(b.needsunlock)) else int(costume_prices.get(str(b.tag),0))))
	# loadDressesForSlot0x4a500 arranges three columns by two rows,
	# then continues horizontally. A half-column remains visible as a hint.
	var item_width=maxf(130.0,471.0/3.5)
	var item_height=item_width*110.0/130.0
	var gap=floor((471.0-130.0*3.5)/4.0)
	var row_gap=(271.0-2.0*item_height)/3.0
	var scroll=ScrollContainer.new();scroll.position=scroll_rect.position;scroll.size=scroll_rect.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	var area=Control.new();area.custom_minimum_size=Vector2(maxf(471.0,ceil(costumes.size()/6.0)*471.0/3.5*3.0),271.0)*factor;scroll.add_child(area)
	scroll.scroll_horizontal=menu_scroll
	scroll.get_h_scroll_bar().value_changed.connect(func(value):menu_scroll=int(value))
	for i in range(costumes.size()):
		var costume=costumes[i]
		var own=Profile.unlocked(str(costume.needsunlock))
		var row=int(i/3)%2
		var column=i%3+int(i/6)*3
		var origin_item=Vector2(gap+column*(item_width+gap),row_gap*(row+1)+row*item_height)*factor
		var offers=Content.catalog.shopList.filter(func(o):return str(o.tag)==str(costume.tag))
		var offer=offers[0] if not offers.is_empty() else {}
		var thumbnail=image_control(area,"assets/cosmetics/previews/"+str(costume.tURL).get_file(),Rect2(origin_item+Vector2(0,-9)*factor,Vector2(130,110)*factor))
		# DressView.nib's UIContentMode1 is aspect fit, including transparent art.
		thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var key="s"+str(costume.slot)
		var wearing=int(Profile.data.dress.get(key,-1))==int(costume.id)
		var previewing=int(dress_preview.get(key,-1))==int(costume.id)
		if not own:
			invisible_button(area,"Try "+str(costume.title),Rect2(origin_item+Vector2(0,-9)*factor,Vector2(130,110)*factor),func():dress_preview[key]=int(costume.id);refresh_controls())
		elif not wearing and not previewing:
			image_button(area,"Wear "+str(costume.title),Rect2(origin_item+Vector2(47,83)*factor,Vector2(36,32)*factor),func():dress_preview[key]=int(costume.id);refresh_controls(),"assets/fitting_try_btn_0.png","assets/fitting_try_btn_1.png")
		if not own and not offer.is_empty() and not previewing:
			image_control(area,"assets/fitting_rope_under_cloth.png",Rect2(origin_item+Vector2(35,60)*factor,Vector2(25,31)*factor))
			image_button(area,"Buy "+str(costume.title),Rect2(origin_item+Vector2(44,67)*factor,Vector2(66,49)*factor),func():dress_preview[key]=int(costume.id);refresh_controls(),"assets/fitting_price.png")
			var price_label=label(area,"%ssp" % offer.pricespice,Rect2(origin_item+Vector2(57,83)*factor,Vector2(42,21)*factor),int(20*factor))
			price_label.add_theme_font_override("font",bold);price_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			price_label.pivot_offset=price_label.size/2;price_label.rotation=0.18
		if (wearing or previewing) and str(costume.get("required",""))!="YES":
			image_button(area,"Pull off "+str(costume.title),Rect2(origin_item+Vector2(25,83)*factor,Vector2(80,32)*factor),func():dress_preview[key]=-1;refresh_controls(),"assets/fitting_pulloff_btn_0.png","assets/fitting_pulloff_btn_1.png")
	for control in [["avatarApplyButton","Apply outfit","Apply",apply_dress],["avatarCancelButton","Cancel outfit","Cancel",func():dress_preview.clear();refresh_controls()]]:
		var entry=interface_entry("career",control[0])
		var rect=career_rect(entry)
		var b=image_button(ui,control[1],rect,control[3],entry.button_images["0"],entry.button_images["1"])
		var title=label(b,control[2],Rect2(Vector2.ZERO,rect.size),int(18*factor))
		title.add_theme_font_override("font",bold);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER

func apply_dress() -> void:
	var cart=[]
	var cost=0
	for key in dress_preview:
		var id=int(dress_preview[key])
		if id<0:continue
		var dresses=Content.catalog.tower_dress.filter(func(d):return int(d.id)==id and "s"+str(d.slot)==str(key))
		if dresses.is_empty():message("This costume could not be found.");return
		var dress=dresses[0]
		if Profile.unlocked(str(dress.needsunlock)):continue
		var offers=Content.catalog.shopList.filter(func(o):return str(o.tag)==str(dress.tag))
		if offers.is_empty():message("This costume is unavailable.");return
		var offer=offers[0]
		if int(Profile.data.level)<int(offer.levellock) or not Profile.unlocked(str(offer.needsunlock)):message("This costume is still locked.");return
		cost+=int(offer.pricespice)
		cart.append(offer)
	if int(Profile.data.spice)<cost:message("You need %d more spice." % (cost-int(Profile.data.spice)));return
	var before=Profile.data.duplicate(true)
	Profile.data.spice-=cost
	for offer in cart:
		if str(offer.unlockstring) not in Profile.data.unlocks:Profile.data.unlocks.append(str(offer.unlockstring))
		Profile.data.transactions.append({"kind":"shop","id":offer.shopitemid,"spice":-int(offer.pricespice)})
	for key in dress_preview:
		if int(dress_preview[key])<0:Profile.data.dress.erase(key)
		else:Profile.data.dress[key]=int(dress_preview[key])
	if not Profile.save_profile():Profile.data=before;message("Could not save the outfit. Your spice and costumes are unchanged.");return
	dress_preview.clear()
	navigate("career")

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
			play_ambient()
			refresh_controls())
	label(ui, "Click to place and select. Drag to pan. Scroll or pinch to zoom.\n1–6 select towers · N launches the next wave · Space pauses\nEscape cancels · G shows the hex grid · F11 toggles fullscreen", Rect2(c.x-300, c.y+100, 600, 160), 21)

func credits_controls() -> void:
	interface_back()
	var factor = menu_scale()
	var width = 768.0*factor
	var area = interface_scroll(Rect2(view_center().x-width/2, 74*factor, width+18, view_size().y-143*factor), Vector2(width, 2260*factor))
	for entry in Content.interface_layouts.credits.entries:
		if int(entry.id) != 31 and not menu_descendant(entry, 31): continue
		var rect = entry_rect(entry, Vector2.ZERO, factor)
		if entry.has("image"): image_control(area, str(entry.image), rect)
		if entry.has("text"):
			var value = str(entry.text)
			if int(entry.id)==54 and not Profile.data.completed.has("13"): value = "Spice Bandits"
			var rgba = entry.color
			var l = label(area, value, rect, int(float(entry.font_size)*factor), Color(rgba[0],rgba[1],rgba[2],rgba[3])); l.horizontal_alignment=int(entry.alignment)
			l.autowrap_mode=TextServer.AUTOWRAP_OFF
	label(area, "macOS reconstruction · Godot Engine (MIT)", Rect2(20,2195*factor,728*factor,44*factor),int(20*factor))

func story_image_rect() -> Rect2:
	var texture=Content.tex("assets/lobby/story_screens/"+str(story_location.story_img).get_basename()+".png")
	return Rect2(0,view_center().y-floor(texture.get_height()/2.0),texture.get_width(),texture.get_height())

func start_mission(id: String, bypass_unlock: bool = false, show_story: bool = true, show_loading: bool = true) -> void:
	if not flush_pending_xp() or not save_result(): return
	var c = Content.mission(id)
	if c.is_empty() or c.waves.is_empty(): message("This mission has no recovered offline schedule."); return
	if not bypass_unlock and not Profile.available(c): message("Unlock the preceding campaign mission first."); return
	menu_navigation_token+=1;menu_transition.clear()
	portrait_view.clear()
	build_hex_view.reset()
	var loc = Content.location(str(c.location))
	if show_story and not test_session and not Profile.data.completed.has(id) and not loc.is_empty() and not str(loc.story_img).is_empty():
		if original_transitions_enabled():await cover_scene()
		story_location = loc
		story_mission = id
		screen = "story"
		refresh_controls()
		if transition.phase==1:transition.close()
		return
	if show_loading and original_transitions_enabled():
		await cover_scene()
		loading_token+=1
		var token=loading_token
		loading_name=str(loc.get("name","Tutorial"))
		loading_kind="arrival"
		loading_started=elapsed_ui
		screen="loading"
		refresh_controls()
		transition.close()
		await transition.revealed
		await get_tree().create_timer(3.0).timeout
		if token!=loading_token or screen!="loading":return
		await cover_scene()
		start_mission(id,bypass_unlock,false,false)
		transition.close()
		return
	sim = Simulation.new()
	base_depth_cache.clear()
	creep_depth_cache.clear()
	creep_animation_owners.clear()
	sim.setup(Content.catalog, Content.maps[c.map], c, Profile.data, 114, Content.animations)
	sim.live_updates=not test_session or "--qa-performance" in OS.get_cmdline_user_args() or "--qa-live-runtime" in OS.get_cmdline_user_args()
	screen = "game"
	wave_fx.reset()
	wave_collapse.clear()
	notice_until = 0
	credited_score = 0.0
	credited_kills = 0
	battle_initial_xp = int(Profile.data.xp)
	next_xp_save = Time.get_ticks_msec()+1000
	next_result_retry = 0
	build_type = 0
	tower_drag=false
	tower_drag_moved=false
	magic_inventory_open=false
	magic_panel_state=MagicPanelView.initial(view_size().y,MagicPanelView.body_height(ClassicUI.MAGIC.size()))
	hovered_tower_type=0
	magic_last_use=Profile.data.settings.get("magic_last_use",{}).duplicate()
	magic_shortcuts=["m_freeze","m_lsd","m_actdef","m_mine","m_portal"]
	magic_shortcuts.sort_custom(func(a,b):return int(magic_last_use.get(a,0))>int(magic_last_use.get(b,0)))
	magic_shortcuts.resize(4)
	result_started=-1.0
	result_clock={};result_clock_age=0.0
	result_closed_delay=0.0;result_initial_delay=0.0
	result_previous_xp=float(Profile.data.xp)
	battle_medals.clear()
	battle_spice_reward=int(Content.catalog.tower_rewards.sp_other if Profile.data.completed.has(id) else Content.catalog.tower_rewards.sp_first)
	reward_bar_emitting=false;reward_fx.reset()
	reward_bar_releasing=false;reward_bar_previous_tip=Vector2.ZERO
	reset_reward_bursts()
	magic_placement = ""
	selected_tower = -1
	tower_panel_close_at=-1.0
	tutorial_step = 0
	tutorial = TutorialFlow.new() if str(c.configid) == "1" else null
	pending_sale = -1
	pending_abandon = ""
	pending_technology.clear()
	speed = 1
	zoom = 1.0
	# InitCamPos0x107f1c centers the friendly-base bounding region when
	# the configuration does not supply an explicit camera point.
	var base_min=Vector2(INF,INF)
	var base_max=Vector2(-INF,-INF)
	for base in sim.bases:
		base_max=base_max.max(base.pos)
		base_min.y=minf(base_min.y,base.pos.y)
		if int(base.get("player",1)) in [0,1]:base_min.x=minf(base_min.x,base.pos.x)
	camera=(base_min+base_max)/2.0 if not sim.bases.is_empty() and is_finite(base_min.x) else Vector2(float(sim.map.width_pixels)/2.0,float(sim.map.height_pixels)/2.0)
	if c.settings.has("cam_x"): camera = Vector2(float(c.settings.cam_x), float(c.settings.cam_y))
	bound_camera()
	effects.clear()
	continuous_beams.clear()
	particle_fx.reset()
	result_saved = false
	hud_money_flash=ClassicUI.Wallet.flash_initial()
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
	play_ambient()

func flush_pending_xp() -> bool:
	if pending_xp.is_empty(): return true
	if test_session and not qa_persist_progress: pending_xp.clear(); return true
	var previous_transactions = Profile.data.transactions.size()
	if not Profile.credit_battle_kills(pending_xp, str(sim.config.configid)):
		sim.paused = true
		message("Earned XP could not be saved. The game is paused; your previous profile is intact.")
		refresh_controls()
		return false
	for row in pending_xp: credited_score += float(row.reward)
	credited_kills += pending_xp.size()
	pending_xp.clear()
	if notice.begins_with("Earned XP could not be saved."): notice="";notice_until=0
	collect_promotions(previous_transactions)
	return true

func save_result() -> bool:
	if sim == null or sim.outcome == "playing" or result_saved: return true
	if test_session and not qa_persist_progress: result_saved = true; return true
	if not flush_pending_xp(): return false
	var previous_transactions = Profile.data.transactions.size()
	if not Profile.settle(sim, credited_score, credited_kills, battle_initial_xp):
		message("The result could not be saved. Your previous profile is intact.")
		return false
	result_saved = true
	battle_medals=preload("res://scripts/medals.gd").select(Content.catalog.tower_medals,preload("res://scripts/medals.gd").battle_values(sim,Profile.data.stats,Content.catalog.tower_medals))
	collect_promotions(previous_transactions)
	sim.paused = false
	return true

func collect_promotions(first: int) -> void:
	# History compaction can change indices. Promotion records are retained;
	# inspect their saved acknowledgement rather than an earlier array length.
	for i in range(Profile.data.transactions.size()):
		var row = Profile.data.transactions[i]
		if str(row.kind) == "promotion" and int(row.level) > int(Profile.data.settings.get("promotion_seen",1)) and not promotions.any(func(p): return int(p.level)==int(row.level)): promotions.append(row.duplicate(true))
	if not promotions.is_empty(): refresh_controls()

func promotion_indicator(rect: Rect2) -> void:
	var b=image_button(ui,"Level up!",rect,open_promotion,"assets/levelup.png")
	var caption=label(b,"Level up!",Rect2(Vector2.ZERO,rect.size),18,Color("#312f2b"))
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)

func dismiss_promotion(route_to_world:bool=true) -> bool:
	if promotions.is_empty() or not promotion_open or promotion_state.get("closing",false):return true
	var settings=Profile.data.settings.duplicate(true)
	Profile.data.settings.promotion_seen=int(promotions[0].level)
	if not Profile.save_profile():
		Profile.data.settings=settings
		message("Could not save the level-up notice. Your earned rewards are already saved.")
		return false
	PromotionView.close(promotion_state)
	if route_to_world:navigate("world")
	refresh_controls()
	return true

func advance_promotion(dt_ms:float) -> void:
	if not promotion_open or promotion_state.is_empty():return
	PromotionView.advance(promotion_state,dt_ms)
	if promotion_state.finished:
		promotion_open=false
		promotions.pop_front()
		if screen=="game" and sim!=null:sim.paused=promotion_was_paused
		refresh_controls()

func open_promotion() -> void:
	if promotions.is_empty() or promotion_open: return
	if screen=="game" and sim!=null:
		promotion_was_paused=sim.paused
		sim.paused=true
	promotion_open = true
	promotion_state=PromotionView.initial()
	if int(promotions[0].level)==2:offer_guidance(5)
	sound("TD_levelup_mono")
	refresh_controls()

func promotion_controls() -> void:
	var reward = promotions[0]
	# CLevelUpScreen uses647x528, different from the battle result's extent.
	var origin = PromotionView.origin(view_size())
	var continue_button=invisible_button(ui,"Continue",Rect2(Vector2.ZERO,view_size()),func():
		if guidance_type==5:dismiss_guidance()
		else:dismiss_promotion())
	continue_button.disabled=promotion_state.get("closing",false)
	var darkness=ColorRect.new();darkness.color=Color(0,0,0,promotion_alpha()/3.0);darkness.size=view_size();darkness.mouse_filter=Control.MOUSE_FILTER_IGNORE;darkness.set_meta("promotion_darkness",true);ui.add_child(darkness)
	var panel = Control.new();panel.position=origin;panel.size=Vector2(647,528);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.modulate.a=promotion_alpha();panel.set_meta("promotion_panel",true);ui.add_child(panel)
	image_control(panel,"assets/gui/levelup_screen_1.png",Rect2(0,0,512,512))
	image_control(panel,"assets/gui/levelup_screen_2.png",Rect2(512,0,128,512))
	image_control(panel,"assets/gui/levelup_screen_3.png",Rect2(640,0,8,64))
	image_control(panel,"assets/gui/levelup_screen_shadow_1.png",Rect2(0,512,512,64))
	image_control(panel,"assets/gui/levelup_screen_shadow_2.png",Rect2(512,512,126,64))
	var rank=PromotionView.observed_rank(int(reward.level))
	if not rank.is_empty():image_control(panel,rank,PromotionView.rank_rect()).set_meta("promotion_rank",true)
	var positions=PromotionView.positions(view_size(),bold.get_string_size("Level up!",HORIZONTAL_ALIGNMENT_LEFT,-1,40).x)
	var title=label(panel,"Level up!",Rect2(positions.title-origin,Vector2(450,48)),40);title.add_theme_font_override("font",bold)
	label(panel,"Congratulations, you are now level %d!"%int(reward.level),Rect2(positions.description-origin,Vector2(450,50)),22)
	if int(reward.spice)>0:label(panel,"+ %d spice!"%int(reward.spice),Rect2(positions.spice-origin,Vector2(440,27)),24).add_theme_font_override("font",bold)
	if int(reward.points)>0:label(panel,"+ %d upgrade points!"%int(reward.points),Rect2(positions.upgrade_label-origin,Vector2(440,27)),24).add_theme_font_override("font",bold)
	var stuff=label(panel,"New stuff unlocked:",Rect2(positions.new_stuff-origin,Vector2(450,30)),24);stuff.add_theme_font_override("font",bold)
	var offers=Content.catalog.shopList.filter(func(o):return int(o.levellock)==int(reward.level) and int(o.itemtype) in [0,1])
	var names=[];var new_items=[]
	for offer in offers:
		if str(offer.itemname) not in names:names.append(str(offer.itemname));new_items.append(offer)
	for index in range(mini(4,new_items.size())):
		var offer=new_items[index];var x=90+100*index
		var path="assets/"+str(offer.unlockstring if int(offer.itemtype)==1 else offer.tag)+".png"
		image_control(panel,path,Rect2(x,355,100,100))
		if int(offer.itemtype)==0:
			var name=label(panel,str(offer.itemname),Rect2(x+7,442,86,52),18);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			var amount=int(Profile.data.abilities.get(str(offer.tag),0))
			var badge=atlas("assets/gui/magic_items_labels.png",Rect2(0,0,35,25) if amount>0 else Rect2(0,26,59,25))
			var plate=TextureRect.new();plate.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;plate.texture=badge;plate.position=Vector2(x+33 if amount>0 else x+20,413);plate.size=badge.get_size();plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(plate)
			if amount>0:
				var count=label(panel,str(amount),Rect2(x+33,417,35,25),20);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			else:
				label(panel,"%dsp"%int(offer.pricespice),Rect2(x+28,420,30,25),14,Color.BLACK).add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
				label(panel,"0",Rect2(x+57,417,24,25),20)
				invisible_button(panel,"Buy "+str(offer.itemname),Rect2(x+20,413,59,25),func():transaction_feedback(Profile.purchase(offer));refresh_controls())
		else:
			var owned=Profile.unlocked(str(offer.unlockstring));var prior=Profile.unlocked(str(offer.needsunlock))
			if not owned and prior:
				var b=invisible_button(panel,"Unlock "+str(offer.itemname),Rect2(x+20,442,60.5,47),func():transaction_feedback(Profile.purchase(offer));refresh_controls())
				for state in ["normal","hover","pressed"]:
					var style=StyleBoxTexture.new();style.texture=atlas("assets/gui/lvlup_spice_button.png",Rect2(0 if state=="normal" else 121,0,121,94));b.add_theme_stylebox_override(state,style)
				var cost=label(panel,"%dsp"%int(offer.pricespice),Rect2(x+20,456,60,26),18);cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			else:
				var parts=str(offer.unlockstring).trim_prefix("T").split("L")
				var name=label(panel,"Unlocked" if owned else str(Content.tower(int(parts[0]),int(parts[1])).name),Rect2(x+7,442,86,52),18);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER

func promotion_alpha() -> float:
	return float(promotion_state.get("alpha",0.0))

func displayed_xp() -> float:
	var value = Profile.f32(float(Profile.data.xp))
	for row in pending_xp: value = Profile.f32(value+Profile.f32(float(row.reward)/10.0))
	return value

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if flush_pending_xp() and save_result(): get_tree().quit()
		else: quit_pending = true; refresh_controls()

func quit_controls() -> void:
	var blocker = Control.new()
	blocker.size = view_size()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(blocker)
	var shade = ColorRect.new()
	shade.size = view_size()
	shade.color = Color(0, 0, 0, 0.8)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocker.add_child(shade)
	label(blocker, "Recent progress could not be saved.", Rect2(view_center()-Vector2(230, 120), Vector2(460, 90)), 28)
	button(blocker, "Keep playing", Rect2(view_center()-Vector2(225, 10), Vector2(215, 50)), func(): quit_pending = false; refresh_controls())
	button(blocker, "Quit without saving", Rect2(view_center()+Vector2(10, -10), Vector2(215, 50)), func(): get_tree().quit())

func select_build(type: int) -> void:
	if not sim.can_unlock(sim.tower_data(type, 1)) and tutorial == null:
		request_technology(sim.tower_data(type, 1))
		return
	if sim.paused or sim.outcome != "playing": return
	if tutorial != null and not tutorial.build_allowed(type):
		message("You are not supposed to do that in the training area!")
		return
	build_type = type
	if sim.money<float(sim.tower_data(type,1).price):ClassicUI.Wallet.flash_request(hud_money_flash)
	reset_tower_preview(type)
	magic_placement = ""
	selected_tower = -1
	refresh_controls()

func reset_tower_preview(type:int) -> void:
	var definition=sim.tower_data(type,1)
	var states=Content.animations["towers/"+str(definition.filename)].states
	tower_preview_animation="Rot" if states.has("Rot") else "Idle"
	var animation=states[tower_preview_animation]
	tower_preview_state=TowerPreview.initial(animation.resolved_frames.size(),float(animation.get("speed",1)),bool(animation.get("loop",0)))
	tower_preview_facing=0

func set_magic_inventory(opened:bool) -> void:
	magic_inventory_open=opened
	if opened:MagicPanelView.open(magic_panel_state)
	else:MagicPanelView.close(magic_panel_state)
	refresh_controls()

func toggle_magic_inventory() -> void:
	if sim==null or sim.paused or sim.outcome!="playing":return
	build_type=0;selected_tower=-1;magic_placement="";sim.cancel_portal_placement()
	set_magic_inventory(bool(magic_panel_state.hidden))

func advance_magic_panel(dt_ms:float) -> void:
	if not magic_panel_state.visible:return
	MagicPanelView.advance(magic_panel_state,dt_ms,view_size().y)
	for panel in magic_panel_root.get_children():
		if not panel.has_meta("magic_panel"):continue
		panel.position.y=magic_panel_state.y
		for item in panel.get_children():
			if item is Button:item.disabled=not magic_panel_state.opened or bool(item.get_meta("magic_level_locked",false))
	if not magic_panel_state.visible:refresh_controls()

func magic_required_level(key:String,offer:Dictionary) -> int:
	return 0 if tutorial!=null and key in ["m_lsd","m_actdef","m_mine"] else int(offer.levellock)

func magic_inventory_controls() -> void:
	var panel=Control.new();panel.position=Vector2(view_size().x/2-158,magic_panel_state.y);panel.size=Vector2(392,int(magic_panel_state.height)-20);panel.mouse_filter=Control.MOUSE_FILTER_STOP;panel.set_meta("magic_panel",true);magic_panel_root.add_child(panel)
	# CMagicPanel::Render0x98d10: authored392px header and3px body strip.
	var header=TextureRect.new();header.texture=atlas("assets/gui/ingame_menus.png",Rect2(513,254,392,16));header.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(header)
	var body=TextureRect.new();body.texture=atlas("assets/gui/ingame_menus.png",Rect2(513,268,392,3));body.position=Vector2(0,16);body.size=Vector2(392,magic_panel_state.height);body.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;body.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(body)
	var title=label(panel,str(Content.interface_tutorials.magic_panel_title),Rect2(23,26,350,25),20);title.autowrap_mode=TextServer.AUTOWRAP_OFF
	for i in range(5):
		var key=ClassicUI.MAGIC[i]
		var offer=ClassicUI.magic_offer(key)
		var rect=Rect2(Vector2(16 if i%2==0 else 209,65*(int(i/2)+1)),Vector2(52,52))
		var icon=TextureRect.new();icon.texture=atlas(ClassicUI.ATLAS,Rect2(758,ClassicUI.MAGIC_ICON_Y[key],40,40));icon.position=rect.position+Vector2(6,6);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(icon)
		var border=TextureRect.new();border.texture=atlas(ClassicUI.ATLAS,Rect2(512,375,52,52));border.position=rect.position;border.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(border)
		var level=magic_required_level(key,offer)
		var item=invisible_button(panel,key,Rect2(rect.position,Vector2(172,52)),magic.bind(key));item.set_meta("magic_level_locked",int(Profile.data.level)<level);item.disabled=not magic_panel_state.opened or int(Profile.data.level)<level
		var name=label(panel,str(offer.get("itemname",key)),Rect2(rect.position+Vector2(54,4),Vector2(135,25)),20);name.autowrap_mode=TextServer.AUTOWRAP_OFF
		label(panel,str(offer.get("itemdescription","")),Rect2(rect.position+Vector2(54,22),Vector2(120,40)),13)
		var amount=int(sim.abilities.get(key,0))
		var badge=TextureRect.new();badge.texture=atlas(ClassicUI.ATLAS,Rect2(543,272,35,25) if amount>0 else Rect2(630,273,59,25));badge.position=rect.position+Vector2(9 if amount>0 else -4,34);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(badge)
		if amount>0:
			var value=str(amount);var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
			label(panel,value,Rect2(rect.position+Vector2(27-width/2,38),Vector2(60,25)),20)
		else:
			label(panel,"0",Rect2(rect.position+Vector2(33,38),Vector2(22,25)),20)
			var price="%dsp"%int(offer.pricespice) if int(offer.pricespice)<10 else "%ds"%int(offer.pricespice)
			label(panel,price,Rect2(rect.position+Vector2(4,41),Vector2(30,25)),14,Color(0,1,1))
		if int(Profile.data.level)<level:
			var lock=TextureRect.new();lock.texture=atlas(ClassicUI.ATLAS,Rect2(579,324,176,58));lock.position=rect.position+Vector2(-3,-1);lock.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(lock)
			label(panel,"lvl %d"%level,Rect2(rect.position+Vector2(76,21),Vector2(100,25)),20)

func begin_tower_drag(type:int, pos:Vector2) -> void:
	if sim==null or sim.paused or sim.outcome!="playing":return
	select_build(type)
	if build_type!=type:return
	tower_drag=true
	tower_drag_moved=false
	drag_start=pos
	tower_drag_position=pos
	dragging=false
	get_viewport().set_input_as_handled()

func _input(event:InputEvent) -> void:
	if transition!=null and transition.phase!=3:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and not magic_placement.is_empty():magic_preview_position=event.position
	if suppress_tower_release and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		suppress_tower_release=false
		get_viewport().set_input_as_handled()
		return
	if not tower_drag:return
	if event is InputEventMouseMotion:
		tower_drag_position=event.position
		if event.position.distance_to(drag_start)>8:tower_drag_moved=true
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		var drop=event.position
		var dragged=tower_drag_moved
		tower_drag=false
		dragging=false
		moved=true
		get_viewport().set_input_as_handled()
		if dragged:
			if drop.y>40 and drop.y<ClassicUI.dock_origin(self).y-10:click_map(drop,true)
			build_type=0
			refresh_controls()
	elif (event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_SPACE]) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
		tower_drag=false
		suppress_tower_release=true
		build_type=0
		dragging=false
		get_viewport().set_input_as_handled()
		refresh_controls()

func magic(key: String) -> void:
	if sim.paused or sim.outcome != "playing": return
	if tutorial != null:
		if not tutorial.magic_allowed(key):
			message("You are not supposed to do that in the training area!")
			return
		if key != "m_mine" and sim.enemies.is_empty(): message("Wait for the earthlings to appear."); return
	if int(sim.abilities.get(key, 0)) <= 0:
		# HandleItem0x98508 calls BuyItem0x998bc, then returns without
		# activating it. The next click spends a charge from that refill.
		var offers = Content.catalog.shopList.filter(func(item): return int(item.itemtype) == 0 and str(item.tag) == key)
		if offers.is_empty(): return
		var previous_stock = int(Profile.data.abilities.get(key, 0))
		transaction_feedback(Profile.purchase(offers[0]))
		if int(Profile.data.abilities.get(key, 0)) > previous_stock:
			sim.abilities[key] = int(Profile.data.abilities[key])
			sound("purchase_02-mono")
		refresh_controls()
		return
	if magic_panel_state.visible:set_magic_inventory(false)
	if key in ["m_mine", "m_portal"]:
		magic_placement = key
		magic_preview_position=get_global_mouse_position()
		build_hex_view.reset()
		build_type = 0
		notice_until=0
		refresh_controls()
	else:
		var result = activate_magic(key)
		message(result)
		update_tutorial()
		refresh_controls()

func activate_magic(key: String, pos: Vector2 = Vector2.ZERO) -> String:
	var error = sim.ability_error(key, pos)
	if not error.is_empty(): return error
	var consumes = key != "m_portal" or sim.portals.size() == 1
	if consumes and tutorial == null and (not test_session or qa_persist_progress):
		if not Profile.consume_magic(key): return "The magic charge could not be saved. Try again."
	var result=sim.use_ability(key,pos)
	if result.is_empty() and tutorial==null:
		magic_last_use[key]=int(Time.get_unix_time_from_system())
		Profile.data.settings.magic_last_use=magic_last_use.duplicate()
		if key not in magic_shortcuts:
			var oldest=0
			for i in range(1,magic_shortcuts.size()):
				if int(magic_last_use.get(magic_shortcuts[i],0))<int(magic_last_use.get(magic_shortcuts[oldest],0)):oldest=i
			magic_shortcuts[oldest]=key
	return result

func request_technology(definition: Dictionary) -> void:
	if sim.paused or sim.outcome != "playing": return
	var token = str(definition.get("unlock", ""))
	var offers = Content.catalog.shopList.filter(func(item): return str(item.unlockstring) == token and not token.is_empty())
	if offers.is_empty(): message("This technology has no recovered shop offer."); return
	pending_technology = {"offer": offers[0], "definition": definition}
	refresh_controls()

func buy_pending_technology() -> void:
	if pending_technology.is_empty(): return
	var offer = pending_technology.offer
	transaction_feedback(Profile.purchase(offer))
	if str(offer.unlockstring) in Profile.data.unlocks:
		if str(offer.unlockstring) not in sim.unlocks: sim.unlocks.append(str(offer.unlockstring))
		pending_technology.clear()
		sound("purchase_02-mono")
	refresh_controls()

func technology_controls() -> void:
	var rect = Rect2(view_center()-Vector2(160.5, 209), Vector2(321, 418))
	var panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style = StyleBoxTexture.new()
	style.texture = Content.tex("assets/ingame_shop_bg.png")
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var offer = pending_technology.offer
	var def = pending_technology.definition
	label(panel, str(def.name), Rect2(24, 24, 273, 58), 26)
	var icon = TextureRect.new()
	icon.texture = Content.tex("assets/%s.png" % offer.unlockstring)
	icon.position = Vector2(110, 86)
	icon.size = Vector2(100, 100)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	label(panel, str(def.get("description", "")), Rect2(24, 193, 273, 72), 19)
	label(panel, "Level %s · %s spice\nBattle upgrade: $%d" % [offer.levellock, offer.pricespice, int(def.price)], Rect2(24, 273, 273, 66), 20)
	var action = picture_button("Unlock technology", Rect2(rect.position+Vector2(102, 348), Vector2(116, 51)), buy_pending_technology, Rect2(231, 274, 116, 51), Rect2(231, 274, 116, 51), int(Profile.data.level) < int(offer.levellock) or int(Profile.data.spice) < int(offer.pricespice) or not Profile.unlocked(str(offer.needsunlock)))
	# This follows native CheckUnlockClick0xedf3c: permanent spice unlock,
	# followed by a separate battle-money upgrade. Never upgrade for free.
	action.tooltip_text = ""
	button(ui, "Close", Rect2(rect.position+Vector2(264, 6), Vector2(50, 32)), func(): pending_technology.clear(); refresh_controls())

func request_sale(id: int) -> void:
	pending_sale = id
	sale_started=elapsed_ui
	update_tutorial()
	refresh_controls()

func confirm_sale() -> void:
	var tower = sim.find_tower(pending_sale)
	if tower.is_empty(): return
	if tutorial != null and (tutorial.page != 11 or tower.cell != Vector2i(11, 3)): return
	var result = sim.sell(pending_sale)
	if result.is_empty(): particle_fx.remove_owner(pending_sale)
	message(result)
	if result.is_empty(): pending_sale = -1; selected_tower = -1
	update_tutorial()
	refresh_controls()

func cancel_sale() -> void:
	pending_sale = -1
	update_tutorial()
	refresh_controls()

func sale_controls() -> void:
	var tower = sim.find_tower(pending_sale)
	if tower.is_empty(): return
	# Native confirmation expands at the sell widget. A background click
	# cancels; it cannot select/place a tower underneath this pending action.
	var cancel = button(ui, "Cancel", Rect2(Vector2.ZERO, view_size()), cancel_sale)
	for state in ["normal", "hover", "pressed", "focus"]: cancel.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: cancel.add_theme_color_override(state, Color.TRANSPARENT)
	var rect = sale_confirm_rect(tower)
	var b = invisible_button(ui, "Confirm sale", rect, confirm_sale)
	var picture=image_control(b,"assets/gui/confirm_btn_0.png",Rect2(Vector2.ZERO,rect.size))
	var source=atlas("assets/gui/confirm_btn_0.png",Rect2(Vector2.ZERO,rect.size));picture.texture=source
	var caption = label(b, "Confirm\nselling", Rect2(13, 14, 95, 50), 20)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.set_meta("sale_frame",true);b.set_meta("sale_rect",rect);b.set_meta("sale_picture",picture);b.set_meta("sale_caption",caption)
	b.set_meta("sale_left",tower_popup_rects(tower).sell.position.x>=91)
	b.mouse_entered.connect(func():source.atlas=Content.tex("assets/gui/confirm_btn_1.png"))
	b.mouse_exited.connect(func():source.atlas=Content.tex("assets/gui/confirm_btn_0.png"))
	update_sale_presentation()

func sale_confirm_rect(tower: Dictionary) -> Rect2:
	# Tablet Update/Render0xee200/0xf4c54: expand left at sell.x+40-121.
	# Reverse near the left boundary, where there is no room for the panel.
	var sell=tower_popup_rects(tower).sell.position
	var position = sell+Vector2(-81 if sell.x>=91 else 61, 0)
	position.x = clampf(position.x, 0, view_size().x-121)
	return Rect2(position, Vector2(121, 74))

func update_sale_presentation() -> void:
	var fraction=clampf((elapsed_ui-sale_started)*4,0,1)
	for control in ui.get_children():
		if not control.has_meta("sale_frame"):continue
		var rect:Rect2=control.get_meta("sale_rect")
		var width=121*fraction
		control.position=rect.position+Vector2(121-width if control.get_meta("sale_left") else 0,0)
		control.size=Vector2(width,74);control.disabled=fraction<1
		var picture:TextureRect=control.get_meta("sale_picture")
		picture.texture.region=Rect2(0,0,width,74);picture.size=Vector2(width,74)
		var caption:Label=control.get_meta("sale_caption")
		caption.position.x=(width-95)/2;caption.modulate.a=clampf((fraction-0.5)*2,0,1)

func cycle_speed() -> void:
	speed = 2 if speed == 1 else 4 if speed == 2 else 1
	refresh_controls()

func toggle_pause() -> void:
	if not pending_abandon.is_empty():return
	if sim.outcome != "playing": return
	sim.paused = not sim.paused
	pending_abandon = ""
	refresh_controls()

func pause_controls() -> void:
	var y = floor((view_size().y-243)/2.0)-8
	image_button(ui,"Resume",Rect2(5,y+79,47,58),toggle_pause,"assets/gui/pause_menu_back_btn_0.png","assets/gui/pause_menu_back_btn_1.png")
	picture_button("Restart",Rect2(40,y+134,110,35),func():pending_abandon="restart";refresh_controls(),Rect2(905,69,110,35),Rect2(905,11,110,35))
	picture_button("To the map",Rect2(40,y+173,152,35),func():pending_abandon="world";refresh_controls(),Rect2(838,185,152,35),Rect2(838,127,152,35))
	label(ui,"Paused",Rect2(220,y+23,500,43),36)
	label(ui,"%s · %s
Wave %d / %d · Base health: %s%%" % [Content.location(str(sim.config.location)).get("name",""),{"1":"Normal","3":"Sudden Death","6":"Air Attack"}.get(str(sim.config.gametype),"Normal"),sim.wave_index,sim.config.waves.size(),SpiceNative.format_xp(sim.base_fraction()*100,false)],Rect2(220,y+78,600,90),25)
	if not pending_abandon.is_empty():
		abandon_controls()

func abandon_controls() -> void:
	if question_key!=pending_abandon:
		question_key=pending_abandon;question_alpha=0.0;question_dim=0.0;question_closing=false
	question_root=Control.new();question_root.size=view_size();question_root.mouse_filter=Control.MOUSE_FILTER_STOP;ui.add_child(question_root)
	var dim=ColorRect.new();dim.size=view_size();dim.mouse_filter=Control.MOUSE_FILTER_IGNORE;dim.set_meta("question_dim",true);question_root.add_child(dim)
	image_control(question_root,"assets/gui/messages/small_window_question.png",MessageView.background(view_size()))
	var caption=label(question_root,"Do you want to abandon the current game?",Rect2(MessageView.text_position(view_size(),300),Vector2(300,100)),20,Color(1,1,0.9,1));caption.add_theme_font_override("font",bold)
	for i in range(2):
		var pose=MessageView.button(view_size(),i);var value="Yes" if i==0 else "No"
		var art=image_control(question_root,"assets/gui/messages/menu_button2_btn_0.png",pose.sprite)
		var control=invisible_button(question_root,value,pose.hit,func():
			if i==1:question_closing=true
			else:
				var action=pending_abandon;pending_abandon="";question_key=""
				start_mission(sim.config.configid,test_session) if action=="restart" else navigate("world"))
		control.mouse_entered.connect(func():art.texture=Content.tex("assets/gui/messages/menu_button2_btn_1.png"))
		control.mouse_exited.connect(func():art.texture=Content.tex("assets/gui/messages/menu_button2_btn_0.png"))
		var text_label=label(question_root,value,Rect2(Vector2(pose.center_x-78,pose.text_y),Vector2(156,40)),23,Color(1,1,0.9,1));text_label.add_theme_font_override("font",bold);text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	update_question_presentation(0)

func update_question_presentation(dt:float) -> void:
	if pending_abandon.is_empty():question_key="";return
	question_alpha=MessageView.advance(question_alpha,dt,question_closing)
	question_dim=clampf(MessageView.f32(question_dim+MessageView.f32(MessageView.f32(dt)*(-3.5 if question_closing else 3.5))),0,MessageView.f32(0.6))
	if question_closing and question_alpha<=0:
		pending_abandon="";question_key="";refresh_controls();return
	if not is_instance_valid(question_root):return
	for control in question_root.get_children():
		if control.has_meta("question_dim"):control.color=Color(0,0,0,question_dim)
		else:control.modulate.a=question_alpha
		if control is Button:control.disabled=not MessageView.button_enabled(question_alpha) or question_closing

func results_origin() -> Vector2:
	# CWinLoseScreen constructor0xb959c and Render0xb9a60 center647x512.
	return (view_center()-Vector2(323,256)).floor()

func advance_closed_result_clock(dt_ms:float) -> void:
	# The original room updates its closed result screen with unscaled time.
	# Its constructor initializes this timer; Open does not reset it.
	if screen!="game" or sim==null or sim.paused or sim.outcome!="playing":return
	var dt=RewardClockView.f32(dt_ms)
	result_closed_delay=RewardClockView.f32(result_closed_delay+RewardClockView.f32(dt*RewardClockView.f32(0.001)))

func sync_result_clock() -> void:
	if result_started<0:
		result_started=elapsed_ui;result_initial_delay=result_closed_delay
	var age=maxf(0,elapsed_ui-result_started)
	if result_clock.is_empty() or age<result_clock_age:
		result_clock=RewardClockView.initial(result_initial_delay);result_clock_age=0.0
	var dt=maxf(0,age-result_clock_age)*1000.0
	if dt>0:RewardClockView.advance(result_clock,dt,sim.outcome=="victory")
	result_clock_age=age

func pose_result(age:float,initial_delay:float=0) -> void:
	if not test_session:return
	result_initial_delay=initial_delay
	result_clock=RewardClockView.initial(initial_delay);result_clock_age=0
	while result_clock_age<age:
		var delta=minf(0.03,age-result_clock_age)
		RewardClockView.advance(result_clock,delta*1000.0,sim.outcome=="victory");result_clock_age+=delta
	result_started=elapsed_ui-age

func results_controls() -> void:
	sync_result_clock()
	var origin=results_origin()
	var first=ui.get_child_count()
	var title=label(ui,"Yay! You did it!" if sim.outcome=="victory" else "You failed!",Rect2(origin+Vector2(70,169),Vector2(507,62)),48,Color.WHITE)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var phrase=str(sim.config.get("msgwin" if sim.outcome=="victory" else "msglost",""))
	if not phrase.is_empty():
		var subtitle=label(ui,phrase,Rect2(origin+Vector2(65,222),Vector2(517,35)),20)
		subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var values=[["towers built:",sim.built_count],["upgrades:",sim.replay.filter(func(a):return str(a.kind)=="upgrade").size()],["top level upgrades:",sim.upgrade_top_count],["creeps killed:",sim.kills],["longest kill chain:",sim.closed_kill_chain],["early waves:",sim.early_wave_count]]
	for i in range(values.size()):
		result_text_pair(str(values[i][0]),str(int(values[i][1])),origin+Vector2(98,272+i*23),Color("#465050"))
	var gain=maxi(0,int(displayed_xp())-battle_initial_xp)
	result_text_pair("XP gained:",str(gain),origin+Vector2(332,272),Color("#00b9ff"))
	if sim.outcome=="victory":
		# Render0xb9a60 formats the entire reward into the regular20pt you_got
		# object. The separately constructed bold you_got_value is unused here.
		var reward=label(ui,result_spice_text(),Rect2(origin+Vector2(332,295),Vector2(315,25)),20,Color(1,0.44699999690055847,0,1))
		reward.autowrap_mode=TextServer.AUTOWRAP_OFF
		reward.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		reward.set_meta("result_spice",true)
	if not battle_medals.is_empty():
		label(ui,"Medals (tap for more info)",Rect2(origin+Vector2(300,369),Vector2(275,20)),14,Color("#465050"))
		for i in range(mini(6,battle_medals.size())):
			var medal=battle_medals[i]
			var source=Vector2(Content.tex("assets/"+str(medal.image)).get_size())
			var rect=RewardView.medal(source,i,6,1,origin).rect
			var icon=image_control(ui,"assets/"+str(medal.image),rect)
			icon.set_meta("result_medal",i);icon.set_meta("result_medal_source",source)
			var hit=invisible_button(ui,str(medal.name),rect,func():selected_medal=medal.duplicate(true);refresh_controls())
			hit.set_meta("result_medal",i);hit.set_meta("result_medal_source",source)
	picture_button("Replay",Rect2(origin+Vector2(95,421),Vector2(110,35)),func():start_mission(sim.config.configid,test_session),Rect2(905,69,110,35),Rect2(905,11,110,35))
	picture_button("To the map!",Rect2(origin+Vector2(403,421),Vector2(152,35)),func():navigate("credits" if sim.outcome=="victory" and str(sim.config.configid)=="13" else "world"),Rect2(838,185,152,35),Rect2(838,127,152,35))
	for i in range(first,ui.get_child_count()):ui.get_child(i).set_meta("result_frame",true)
	update_result_controls()
	if tutorial!=null and sim.outcome=="victory":
		tutorial_layout=TutorialView.portrait(self,"Great job cadet!\n\nPress \"To the map\" to return to the world map.",true)
		desired_portrait={"layout":tutorial_layout,"key":"tutorial/victory","caption":"","action":Callable()}
	if not selected_medal.is_empty():result_medal_controls()

func update_result_controls() -> void:
	var medal_time=RewardView.medal_clock(result_clock.medal_clock)
	var content=result_spice_size()
	var spice=RewardView.spice(content,RewardView.text_quad(content),result_clock.spice_phase,results_origin(),1,result_clock.alpha)
	for control in ui.get_children():
		if control.has_meta("result_frame"):control.modulate.a=result_clock.alpha
		if control.has_meta("result_spice"):
			control.modulate.a=spice.alpha
			control.scale=spice.scale
			control.position=spice.point
		if control.has_meta("result_medal"):
			var pose=RewardView.medal(control.get_meta("result_medal_source"),int(control.get_meta("result_medal")),medal_time.slot,medal_time.fraction,results_origin(),result_clock.alpha)
			control.position=pose.rect.position;control.size=pose.rect.size;control.modulate.a=pose.alpha if result_clock.medal_clock>0 else 0
			if control is Button:control.disabled=control.modulate.a<=0

func reset_reward_bursts() -> void:
	reward_burst_fx.reset();reward_spice_burst=false;reward_medal_bursts.clear()

func result_spice_text() -> String:return "%s! We got %d spice!"%[Profile.data.name,battle_spice_reward]

func result_spice_size() -> Vector2:return Vector2(font.get_string_size(result_spice_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,20).x,font.get_height(20))

func emit_reward_burst(name:String,point:Vector2,speed:float=1) -> void:
	var definition=RewardView.burst_definition(Content.particles.systems[name],speed)
	reward_burst_fx.emit_definition(name,definition,Content.tex(definition.texture),point,"","",-1)

func update_reward_bursts() -> void:
	if sim.outcome!="victory":return
	var origin=results_origin()
	if battle_spice_reward!=0 and result_clock.spice_phase>=1 and not reward_spice_burst:
		reward_spice_burst=true
		var content=result_spice_size()
		for i in range(7):
			var vector=SpiceNative.projected_random_vector(reward_burst_fx.random.randi_range(0,0x7fffffff),reward_burst_fx.random.randi_range(0,0x7fffffff))
			var radius=RewardView.burst_radius(reward_burst_fx.random.randi_range(0,0x7fffffff))
			emit_reward_burst("WinSpiceBump",RewardView.spice_burst_point(content,i,origin,vector,radius),reward_burst_fx.random.randf_range(1,3))
		sound("obj_boom")
	var medal_time=RewardView.medal_clock(result_clock.medal_clock)
	for i in range(mini(6,battle_medals.size())):
		var source=Vector2(Content.tex("assets/"+str(battle_medals[i].image)).get_size())
		var pose=RewardView.medal(source,i,medal_time.slot,medal_time.fraction,origin)
		if result_clock.medal_clock>0 and pose.burst and not reward_medal_bursts.has(i):
			reward_medal_bursts[i]=true;emit_reward_burst("WinObjBump",pose.burst_point);sound("obj_boom")

func result_text_pair(caption:String,value:String,point:Vector2,color:Color) -> void:
	var text_label=label(ui,caption,Rect2(point,Vector2(235,25)),20,color)
	text_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	text_label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	var number=label(ui,value,Rect2(point+Vector2(width+3,0),Vector2(160,25)),20,color)
	number.add_theme_font_override("font",bold)
	number.autowrap_mode=TextServer.AUTOWRAP_OFF
	number.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)

func result_medal_controls() -> void:
	var origin=results_origin()+Vector2(295,378)
	# MedalScreen0xa841c deliberately expands128x64 by2.2x1.6.
	var rect=Rect2(origin-Vector2(140,102),Vector2(281,102))
	var back=image_control(ui,"assets/gui/medal_popup_add.png",rect,Color(1,1,1,0.7))
	var add=CanvasItemMaterial.new();add.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;back.material=add
	image_control(ui,"assets/"+str(selected_medal.image),Rect2(rect.position+Vector2(14,24),Vector2(54,54)))
	var font_size=23
	while font_size>10 and bold.get_string_size(str(selected_medal.name),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>196:font_size-=1
	var heading=label(ui,str(selected_medal.name),Rect2(rect.position+Vector2(75,20),Vector2(196,26)),font_size,Color("#6bbbff"))
	heading.add_theme_font_override("font",bold)
	label(ui,str(selected_medal.description),Rect2(rect.position+Vector2(75,46),Vector2(196,56)),18,Color("#6bbbff"))
	invisible_button(ui,"Close medal description",Rect2(Vector2.ZERO,view_size()),func():selected_medal.clear();refresh_controls())

func start_departure_particles() -> void:
	var positions=ClassicUI.departure_positions(self,0)
	for i in range(3):
		var definition={"name":"ByeRocket%d"%i,"source_sha256":"native-CByeScreen-9fbcc","texture_list":[],"max_particles":30,"num_release":1,"release_interval":0.05+i/100.0,"life_cycle":1.5,"fade_in_time":0.5,"blend_delay":2,"velocity":[-28.0,42.0],"velocity_var":0,"wind_enabled":false,"gravity":[0,0],"wind":[0,0],"color":[0.7,0.7,0.7,0.7],"use_real_size":1,"size":0.7,"rotational":0,"scalable":0,"rot_speed":0}
		reward_fx.emit_definition(definition.name,definition,atlas("assets/gui/loader/bye_loading_beam.png",Rect2(17,17,3,3)),positions.rocket+Vector2(-7-i*2,16-i*3)*0.7)

func draw_results_frame(prefix: String, origin: Vector2) -> void:
	draw_image("assets/gui/"+prefix+"_1.png",Rect2(origin,Vector2(512,512)))
	draw_image("assets/gui/"+prefix+"_2.png",Rect2(origin+Vector2(512,0),Vector2(128,512)))
	draw_image("assets/gui/"+prefix+"_3.png",Rect2(origin+Vector2(640,0),Vector2(8,64)))
	draw_image("assets/gui/final_screen_shadow_1.png",Rect2(origin+Vector2(0,512),Vector2(512,64)))
	draw_image("assets/gui/final_screen_shadow_2.png",Rect2(origin+Vector2(512,512),Vector2(128,64)))

func tutorial_controls() -> void:
	if tutorial.display_page >= 17: return
	tutorial_layout = TutorialView.layout(self)
	if tutorial_layout.hit_rect.has_area():
		var words=tutorial_layout.labels.filter(func(h):return h.get("uikit",false))
		desired_portrait={"layout":tutorial_layout,"key":"tutorial/"+str(words[0].value) if not words.is_empty() else "","caption":"Continue","action":acknowledge_tutorial}
	# Authored GL text/images share their original world/screen drawing pass.
	# The portrait remains an independent UIKit-style control/lifecycle.
	var rect = tutorial_layout.hit_rect
	if not rect.has_area() and tutorial.page in [1, 2]:
		# A desktop continuation target accompanies the native click-anywhere
		# pages; the battlefield keeps the same dismissal behavior.
		invisible_button(ui,"Continue",Rect2(0,40,view_size().x,view_size().y-120),acknowledge_tutorial)

func acknowledge_tutorial() -> void:
	if tutorial == null: return
	if tutorial.page==0 and not tutorial.transition_pending:tutorial.hint_visible=false
	tutorial.acknowledge()
	tutorial_step = tutorial.page
	refresh_controls()

func update_tutorial(dt_ms:float=-1) -> void:
	if tutorial == null: return
	var real_seconds = qa_real_seconds if test_session and qa_real_seconds >= 0.0 else float(Time.get_ticks_msec())/1000.0
	var changed=tutorial.advance_ui(dt_ms,sim,selected_tower,pending_sale,real_seconds) if dt_ms>=0 else tutorial.observe(sim,selected_tower,pending_sale,real_seconds)
	if changed:
		tutorial_step = tutorial.page
		if tutorial.page >= 4: build_type = 0
		refresh_controls()

func message(value: String) -> void:
	if value.is_empty(): return
	notice = value
	notice_until = ui_time_ms()+4000
	queue_redraw()

func transaction_feedback(value:String) -> void:
	# Original successful purchases/allocations update their item and wallet.
	# They do not paint the reconstruction's full-width status banner.
	if value.begins_with("Purchased ") or value.ends_with(" upgraded.") or value.begins_with("Returned ") or value.begins_with("Added "):
		notice="";notice_until=0;queue_redraw();return
	message(value)

func ui_time_ms() -> int:
	return int(qa_real_seconds*1000.0) if test_session and qa_real_seconds >= 0.0 else Time.get_ticks_msec()

func play_music() -> void:
	if music == null: return
	if not Profile.data.settings.music: music.stop(); return
	var path = music_path
	if music.stream != null and music.stream.resource_path == path and music.playing: return
	music.stream = load(path)
	if music.stream is AudioStreamMP3: music.stream.loop = true
	# CMusicPlayer::Play 0x11e7f0 initializes the native gain to0.2.
	music.volume_db = linear_to_db(0.2)
	music.play()

func sound_definition(name: String) -> Dictionary:
	var bank = Content.catalog.soundbanks["game" if screen == "game" else "lobby"]
	var definition = bank.cues.get(name, {}).duplicate()
	definition.gain = float(definition.get("volume", bank.default_volume))/float(bank.max_volume)
	if name=="xp_bar_grow":
		# WinLose::Update0xbc08c loads this independent loop with SetGain0.1.
		definition.gain=0.1;definition.loop=1;definition.max_play=1
	elif name=="obj_boom":
		# CWinLoseScreen::PlayBoomSound0xbbf9c uses gain1 and layer4.
		definition.gain=1.0;definition.layer=4
	elif name=="UI_tab_select_and_move-mono":
		# The native controller passes layer4; the lobby bank supplies0.5/2.
		definition.layer=4
	return definition

func advance_xp_result_particles(dt_ms:float) -> void:
	if result_clock.xp_phase>0 and not reward_bar_emitting:
		var definition=Content.particles.systems.XpBarGrow
		XPEmitterView.create(reward_fx,definition,Content.tex(definition.texture))
		reward_bar_emitting=true
	reward_fx.advance_ui(dt_ms)

func update_xp_emission_from_render() -> void:
	if test_session:
		qa_result_render_count+=1;qa_result_render_age=elapsed_ui-result_started
	var tip=ClassicUI.result_bar_tip(self)
	reward_bar_releasing=XPEmitterView.after_render(reward_fx,reward_bar_previous_tip,tip) if reward_bar_emitting else false
	reward_bar_previous_tip=tip
	update_result_sound(reward_bar_releasing)

func update_result_sound(growing:bool) -> void:
	if growing and Profile.data.settings.sound:sound("xp_bar_grow")
	else:
		for voice in voices:
			if voice.get_meta("cue","")=="xp_bar_grow":voice.stop()

func play_ambient() -> void:
	if ambient == null: return
	if screen != "game" or sim == null or not Profile.data.settings.sound: ambient.stop(); return
	var theme = {"snow": "ice", "desert": "sand", "jungle": "jungle", "forest": "forest", "urban": "urban", "sport": "sports"}.get(str(sim.map.get("theme", "")), "")
	if theme.is_empty(): ambient.stop(); return
	var path = "res://assets/sounds/ambient/TD_ambience_%s-loop-mono-vbr.mp3" % theme
	if ambient.playing and ambient.stream.resource_path == path: return
	ambient.stream = load(path)
	ambient.stream.loop = true
	ambient.volume_db = linear_to_db(0.15 if theme == "urban" else 0.2)
	ambient.play()

func update_audio_mix(delta: float) -> void:
	if ambient.playing and (screen != "game" or not Profile.data.settings.sound): ambient.stop()
	var active = voices.filter(func(v): return v.playing)
	if screen == "game":
		audio_mix.update(active.size(), active.any(func(v): return int(v.get_meta("definition", {}).get("important", 0)) == 1), delta*1000.0)
	else: audio_mix = AudioMix.new()
	for voice in active:
		voice.volume_db = linear_to_db(audio_mix.gain(voice.get_meta("definition")))

func sound(name: String, tail: String = "") -> void:
	if not Profile.data.settings.sound: return
	if Time.get_ticks_msec()-int(last_sound.get(name, -10000)) < 80: return
	var definition = sound_definition(name)
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
			if v.stream is AudioStreamWAV:
				v.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if int(definition.get("loop", 0)) else AudioStreamWAV.LOOP_DISABLED
				# Converted CAFs have no RIFF loop chunk. Setting a loop mode
				# alone leaves Godot's end at0, repeating an empty first sample.
				if int(definition.get("loop", 0)):
					v.stream.loop_begin = 0
					v.stream.loop_end = int(round(v.stream.get_length()*v.stream.mix_rate))
			v.set_meta("definition", definition)
			v.volume_db = linear_to_db(audio_mix.gain(definition))
			v.set_meta("cue", name)
			v.set_meta("loop", int(definition.get("loop", 0)) == 1)
			v.set_meta("tail", tail)
			v.set_meta("until", Time.get_ticks_msec()+180)
			v.play()
			last_sound[name] = Time.get_ticks_msec()
			break

func resource_sound(params: Dictionary, field: String, tick: int) -> void:
	var cues = params.get(field+"_list", [])
	if not cues.is_empty(): sound(cues[posmod(int(tick/30), cues.size())])
	elif params.has(field): sound(str(params[field]))

func request_wave_launch() -> void:
	if sim==null or sim.paused or sim.outcome!="playing" or tutorial!=null or sim.wave_index>=sim.config.waves.size() or not wave_collapse.is_empty():return
	wave_collapse=ClassicUI.Wave.initial_collapse(sim.wave_index)
	sim.early_wave_count+=1
	ClassicUI.Wave.battle_rows(sim,wave_collapse)

func _process(delta: float) -> void:
	animation_epoch+=1
	animation_delta_ms=delta*1000.0*speed if screen=="game" and sim!=null and not sim.paused and sim.outcome=="playing" else 0.0
	world_decor_dt_ms=delta*1000.0 if screen=="world" else 0.0
	if screen=="world":world_blades.advance(delta*1000.0)
	world_clouds.advance(delta*1000.0 if screen=="world" else 0.0)
	elapsed_ui += delta
	advance_closed_result_clock(delta*1000.0)
	if screen=="game" and sim!=null and not sim.paused:ClassicUI.Wallet.flash_advance(hud_money_flash,delta*1000.0*speed)
	if screen=="menu" and not is_instance_valid(startup):advance_main_menu_presentation(delta)
	if screen=="upgrades":advance_upgrade_presentation(delta)
	if screen=="game" and sim!=null and sim.paused:update_question_presentation(delta)
	menu_transition.advance(delta)
	portrait_view.advance(delta)
	advance_promotion(delta*1000.0)
	var xp_growing=screen=="game" and sim!=null and sim.outcome!="playing" and reward_bar_releasing
	if screen=="game" and sim!=null and not wave_collapse.is_empty():
		if sim.outcome!="playing" or sim.wave_index!=wave_collapse.current:wave_collapse.clear()
		elif not sim.paused and wave_collapse.first< -39:
			# ProcessWaves0xd3bf8 launches from the previous rendered quad,
			# after its collapse crosses-39. The press was already counted.
			sim.next_wave(true,true);wave_collapse.clear()
	if screen=="game" and sim!=null and not sim.paused and sim.outcome=="playing" and build_type>0 and not tower_preview_state.is_empty():
		TowerPreview.advance(tower_preview_state,delta*1000.0*speed)
	if screen=="game":advance_magic_panel(delta*1000.0)
	if pending_sale>=0:update_sale_presentation()
	if promotion_open:
		for control in ui.get_children():
			if control.has_meta("promotion_panel"):control.modulate.a=promotion_alpha()
			elif control.has_meta("promotion_darkness"):control.color.a=promotion_alpha()/3.0
	if screen=="game" and tower_panel_close_at>=0:
		if elapsed_ui-tower_panel_close_at>=0.4:
			selected_tower=-1;tower_panel_close_at=-1.0;refresh_controls()
		else:
			for control in ui.get_children():
				if control.has_meta("tower_panel"):control.modulate.a=tower_panel_alpha()
	if screen=="world" and not selected_location.is_empty():
		if not fan_closing and fan_opened>=0 and elapsed_ui-fan_opened<0.7:world_camera=world_camera_from.lerp(world_camera_to,ClassicUI.interpolate_ease((elapsed_ui-fan_opened)/0.7))
		advance_mode_fan(delta*1000.0)
	if screen=="game" and sim!=null and sim.outcome!="playing":
		sync_result_clock();update_result_controls()
		reward_burst_fx.advance_ui(delta*1000.0)
		update_reward_bursts()
		advance_xp_result_particles(delta*1000.0)
	elif screen=="loading" and loading_kind=="departure":
		var rocket=ClassicUI.departure_positions(self,elapsed_ui-loading_started).rocket
		for i in range(reward_fx.systems.size()):reward_fx.systems[i].pos=rocket+Vector2(-7-i*2,16-i*3)*0.7
		reward_fx.advance_ui(delta*1000.0)
	reward_fx.visible=(screen=="game" and sim!=null and sim.outcome!="playing") or (screen=="loading" and loading_kind=="departure")
	reward_burst_fx.visible=screen=="game" and sim!=null and sim.outcome!="playing"
	update_result_sound(xp_growing)
	var tails: Array[String] = []
	for voice in voices:
		if voice.playing and (not Profile.data.settings.sound or (voice.get_meta("loop", false) and Time.get_ticks_msec() >= int(voice.get_meta("until", 0)))):
			if Profile.data.settings.sound and not str(voice.get_meta("tail", "")).is_empty(): tails.append(str(voice.get_meta("tail")))
			voice.stop()
	for tail in tails: sound(tail)
	if screen == "game" and sim != null and not sim.paused and sim.clock_ms < sim.disco_until: sound("magic_lsd")
	update_audio_mix(delta)
	if not qa_state_path.is_empty() and Time.get_ticks_msec() >= qa_state_at:
		qa_state_at = Time.get_ticks_msec()+250
		var state = {"screen": screen, "fps": Engine.get_frames_per_second(), "window": [view_size().x, view_size().y], "fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "sound": Profile.data.settings.sound, "music": Profile.data.settings.music, "xp": displayed_xp(), "saved_xp": Profile.data.xp, "pending_xp": pending_xp.size(),"profile_path":Profile.path,"qa_persist_progress":qa_persist_progress}
		if screen=="loading":state.merge({"loading_kind":loading_kind,"loading_elapsed":elapsed_ui-loading_started,"loading_name":loading_name})
		if screen=="world":state.merge({"world_camera":[world_camera.x,world_camera.y],"world_zoom":world_zoom,"world_clouds_visible":world_clouds.rendered.size()})
		if screen=="upgrades":state.merge({"selected_upgrade":selected_upgrade,"upgrade_scroll_y":upgrade_scroll_y,"upgrade_detail_keys":upgrade_view_states.keys()})
		if is_instance_valid(startup): state.merge({"startup": true, "startup_elapsed": startup.elapsed, "startup_variant": startup.variant, "video_position": startup.player.stream_position, "video_playing": startup.player.is_playing()})
		if sim != null:
			state.merge({"hud_money_flash_active":hud_money_flash.active,"hud_money_flash_age_ms":hud_money_flash.age_ms})
			var tower_cells = []
			for tower in sim.towers: tower_cells.append([tower.cell.x, tower.cell.y])
			state.merge({"config": sim.config.configid, "paused": sim.paused, "speed": speed, "ms": sim.clock_ms, "money": sim.money, "towers": sim.towers.size(), "tower_cells": tower_cells, "tower_forms": sim.towers.map(func(t): return {"id": t.id, "type": t.type, "level": t.level, "targeting": t.targeting}), "enemies": sim.enemies.size(), "enemy_missiles": sim.enemy_missiles.size(), "camera": [camera.x, camera.y], "zoom": zoom, "tutorial_step": tutorial_step, "build_type": build_type, "selected_tower": selected_tower, "pending_sale": pending_sale, "magic_placement": magic_placement, "outcome": sim.outcome})
			state.merge({"kills":sim.kills,"score":sim.score,"ability_stock":sim.abilities,"mines":sim.mines.size(),"mine_cells":sim.mines.map(func(m):return [m.cell.x,m.cell.y]),"disco_active":sim.clock_ms<sim.disco_until,"defense_active":sim.clock_ms<sim.defense_until,"bases":sim.bases.map(func(b):return {"hp":b.hp,"hpmax":b.hpmax}),"result_clock":result_clock,"wave_index":sim.wave_index,"spawn_hold":sim.spawn_hold,"tutorial_finished":sim.tutorial_finished})
			if tutorial!=null:state.merge({"tutorial_display_page":tutorial.display_page,"tutorial_transition_pending":tutorial.transition_pending})
		var state_file = FileAccess.open(qa_state_path, FileAccess.WRITE)
		if state_file: state_file.store_string(JSON.stringify(state)); state_file.close()
	if screen == "game" and sim != null and not qa_gallery:
		frame_remainder += delta*1000.0*speed
		var ms = int(frame_remainder)
		frame_remainder -= ms
		var physics_started=Time.get_ticks_usec()
		var clock_before=sim.clock_ms
		var battle_advancing=not sim.paused and sim.outcome=="playing"
		if sim.live_updates:sim.advance_frame(delta*1000.0*speed)
		else:sim.advance(ms)
		record_qa_time("physics",physics_started)
		update_tutorial(delta*1000.0)
		if not wave_collapse.is_empty():
			if sim.wave_index!=wave_collapse.current or sim.outcome!="playing":wave_collapse.clear()
			elif not sim.paused:
				var delay=int(sim.config.wavedelay)
				var elapsed=clampi(sim.clock_ms-sim.next_wave_ms+delay,0,delay)
				ClassicUI.Wave.advance_collapse(wave_collapse,delta*1000.0*speed,sim.wave_index,elapsed,delay,sim.config.waves.size())
		if tutorial!=null:
			for control in ui.get_children():
				if control.has_meta("tutorial_gl"):control.modulate.a=tutorial.fade_state.alpha
		var events_started=Time.get_ticks_usec()
		for event in sim.events: handle_event(event)
		sim.events.clear()
		if battle_advancing and sim.clock_ms>clock_before:
			advance_bolt_effects(delta*1000.0*speed if sim.live_updates else float(sim.clock_ms-clock_before))
		record_qa_time("events",events_started)
		var particles_started=Time.get_ticks_usec()
		particle_fx.advance(sim,delta*1000.0*speed if sim.live_updates else -1.0)
		record_qa_time("particles",particles_started)
		if not pending_xp.is_empty() and Time.get_ticks_msec() >= next_xp_save:
			next_xp_save = Time.get_ticks_msec()+1000
			flush_pending_xp()
		if sim.outcome != "playing" and not result_saved and Time.get_ticks_msec() >= next_result_retry:
			next_result_retry = Time.get_ticks_msec()+1000
			save_result()
			refresh_controls()
		for effect in effects.duplicate():
			if effect.has("bolt_clock"):continue
			if effect.until <= sim.clock_ms:
				effects.erase(effect)
				continuous_beams.erase(effect.get("key",""))
	queue_redraw()
	wave_fx.advance(delta*1000.0*speed)
	bolt_renderer.prepare()
	particle_fx.visible = screen == "game"
	battle_overlay.queue_redraw()
	if not qa_capture.is_empty() and not qa_capture_done and elapsed_ui > 2.0:
		qa_capture_done = true
		capture.call_deferred()
	if "--smoke-quit" in OS.get_cmdline_user_args() and elapsed_ui > 3.0: get_tree().quit()

func capture() -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var im = get_viewport().get_texture().get_image()
	var err = im.save_png(qa_capture)
	print("CAPTURE ", qa_capture, " ", err, " screen=", screen)
	print("QA_AUDIT ", JSON.stringify({"screen": screen, "capture": err, "fps": Performance.get_monitor(Performance.TIME_FPS), "frame_ms": Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, "architecture": "arm64" if OS.has_feature("arm64") else "x86_64", "viewport": [get_viewport_rect().size.x, get_viewport_rect().size.y], "engine": Engine.get_version_info().string, "seed": 114}))

func render_projectile_gallery() -> void:
	# Synthetic positions/technology keep each source effect visible. This is
	# renderer evidence, never a campaign strategy or original-device comparison.
	start_mission("8", true, false)
	sim.next_wave_ms = 1000000
	sim.money = 10000
	Profile.data.settings.music = false
	Profile.data.settings.sound = false
	music.stop()
	for index in range(4):
		var type = [5, 7, 8, 14][index]
		var cell = [Vector2i(8, 6), Vector2i(11, 6), Vector2i(8, 10), Vector2i(11, 10)][index]
		var t = {"id": index+1, "type": type, "level": 1, "cell": cell, "pos": sim.center(cell.x, cell.y),
			"def": sim.tower_data(type, 1), "angle": 0.0, "ready_ms": 0, "shot_ms": 0, "born_ms": 0, "foundation_ms": 0,
			"reload_ms": 100000.0, "targeting": "strongest", "receipts": []}
		sim.towers.append(t)
		var e = sim.spawn_enemy(2 if type == 14 else 5, 0, "", 900+index, false)
		e.pos = t.pos+Vector2(110, -30)
		e.speed = 0
		e.cell=cell;e.next_cell=cell;e.move_start=e.pos
		e.hp = 100000
		e.max_hp = 100000
	camera = sim.center(10, 8)
	zoom = 0.85
	refresh_controls()
	var directory = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="): directory = arg.trim_prefix("--capture-root=")
	if directory.is_empty(): push_error("Projectile gallery needs capture-root."); get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest = {"fixture": "Synthetic combat effects, four preserved tower forms and stationary targets.", "captures": [], "failures": []}
	for tick in [300, 720, 3000, 4440]:
		while sim.clock_ms < tick:
			sim.advance(Simulation.STEP_MS)
			for event in sim.events: handle_event(event)
			sim.events.clear()
			particle_fx.advance(sim)
		for effect in effects.duplicate():
			if effect.until <= sim.clock_ms: effects.erase(effect)
		queue_redraw()
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var filename = "projectiles-%d.png" % sim.clock_ms
		var error = get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
		var nuke = sim.missiles.filter(func(p): return int(p.type) == 5)
		var active_clouds = sim.zones.filter(func(z): return not z.has("bubble")).size()
		var row = {"path": filename, "error": error, "ms": sim.clock_ms, "missiles": sim.missiles.size(), "bubbles": sim.bubbles.size(), "active_clouds": active_clouds,
			"nuke_stage": nuke.map(func(p): return {"up": p.up, "down": p.down}), "effects": effects.size()}
		manifest.captures.append(row)
		if tick == 300 and (sim.bubbles.size() != 2 or nuke.is_empty() or nuke[0].up <= 0): manifest.failures.append("Growth/ascent stage did not execute.")
		if tick == 720 and sim.bubbles.size() != 2: manifest.failures.append("Chemical flight stage did not execute.")
		if tick == 3000 and (nuke.is_empty() or nuke[0].down <= 0): manifest.failures.append("Nuke descent did not execute.")
		if tick == 4440 and (active_clouds < 1 or effects.is_empty()): manifest.failures.append("Nuke impact/radiation did not execute.")
	var file = FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t")); file.close()
	get_tree().quit(0 if manifest.failures.is_empty() else 1)

func render_turn_gallery() -> void:
	start_mission("8", true, false)
	Profile.data.settings.music = false
	Profile.data.settings.sound = false
	music.stop()
	var directory = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="): directory = arg.trim_prefix("--capture-root=")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	camera = sim.center(14, 8)
	zoom = 1.0
	var manifest = {"fixture": "Synthetic authored aircraft/tank poses along a vertical-to-diagonal corner; native projection and rotation/alpha math have separate isolated ARM checks.", "captures": [], "failures": []}
	var view = Simulation.CreepView
	for progress in [0.55, 0.7, 0.8, 0.05, 0.2]:
		sim.enemies.clear()
		for i in range(5):
			var e = sim.spawn_enemy([2, 3, 4, 5, 6][i], 0, "", 900+i, false)
			var a = Vector2i(8+i*3, 6)
			var b = a+Vector2i(0, 2)
			var c = b+Vector2i(1, 1)
			e.path = [a, b, c, c+Vector2i(1, 1), c+Vector2i(2, 2), c+Vector2i(3, 3)]
			e.path_at = 1
			e.cell = a
			e.next_cell = b
			e.move_start = sim.center(a.x, a.y)
			var target = sim.center(b.x, b.y)
			e.dir = (target-e.move_start).normalized()
			e.pos = sim.vector_interpolate(e.move_start, target, 0.5)
			view.prepare(sim, e)
			if progress >= 0.75 or progress < 0.25:
				e.pos = sim.vector_interpolate(e.move_start, target, 0.75)
				view.prepare(sim, e)
			if progress < 0.25:
				e.path_at = 2
				e.cell = b
				e.next_cell = c
				e.move_start = target
				target = sim.center(c.x, c.y)
				e.dir = (target-e.move_start).normalized()
			e.pos = sim.vector_interpolate(e.move_start, target, progress)
			view.update(sim, e)
		queue_redraw()
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var filename = "turn-%03d.png" % int(progress*1000)
		var error = get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
		var poses = sim.enemies.map(func(e): return {"type": e.type, "logical": [e.pos.x, e.pos.y], "drawn": [e.visual_pos.x, e.visual_pos.y], "layers": e.visual_layers})
		manifest.captures.append({"path": filename, "error": error, "progress": progress, "poses": poses})
		if progress in [0.55, 0.05] and sim.enemies.any(func(e): return float(e.visual_layers[1].alpha) <= 0): manifest.failures.append("Expected native blending layers are absent.")
		if progress in [0.8, 0.05, 0.2] and sim.enemies.any(func(e): return e.visual_pos.is_equal_approx(e.pos)): manifest.failures.append("Expected projected corner position is absent.")
		var expected = "RunDown" if progress == 0.55 else "RunDownRight" if progress == 0.2 else "TurnDownRight"
		if sim.enemies.any(func(e): return e.visual_layers[0].state != expected): manifest.failures.append("Expected native corner animation is absent.")
	var file = FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t")); file.close()
	get_tree().quit(0 if manifest.failures.is_empty() else 1)

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
		if tutorial != null: tutorial.hint_visible = false
		refresh_controls()
		portrait_view.advance(0.5) # Gallery pose removes the suppressed Training view.
		await get_tree().process_frame
		# The native window may be occluded during this long QA corpus. Force
		# its actual OpenGL frame after deferred UI/redraw work has completed.
		RenderingServer.force_draw(true)
		var path = output.path_join("config-"+str(mission.configid)+".png")
		var error = get_viewport().get_texture().get_image().save_png(path)
		captures.append({"config": mission.configid, "map": mission.map, "mode": mission.gametype, "error": error, "path": path.get_file()})
	var file = FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "captures": captures}, "\t"))
	file.close()
	print("CAMPAIGN_GALLERY ", captures.size())
	get_tree().quit()

func advance_bolt_effects(delta_ms:float) -> void:
	if sim==null or sim.paused:return
	var bolt=preload("res://scripts/bolt_view.gd")
	for effect in effects.duplicate():
		if not effect.has("bolt_clock"):continue
		# Area/Active Defense callers retain refreshed bolts without Update.
		if not (effect.area and effect.refreshed):bolt.advance_clock(effect.bolt_clock,delta_ms)
		effect.refreshed=false
		if not effect.bolt_clock.alive:
			effects.erase(effect);continuous_beams.erase(effect.get("key",""))

func add_beam_effect(event: Dictionary) -> void:
	var from:Vector2=event.from
	var active_defense=str(event.kind)=="beam" and not event.has("filename")
	var owner_tower=sim.find_tower(int(event.get("tower_id",-1)))
	var filename=str(event.get("filename",owner_tower.get("def",{}).get("filename","")))
	var parameters=Content.animations.get("towers/"+filename,{}).get("params",{})
	var bolt=preload("res://scripts/bolt_view.gd")
	var offset=[0,0] if active_defense else parameters.get("add_bold_pos",[0,-20] if int(event.type)==11 else [0,0])
	from=from+Vector2(offset[0],offset[1]) if int(event.type)==11 else bolt.source_point(from,Vector2(offset[0],offset[1]))
	var target:Vector2=event.to if int(event.type)==11 else event.get("visual_to",event.to)
	var id=int(event.get("enemy_id",-1))
	var key=str(event.get("tower_id",event.from))+":"+str(id)+":"+str(event.type)+":"+str(event.kind)
	var continuous=str(event.kind)=="beam"
	var flags=bolt.caller_flags(int(event.type),active_defense)
	var sampled={"points":PackedVector2Array([from,target]),"ball_flip":Vector2i.ZERO} if int(event.type)==11 else bolt.sample(from,target,int(event.ms)+id,flags.scatter,flags.ball)
	var path:PackedVector2Array=sampled.points
	if continuous and continuous_beams.has(key):
		var old:Dictionary=continuous_beams[key]
		old.points=path;old.ball_flip=sampled.ball_flip;old.born=int(event.ms);old.until=int(event.ms)+350
		if old.has("bolt_clock"):old.ribbon_alpha=old.bolt_clock.opacity;old.refreshed=true
	else:
		var effect={"kind":"shot","texture":bolt.texture_path(parameters,int(event.type),active_defense),"key":key,"points":path,"type":int(event.type),"born":int(event.ms),"until":int(event.ms)+(92 if int(event.type)==11 else 350),"ball":flags.ball,"ball_source":from,"ball_flip":sampled.ball_flip,"scatter":flags.scatter}
		if int(event.type)!=11:effect.merge({"bolt_clock":bolt.clock(),"ribbon_alpha":1.0,"area":flags.scatter,"refreshed":true})
		effects.append(effect)
		if continuous:continuous_beams[key]=effect

func handle_event(event: Dictionary) -> void:
	if event.kind=="kill" or event.kind=="base_impact":creep_animation_owners.erase(int(event.get("id",-1)))
	match event.kind:
		"build":
			sound("tower_place")
			if not test_session and str(sim.config.configid) != "1" and not Profile.record_build(int(event.type)): message("The construction statistics could not be saved.")
		"upgrade": sound("tower_upgrade")
		"sell":
			sound("TD_sell_tower_mono_03")
			particle_fx.remove_owner(int(event.get("id",-1)))
			particle_fx.emit_system("TowerSold",event.pos)
		"wave":
			sound("wave_launch_early-mono" if event.early else "wave_launch-mono")
			wave_fx.launch()
		"shot":
			var params = Content.animations.get("towers/"+str(event.get("filename", "")), {}).get("params", {})
			if int(event.type) != 5: resource_sound(params, "shoot_sound", int(event.ms))
			var extra = params.get("extra_shoot_sound_list", [])
			if not extra.is_empty(): sound(extra[0], str(params.get("sound_end", "")))
			if int(event.type) in [1,2,3,13,15]:effects.append({"kind":"flash","from":event.from,"to":event.to,"type":event.type,"filename":event.filename,"born":int(event.ms),"until":int(event.ms)+40})
			elif int(event.type) in [10,11]: add_beam_effect(event)
		"nuke_warning": resource_sound(Content.animations["towers/"+str(event.filename)].params, "shoot_sound", int(event.ms))
		"cloud_active":
			if int(event.type) != 5: sound("acid_splash_and_burn-mono")
		"beam":
			if int(event.type) == 12: resource_sound(Content.animations["towers/"+str(event.filename)].params, "shoot_sound", int(event.ms))
			add_beam_effect(event)
		"enemy_shot":
			var cues = Content.animations.get("creeps/"+str(event.filename), {}).get("params", {}).get("shoot_sound_list", [])
			if not cues.is_empty(): sound(cues[posmod(int(event.ms/30), cues.size())])
		"enemy_impact":
			var enemy_def = Content.catalog.tower_creeps[int(event.type)]
			var cues = Content.animations.get("creeps/"+str(enemy_def.filename), {}).get("params", {}).get("missile_explosion_sounds", [])
			sound(cues[0] if not cues.is_empty() else "missile_explosion")
			for name in ["MissileExplodeCenter","MissileExplodeGray","MissileExplodeSpray"]:particle_fx.emit_system(name,event.pos)
		"kill":
			if not test_session or qa_persist_progress: pending_xp.append({"reward": float(event.reward), "type": int(event.type)})
			var enemy_def = Content.catalog.tower_creeps[int(event.type)]
			var bindings = Content.particles.bindings.get("creeps/"+str(enemy_def.filename), {})
			for alias in ["explosion_parts", "explosion_parts2", "explosion_smoke"]:
				if bindings.has(alias): particle_fx.emit_system(str(bindings[alias].filename), event.pos, str(enemy_def.get("color", "")), "", 500 if alias == "explosion_smoke" else 0)
			resource_sound(Content.animations.get("creeps/"+str(enemy_def.filename), {}).get("params", {}), "explosion_sound", int(event.ms))
		"explosion":
			var cues = Content.animations.get("towers/"+str(event.get("filename", "")), {}).get("params", {}).get("missile_explosion_sounds", [])
			sound(cues[posmod(int(event.ms/30), cues.size())] if not cues.is_empty() else "missile_explosion")
			if int(event.type) not in [0,5]:
				for name in ["MissileExplodeCenter","MissileExplodeGray","MissileExplodeSpray"]:particle_fx.emit_system(name,event.pos)
			if int(event.type) in [0,5]:effects.append({"kind": "explosion", "pos": event.pos, "radius": float(event.radius)*55.0, "type": event.type, "born": int(event.ms), "until": int(event.ms)+(1340 if int(event.type) == 5 else 600)})
		"base_hit": sound("base_under_attack_alert-mono")
		"teleport": sound("portal_teleport-mono")
		"blocked": message("You cannot block every path. The tower cost was returned.")
		"magic":
			sound({"m_freeze": "freeze_activation-mono", "m_lsd": "magic_lsd", "m_actdef": "active_defense_on-mono"}.get(event.key, "UI_click"))
		"magic_end": sound("freeze_deactivation-mono" if event.key == "m_freeze" else "active_defense_off-mono")
		"victory": sound("level_won")
		"defeat": sound("level_lost")

func draw_image(path: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var t = Content.tex(path)
	if t != null: draw_texture_rect(t, rect, false, tint)

func text(pos: Vector2, value: String, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(bold, pos+Vector2.ONE, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	draw_string(bold, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func owned_animation(owner:Dictionary,key:String,set_name:String,state_name:String,playing:bool=true) -> Dictionary:
	var definition=Content.animations.get(set_name,{}).get("states",{}).get(state_name,{})
	if definition.is_empty():return {}
	if not owner.has("render_animators"):owner.render_animators={}
	var state=owner.render_animators.get(key,{})
	if state.is_empty():
		var frames=definition.get("resolved_frames",definition.get("added_frames",[]))
		state=Animator.initial(maxi(1,frames.size() if not frames.is_empty() else int(definition.get("frames",1))),float(definition.get("speed",1)),bool(definition.get("loop",false)))
		state.last_epoch=-1;state.owner_playing=playing;owner.render_animators[key]=state
		Animator.play(state,state_name,definition)
		state.stopped=not playing
	if state.name!=state_name or (playing and not state.owner_playing):
		Animator.play(state,state_name,definition);state.last_epoch=-1
	state.owner_playing=playing
	if state.last_epoch!=animation_epoch:
		Animator.advance(state,animation_delta_ms,int(elapsed_ui*1000.0),bool(definition.get("alpha_anim",false)),not playing or (sim!=null and sim.paused))
		state.last_epoch=animation_epoch
	return state

func sprite(set_name: String, state: String, pos: Vector2, index: float = 0, color_name: String = "", tint: Color = Color.WHITE, lift: float = 0.0, native_scale: Vector2 = Vector2.ONE, animator:Dictionary={}) -> void:
	var owned=not animator.is_empty()
	var frame_index=int(animator.frame) if owned else int(index)
	var first=Content.frame(set_name,state,frame_index,color_name)
	if first.is_empty():return
	var flags=int(first.blend_flags)
	if flags==0:
		# The ordinary path stays one lookup/quad. Most battle sprites have
		# neither source interpolation flag; do not resolve their state again.
		var texture:Texture2D=first.texture
		draw_texture_rect(texture,Rect2(pos+(-texture.get_size()/2.0+first.offset)*native_scale+Vector2(0,lift),texture.get_size()*native_scale),false,tint)
		return
	if flags&2 and owned:tint=Animator.straight(animator.alpha_color)
	if not flags&1:draw_sprite_frame(first,pos,tint,lift,native_scale);return
	var phase=float(animator.phase) if owned else index
	var second=Content.frame(set_name,state,frame_index+1,color_name)
	if second.is_empty():return
	var images=[first,second]
	var recipe=Animator.render_frames(0,Animator.f32(phase-frame_index),[first.native_key,second.native_key],true)
	for draw in recipe:
		# Keep the complete source plan, but zero RGBA contributes no pixels.
		if draw.color.a<=0:continue
		draw_sprite_frame(images[draw.frame],pos,Animator.straight(draw.color),lift,native_scale)

func draw_sprite_frame(frame:Dictionary,pos:Vector2,tint:Color,lift:float,native_scale:Vector2) -> void:
	var texture:Texture2D=frame.texture
	draw_texture_rect(texture,Rect2(pos+(-texture.get_size()/2.0+frame.offset)*native_scale+Vector2(0,lift),texture.get_size()*native_scale),false,tint)

func extra_sprite(set_name: String, name: String, pos: Vector2, variation: String = "", native_scale: Vector2 = Vector2.ONE, tint: Color = Color.WHITE) -> bool:
	var frame = Content.extra_frame(set_name, name, variation)
	if frame.is_empty(): return false
	var texture: Texture2D = frame.texture
	draw_texture_rect(texture, Rect2(pos+(-texture.get_size()/2.0+frame.offset)*native_scale, texture.get_size()*native_scale), false, tint)
	return true

func creep_owned_animation(e:Dictionary,index:int,layer:Dictionary,states:Dictionary) -> Dictionary:
	var definition=states.get(layer.state,states.get("Idle",{}))
	if definition.is_empty():return {}
	var id=int(e.id)
	var owner=creep_animation_owners.get(id,{})
	if owner.is_empty() or not is_same(owner.creep,e):
		owner={"creep":e,"clocks":[{},{}],"was_attacking":false};creep_animation_owners[id]=owner
	if index==0:
		if e.attacking and not owner.was_attacking:
			# The source attack branch also stops the currently hidden animator.
			for clock in owner.clocks:
				if not clock.is_empty():clock.stopped=true;clock.phase=0.0;clock.frame=0;clock.was_attacking=true
		owner.was_attacking=bool(e.attacking)
	var state=owner.clocks[index]
	if state.is_empty():
		state=CreepAnimator.initial(str(layer.state),definition)
		state.last_epoch=-1;owner.clocks[index]=state
	CreepAnimator.prepare(state,str(layer.state),definition,float(e.get("animation_divisor",1)),float(e.get("animation_multiplier",1)),bool(e.attacking))
	if state.last_epoch!=animation_epoch:
		CreepAnimator.render_tick(state,animation_delta_ms,sim.paused)
		state.last_epoch=animation_epoch
	return state

func creep_shadow(e: Dictionary, set_name: String, position: Vector2, layer: Dictionary, growth: Dictionary, body_scale_x: float, map_zoom: float, frame:int=0) -> void:
	# CCreepShadow::Render0xfc7b8: black tint, animator-sized quad,
	# native facing/physical rotation and a linear grow factor.
	var factor = float(e.def.traits.get("shadow_scale_factor", 1))*float(growth.alpha)
	var tint = Color(0, 0, 0, clampf(1.0-body_scale_x*0.5, 0, 1))
	var animated = str(e.def.traits.get("animated_shadow", ""))
	if not animated.is_empty():
		var f = Content.frame("creeps/"+animated, layer.state, frame)
		if f.is_empty(): return
		var size = f.texture.get_size()*factor
		draw_texture_rect(f.texture, Rect2(position-size/2.0, size), false, tint)
		return
	var shadow = Content.extra_frame(set_name, "shadow", str(e.def.get("color", "")))
	var body = Content.frame(set_name, layer.state, frame, str(e.def.get("color", "")))
	if shadow.is_empty() or body.is_empty(): return
	var direction = Simulation.AIM_ANIMATIONS.get(str(layer.state), e.dir)
	var angle = sim.f32(sim.f32(sim.native_angpos(direction)*57.295780181884766)-90.0)+float(layer.rotation)
	var size = body.texture.get_size()*Vector2(factor, factor*0.800000011920929)
	draw_set_transform(map_origin()+position*map_zoom, deg_to_rad(angle), Vector2.ONE*map_zoom)
	draw_texture_rect(shadow.texture, Rect2(-size/2.0, size), false, tint)
	draw_set_transform(map_origin(), 0, Vector2.ONE*map_zoom)

func draw_avatar(rect: Rect2) -> void:
	# AvatarDrawer::sortArray (0x490f8) sorts sN by length then lexical order;
	# for the recovered s1..s11 keys this is ascending numeric slot order.
	for slot in range(1, 13):
		var key = "s"+str(slot)
		var wardrobe = Profile.data.dress.duplicate()
		if screen == "dress": wardrobe.merge(dress_preview,true)
		if not wardrobe.has(key): continue
		for costume in Content.catalog.tower_dress:
			if int(costume.slot) == slot and int(costume.id) == int(wardrobe[key]):
				draw_image("assets/cosmetics/"+str(costume.URL).get_file(), rect)
				break

func _draw() -> void:
	if world_blades!=null:world_blades.prepare(self)
	if world_clouds!=null:world_clouds.prepare()
	if font == null: return
	var size = view_size()
	if screen == "game" and sim != null:
		var started=Time.get_ticks_usec();draw_game();record_qa_time("draw",started)
	elif screen == "loading":
		if loading_kind=="departure":ClassicUI.draw_departure(self,elapsed_ui-loading_started)
		else:ClassicUI.draw_loading(self,elapsed_ui-loading_started)
	elif screen == "story":
		var image=story_image_rect()
		draw_image("assets/lobby/story_screens/topline.png",Rect2(0,image.position.y-142,1024,149))
		draw_image("assets/lobby/story_screens/bottom_line.png",Rect2(0,image.position.y+477,1024,149))
	elif screen == "world": draw_world()
	elif screen == "menu": draw_menu()
	elif screen in ["career", "dress"]: draw_career()
	elif screen == "medals":
		draw_career()
		draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,0.33))
	elif screen in ["shop", "upgrades", "credits", "spicery"]:
		var background = {"shop":"tech_shop_bg", "upgrades":"upgrades_yard_bg", "credits":"credits_bg","spicery":"spiceshop_bg"}[screen]
		var origin=Vector2(0,0) if screen=="spicery" else menu_origin()+Vector2(0,-128)*menu_scale()
		draw_image("assets/"+background+".png", Rect2(origin,Vector2(1024,1024)*menu_scale()))
	else:
		var background = {"shop": "tech_shop_bg", "spicery": "spiceshop_bg", "upgrades": "tech_shop_bg", "career": "career_bg", "medals": "medalsViewController_bg", "dress": "career_bg", "settings": "career_bg", "credits": "career_bg"}.get(screen, "career_bg")
		draw_image("assets/"+background+".png", Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(22, 94, size.x-44, size.y-155), Color(0.015, 0.08, 0.12, 0.52))
		if screen == "dress": draw_avatar(Rect2(size.x-360, 160, 350, 350))
	if screen not in ["world","career","dress","shop","upgrades","spicery","game","menu","loading","story"]:
		draw_image("assets/menu_nakladka_top.png", Rect2(0, 0, size.x, 72))
		draw_image("assets/menu_nakladka_bottom.png", Rect2(0, size.y-59, size.x, 59))
		text(Vector2(32, size.y-20), "%s · Level %d · %.1f XP" % [Profile.data.name, int(Profile.data.level), Profile.data.xp], 21)
		text(Vector2(size.x-290, size.y-20), "%d spice · %d points" % [int(Profile.data.spice), int(Profile.data.specpoints)], 21, Color("#fff0b1"))
	if ui_time_ms() < notice_until:
		draw_rect(Rect2(26, size.y-225, size.x-52, 48), Color(0.02, 0.05, 0.08, 0.93))
		text(Vector2(42, size.y-194), notice, 19, Color("#ffed9b"))

func draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO,view_size()),Color("#06121b"))
	var base=Transform2D(0,Vector2.ONE*menu_scale(),0,menu_origin())
	var effects_by_id={}
	for entry in Content.menu_layout.entries:
		var outlet=str(entry.outlet)
		if menu_floats.items.has(int(entry.id)):
			effects_by_id[int(entry.id)]=menu_floats.transform_for(int(entry.id),menu_rect(entry))
		if MainMenuView.ROTATIONS.has(outlet) or MainMenuView.MOTIONS.has(outlet) or outlet=="logoRocket2":
			effects_by_id[int(entry.id)]=main_menu_view.transform_for(outlet,menu_rect(entry))
	draw_set_transform_matrix(base)
	for entry in Content.menu_layout.entries:
		draw_set_transform_matrix(base)
		if int(entry.id) in [64,246]:
			if int(entry.id)==64:draw_avatar(menu_rect(entry))
			else:draw_image("assets/sound_icon_1.png",menu_rect(entry),Color.WHITE if Profile.data.settings.music else Color(0.4,0.4,0.4))
		if int(entry.id)==268:menu_bubbles.draw(self)
		if int(entry.id)==110:menu_motion.draw_notes(self,Content)
		if not entry.has("image"):continue
		if menu_descendant(entry,263) or int(entry.id)==300 or menu_descendant(entry,110):continue
		var rect=menu_rect(entry)
		if menu_motion.flies.has(int(entry.id)):rect.position=menu_motion.fly_position(int(entry.id))-rect.size/2
		var transform=Transform2D.IDENTITY
		for ancestor in entry.ancestors:
			if effects_by_id.has(int(ancestor)):transform*=effects_by_id[int(ancestor)]
		if effects_by_id.has(int(entry.id)):transform*=effects_by_id[int(entry.id)]
		var tint=Color(1,1,1,float(entry.get("alpha",1.0)))
		if int(entry.get("tag",0)) in range(100,109):tint.a=MenuFloatView.lamp_alpha(int(entry.tag),menu_floats.age)
		var path=str(entry.image)
		if str(entry.outlet) in ["logoRocket1","logoRocket2"]:path="assets/logo_rocket_%d.png"%(1+int(main_menu_view.age/(MainMenuView.ROCKET_DURATION/4))%4)
		if str(entry.outlet) in MainMenuView.LIGHT_TARGETS:tint.a=main_menu_view.light_alpha()
		if int(entry.id)==221:
			var amount=main_menu_view.eye_amount()
			if amount<=0:continue
			var eye_id=[24,31,23][main_menu_view.eye_index]
			var target=Content.menu_layout.entries.filter(func(e):return int(e.id)==eye_id)[0]
			rect=menu_rect(target);tint.a=amount
			transform*=Transform2D(0,Vector2.ONE*amount,0,rect.get_center())*Transform2D(0,-rect.get_center())
		draw_set_transform_matrix(base*transform)
		draw_image(path,rect,tint)
	draw_set_transform_matrix(base*effects_by_id.get(17,Transform2D.IDENTITY))
	var name_rect=menu_rect(menu_entry("nameLabel"))
	text(name_rect.position+Vector2(0,30),Profile.data.name,30)
	text(menu_rect(menu_entry("howdy")).position+Vector2(0,28),"Ahoy!",27)
	draw_set_transform_matrix(base*effects_by_id.get(215,Transform2D.IDENTITY))
	text(Vector2(904,163),"xp: %.0f"%Profile.data.xp,18)
	draw_set_transform_matrix(base*effects_by_id.get(22,Transform2D.IDENTITY))
	text(Vector2(904,188),"%d spice"%int(Profile.data.spice),18)
	draw_set_transform(Vector2.ZERO)

func draw_world() -> void:
	var origin = world_origin()
	draw_set_transform(origin, 0, Vector2.ONE*world_zoom)
	draw_image(Content.maps.lobby_map.background, Rect2(0, 0, 4096, 3072))
	var animated=Content.maps.lobby_map.get("animated_objects",[])
	var poses=world_decor.poses(animated,world_decor_dt_ms)
	for i in range(animated.size()):
		var texture=Content.tex(animated[i].texture)
		if texture==null:continue
		var pose=poses[i]
		draw_set_transform(origin+pose.position*world_zoom,deg_to_rad(pose.angle),Vector2.ONE*world_zoom)
		draw_texture_rect(texture,Rect2(-texture.get_size()/2,texture.get_size()),false)
		draw_set_transform(origin,0,Vector2.ONE*world_zoom)
	for loc in Content.catalog.tower_locations:
		if int(loc.id) == 1000:
			if location_visible(loc):
				var point = Vector2(float(loc.x),float(loc.y))
				draw_image("assets/hello_africa.png",Rect2(point-Vector2(64,48),Vector2(128,96)))
				text(point+Vector2(-60,62),loc.name,28)
			continue
		if int(loc.id) > 1000: continue
		var missions = []
		var visible = false
		for c in Content.catalog.offlineConfigs:
			if int(c.location) == int(loc.id) and not c.waves.is_empty():
				missions.append(c)
				visible = visible or Profile.available(c)
		if not visible: continue # CLocation::UpdateData0x92644 hides inaccessible locations.
		var p = Vector2(float(loc.x), float(loc.y))
		if int(loc.get("struct_type", 0)) > 0:
			# UpdateData constructs100x70 city art at exact(-50,-36) offset.
			draw_image("assets/lobby/lvl_structures/lvl_structure_%d.png" % int(loc.struct_type), Rect2(p+Vector2(-50, -36), Vector2(100, 70)))
		for c in missions:
			var slot = int(c.gametype)-1
			var completed = Profile.unlocked(str(c.get("grantsunlock", "")))
			var color_name = "green" if completed else "orange" if Profile.available(c) else "white"
			draw_location_extra(color_name+"_"+str(slot), p)
			var icon = Content.extra_frame("lobby/location_res", "icon_"+str(slot))
			var offset_values = icon.get("params", {}).get("green_offset", [0, 0]) if completed else [0, 0]
			draw_location_extra("icon_"+str(slot), p+Vector2(float(offset_values[0]), float(offset_values[1])))
			if int(Profile.data.completed.get(c.configid, 0)) > 0: draw_location_extra("star_"+str(slot), p)
		if int(loc.get("struct_type", 0)) == 0:
			draw_image("assets/lobby/level_blinker.png", Rect2(p-Vector2(48, 48), Vector2(96, 96)), Color(1, 1, 1, 0.6+0.4*sin(elapsed_ui*2.0)))
		var label_offset = Vector2(float(loc.get("label_x", -50)), float(loc.get("label_y", 52)))
		if int(loc.get("struct_type",0))>0 and not loc.has("label_x"):label_offset=Vector2(65,14)
		draw_string(handwriting,p+label_offset,loc.name,HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if not selected_location.is_empty():
		if int(selected_location)==1000:draw_rect(Rect2(view_size().x-320,72,320,view_size().y-135),Color(0.02,0.07,0.12,0.94))

func draw_location_extra(name: String, pos: Vector2) -> void:
	var frame = Content.extra_frame("lobby/location_res", name)
	if frame.is_empty(): return
	var texture: Texture2D = frame.texture
	# RenderQuadFast0x1152d0 adds its authored top-left offset directly.
	draw_texture_rect(texture, Rect2(pos+frame.offset, texture.get_size()), false)

func tower_depth(tower:Dictionary) -> float:
	var filename=str(tower.get("depth_filename",tower.def.filename))
	var cached=tower_depth_cache.get(tower.id,{})
	if cached.get("filename","")==filename and cached.get("position",Vector2.INF)==tower.pos:return cached.depth
	var resource=Content.animations.get("towers/"+filename,{})
	var value=MapDepth.tower(tower.pos.y,resource)
	tower_depth_cache[tower.id]={"filename":filename,"position":tower.pos,"depth":value}
	return value

func base_depth(base:Dictionary) -> float:
	# Base type/position and imported resources are static during a battle.
	var identity=Vector3(base.pos.x,base.pos.y,int(base.type))
	if base_depth_cache.has(identity):return base_depth_cache[identity]
	var value=MapDepth.base(base.pos.y,Content.animations.get("bases/base"+str(base.type),{}))
	base_depth_cache[identity]=value
	return value

func uses_air_pass(enemy:Dictionary) -> bool:
	# CCreep construction registers only resource type1 with CMap. Type2
	# bodies are routed by CCreepManager::RenderAllAirCreeps0xfbe8c.
	return bool(enemy.get("native_air",enemy.get("def",{}).get("class","ground")=="air"))

func creep_depth(enemy:Dictionary) -> float:
	var filename=str(enemy.get("def",{}).get("filename",""))
	if not creep_depth_cache.has(filename):
		creep_depth_cache[filename]=MapDepth.creep_height(Content.animations.get("creeps/"+filename,{}))
	var position:Vector2=enemy.get("visual_pos",enemy.pos)
	return SpiceNative.creep_depth(position.y,creep_depth_cache[filename])

func battle_air_objects() -> Array:
	return sim.enemies.filter(func(e):return uses_air_pass(e))

func enemy_missile_passes() -> Dictionary:
	return preload("res://scripts/creep_owner_view.gd").missile_passes(sim.enemies,sim.enemy_missiles,Content.catalog.tower_creeps)

func draw_enemy_missile(missile:Dictionary,scale:float) -> void:
	var definition=Content.catalog.tower_creeps[int(missile.type)]
	draw_set_transform(map_origin()+missile.pos*scale,deg_to_rad(float(missile.angle)-90.0),Vector2.ONE*scale)
	if not extra_sprite("creeps/"+str(definition.filename),"missile",Vector2.ZERO):draw_circle(Vector2.ZERO,3.0,Color("#ffe3a0"))
	draw_set_transform(map_origin(),0,Vector2.ONE*scale)

func selected_range_pose() -> Dictionary:
	if sim==null or selected_tower<0:return {}
	var tower=sim.find_tower(selected_tower)
	if tower.is_empty() or tower.get("def",{}).is_empty():return {}
	var spacing=BuildHexView.f32(float(sim.map.hex_h)/1000.0)
	# Original RenderForceBefore forwards panel alpha to the same authored
	# oval used by inactive towers. Supply's additive range field is separate.
	return {"position":tower.pos,"draws":BuildHexView.oval(tower_panel_alpha(),spacing,float(tower.def.get("range",0)),0)}

func battle_objects() -> Array:
	var objects=[]
	for layer in sim.map.get("foreground",[]):objects.append({"y":float(layer.y)+float(layer.tile.get("depth_pos",layer.tile.get("h",0))),"layer":layer})
	for base in sim.bases:
		objects.append({"y":base_depth(base),"base":base})
	for t in sim.towers:
		objects.append({"y":tower_depth(t),"tower":t})
	for mine in sim.mines:
		objects.append({"y":MapDepth.effect(mine.pos.y,Content.animations.get("sfx/mine",{}),"Idle"),"mine":mine,"preview":false})
	if magic_placement=="m_mine":
		var position=mouse_world(magic_preview_position)
		objects.append({"y":MapDepth.effect(position.y,Content.animations.get("sfx/mine",{}),"Idle"),"mine":{"pos":position,"cell":sim.nearest(position)},"preview":true})
	for e in sim.enemies:
		if not uses_air_pass(e):objects.append({"y":creep_depth(e),"enemy":e})
	# Original whole-map registration, equal-depth introsort order, global
	# jitter and complete animator/owner lifetimes remain unresolved.
	objects.sort_custom(func(a,b):return a.y<b.y)
	return objects

func battle_portal_objects() -> Array:
	var objects=[]
	for index in range(sim.portals.size()):
		var portal=sim.portals[index]
		var presentation=sim.portals[0].get("presentation",{})
		var gate=presentation.gates[index] if not presentation.is_empty() else {"state":0,"scale":1.0}
		if gate.state==3:continue
		var age=maxi(0,sim.clock_ms-int(sim.portals[0].get("connected_ms",portal.get("born_ms",0)))) if sim.portals.size()==2 else 0
		objects.append({"pos":portal.pos,"state":"Blue" if index==0 else "Red","frame":int(age/1000),"preview":false,"scale":gate.scale,"gate_state":gate.state,"gate":gate})
	for pair in sim.static_portals:
		for index in range(2):
			var kind="in" if index==0 else "out"
			var gate=pair.presentation.gates[index]
			if gate.state!=3:objects.append({"pos":sim.center(pair[kind].x,pair[kind].y),"state":"Blue" if index==0 else "Red","frame":int(sim.clock_ms/1000),"preview":false,"scale":gate.scale,"gate_state":gate.state,"gate":gate})
	if magic_placement=="m_portal":objects.append({"pos":mouse_world(magic_preview_position),"state":"Blue" if sim.portals.is_empty() else "Red","frame":0,"preview":true,"scale":0.3,"gate_state":0,"gate":{}})
	for portal in objects:portal.depth=MapDepth.effect(portal.pos.y,Content.animations.get("sfx/portals",{}),"Blue")
	objects.sort_custom(func(a,b):return a.depth<b.depth)
	return objects

func draw_mine_object(mine:Dictionary,preview:bool) -> void:
	var remaining=0 if preview else maxi(0,int(mine.ready)-sim.clock_ms)
	var light=float(sim.map.cells[sim.cell_index(mine.cell)].get("l",1)) if sim.within(mine.cell) else 1.0
	var pose=MagicView.mine(mine.pos,not preview,0 if remaining>0 or preview else 2,remaining,int(Content.catalog.tower_magic.mine_sleep),light)
	for actor in pose.sprites:
		var lights=actor.key=="lights"
		var animation=owned_animation(mine,"lights","sfx/mine_lights","Builded") if lights else {}
		sprite("sfx/mine_lights" if lights else "sfx/mine","Builded" if lights else "Idle",mine.pos,0,"",MagicView.straight(actor.color),0,Vector2.ONE,animation)
	for bar in pose.bars:draw_rect(bar.rect,bar.color)

func draw_game() -> void:
	if probe_placement_order:placement_draw_trace.clear()
	var scale = map_scale()
	draw_set_transform(map_origin(), 0, Vector2.ONE*scale)
	for z in sim.zones:
		if z.has("bubble"): continue
		draw_circle(z.pos, float(z.def.get("poison_range", 1500))/1000.0*40.0, Color(0.4, 0.75, 0.05, 0.22))
	# Portal art belongs to registered RenderBefore; its body is empty.
	for portal in battle_portal_objects():
		var animation=owned_animation(portal.gate,"portal","sfx/portals",portal.state,bool(portal.gate.get("animation_played",false)))
		sprite("sfx/portals",portal.state,portal.pos,0,"",MagicView.straight(MagicView.portal(false,0)[0].color) if portal.preview else Color.WHITE,0,Vector2.ONE*float(portal.scale),animation)
	var objects=battle_objects()
	var enemy_projectiles=enemy_missile_passes()
	var depth_bases=[]
	for object in objects:
		if object.has("layer"):
			var layer = object.layer
			var tile = layer.tile
			var texture = Content.tex(layer.texture)
			if texture != null:
				draw_texture_rect_region(texture, Rect2(float(layer.x)+float(tile.get("offset_x", 0)), float(layer.y)+float(tile.get("offset_y", 0)), float(tile.w), float(tile.h)), Rect2(float(tile.get("sx", 0)), float(tile.get("sy", 0)), float(tile.w), float(tile.h)))
		elif object.has("base"):
			var b=object.base
			depth_bases.append(b)
			var pct=int(b.hp/b.hpmax*100)
			var state="Idle-%d" % (int(ceil(pct/20.0))*20)
			# Original map registration places the base body in this depth
			# pass. Its visible center is independent of its depth override.
			sprite("bases/base"+str(b.type),state,b.pos)
		elif object.has("tower"):
			var t = object.tower
			var set_name = "towers/"+str(t.def.filename)
			var presentation = Content.tower_presentation(t.def, t.angle, sim.clock_ms-int(t.get("born_ms", 0)))
			if int(t.type) == 5 and t.has("animation"):
				var state = Content.animations[set_name].states.get(t.animation, {})
				var count = state.get("resolved_frames", []).size()
				var frame = int(maxi(0, sim.clock_ms-int(t.animation_ms))*float(state.get("speed", 1))/1000.0)
				if t.animation == "Close" and frame >= count: presentation = {"state": "Idle", "frame": 0}
				else: presentation = {"state": t.animation, "frame": mini(frame, maxi(0, count-1))}
			var position = t.pos+Vector2(0, -7)
			for foundation in Content.tower_foundation(str(sim.map.theme), t.cell, sim.clock_ms-int(t.get("foundation_ms", 0))):
				sprite(foundation.name, "Building", position, foundation.frame, "", Color(1, 1, 1, foundation.alpha))
			extra_sprite(set_name, "pad1", position)
			var animation=owned_animation(t,"body",set_name,presentation.state) if bool(Content.animations[set_name].states.get(presentation.state,{}).get("alpha_between_frame",false)) else {}
			sprite(set_name,presentation.state,position,presentation.frame,"",Color.WHITE,0,Vector2.ONE,animation)
			if int(t.type)==5 and t.get("animation","")=="Open":sprite("towers/nuke_lights","Blinking",position,0,"",Color.WHITE,0,Vector2.ONE,owned_animation(t,"nuke-lights","towers/nuke_lights","Blinking"))
		elif object.has("mine"):
			draw_mine_object(object.mine,object.preview)
		else:
			draw_creep_body(object.enemy,scale,enemy_projectiles.body.get(int(object.enemy.id),[]))
	if probe_placement_order:placement_draw_trace.append("ground-bodies")
	# CMap::DrawTowerOvalSelection0x10406c follows all ground bodies.
	var selection=selected_range_pose()
	if not selection.is_empty():BuildHexView.draw_oval(self,selection.position,selection.draws,1.0/scale)
	if probe_placement_order:placement_draw_trace.append("selection")
	draw_placement_phase()
	if probe_placement_order:placement_draw_trace.append("air-manager")
	for missile in enemy_projectiles.before_air:draw_enemy_missile(missile,scale)
	# Native air bodies follow every ground/map body, independent of Y.
	for air in battle_air_objects():draw_creep_body(air,scale,enemy_projectiles.body.get(int(air.id),[]))
	# CBase::RenderAfter0x76c48 paints health after the sorted body pass.
	# Full map/owner/air interleaving remains separately unresolved.
	for b in depth_bases:
		if b.hp>=b.hpmax:continue
		var params=Content.animations["bases/base"+str(b.type)].get("params",{})
		if b.hp<=0 and bool(params.get("hide_hp_bar_on_dead",false)):continue
		var frame=Content.frame("bases/base"+str(b.type),"Idle-100")
		var offset=params.get("hp_bar_offset",[0,0])
		var origin=b.pos+Vector2(-5,-frame.canvas_size.y/2.0-15)+Vector2(offset[0],offset[1])
		ClassicUI.region(self,Rect2(130,313,32,4),Rect2(origin,Vector2(32,4)))
		var width=32*maxf(0,b.hp)/b.hpmax
		if width>0:ClassicUI.region(self,Rect2(97,313,width,4),Rect2(origin,Vector2(width,4)))
	for bubble in sim.bubbles:
		if not bubble.active: continue
		var texture = Content.tex("assets/sfx/goo_bubble.png" if int(bubble.type) == 8 else "assets/sfx/poison_bubble.png")
		var size = float(bubble.size)
		draw_texture_rect_region(texture, Rect2(bubble.shadow-Vector2(10, 8), Vector2(20, 16)), Rect2(66, 27, 20, 16), Color(1, 1, 1, bubble.alpha))
		draw_texture_rect_region(texture, Rect2(bubble.pos-Vector2.ONE*size/2.0, Vector2.ONE*size), Rect2(0, 0, 64, 64), Color(1, 1, 1, bubble.alpha))
	for missile in sim.missiles:
		if not missile.get("active", true): continue
		var set_name = "towers/"+str(missile.def.filename)
		var is_nuke = int(missile.type) == 5
		draw_set_transform(map_origin()+missile.pos*scale, 0.0 if is_nuke else deg_to_rad(float(missile.angle)-90.0), Vector2.ONE*scale)
		extra_sprite(set_name, "missile2" if is_nuke and missile.up >= 1.0 else "missile", Vector2.ZERO, "", Vector2.ONE*float(missile.scale), Color(1, 1, 1, missile.alpha))
		draw_set_transform(map_origin(), 0, Vector2.ONE*scale)
	for missile in enemy_projectiles.ground_after:draw_enemy_missile(missile,scale)
	for effect in effects:
		var remaining = float(effect.until-sim.clock_ms)
		if effect.kind == "shot":
			continue
		elif effect.kind == "flash":
			var point=effect.from+Vector2(0,-7)
			var direction=(effect.to-point).normalized()
			var params=Content.animations.get("towers/"+str(effect.filename),{}).get("params",{})
			point+=direction*float(params.get("shoot_offset_len",10))
			draw_set_transform(map_origin()+point*scale,direction.angle()+PI/2,Vector2.ONE*scale)
			sprite("towers/tower_fire","Fire-1" if int(effect.born/30)%2 else "Fire-2",Vector2.ZERO)
			draw_set_transform(map_origin(),0,Vector2.ONE*scale)
		else:
			if int(effect.get("type", 0)) == 5:
				sprite("towers/nuke_explosion", "Explosion", effect.pos, mini(19, int((sim.clock_ms-int(effect.born))*15/1000)), "", Color.WHITE, 0, Vector2.ONE*2.0)
			else: sprite("sfx/mine_explosion", "Explosion", effect.pos, int((600.0-remaining)/45.0), "", Color(1, 1, 1, clampf(remaining/300.0, 0, 1)))
	draw_set_transform(Vector2.ZERO)
	ClassicUI.draw_tower_info(self)

# CMap::Render0x104088: preview hexes, then grid, inactive tower, air.
func draw_placement_phase() -> void:
	if build_type > 0:
		var cell = sim.nearest(mouse_world(tower_drag_position if tower_drag else get_global_mouse_position()))
		var pos = sim.center(cell.x, cell.y)
		var def = sim.tower_data(build_type, 1)
		var okay = sim.buildable(cell) and sim.tower_at(cell).is_empty() and sim.money>=floor(float(def.price)) and sim.can_unlock(def)
		var range_value=float(def.get("range",0));var spacing=BuildHexView.f32(float(sim.map.hex_h)/1000)
		BuildHexView.draw_oval(self,pos,BuildHexView.oval(1,spacing,range_value,0),1.0/map_scale())
		var shape=build_hex_view.prepare(sim,cell,pos,BuildHexView.f32(BuildHexView.f32(range_value*spacing)*2),okay)
		BuildHexView.draw(self,shape,1.0/map_scale())
		if probe_placement_order:placement_draw_trace.append("preview-hexes")
	if not magic_placement.is_empty():
		var position=mouse_world(magic_preview_position)
		var cell=sim.nearest(position)
		var valid=sim.ability_error(magic_placement,position).is_empty()
		BuildHexView.draw(self,build_hex_view.prepare(sim,cell,position,70,valid),1.0/map_scale())
		if probe_placement_order:placement_draw_trace.append("preview-hexes")
	if show_grid:
		for y in range(int(sim.map.hex_height)):
			for x in range(int(sim.map.hex_width)):
				if sim.buildable(Vector2i(x, y)):
					draw_hex(sim.center(x, y), Color(0.05, 0.1, 0.05, 0.28))
		if probe_placement_order:placement_draw_trace.append("grid")
	if build_type>0:
		var cell=sim.nearest(mouse_world(tower_drag_position if tower_drag else get_global_mouse_position()))
		var pos=sim.center(cell.x,cell.y)
		var def=sim.tower_data(build_type,1)
		var okay=sim.buildable(cell) and sim.tower_at(cell).is_empty() and sim.money>=floor(float(def.price)) and sim.can_unlock(def)
		var tint=TowerPreview.tint(okay)
		extra_sprite("towers/"+str(def.filename),"pad1",pos+Vector2(0,-7),"",Vector2.ONE,tint)
		sprite("towers/"+str(def.filename),tower_preview_animation,pos,int(tower_preview_state.get("frame",0)),"",tint,-7)
		# RenderInActive retains the last rendered Rot frame*9 when activated.
		if tower_preview_animation=="Rot":tower_preview_facing=float(tower_preview_state.get("frame",0))*9
		if probe_placement_order:placement_draw_trace.append("tower-preview")

func creep_layers(e:Dictionary,states:Dictionary) -> Array:
	if not reference_creep_layers and e.has("visual_layers"):
		if probe_creep_layers:creep_layer_usage.cached+=1
		return e.visual_layers
	if probe_creep_layers:creep_layer_usage.reference+=1
	var state=sim.creep_animation(e)
	if not states.has(state):state="Idle" if states.has("Idle") else str(states.keys()[0])
	return e.get("visual_layers",[{"state":state,"rotation":0.0,"alpha":1.0,"born":e.born_ms}])

func creep_body_tint(e:Dictionary,alpha:float=1) -> Color:
	return CreepLight.body_color(uses_air_pass(e),float(e.get("draw_light",1)),alpha)

func creep_animator_position(e:Dictionary) -> Vector2:
	var position:Vector2=e.get("visual_pos",e.pos)
	var offset=e.def.traits.get("offset",[0,0])
	return position+Vector2(offset[0],offset[1])+Vector2(0,-30 if sim.clock_ms<e.float_until else 0)

func creep_health_layout(e:Dictionary) -> Dictionary:
	return preload("res://scripts/creep_health_view.gd").layout(creep_animator_position(e),float(e.hp),int(e.max_hp),float(sim.spawn_presentation(e).alpha),int(e.get("state",0)))

func draw_creep_body(e:Dictionary,scale:float,owner_missiles:Array=[]) -> void:
	var position: Vector2 = e.get("visual_pos", e.pos)
	var set_name = "creeps/"+str(e.def.filename)
	var states = Content.animations.get(set_name, {}).get("states", {})
	var growth = sim.spawn_presentation(e)
	var tint=creep_body_tint(e,growth.alpha)
	var scale_values = e.def.traits.get("scale", [1, 1])
	var native_scale = Vector2(scale_values[0], scale_values[1])*growth.scale
	if growth.has("native_scale"):native_scale=growth.native_scale
	var animator_position=creep_animator_position(e)
	var layers=creep_layers(e,states)
	var body_clocks=[creep_owned_animation(e,0,layers[0],states),{}]
	if layers.size()>1 and float(layers[1].alpha)!=0:body_clocks[1]=creep_owned_animation(e,1,layers[1],states)
	creep_shadow(e,set_name,position,layers[0],growth,native_scale.x,scale,int(body_clocks[0].get("frame",0)))
	for index in layers.size():
		var layer=layers[index]
		if float(layer.alpha)<=0:continue
		var animation=body_clocks[index]
		var layer_frame=int(animation.get("frame",0))
		var color = tint
		color.a *= float(layer.alpha)
		draw_set_transform(map_origin()+animator_position*scale, deg_to_rad(float(layer.rotation)), Vector2.ONE*scale)
		sprite(set_name,layer.state,Vector2.ZERO,layer_frame,str(e.def.get("color","")),color,0,native_scale,animation)
		draw_set_transform(map_origin(), 0, Vector2.ONE*scale)
	if CreepStatus.active(int(e.get("state",0)),int(e.get("freeze_remaining",0)),float(e.get("slow_pending",-1))):
		var coefficient=CreepStatus.coefficient(float(e.get("draw_light",1)))
		for index in CreepStatus.layers(layers).size():
			var layer=layers[index]
			var frame=int(body_clocks[index].get("frame",0))
			var image=Content.frame(set_name,layer.state,frame,str(e.def.get("color","")),true)
			if image.is_empty():continue
			var texture:Texture2D=image.texture
			draw_set_transform(map_origin()+animator_position*scale,deg_to_rad(float(layer.rotation)),Vector2.ONE*scale)
			# LCD's white CONSTANT_COLOR and ONE_MINUS_SRC_COLOR implement
			# the source screen blend per command, between this body and HP.
			CreepStatus.draw(self,texture,Rect2((-texture.get_size()/2+image.offset)*native_scale,texture.get_size()*native_scale),coefficient)
			draw_set_transform(map_origin(),0,Vector2.ONE*scale)
	# Original full Render routes flag+a0 after this owner's body, before HP.
	for missile in owner_missiles:draw_enemy_missile(missile,scale)
	var health=creep_health_layout(e) if float(e.hp)<int(e.max_hp) else {}
	if not health.is_empty():
		draw_texture(Content.tex("assets/creeps/life_bar_red.png"),health.origin,health.color)
		if health.fill.size.x>0:draw_texture_rect_region(Content.tex("assets/creeps/life_bar_green.png"),health.fill,health.source,health.color)

func draw_battle_overlays(canvas: CanvasItem) -> void:
	if screen != "game" or sim == null:return
	var size=view_size()
	if sim.paused or sim.outcome != "playing":
		var alpha=float(result_clock.get("alpha",0)) if sim.outcome!="playing" else 1.0
		canvas.draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,alpha/3.0 if sim.outcome!="playing" else 0.5))
		if sim.outcome!="playing":
			var origin=results_origin()
			var prefix="win_screen" if sim.outcome=="victory" else "loose_screen"
			for piece in [[prefix+"_1",Vector2.ZERO,Vector2(512,512)],[prefix+"_2",Vector2(512,0),Vector2(128,512)],[prefix+"_3",Vector2(640,0),Vector2(8,64)],["final_screen_shadow_1",Vector2(0,512),Vector2(512,64)],["final_screen_shadow_2",Vector2(512,512),Vector2(128,64)]]:
				var texture=Content.tex("assets/gui/"+str(piece[0])+".png")
				if texture!=null:canvas.draw_texture_rect(texture,Rect2(origin+piece[1],piece[2]),false,Color(1,1,1,alpha))
			ClassicUI.result_bar(self,canvas)
			update_xp_emission_from_render()
		else:canvas.draw_texture_rect(Content.tex("assets/gui/pause_menu_bg.png"),Rect2(0,floor((size.y-199)/2),size.x,199),false)
	TutorialView.draw_phase(self,canvas,"screen")

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
	if transition!=null and transition.phase!=3:
		get_viewport().set_input_as_handled()
		return
	if not pending_abandon.is_empty():
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:question_closing=true
		get_viewport().set_input_as_handled();return
	if promotion_open and not promotions.is_empty():
		if (event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_ENTER]) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			dismiss_promotion()
			get_viewport().set_input_as_handled()
		return
	if quit_pending:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: quit_pending = false; refresh_controls()
		return
	if screen=="game" and magic_panel_state.visible and not magic_panel_state.hidden and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		var panel_rect=Rect2(Vector2(view_size().x/2-158,magic_panel_state.y),Vector2(392,int(magic_panel_state.height)-20))
		if not panel_rect.has_point(event.position):
			set_magic_inventory(false);dragging=false;get_viewport().set_input_as_handled();return
	if pending_sale >= 0:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: cancel_sale(); return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE: cancel_sale()
			elif event.keycode == KEY_F11: set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if test_session and "--qa-intro" in OS.get_cmdline_user_args() and event.keycode == KEY_F9:
			show_startup()
		elif event.keycode == KEY_F11:
			set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif screen == "game":
			if event.keycode == KEY_SPACE: toggle_pause()
			elif event.keycode == KEY_N and str(sim.config.configid) != "1": request_wave_launch()
			elif event.keycode == KEY_G: show_grid = not show_grid
			elif event.keycode >= KEY_1 and event.keycode <= KEY_6: select_build(Simulation.ROOT_TYPES[event.keycode-KEY_1])
			elif event.keycode == KEY_ESCAPE:
				if not pending_technology.is_empty(): pending_technology.clear(); refresh_controls(); return
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
			pending_technology.clear()
			build_type = 0
			magic_placement = ""
			if sim != null: sim.cancel_portal_placement()
			if screen == "world":close_mode_fan()
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
	if screen == "world":world_camera -= delta/world_zoom;bound_world_camera()
	elif sim != null:
		camera -= delta/map_scale()
		bound_camera()
	if screen == "game" and (tutorial != null or selected_tower >= 0): refresh_controls()

func set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	Profile.data.settings.fullscreen = enabled
	if not test_session and not Profile.save_profile(): message("The window preference could not be saved.")
	refresh_controls()

func zoom_at(pos: Vector2, factor: float) -> void:
	if screen == "world":
		var before = (pos-world_origin())/world_zoom
		world_zoom = clampf(world_zoom*factor, 0.25, 1.0)
		world_camera += before-(pos-world_origin())/world_zoom
		bound_world_camera()
	elif sim != null:
		var before = mouse_world(pos)
		zoom = clampf(zoom*factor, 0.55, 2.6)
		camera += before-mouse_world(pos)
		bound_camera()
	if screen == "game" and (tutorial != null or selected_tower >= 0): refresh_controls()

func close_mode_fan() -> void:
	if selected_location.is_empty() or fan_closing:return
	if selected_location=="1000":selected_location="";refresh_controls();return
	# Close0x87994 changes the parent to closing; Update0x8a2a8 resets
	# each open item once. Keep the location until the700ms parent ends.
	fan_closing=true;fan_close_phase=0.0
	for state in mode_states.values():state.opened=false;state.phase=0.0;state.text_phase=0.0
	sound("menu_options_fly_in")
	ClassicUI.update_modes(self)

func advance_mode_fan(dt_ms:float) -> void:
	ClassicUI.update_modes(self,dt_ms)
	if not fan_closing:return
	fan_close_phase=MagicPanelView.f32(fan_close_phase+MagicPanelView.f32(MagicPanelView.f32(dt_ms)/700.0))
	if MagicPanelView.slide_ease(1,0,fan_close_phase)<=0:
		selected_location="";fan_closing=false;refresh_controls()

func click_map(pos: Vector2, silent_rejection:bool=false) -> void:
	if screen == "world":
		if not selected_location.is_empty():
			close_mode_fan();return
		for loc in Content.catalog.tower_locations:
			if not location_visible(loc): continue
			var point = world_origin()+Vector2(float(loc.x), float(loc.y))*world_zoom
			if point.distance_to(pos) < 25:
				if guidance_type==3:dismiss_guidance()
				guidance_type=0
				selected_location = str(int(loc.id))
				fan_closing=false;fan_close_phase=0.0
				world_camera_from=world_camera
				world_camera_to=Vector2(float(loc.x),float(loc.y))-(Vector2(360,384)-view_center())/world_zoom
				fan_opened=elapsed_ui
				sound("menu_options_fly_out")
				refresh_controls()
				return
	elif screen == "game" and not sim.paused and sim.outcome == "playing":
		if pending_sale >= 0: return
		if not pending_technology.is_empty(): pending_technology.clear()
		if tutorial != null and tutorial.page in [0, 1, 2]: acknowledge_tutorial(); return
		var world = mouse_world(pos)
		if not magic_placement.is_empty():
			magic_preview_position=pos
			if str(sim.config.configid) == "1" and sim.nearest(world) != Vector2i(7, 6): message("Place a mine here, cadet."); return
			var result = activate_magic(magic_placement, world)
			build_hex_view.reset()
			if result=="Choose the portal exit.":notice_until=0
			else:message(result)
			if result.is_empty():
				magic_placement = ""
				update_tutorial()
		elif build_type > 0:
			var cell = sim.nearest(world)
			if tutorial != null and (not tutorial.build_allowed(build_type) or cell not in TUTORIAL_CELLS):
				if not silent_rejection:message("You are not supposed to do that in the training area!")
			else:
				var result=sim.build(cell,build_type)
				if result.is_empty():
					sim.tower_at(cell).angle=tower_preview_facing
					reset_tower_preview(build_type)
				if not silent_rejection:message(result)
		else:
			var t = sim.tower_at(sim.nearest(world))
			if int(t.get("id",-1))!=selected_tower:tower_panel_close_at=-1.0
			selected_tower = int(t.get("id", -1))
		update_tutorial()
		refresh_controls()
