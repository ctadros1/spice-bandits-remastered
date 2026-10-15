extends RefCounted

# EAGLViewController menuTopView:loadMenu:0x36cd8. These are requested
# Core Animation properties; UIKit's compositor is not executed by Godot.
const DURATION=0.4000000059604645
const IDS={"menu":100,"world":101,"career":102,"dress":102,"medals":102,"shop":103,"upgrades":104,"spicery":105,"game":200}

static func request(previous:int,next:int) -> Dictionary:
	var changed=previous!=next
	var animate=changed and previous!=200 and next!=200
	var fade=previous==100 or next==100
	return {"animation":animate,"duration":DURATION if animate else 0.0,
		"type":("fade" if fade else "push") if animate else "",
		"subtype":("fromRight" if next>previous else "fromLeft") if animate and not fade else "",
		"current":next if changed else previous,"interaction":next!=100,
		"sound":changed and previous!=0 and previous!=200,
		"loaded_delay":DURATION if changed else 0.0,"hide_delay":0.5 if changed and animate and previous==100 else 0.0}
