extends SceneTree
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var reference=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../tests/fixtures/native-bolt-order-reference.json")))
	for case in reference.renders:
		var commands=case.calls.filter(func(c):return c.has("blend") or c.has("quad") or c.has("draw"))
		if not case.alive:check(commands.is_empty(),"original dead bolt submits no draws");continue
		check(commands[0].blend==[770.0,1.0],"original source ball uses SRC_ALPHA,ONE")
		var index=1
		if case.ball:check(commands[index].has("quad"),"original source quad precedes both ribbon passes");index+=1
		check(commands[index].blend==[1.0,769.0],"original broad ONE,ONE_MINUS_SRC_COLOR pass follows this ball")
		check(commands[index+1].draw.buffer==24576 and commands[index+1].draw.count==26,"original broad strip submits its own saved buffer")
		check(commands[index+2].blend==[770.0,1.0],"original core SRC_ALPHA,ONE follows this broad strip")
		check(commands[index+3].draw.buffer==20480 and commands[index+3].draw.count==24,"original core submits its own saved buffer before returning")
	for case in reference.owners:
		var actual=case.calls.filter(func(c):return c.has("bolt")).map(func(c):return int(c.bolt))
		var expected=[]
		if case.visible:
			if case.primary:expected.append(4096)
			for offset in case.bolts:expected.append(int(offset))
		check(actual==expected,"original visible owner submits primary then area bolts in saved vector order")
	var report={"checks":checks,"failures":failures,"method":reference.method}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../builds/bolt-order-verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOLT_ORDER_VERIFICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
