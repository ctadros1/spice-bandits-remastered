extends Node

const VERSION = 1
const RECENT_TRANSACTIONS = 256
const COMPACT_TRANSACTIONS_AT = 1024
const Medals = preload("res://scripts/medals.gd")
var data: Dictionary = {}
var path = "user://profile.json"
var recovery_message = ""
var read_only = false
var verification_context = false

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	verification_context = Array(args).any(func(arg): return str(arg).begins_with("--qa")) or Array(OS.get_cmdline_args()).any(func(arg): return str(arg).ends_with("scripts/verify.gd") or str(arg).ends_with("scripts/ui_verify.gd"))
	if verification_context: path = "user://qa/profile.json"
	if "--qa" in OS.get_cmdline_user_args() and "--qa-persist-progress" in OS.get_cmdline_user_args(): path = "user://qa-progress/profile.json"
	if "--qa" in args and "--qa-input-rewards" in args:
		# Every native input run gets a new account. It may exercise real reward
		# transactions without resetting the retained earned campaign or normal save.
		path="user://verification/native-input/%d-%d/profile.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	load_profile()

func fresh() -> Dictionary:
	return {"version": VERSION, "name": "Cadet", "spice": 0, "xp": 0.0, "level": 1,
		"specpoints": 0, "unlocks": [], "upgrades": {}, "abilities": {"m_freeze": 0, "m_lsd": 0, "m_actdef": 0, "m_mine": 0, "m_portal": 0},
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
	if value.has("history_archives") and not value.history_archives is Array:return {}
	if value.has("history_head") and not value.history_head is String:return {}
	# JSON's decimal parser can return an adjacent f64 value even for a fully
	# printed f32. XP is a native float, so restore its actual storage precision.
	value.xp = f32(float(value.xp))
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
	# Enforce isolation at the write boundary, including a driver that loses
	# its --qa flag or mistakenly restores the normal path after a fixture.
	if verification_context and path == "user://profile.json": return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var candidate=data
	if data.transactions.size()>COMPACT_TRANSACTIONS_AT or data.has("history_archives"):
		var ordinary=0
		for row in data.transactions:
			if str(row.get("kind",""))!="promotion":ordinary+=1
		if ordinary>COMPACT_TRANSACTIONS_AT or data.has("history_archives"):
			# Preserve the entire valid pre-compaction state in a content-addressed
			# snapshot. Currency, unlocks and every promotion stay in the live save.
			var archive_payload=JSON.stringify(data,"",true,true)
			var archive_hash=archive_payload.sha256_text()
			var archive_dir=path+".history"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(archive_dir))
			var archive_path=archive_dir.path_join(archive_hash+".json")
			if not FileAccess.file_exists(archive_path):
				var archive=FileAccess.open(archive_path+".tmp",FileAccess.WRITE)
				if archive==null:return false
				archive.store_string(JSON.stringify({"payload":archive_payload,"sha256":archive_hash}));archive.flush();archive.close()
				if _decode(archive_path+".tmp").is_empty() or DirAccess.rename_absolute(ProjectSettings.globalize_path(archive_path+".tmp"),ProjectSettings.globalize_path(archive_path))!=OK:return false
			var archived_envelope=JSON.parse_string(FileAccess.get_file_as_string(archive_path))
			if not archived_envelope is Dictionary or str(archived_envelope.get("sha256",""))!=archive_hash or _decode(archive_path).is_empty():return false
			candidate=data.duplicate(true)
			var retained=[]
			var discard=ordinary-RECENT_TRANSACTIONS
			for row in data.transactions:
				if str(row.get("kind",""))=="promotion":retained.append(row)
				elif discard>0:discard-=1
				else:retained.append(row)
			candidate.transactions=retained
			# Each full snapshot already contains its preceding head. Keep one
			# reference in the live save instead of a growing list of every archive.
			candidate.history_head=archive_hash
			candidate.erase("history_archives")
	# Preserve the recovered f32 XP value exactly across relaunches. Godot's
	# default JSON formatting drops digits even when the value is representable.
	var payload = JSON.stringify(candidate, "", true, true)
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
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:return false
	data=candidate
	return true

func unlocked(token: String) -> bool:
	return preload("res://scripts/unlocks.gd").has_unlock(token, data.unlocks)

func available(c: Dictionary) -> bool:
	var owned = data.unlocks.duplicate()
	# Offline-only bridges for two preserved prerequisite defects. They are
	# virtual access tokens, never recorded as wins for an unavailable mission.
	#81 spells mo30_sd as30_sd;286 requires mo40_ao, whose mission is absent
	# from all preserved offline schedules. Use the same location's Normal win.
	if str(c.configid) == "81" and "mo30_sd" in owned: owned.append("30_sd")
	if str(c.configid) == "286" and "mo40_sp" in owned: owned.append("mo40_ao")
	return preload("res://scripts/unlocks.gd").has_unlock(str(c.get("needsunlock", "")), owned)

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
	data.transactions.append({"kind": "upgrade", "key": key, "level": level+1, "points": -cost})
	if not save_profile():
		data = before
		return "The upgrade could not be saved."
	return "%s upgraded." % definition.name

func refund_upgrade(key: String) -> String:
	if not Content.catalog.tower_upgrades.has(key): return "Unknown upgrade."
	var level = int(data.upgrades.get(key, 0))
	if level <= 0: return "No upgrade level to refund."
	if level > 10: return "This upgrade is outside the supported original range."
	# onMinusPress 0x67c60 returns NeedPointsForLevel(currentLevel-1).
	# Our local schema stores the interpreted level; original userData stores
	# cumulative allocated points before UpgradeLevel converts them to a level.
	var points = int(Content.catalog.tower_upgrade_costs[str(level)])
	var before = data.duplicate(true)
	data.upgrades[key] = level-1
	data.specpoints += points
	data.transactions.append({"kind": "upgrade-refund", "key": key, "level": level-1, "points": points})
	if not save_profile():
		data = before
		return "The refund could not be saved."
	return "Returned %d upgrade points." % points

func exchange_points() -> String:
	var offer = Content.catalog.tower_pu_exchange
	if int(data.spice) < int(offer.spice_cost): return "You need %d spice." % int(offer.spice_cost)
	var before = data.duplicate(true)
	data.spice -= int(offer.spice_cost)
	data.specpoints += int(offer.pu_award)
	data.transactions.append({"kind": "point-exchange", "spice": -int(offer.spice_cost), "points": int(offer.pu_award)})
	if not save_profile(): data = before; return "The exchange could not be saved."
	return "Added %d upgrade points." % int(offer.pu_award)

func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

func credit_battle_kills(rows: Array[Dictionary], config_id: String) -> bool:
	if rows.is_empty(): return true
	var before = data.duplicate(true)
	var score = 0.0
	for row in rows:
		var reward = float(row.reward)
		if reward > 0:
			# DoDamage calls addXP with the reward; addXP divides by10 and
			# stores NSNumber.float values after each addition.
			data.xp = f32(f32(float(data.xp))+f32(reward/10.0))
			score += reward
	if config_id != "1": data.stats.kills += rows.size()
	advance_levels()
	data.transactions.append({"kind": "battle-xp", "config": config_id, "score": score, "kills": rows.size()})
	if not save_profile(): data = before; return false
	return true

func settle(sim, credited_score: float = 0.0, credited_kills: int = 0, initial_xp: int = -1) -> bool:
	var before = data.duplicate(true)
	if initial_xp < 0: initial_xp = int(data.xp)
	var id = str(sim.config.configid)
	var first = not data.completed.has(id)
	# The original awards a single perfect-game star, not a three-star rating.
	var stars = 1 if sim.perfect_game() else 0
	if sim.outcome == "victory":
		data.completed[id] = maxi(stars, int(data.completed.get(id, 0)))
		data.spice += int(Content.catalog.tower_rewards.sp_first if first else Content.catalog.tower_rewards.sp_other)
		var token = str(sim.config.get("grantsunlock", ""))
		if not token.is_empty() and token not in data.unlocks: data.unlocks.append(token)
		if id != "1": data.stats.wins += 1
		var modes = {"1": "won_games_normal", "3": "won_games_sd", "6": "won_games_air"}
		var key = modes.get(str(sim.config.gametype), "")
		if id != "1" and not key.is_empty(): data.stats[key] = int(data.stats.get(key, 0))+1
	var earned = f32(maxf(0.0, float(sim.score)-credited_score)/10.0)
	data.xp = f32(f32(float(data.xp))+earned)
	if id != "1": data.stats.kills += maxi(0, sim.kills-credited_kills)
	var medal_score = award_battle_medals(sim)
	var career_score = 0
	if sim.outcome == "victory":
		# CRoom snapshots integer XP at0xc60f4. CWinLoseScreen 0xbcfee..
		# 0xbd062 truncates the gained XP, multiplies by the integer upgrade
		# product and f32(0.01), truncates, then calls addXP (divide10 again).
		var delta = maxi(0, int(f32(float(data.xp)-float(initial_xp))))
		var level = int(sim.upgrades.get("up_career", 0))
		var percent = int(Content.catalog.tower_upgrades.up_career.percent)
		career_score = int(f32(float(delta*level*percent)*0.009999999776482582))
		data.xp = f32(f32(float(data.xp))+f32(float(career_score)/10.0))
		advance_levels()
	data.transactions.append({"kind": sim.outcome, "config": id, "score": sim.score, "stars": stars, "first": first, "medal_score": medal_score, "career_score": career_score})
	if not save_profile():
		data = before
		return false
	return true

func level_threshold(level: int) -> float:
	# Main iPad footage670.5/691.5s shows level2 at31/55 total XP.
	# Only the first10 threshold is bundled; later levels remain a fallback.
	if level==2:return 55.0
	return 10.0 * float(level * level)

func career_progress() -> Dictionary:
	# CareerViewController::setInfoWithUserData0x29c00. These are rounded
	# percentages of owned tokens, rather than counts of visible missions.
	var development = 0
	if not data.unlocks.is_empty():
		var tokens = data.unlocks.filter(func(u): return str(u).begins_with("T")).size()
		development = mini(100, int(round(f32(f32(float(tokens+2)/54.0)*100.0))))
	var completed_locations = {}
	for c in Content.catalog.configs:
		var token = str(c.get("grantsunlock", ""))
		if not token.is_empty() and token in data.unlocks: completed_locations[str(c.location)] = true
	var denominator = maxi(1, Content.catalog.tower_locations.size()-4)
	var locations = clampi(int(round(f32(f32(float(completed_locations.size())/denominator)*100.0))), 0, 100)
	return {"towers": development, "locations": locations}

func consume_magic(key: String) -> bool:
	var before = data.duplicate(true)
	var stock = int(data.abilities.get(key, 0))
	if stock <= 0: return false
	data.abilities[key] = stock-1
	var stat = {"m_freeze": "use_freeze", "m_lsd": "use_lsd", "m_actdef": "use_actdef", "m_mine": "use_mines", "m_portal": "use_teleport"}[key]
	data.stats[stat] = int(data.stats.get(stat, 0))+1
	data.stats.use_total_magic = int(data.stats.get("use_total_magic", 0))+1
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
	if not save_profile():
		data = before
		return false
	return true

func medal_id(m: Dictionary) -> String: return Medals.identity(m)

func has_medal(m: Dictionary) -> bool:
	# Preserve old unique-image identifiers. Secret medals share their image,
	# so that old image cannot identify a particular secret achievement.
	return medal_id(m) in data.medals or (int(m.get("secret", 0)) == 0 and m.image in data.medals)

func medal_count(m: Dictionary) -> int:
	return int(data.stats.get("medal_counts", {}).get(medal_id(m), 1 if has_medal(m) else 0))

func award_battle_medals(sim) -> int:
	var values = Medals.battle_values(sim, data.stats, Content.catalog.tower_medals)
	var selected = Medals.select(Content.catalog.tower_medals, values)
	var raw_score = 0
	var counts = data.stats.get("medal_counts", {}).duplicate()
	for m in selected:
		var id = medal_id(m)
		counts[id] = medal_count(m)+1
		if id not in data.medals: data.medals.append(id)
		raw_score += int(m.get("xp_award", 0))
	if not selected.is_empty(): data.stats.medal_counts = counts
	# Open0xbcddc sums raw medal awards, then calls addXP once. Native
	# modGiveMedal0x462f0 increments an award count even when already owned.
	data.xp = f32(f32(float(data.xp))+f32(float(raw_score)/10.0))
	return raw_score

func advance_levels() -> void:
	# Bundled first threshold, observed second threshold, then recorded fallback.
	while data.xp >= level_threshold(int(data.level)):
		var prior_level=int(data.level)
		var threshold=level_threshold(prior_level)
		data.level += 1
		# The recovered server response schema supplies rewards, but the
		# only observed first-promotion footage awards5sp/3PU. Use those
		# for level2; later unavailable rewards retain the recorded fallback.
		var points = 3 if int(data.level) == 2 else 1
		var spice = 5 if int(data.level) == 2 else 0
		data.specpoints += points
		data.spice += spice
		data.transactions.append({"kind": "promotion", "level": int(data.level), "spice": spice, "points": points, "rule": "observed-first-promotion" if int(data.level) == 2 else "offline-fallback",
			"threshold":threshold,"threshold_source":"bundled-initial" if prior_level==1 else "observed-main-ipad" if prior_level==2 else "offline-quadratic-fallback"})
