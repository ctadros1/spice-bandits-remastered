extends SceneTree
const Hex=preload("res://scripts/build_hex_view.gd")
var checks=0
var failures=[]
func check(value:bool,name:String):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():run.call_deferred()
func run():
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-build-hex-reference.json"))
	for c in fixture.cases:
		var r=c.result
		for cell in r.cells:cell.base_blocked=c.base_blocked and cell.cell==[1.0,1.0]
		var shape=Hex.geometry(r.cells,Vector2(r.origin[0],r.origin[1]),Vector2i(1,1),c.radius,bool(c.active),bool(c.positioned),bool(c.valid),r.corners,Vector2(c.offset[0],c.offset[1]))
		check(shape.quads.size()==r.quads.size(),"native selected/blocked hex polygon count")
		check(shape.lines.size()==r.lines.size(),"native outline/jitter/cross submission count")
		for i in range(mini(shape.quads.size(),r.quads.size())):
			for j in range(6):
				var v=r.quads[i][j]
				check(shape.quads[i].points[j].distance_to(Vector2(v.position[0],v.position[1]))<0.00001,"native hex vertex")
				var b=v.color_bytes
				check(shape.quads[i].color.is_equal_approx(Color(b[0]/255.0,b[1]/255.0,b[2]/255.0,b[3]/255.0)),"native byte-quantized fill color")
		for i in range(mini(shape.lines.size(),r.lines.size())):
			for key in ["start","end"]:
				check(shape.lines[i][key].distance_to(Vector2(r.lines[i][key][0],r.lines[i][key][1]))<0.00001,"native jitter/cross endpoint")
				var color=r.lines[i][key+"_color"]
				check(absf(shape.lines[i][key+"_color"].a-color[3])<0.000001,"native endpoint opacity")
	var ovals=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-preview-oval-reference.json"))
	for c in ovals.cases:
		var draws=Hex.oval(c.alpha,c.distance,c.range,c.bonus,bool(c.visible))
		check(draws.size()==c.draws.size(),"native preview oval draw count")
		for i in range(draws.size()):
			var r=c.draws[i]
			check(draws[i].filled==r.filled,"native preview fill/outline order")
			check(draws[i].axes.distance_to(Vector2(r.axes[0],r.axes[1]))<0.00001,"native preview oval radii/jitter")
			check(draws[i].color.is_equal_approx(Color(r.color[0],r.color[1],r.color[2],r.color[3])),"native preview oval color/fade")
	print("BUILD_HEX_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures,"limit":"Original geometry/color submission oracle with explicit grid/build flags; Godot rasterization is not an original-device comparison."}))
	quit(0 if failures.is_empty() else 1)
