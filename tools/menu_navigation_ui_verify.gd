extends SceneTree
const Navigation=preload("res://scripts/menu_navigation.gd")
var checks=0
var failures=[]
func check(value:bool,name:String):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():
	var file=FileAccess.open("res://../tests/fixtures/native-menu-navigation-reference.json",FileAccess.READ)
	var data=JSON.parse_string(file.get_as_text())
	for c in data.cases:
		var actual=Navigation.request(int(c.old),int(c.new));var expected=c.result
		for key in ["animation","type","subtype","current","interaction"]:check(actual[key]==expected[key],"original menu request "+key)
		check(absf(actual.duration-expected.duration)<0.00000001,"original400ms animation duration")
		check(actual.sound==not expected.sounds.is_empty(),"original previous-menu sound guard")
		var loaded=expected.scheduled.filter(func(s):return s.selector=="viewControllerLoaded:")
		check(absf(actual.loaded_delay-(loaded[0].delay if not loaded.is_empty() else 0.0))<0.00000001,"original controller loaded delay")
		var hidden=expected.scheduled.filter(func(s):return s.selector=="hideView")
		check(actual.hide_delay==(hidden[0].delay if not hidden.is_empty() else 0.0),"original Home hide delay")
	print("MENU_NAVIGATION_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
