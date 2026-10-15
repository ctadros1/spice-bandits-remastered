extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var rows: Array[Dictionary] = []
var source_hashes = {}
const SOURCES = ["res://scripts/simulation.gd", "res://scripts/creep_view.gd", "res://data/catalog.json", "res://data/maps.json", "res://data/animations.json"]

func _initialize() -> void:
	run.call_deferred()

func write_report(path: String, complete: bool) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "complete": complete,
		"method": "Passive battles with no towers or magic. Tutorial instructional wave transitions manually bypassed when a wave clears. Original schedules and starting bases; not a victory campaign or fresh-profile progression traversal.",
		"source_hashes_before": source_hashes, "source_hashes_after": hashes(), "resources_unchanged": source_hashes == hashes(),
		"seed": 114, "simulation_limit_ms": 900000, "configurations": rows}, "\t"))
	file.close()

func hashes() -> Dictionary:
	var result = {}
	for path in SOURCES: result[path] = FileAccess.get_sha256(path)
	return result

func run() -> void:
	await process_frame
	var content = root.get_node("Content")
	var profile = root.get_node("Profile")
	source_hashes = hashes()
	for mission in content.catalog.offlineConfigs:
		if mission.waves.is_empty(): continue
		var sim = Simulation.new()
		sim.setup(content.catalog, content.maps[mission.map], mission, profile.fresh(), 114, content.animations)
		if str(mission.configid) == "1":
			sim.spawn_hold = false
			sim.tutorial_finished = true
			sim.next_wave_ms = 0
		var peak_enemies = 0
		var event_counts = {}
		while sim.outcome == "playing" and sim.clock_ms < 900000:
			sim.advance(300)
			peak_enemies = maxi(peak_enemies, sim.enemies.size())
			for event in sim.events: event_counts[event.kind] = int(event_counts.get(event.kind, 0))+1
			sim.events.clear()
			if str(mission.configid) == "1" and sim.outcome == "playing" and sim.running_waves.is_empty() and sim.enemies.is_empty() and sim.wave_index < mission.waves.size(): sim.next_wave(false)
		var health = []
		for base in sim.bases: health.append(base.hp/base.hpmax)
		rows.append({"config": mission.configid, "map": mission.map, "mode": mission.gametype,
			"outcome": sim.outcome, "ms": sim.clock_ms, "waves_started": sim.wave_index, "authored_waves": mission.waves.size(),
			"kills": sim.kills, "base_health": health, "peak_live_enemies": peak_enemies, "events": event_counts,
			"static_mines": mission.settings.get("mines", []).size(), "static_portals": sim.static_portals.size(), "digest": sim.digest()})
		write_report("../builds/campaign-combat-progress.json", false)
		print("CAMPAIGN_COMBAT ", rows.size(), " config=", mission.configid, " ", sim.outcome, " ", sim.clock_ms)
		await process_frame
	write_report("../builds/campaign-combat-verification.json", true)
	print("CAMPAIGN_COMBAT_COMPLETE ", rows.size())
	quit(0 if rows.size() == 148 else 1)
