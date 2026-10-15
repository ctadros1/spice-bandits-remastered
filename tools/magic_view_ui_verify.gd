extends SceneTree
const View=preload("res://scripts/magic_view.gd")
const Simulation=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func check(value:bool,name:String) -> void:
	checks+=1
	if not value:failures.append(name)
func color_check(value:Color,expected:Array,name:String) -> void:
	for i in range(4):check(value[i]==View.f32(expected[i]),name+str(i))
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-magic-view-reference.json")))
	for case in original.renders:
		var sprites=[];var bars=[]
		if case.kind=="mine":
			var pose=View.mine(Vector2(120,170),case.active==1,int(case.state),int(case.sleep),5000,case.light)
			sprites=pose.sprites;bars=pose.bars
		else:sprites=View.portal(case.active==1,int(case.state))
		check(sprites.size()==case.result.actors.size(),"original magic animator count")
		check(bars.size()==case.result.bars.size(),"original magic bar count")
		for i in range(mini(sprites.size(),case.result.actors.size())):
			color_check(sprites[i].color,case.result.actors[i].color,"original magic GL modulation")
			var tint=View.straight(sprites[i].color)
			for j in range(3):check(is_equal_approx(tint[j]*tint.a,sprites[i].color[j]),"straight texture preserves native premultiplied modulation")
		for i in range(mini(bars.size(),case.result.bars.size())):
			var actual=[bars[i].rect.position.x,bars[i].rect.position.y,bars[i].rect.size.x,bars[i].rect.size.y]
			for j in range(4):check(actual[j]==View.f32(case.result.bars[i].rect[j]),"original mine arming rectangle")
			color_check(bars[i].color,case.result.bars[i].color,"original mine arming color")
	for case in original.placements:
		if case.kind!="mine":continue
		var within=int(case.cell[0])==0 and int(case.cell[1])==0
		check(View.mine_allowed(within,case.buildable==1,case.walkable==1,int(case.owner),int(case.player))==case.result,"original mine bounds/build/walk/owner guard")
	var content=root.get_node("Content")
	var mission=content.mission("8")
	var sim=Simulation.new();sim.setup(content.catalog,content.maps[mission.map],mission,root.get_node("Profile").fresh())
	sim.abilities.m_mine=5
	check(not sim.use_ability("m_mine",sim.center(9,1)).is_empty() and sim.mines.is_empty() and sim.abilities.m_mine==5,"walkable non-buildable terrain rejects a mine without a debit")
	check(sim.build(Vector2i(8,9),1).is_empty(),"ordinary tower occupies the mine guard fixture")
	check(not sim.use_ability("m_mine",sim.center(8,9)).is_empty() and sim.mines.is_empty() and sim.abilities.m_mine==5,"native occupied cell rejects a mine without a debit")
	check(sim.use_ability("m_mine",sim.center(12,9)).is_empty() and sim.mines.size()==1 and sim.abilities.m_mine==4,"legal mine consumes once and starts its arming clock")
	var report={"checks":checks,"failures":failures,"method":"56 original mine/portal Render submissions and72 original mine placement cases; renderer/animator calls stubbed. Portal placement cases retained for further caller tracing, not ported here."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/magic-view-verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAGIC_VIEW_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
