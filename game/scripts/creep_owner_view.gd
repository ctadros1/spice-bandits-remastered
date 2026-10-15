extends RefCounted

# CCreep::RenderBefore0x7f518 draws type2 missiles before the air bodies.
# RenderAfter0x7f55c draws type1 missiles later. Inputs here are the current
# simulation's missiles. Body flag+a0 routes after its own body; lifetime and
# the two ground-owner after calls remain separate reconstruction work.
static func missile_passes(enemies:Array, missiles:Array, definitions:Array) -> Dictionary:
	var result={"before_air":[],"ground_after":[],"body":{}}
	var owners={}
	var living_owners={}
	for enemy in enemies:living_owners[int(enemy.id)]=true
	for missile in missiles:
		var owner=int(missile.owner)
		if bool(missile.get("body_flag",false)) and living_owners.has(owner):
			if not result.body.has(owner):result.body[owner]=[]
			result.body[owner].append(missile)
			continue
		var kind=str(definitions[int(missile.type)].get("class",""))
		if kind=="air":
			if not owners.has(owner):owners[owner]=[]
			owners[owner].append(missile)
		elif kind=="ground":result.ground_after.append(missile)
	if owners.is_empty():return result
	for enemy in enemies:
		var owner=int(enemy.id)
		if owners.has(owner):
			result.before_air.append_array(owners[owner]);owners.erase(owner)
	# The current simulation can retain a missile after its owner disappears.
	# Preserve that existing lifetime until the original destructor is traced.
	for owner in owners:result.before_air.append_array(owners[owner])
	return result
