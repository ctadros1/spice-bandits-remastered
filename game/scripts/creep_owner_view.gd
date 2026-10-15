extends RefCounted

# CCreep::RenderBefore0x7f518 draws type2 missiles before the air bodies.
# RenderAfter0x7f55c draws type1 missiles later. Inputs here are the current
# simulation's missiles; original body/before-after routing, lifetime and
# the two ground-owner after calls remain separate reconstruction work.
static func missile_passes(enemies:Array, missiles:Array, definitions:Array) -> Dictionary:
	var result={"before_air":[],"ground_after":[]}
	var owners={}
	for missile in missiles:
		var kind=str(definitions[int(missile.type)].get("class",""))
		if kind=="air":
			var owner=int(missile.owner)
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
