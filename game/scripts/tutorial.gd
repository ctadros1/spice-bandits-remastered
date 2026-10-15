extends RefCounted

# CTutorialInterface::SwitchPage 0xb31c8 and Page*_EndCondition 0xb7ed8..
# 0xb90d8. UI layout/camera easing remain a separate presentation audit.
const CELLS = [Vector2i(7, 4), Vector2i(6, 7), Vector2i(8, 6), Vector2i(11, 3)]
const FIGHTING_CELLS = [Vector2i(7, 4), Vector2i(6, 7), Vector2i(8, 6)]
const Fade=preload("res://scripts/tutorial_fade.gd")
const PROMPTS = [
	"Welcome to the camp, cadet! You build defensive towers, and they do the shooting.\n\nTap anywhere to continue...",
	"It's your base. Don't let humans destroy it!\n\nEnemies appear from here.",
	"Speed controls the upcoming waves\n\nYour money, spice and XP information",
	"Now build 4 minigun towers in the designated locations.",
	"Great job. Now you can see the earthlings appearing. They are walking to face their fate. Haha!",
	"Every time you kill an earthling you get some money.\n\nYou can spend money to build new towers or upgrade the existing ones.",
	"You can upgrade or sell your towers.\n\nLet's upgrade our towers!",
	"And here please.\n\nTap to upgrade.",
	"Great. Now upgrade the other towers.",
	"That tower never fired a round. Let's sell it and get a part of the money back.",
	"You can also sell the tower. Try it!",
	"Confirm it",
	"You are doing really well, rookie.\n\nLet's apply Disco Magic to these humans. It will disorient them.",
	"",
	"Sweet, isn't it?\n\nNow let's try Active Defense.\n\nAll towers will be damaging all enemies in their range with electricity.",
	"",
	"There's more to magic. If you don't want an enemy to pass somewhere, place a mine.\n\nLet's place a mine on the way to our base.",
	""
]
var page = 0
var display_page=0
var fade_state=Fade.initial()
var transition_pending=false
var hint_visible = true
var marine101_dead = false
var wait_started = 0.0
var history: Array[int] = [0]

func acknowledge() -> void:
	if transition_pending:return
	if page in [0, 1, 2]:
		page += 1
		history.append(page)
		transition_pending=true
	else: hint_visible = false

func wave_pending(sim: BanditSimulation, index: int) -> bool:
	if sim.wave_index <= index: return true
	for running in sim.running_waves:
		if int(running.index) == index: return true
	return false

func wave_clear(sim: BanditSimulation, index: int) -> bool:
	return not wave_pending(sim, index) and sim.enemies.is_empty()

func enter(value: int, sim: BanditSimulation, real_seconds: float) -> void:
	page = value
	history.append(page)
	transition_pending=true

func activate_page(sim:BanditSimulation,real_seconds:float) -> void:
	# Wait pages13/15 only clear the magic highlight. The native controller
	# leaves the preceding portrait on screen until dismissed or replaced.
	if page not in [13,15]:hint_visible = not PROMPTS[page].is_empty()
	if page == 4 or page == 12 or page == 17:
		sim.spawn_hold = false
		sim.next_wave(false)
	if page == 5 or page == 16: sim.spawn_hold = true
	if page == 12: sim.build_overrides[sim.cell_index(Vector2i(11, 3))] = 0
	if page == 13: wait_started = real_seconds
	if page == 16: sim.build_overrides[sim.cell_index(Vector2i(7, 6))] = 1
	if page == 17: sim.tutorial_finished = true

func advance_ui(dt_ms:float,sim:BanditSimulation,selected_id:int,pending_sale:int,real_seconds:float) -> bool:
	# CRoom::Update0xd2768 skips the tutorial while its single-player pause
	# screen is open. Do not consume a pending page or its wave launch.
	if sim.paused:return false
	var before=page;var before_display=display_page
	Fade.advance_in(fade_state,dt_ms)
	observe(sim,selected_id,pending_sale,real_seconds)
	if transition_pending and Fade.advance_out(fade_state):
		display_page=page;transition_pending=false;fade_state=Fade.initial()
		activate_page(sim,real_seconds)
	return page!=before or display_page!=before_display

func pose(value:int) -> void:
	# Explicit presentation fixture, without a page's battle side effects.
	page=value;display_page=value;transition_pending=false
	fade_state={"alpha":1.0,"previous_ms":0.0,"opaque":true}

func observe(sim: BanditSimulation, selected_id: int, pending_sale: int, real_seconds: float) -> bool:
	if sim.paused:return false
	var before = page
	for event in sim.events:
		if event.kind == "kill" and int(event.id) == 101: marine101_dead = true
	if transition_pending:return false
	var selected = sim.find_tower(selected_id)
	var first = sim.tower_at(Vector2i(8, 6))
	match page:
		3:
			var built = true
			for cell in CELLS: built = built and not sim.tower_at(cell).is_empty()
			if built: enter(4, sim, real_seconds)
		4:
			if marine101_dead or wave_clear(sim, 0): enter(5, sim, real_seconds)
		5:
			if wave_clear(sim, 0): enter(6, sim, real_seconds)
		6:
			if not selected.is_empty() and selected.cell == Vector2i(8, 6): enter(7, sim, real_seconds)
			if not first.is_empty() and int(first.level) > 1: enter(8, sim, real_seconds)
		7:
			if selected.is_empty() or selected.cell != Vector2i(8, 6): enter(6, sim, real_seconds)
			if not first.is_empty() and int(first.level) > 1: enter(8, sim, real_seconds)
		8:
			var upgraded = true
			for cell in FIGHTING_CELLS:
				var tower = sim.tower_at(cell)
				upgraded = upgraded and not tower.is_empty() and int(tower.level) > 1
			if upgraded: enter(9, sim, real_seconds)
		9:
			if not selected.is_empty() and selected.cell == Vector2i(11, 3): enter(10, sim, real_seconds)
		10:
			if pending_sale >= 0: enter(11, sim, real_seconds)
			elif selected.is_empty() or selected.cell != Vector2i(11, 3): enter(9, sim, real_seconds)
		11:
			if sim.tower_at(Vector2i(11, 3)).is_empty(): enter(12, sim, real_seconds)
			elif pending_sale < 0: enter(9, sim, real_seconds)
		12:
			if wave_clear(sim, 1): enter(16, sim, real_seconds)
			elif sim.clock_ms < sim.disco_until: enter(13, sim, real_seconds)
		13:
			if wave_clear(sim, 1): enter(16, sim, real_seconds)
			elif real_seconds-wait_started >= 3.0: enter(14, sim, real_seconds)
		14:
			if wave_clear(sim, 1): enter(16, sim, real_seconds)
			elif sim.clock_ms < sim.defense_until: enter(15, sim, real_seconds)
		15:
			if wave_clear(sim, 1): enter(16, sim, real_seconds)
		16:
			for mine in sim.mines:
				# Native tests placement/active byte0x40, not the arming timer.
				if mine.cell == Vector2i(7, 6): enter(17, sim, real_seconds); break
	return before != page

func build_allowed(type: int) -> bool:
	return page in [2, 3] and type == 1

func magic_allowed(key: String) -> bool:
	return (page == 12 and key == "m_lsd") or (page == 14 and key == "m_actdef") or (page == 16 and key == "m_mine")

func markers(sim: BanditSimulation) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if display_page == 3:
		for cell in CELLS:
			if sim.tower_at(cell).is_empty(): cells.append(cell)
	elif display_page in [6, 7]: cells.append(Vector2i(8, 6))
	elif display_page == 8:
		for cell in FIGHTING_CELLS:
			var tower = sim.tower_at(cell)
			if not tower.is_empty() and int(tower.level) < 2: cells.append(cell)
	elif display_page in [9, 10, 11]: cells.append(Vector2i(11, 3))
	elif display_page == 16: cells.append(Vector2i(7, 6))
	return cells
