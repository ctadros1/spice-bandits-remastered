extends RefCounted
## Full original GetThemeByName/ismatch and bounded Load assignment evidence.
static func selector(value:Variant) -> int:
	if value==null:return 0
	match str(value):
		"snow","winter":return 1
		"desert":return 2
		"jungle":return 3
		"forest":return 4
		"urban":return 5
		"sport":return 6
	return 0
