extends SceneTree
class Host extends Node2D:
	var screen="game"
	var draws=0
	func map_scale() -> float:return 1.0
	func map_origin() -> Vector2:return Vector2.ZERO
	func record_qa_time(key:String,_start:int) -> void:
		if key=="particle_draw":draws+=1
var output=""
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reset-proof-root="):output=arg.trim_prefix("--reset-proof-root=")
	create_timer(20).timeout.connect(func():quit(1));run.call_deferred()
func capture(viewport:SubViewport,name:String) -> Image:
	await process_frame;await process_frame;RenderingServer.force_draw(true)
	var image=viewport.get_texture().get_image();image.save_png(output.path_join(name+".png"));return image
func run():
	if output.is_empty():push_error("Reset proof needs a fresh output directory.");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(384,288)
	var viewport=SubViewport.new();viewport.size=Vector2i(256,192);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var background=ColorRect.new();background.size=Vector2(256,192);background.color=Color(.12,.23,.34,1);viewport.add_child(background)
	var host=Host.new();viewport.add_child(host)
	var fx=load("res://scripts/particle_fx.gd").new();fx.app=host;fx.size=Vector2(256,192);host.add_child(fx)
	var blank=await capture(viewport,"blank")
	fx.emit_system("MissileExplodeGray",Vector2(128,96))
	for i in range(10):
		fx.clock_seconds=Vector2(fx.clock_seconds+Vector2(.03,0).x,0).x;fx.clock_ms=fx.clock_seconds*1000
		SpiceNative.advance_systems(fx.systems,fx.clock_ms,fx.emit_system,fx.emit_batch,fx.random,Vector2(.03,0).x)
	for layer in fx.layers:layer.queue_redraw()
	var live=await capture(viewport,"visible")
	var before=host.draws;fx.reset()
	var cleared=await capture(viewport,"reset")
	var failures=[]
	if live.get_data()==blank.get_data():failures.append("supplied real smoke did not draw")
	if not fx.systems.is_empty():failures.append("reset left active systems")
	if cleared.get_data()!=blank.get_data():failures.append("reset retained stale native canvas drawing")
	var report={"checks":3,"failures":failures,"visible_smoke":live.get_data()!=blank.get_data(),"reset_empty_full_rgba":cleared.get_data()==blank.get_data(),"reset_layer_draws":host.draws-before,"width":256,"height":192,"scope":"Native OpenGL actual ParticleFX.reset with real preserved smoke and frozen neutral backdrop. Full RGBA after reset must match pre-emission framebuffer; no pointer or source-device identity claim. Canvas caching is exercised without process/advance after reset."}
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("PARTICLE_RESET ",JSON.stringify(report));viewport.free();quit(0 if failures.is_empty() else 1)
