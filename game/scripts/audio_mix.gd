extends RefCounted

# CRoom::Update0xd2768 and UpdateImportantSounds0xd35e8; CSound::SetGain0x11fa08.
var multiple = 1.0
var important = 1.0
var important_active = false
var transition_ms = 0.0

static func f32(value: float) -> float: return PackedFloat32Array([value])[0]

func update(count: int, active: bool, ms: float) -> void:
	var target = 1.0 if count < 15 else f32(1.0+f32(float(count-15)*f32(-0.03)))
	if multiple > target: multiple = maxf(0, f32(multiple+f32(-0.02)))
	elif multiple < target: multiple = minf(1, f32(multiple+f32(0.01)))
	var low = f32(0.85)
	if active != important_active:
		important_active = active
		transition_ms = f32(absf(f32((1.0 if active else low)-important))/0.1499999761581421*500.0)
	if (active and important <= low) or (not active and important >= 1): transition_ms = 0; return
	transition_ms = f32(transition_ms+ms)
	var p = minf(1, f32(transition_ms/500.0))
	var eased = f32(f32(p*6)-15)
	eased = f32(f32(eased*p)+10)
	eased = f32(f32(f32(eased*p)*p)*p)
	important = f32((1.0 if active else low)+f32(((low-1.0) if active else (1.0-low))*eased))

func gain(definition: Dictionary, global_gain: float = 1.0, applies_global: bool = true) -> float:
	var value = f32(float(definition.gain))
	if applies_global: value = f32(value*global_gain)
	if int(definition.get("important", 0)) == 0: value = f32(value*important)
	return f32(value*multiple)
