extends SceneTree
const Sim = preload("res://scripts/simulation.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	var content = root.get_node("Content")
	var profile = root.get_node("Profile")
	var choices = []
	var p = profile.fresh()
	p.unlocks = ["T1L3"]
	for row in range(5, 12):
		for col in range(10, 17):
			choices.append(Vector2i(col, row))
	for style in range(8):
		var s = Sim.new()
		var c = content.mission("8")
		s.setup(content.catalog, content.maps[c.map], c, p)
		var candidates = choices.duplicate()
		candidates.sort_custom(func(a,b):
			var target = Vector2i(15 if style%2==0 else 12, 8+int(style/4))
			return a.distance_squared_to(target)<b.distance_squared_to(target))
		var cells = []
		for cell in candidates:
			if cells.size() == 5: break
			if s.build(cell, 1).is_empty(): cells.append(cell)
		s.advance(1020)
		for t in s.towers: s.upgrade_tower(t.id, 1, 2)
		s.advance(1020)
		for t in s.towers: s.upgrade_tower(t.id, 1, 3)
		s.advance(1020)
		while s.outcome == "playing" and s.clock_ms < 900000:
			if s.enemies.is_empty() and s.running_waves.is_empty() and s.wave_index < s.config.waves.size(): s.next_wave()
			s.advance(300)
			s.events.clear()
		print("STRATEGY ", style, " ", cells, " ", s.outcome, " kills=", s.kills, " hp=", s.base_fraction(), " ms=", s.clock_ms)
	quit()
