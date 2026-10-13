extends Node

const VERSION = 1
var data: Dictionary = {}
var path = "user://profile.json"
var recovery_message = ""
var read_only = false

func _ready() -> void:
	if "--qa" in OS.get_cmdline_user_args(): path = "user://qa/profile.json"
	load_profile()

func fresh() -> Dictionary:
	return {"version": VERSION, "name": "Offliner", "spice": 0, "xp": 0.0, "level": 1,
		"specpoints": 0, "unlocks": [], "upgrades": {}, "abilities": {"m_freeze": 5, "m_lsd": 5, "m_actdef": 5, "m_mine": 0, "m_portal": 0},
		"completed": {}, "medals": [], "stats": {"kills": 0, "wins": 0, "towers": 0}, "dress": {"s1": 0, "s2": 0},
		"settings": {"music": true, "sound": true, "fullscreen": false}, "transactions": []}

func _decode(file: String) -> Dictionary:
	if not FileAccess.file_exists(file): return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file)) != OK: return {}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.has("payload") or not envelope.has("sha256"): return {}
	if not envelope.payload is String or envelope.payload.sha256_text() != envelope.sha256: return {}
	var value = JSON.parse_string(envelope.payload)
	if not value is Dictionary or value.get("version", 0) != VERSION: return {}
	# Validate before applying. A valid hash is not enough to trust an external save.
	for key in fresh():
		if not value.has(key) or typeof(value[key]) != typeof(fresh()[key]):
			if key in ["spice", "level", "specpoints", "version"] and value.get(key) is float: continue
			return {}
	if float(value.spice) < 0 or float(value.xp) < 0 or int(value.level) < 1: return {}
	return value

func load_profile() -> void:
	read_only = false
	data = _decode(path)
	if data.is_empty() and FileAccess.file_exists(path):
		var envelope = JSON.new()
		if envelope.parse(FileAccess.get_file_as_string(path)) == OK and envelope.data is Dictionary:
			var saved = JSON.parse_string(str(envelope.data.get("payload", "{}")))
			if saved is Dictionary and int(saved.get("version", 0)) > VERSION:
				read_only = true
				data = fresh()
				recovery_message = "This profile was saved by a newer version. Saving is disabled to preserve it."
				return
		var retained = path + ".corrupt-" + str(Time.get_unix_time_from_system())
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(retained))
		data = _decode(path + ".bak")
		recovery_message = "Recovered the backup profile." if not data.is_empty() else "The saved profile could not be read; a fresh profile is in use."
	if data.is_empty(): data = fresh()

func save_profile() -> bool:
	if read_only: return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var payload = JSON.stringify(data)
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	file.close()
	if _decode(path + ".tmp").is_empty(): return false
	# Do not replace a good backup with a damaged primary.
	if not _decode(path).is_empty():
		var error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
		if error != OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func unlocked(token: String) -> bool:
	return token.is_empty() or token in data.unlocks

func available(c: Dictionary) -> bool:
	return unlocked(str(c.get("needsunlock", "")))

func purchase(item: Dictionary) -> String:
	if int(item.levellock) > int(data.level): return "Reach level %s first." % item.levellock
	if not unlocked(str(item.needsunlock)): return "Unlock %s first." % item.needsunlock
	if not str(item.unlockstring).is_empty() and unlocked(item.unlockstring): return "Already unlocked."
	var cost = int(item.pricespice)
	if int(data.spice) < cost: return "You need %d more spice." % (cost - int(data.spice))
	var before = data.duplicate(true)
	data.spice -= cost
	if int(item.itemtype) == 0:
		data.abilities[item.tag] = int(data.abilities.get(item.tag, 0)) + int(item.consumableamount)
	else: data.unlocks.append(str(item.unlockstring))
	data.transactions.append({"kind": "shop", "id": item.shopitemid, "spice": -cost})
	if not save_profile():
		data = before
		return "The purchase could not be saved."
	return "Purchased %s." % item.itemname

func upgrade(key: String) -> String:
	var definition = Content.catalog.tower_upgrades[key]
	var level = int(data.upgrades.get(key, 0))
	if key == "up_friends": return "Friend Power depended on the original online service."
	if int(data.level) < int(definition.level): return "Reach level %s first." % definition.level
	if level >= 10: return "Maximum level."
	var cost = int(Content.catalog.tower_upgrade_costs[str(level + 1)])
	if int(data.specpoints) < cost: return "You need %d upgrade points." % cost
	var before = data.duplicate(true)
	data.specpoints -= cost
	data.upgrades[key] = level + 1
	if not save_profile():
		data = before
		return "The upgrade could not be saved."
	return "%s upgraded." % definition.name

func exchange_points() -> String:
	var offer = Content.catalog.tower_pu_exchange
	if int(data.spice) < int(offer.spice_cost): return "You need %d spice." % int(offer.spice_cost)
	var before = data.duplicate(true)
	data.spice -= int(offer.spice_cost)
	data.specpoints += int(offer.pu_award)
	data.transactions.append({"kind": "point-exchange", "spice": -int(offer.spice_cost), "points": int(offer.pu_award)})
	if not save_profile(): data = before; return "The exchange could not be saved."
	return "Added %d upgrade points." % int(offer.pu_award)

func settle(sim) -> bool:
	var before = data.duplicate(true)
	var id = str(sim.config.configid)
	var first = not data.completed.has(id)
	# The original awards a single perfect-game star, not a three-star rating.
	var stars = 1 if sim.perfect_game() else 0
	if sim.outcome == "victory":
		data.completed[id] = maxi(stars, int(data.completed.get(id, 0)))
		data.spice += int(Content.catalog.tower_rewards.sp_first if first else Content.catalog.tower_rewards.sp_other)
		var token = str(sim.config.get("grantsunlock", ""))
		if not token.is_empty() and token not in data.unlocks: data.unlocks.append(token)
		data.stats.wins += 1
		var modes = {"1": "won_games_normal", "3": "won_games_sd", "6": "won_games_air"}
		var key = modes.get(str(sim.config.gametype), "")
		if not key.is_empty(): data.stats[key] = int(data.stats.get(key, 0))+1
	var earned = float(sim.score) / 10.0
	earned *= 1.0 + float(data.upgrades.get("up_career", 0)) * 0.01
	data.xp += earned
	data.stats.kills += sim.kills
	award_global_medals()
	data.transactions.append({"kind": sim.outcome, "config": id, "score": sim.score, "stars": stars, "first": first})
	if not save_profile():
		data = before
		return false
	return true

func level_threshold(level: int) -> float:
	return 10.0 * float(level * level)

func consume_magic(key: String) -> bool:
	var before = data.duplicate(true)
	var stock = int(data.abilities.get(key, 0))
	if stock <= 0: return false
	data.abilities[key] = stock-1
	var stat = {"m_freeze": "use_freeze", "m_lsd": "use_lsd", "m_actdef": "use_actdef", "m_mine": "use_mines", "m_portal": "use_teleport"}[key]
	data.stats[stat] = int(data.stats.get(stat, 0))+1
	data.stats.use_total_magic = int(data.stats.get("use_total_magic", 0))+1
	award_global_medals()
	data.transactions.append({"kind": "magic", "key": key})
	if not save_profile():
		data = before
		return false
	return true

func record_build(type: int) -> bool:
	var before = data.duplicate(true)
	var key = {1: "built_mg", 4: "built_missiles", 7: "built_acid", 10: "built_electricity", 13: "built_aa", 16: "built_support"}.get(type, "")
	data.stats.towers += 1
	if not key.is_empty(): data.stats[key] = int(data.stats.get(key, 0))+1
	award_global_medals()
	if not save_profile():
		data = before
		return false
	return true

func award_global_medals() -> void:
	for m in Content.catalog.tower_medals:
		if int(m.global) != 1 or m.image in data.medals: continue
		if int(data.stats.get(m.key, 0)) >= int(m.param):
			data.medals.append(m.image)
			data.xp += float(m.get("xp_award", 0))/10.0
	# Original level thresholds remain under investigation; this is a recorded local adaptation.
	while data.xp >= level_threshold(int(data.level)):
		data.level += 1
		data.specpoints += 1
