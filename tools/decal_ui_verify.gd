extends SceneTree
const DecalData=preload("res://scripts/decal_view.gd")
var checks=0
var failures=[]
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label)
func same(a,b) -> bool:
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same(a[i],b[i]):return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]):return false
		return true
	return a==b
func bits(v:float) -> int:return PackedFloat32Array([v]).to_byte_array().decode_u32(0)
func fields(d:Dictionary) -> Dictionary:return {"clock_bits":bits(d.clock),"alpha_bits":bits(d.alpha),"deleted":d.deleted,"fading":d.fading}
func _initialize():
	create_timer(45).timeout.connect(func():quit(1));run.call_deferred()
func run():
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../tests/fixtures/native-decal-reference.json"))
	for c in fixture.headers:check(same(DecalData.header(int(c.width),int(c.height)),c.fields),"original array header")
	for c in fixture.clocks:
		var model=DecalData.new();model.setup(250,250)
		var item=model.add(Vector2(123.25,234.5),"test",1,float(c.life),float(c.fade),float(c.fade_in),0)
		for row in c.frames:
			var prior=model.items.size()
			if row.dt_ms!=null:model.advance(float(row.dt_ms))
			check(same(fields(item),row.fields),"original exact decal clock/alpha bits")
			check((not model.items.is_empty())==row.present and prior-model.items.size()==row.destroyed,"original manager next-update removal")
			check(model.items.size()==row.draws.size(),"original RenderAll count/order")
			for draw in row.draws:
				check(same([bits(item.alpha),bits(item.alpha),bits(item.alpha),bits(item.alpha)],draw.rgba_bits),"original premultiplied decal RGBA")
				check(same([bits(item.position.x),bits(item.position.y)],draw.point_bits) and same([bits(item.scale),bits(item.scale)],draw.scale_bits),"original decal position/proportions")
	for i in fixture.admissions.size():
		var c=fixture.admissions[i];var input=c.input;var model=DecalData.new();model.setup(int(input.width),int(input.height))
		var point=Vector2(input.point[0],input.point[1]);var key=model.cell_at(point)
		if point.x<0 or point.y<0 or key.x>=int(model.width/100.0) or key.y>=int(model.height/100.0):key=Vector2i.ZERO
		var old=[]
		for j in input.existing.size():
			var p=input.existing[j];var item=DecalData.initial(Vector2(p[0],p[1]),1,4000,4000);item.label=j;item.cell=key;item.id=j;old.append(item)
		model.cells[key]=old.duplicate()
		var added=model.add(point,"test",1.6,4000,4000,0,int(input.kind),input.array)
		if not added.is_empty():added.label="new"
		var members=model.cells[key].map(func(d):return d.label)
		var actual={"created":int(not added.is_empty()),"members":members,"old_deleted":old.map(func(d):return d.deleted),"unhooked":old.filter(func(d):return d.deleted).size()}
		check(same(actual,c.output),"original spatial admission "+str(i))
	var content=root.get_node("Content");var profile=root.get_node("Profile").fresh()
	var mission=content.mission("1");var sim=load("res://scripts/simulation.gd").new()
	sim.setup(content.catalog,content.maps[mission.map],mission,profile,125,content.animations);sim.spawn_hold=true
	var enemy=sim.spawn_enemy(1,0,"",980,false);enemy.pos=sim.center(8,6);enemy.visual_pos=enemy.pos;enemy.path=[]
	var prior_rng=sim.rng.state;sim.damage(enemy,10000)
	check(sim.decals.items.size()==1 and enemy.crater_created,"actual lethal damage admits one original crater")
	var crater=sim.decals.items[0];var money=sim.money;var kills=sim.kills
	check(crater.position==enemy.pos and crater.alpha==1 and crater.clock==0 and crater.life==4000 and crater.fade==4000,"actual combat birth preserves original logical point/fresh clock")
	check(sim.rng.state==prior_rng,"cosmetic crater choice preserves combat RNG state")
	sim.damage(enemy,10000)
	check(sim.decals.items.size()==1 and sim.money==money and sim.kills==kills,"repeat lethal calls do not add crater or earned rewards")
	sim.paused=true;sim.advance_frame(30)
	check(crater.clock==0,"actual pause holds crater clock")
	sim.paused=false;sim.advance_frame(30)
	check(crater.clock==30 and crater.alpha==1,"actual resumed frame advances admitted crater before combat")
	var air_type=-1
	for type in content.catalog.tower_creeps.size():
		if str(content.catalog.tower_creeps[type].get("filename",""))=="creep5":air_type=type;break
	check(air_type>=0,"preserved large-crater creature is populated")
	var large=sim.spawn_enemy(air_type,0,"",981,false);large.pos=sim.center(9,6);sim.damage(large,10000)
	check(sim.decals.items[-1].scale==DecalData.f32(1.6),"actual creature resource carries authored crater scale")
	var report={"checks":checks,"failures":failures,"scope":"Full original CMapArray header,AddDecal/constructor/distance guards,Update/interpolation and manager/Render submissions on supplied records. Actual Simulation lethal creation/once-only rewards/pause/resume/scale bridge also checked. GPU/map loader/global RNG/complete game not executed."}
	var out=FileAccess.open("res://../builds/decal-verification.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close();print("DECAL_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
