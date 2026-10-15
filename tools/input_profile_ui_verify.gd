extends SceneTree
var checks=0
var failures=[]
func check(value:bool,name:String):
	checks+=1
	if not value:failures.append(name);push_error(name)
func _initialize():run.call_deferred()
func run():
	var profile=root.get_node("Profile")
	check(profile.verification_context and profile.path.begins_with("user://verification/native-input/"),"input reward account is isolated before Main loads")
	check(not FileAccess.file_exists(profile.path) and profile.data.xp==0 and profile.data.spice==0,"input account starts fresh without replacing a retained save")
	var target=profile.path
	profile.data.settings.music=false;profile.data.settings.sound=false
	var app=load("res://scenes/main.tscn").instantiate();app.set_meta("qa_fixture",true);root.add_child(app);app.set_process(false)
	check(app.test_session and app.qa_persist_progress and profile.path==target,"native reward flag retains its unique account and enables ordinary credit transactions")
	check(profile.save_profile(),"new input account saves normally")
	profile.data.name="Unsaved name";profile.load_profile()
	check(profile.data.name=="Cadet" and profile.path==target,"input account reloads its own saved state")
	profile.path="user://profile.json"
	check(not profile.save_profile(),"input rewards cannot bypass the normal-save write guard")
	profile.path=target
	app.queue_free();await process_frame
	print("INPUT_PROFILE_VERIFICATION ",JSON.stringify({"checks":checks,"failures":failures,"path":target,"limit":"Neutral isolated account and write/reload guard; no battle victory or earned XP fixture."}))
	quit(0 if failures.is_empty() else 1)
