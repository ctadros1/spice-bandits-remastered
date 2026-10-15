extends SceneTree
var failures=[]
var checks=0
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func median(values:Array) -> float:
 values.sort();return float(values[values.size()/2])
func run() -> void:
 var content=root.get_node("Content")
 var app=load("res://scripts/main.gd").new()
 app.sim=load("res://scripts/simulation.gd").new()
 var mission=content.mission("1")
 app.sim.setup(content.catalog,content.maps[mission.map],mission,{},114,content.animations)
 var actors=[]
 for type in range(content.catalog.tower_creeps.size()):
  if not content.catalog.tower_creeps[type].has("filename"):continue
  var e=app.sim.spawn_enemy(type,0,"",1000+type,false)
  var states=content.animations["creeps/"+str(e.def.filename)].states
  for attacking in [false,true]:
   e.attacking=attacking
   for cached in [false,true]:
    if cached:e.visual_layers=[{"state":"RunDownRight","rotation":0.137,"alpha":0.75,"born":0},{"state":"RunUpLeft","rotation":-0.31,"alpha":0.25,"born":3}]
    else:e.erase("visual_layers")
    app.reference_creep_layers=true;var old=app.creep_layers(e,states)
    app.reference_creep_layers=false;var prepared=app.creep_layers(e,states)
    check(old==prepared,"same moving/attacking cached/fallback layer values for resource "+str(type))
    if cached:check(prepared==e.visual_layers,"caller-prepared blended state and ages remain unchanged")
  for age in [0.0,1.0,100.0,399.0,399.99999,400.0,401.0,1000.0,10000000.0]:
   e.grow_ms=age
   app.sim.reference_spawn_presentation=true;var old_growth=app.sim.spawn_presentation(e)
   app.sim.reference_spawn_presentation=false;var prepared_growth=app.sim.spawn_presentation(e)
   check(old_growth==prepared_growth,"same original growth polynomial/plateau at "+str(age))
  e.grow_ms=400.0;e.attacking=bool(type%2)
  actors.append({"actor":e,"states":states})
 var phases=[]
 for reference in [true,false,false,true]:
  app.reference_creep_layers=reference;app.sim.reference_spawn_presentation=reference
  var layers=[];var growth=[]
  for sample in range(10):
   var start=Time.get_ticks_usec()
   for repeat in range(40):
    for item in actors:app.creep_layers(item.actor,item.states)
   layers.append((Time.get_ticks_usec()-start)/float(40*actors.size()))
   start=Time.get_ticks_usec()
   for repeat in range(40):
    for item in actors:app.sim.spawn_presentation(item.actor)
   growth.append((Time.get_ticks_usec()-start)/float(40*actors.size()))
  phases.append({"reference":reference,"samples":10,"resolutions_per_sample":40*actors.size(),"layer_median_us_per_call":median(layers),"growth_median_us_per_call":median(growth)})
 app.free()
 var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"resources":actors.size(),"phases":phases,"method":"Source Godot4.7.2 fixed29-resource selector/growth ABBA microbenchmark. Prepared moving/attacking/fallback layers and boundary growth values match the prior calculation. CPU per call only; no GPU, live FPS or original-device performance claim."}
 var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/creep-layers-benchmark-r100.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 print("CREEP_LAYERS_BENCHMARK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
