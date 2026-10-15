extends SceneTree
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func median(values:Array) -> float:values.sort();return values[values.size()/2]
func run() -> void:
	var content=root.get_node("Content");var queries=[];var states_checked=0
	for name in content.animations:
		var source=content.animations[name]
		var states=source.states.keys().slice(0,4)
		states.append("__missing_state_uses_original_idle_fallback__")
		var variations=[""]
		for definition in content.catalog.tower_creeps:
			if "creeps/"+str(definition.get("filename",""))==name and not variations.has(str(definition.get("color",""))):variations.append(str(definition.get("color","")))
		for state in states:
			states_checked+=1
			for variation in variations:
				for index in [-1,0,1,123456]:
					var expected=content.frame_reference(name,state,index,variation)
					var actual=content.frame(name,state,index,variation)
					check(actual==expected,"same cached texture/offset/speed/canvas and normalized index "+name+":"+state+":"+str(index)+":"+variation)
					check(content.frame(name,state,index,variation)==actual,"repeat lookup returns the same frame value")
		for state in source.states:
			if name.begins_with("creeps/"):queries.append([name,state,3,""])
	check(content.frame("__missing_animation__","Idle").is_empty(),"missing animation keeps original empty result")
	var phases=[]
	for reference in [true,false,false,true]:
		var samples=[]
		for sample in range(8):
			var start=Time.get_ticks_usec()
			for repeat in range(80):
				for q in queries:
					if reference:content.frame_reference(q[0],q[1],q[2],q[3])
					else:content.frame(q[0],q[1],q[2],q[3])
			samples.append((Time.get_ticks_usec()-start)/float(80*queries.size()))
		phases.append({"reference":reference,"median_us_per_call":median(samples),"samples":8,"queries_per_sample":80*queries.size()})
	var report={"checks":checks,"failures":failures,"animation_sets":content.animations.size(),"state_requests":states_checked,"phases":phases,"method":"Source-only warmed frame lookup ABBA. First four states/all108 sets plus original Idle fallback, catalog creep colors and negative/large wrapped indexes compare exact Dictionary/Texture/geometry with the preserved resolver. CPU per call only; native frozen frame comparisons separately required."}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/frame-lookup-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FRAME_LOOKUP_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
