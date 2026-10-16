extends SceneTree
var app
var checks=0
var failures=[]
var pairs=[]
func check(value:bool,label:String):
	checks+=1
	if not value:failures.append(label)
func _initialize():
	create_timer(45).timeout.connect(func():quit(1));run.call_deferred()
func capture(reference:bool) -> Image:
	app.reference_decal_rendering=reference;app.queue_redraw()
	await process_frame;await process_frame;RenderingServer.force_draw(true)
	return root.get_texture().get_image()
func compare(name:String):
	var a=await capture(true);var b=await capture(false);var exact=a.get_data()==b.get_data()
	check(exact,"exact original/current full RGBA "+name)
	a.save_png("res://../builds/decal-render-r126/"+name+"-reference.png");b.save_png("res://../builds/decal-render-r126/"+name+"-cached.png")
	pairs.append({"name":name,"exact_full_rgba":exact,"width":a.get_width(),"height":a.get_height()})
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../builds/decal-render-r126"))
	app=load("res://scripts/main.gd").new();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	app.start_mission("1",true,false);app.tutorial=null;app.sim.spawn_hold=true;app.qa_gallery=true;app.refresh_controls();app.notice_until=0;app.animation_delta_ms=0
	var pos=app.sim.center(8,6)
	for i in range(3):
		var d=app.sim.decals.add(pos+Vector2(10*i,-10*i),"assets/sfx/craters/crater_"+str(i+1)+".png",[1.0,.4,1.6][i]);d.alpha=[.25,.5,1.0][i]
	await compare("overlap-alpha-scale")
	check(app.decal_render_cache.size()==3,"cache contains all supplied immutable geometries")
	var item=app.sim.decals.items[0];item.position+=Vector2(16.25,11.75);item.scale=1.6;item.texture="assets/sfx/craters/crater_5.png"
	await compare("changed-geometry")
	app.sim.decals.setup(int(app.sim.map.width_pixels),int(app.sim.map.height_pixels))
	app.sim.decals.add(pos-Vector2(100,50),"assets/sfx/craters/crater_4.png",.75)
	await compare("reused-id")
	app.ordered_battle_rendering=true
	await compare("ordered-span")
	var report={"checks":checks,"failures":failures,"pairs":pairs,"scope":"Native current source reference(R125 direct geometry)/cached decal paths, full RGBA frozen supplied scenes. Tests overlap/fade scale, geometry change/ID reuse and ordered spans. No original-device/GPU/whole game equivalence."}
	var out=FileAccess.open("res://../builds/decal-render-r126-verification.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close();print("DECAL_RENDER ",JSON.stringify(report));app.free();quit(0 if failures.is_empty() else 1)
