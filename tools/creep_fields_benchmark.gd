extends SceneTree
const Freeze=preload("res://scripts/creep_freeze_view.gd")
var checks=0
var failures=[]
func _initialize() -> void:run.call_deferred()
func check(value:bool,label:String) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func actor(growth:float,speed:float,pending:Variant,attached:bool,aux:bool) -> Dictionary:
	return {"grow_ms":growth,"speed":speed,"slow_pending":pending,"freeze_attached":attached,"freeze_auxiliary_present":aux,"freeze_auxiliary_value":1,"poison_count":7,"slow_count":9,"unchanged":{"marker":19}}
func median(values:Array) -> float:
	values.sort();return float(values[values.size()/2])
func run() -> void:
	for growth in [-10.0,0.0,399.99997,400.0]:
		for speed in [-100.123,0.0,.0001,78.5,3000.0]:
			for pending in [-2.0,-1.0,0.0,.3,1.0,2,0.10000000001]:
				for attached in [false,true]:
					for aux in [false,true]:
						for remaining in [-3,0,1,5999]:
							for dt in [0.0,16.666667,30.0,1000.0]:
								var reference=actor(growth,speed,pending,attached,aux)
								var native=reference.duplicate(true)
								Freeze.reference_fields(reference,dt,remaining);Freeze.advance_fields(native,dt,remaining)
								check(var_to_bytes(reference)==var_to_bytes(native),"full-state float/type "+str([growth,speed,pending,attached,aux,remaining,dt]))
	# Missing optional fields, signed zero and ordinary sequential expiry.
	for remaining in [30,0,-1,100]:
		var reference={"grow_ms":0.0,"speed":-0.0,"slow_pending":-0.0}
		var native=reference.duplicate(true)
		Freeze.reference_fields(reference,30,remaining);Freeze.advance_fields(native,30,remaining)
		check(var_to_bytes(reference)==var_to_bytes(native),"missing optionals "+str(remaining))
	var reference=actor(0,90,.5,true,true)
	var native=reference.duplicate(true)
	for remaining in [60,30,0,0,0]:
		Freeze.reference_fields(reference,30,remaining);Freeze.advance_fields(native,30,remaining)
		check(var_to_bytes(reference)==var_to_bytes(native),"expiry sequence "+str(remaining))
	# Invalid arithmetic must reject before any mutation, then use the reference.
	for invalid in [{"grow_ms":NAN},{"grow_ms":INF},{"speed":INF},{"speed":NAN},{"slow_pending":INF},{"speed":1e300}]:
		var input=actor(0,30,1.0,true,true)
		input.merge(invalid,true)
		var before=var_to_bytes(input)
		check(not SpiceNative.advance_creep_fields(input,30,0),"nonfinite rejection "+str(invalid))
		check(var_to_bytes(input)==before,"rejection unchanged "+str(invalid))
		var expected=input.duplicate(true)
		Freeze.reference_fields(expected,30,0);Freeze.advance_fields(input,30,0)
		check(var_to_bytes(expected)==var_to_bytes(input),"nonfinite fallback "+str(invalid))
	var phases=[]
	for use_reference in [true,false,false,true]:
		var actors=[]
		for i in range(64):actors.append(actor(float(i),78.5,.5 if i%3==0 else -1.0,i%4==0,i%2==0))
		var samples=[]
		for sample in range(8):
			var started=Time.get_ticks_usec()
			for repeat in range(256):
				for entry in actors:
					if use_reference:Freeze.reference_fields(entry,30,120)
					else:Freeze.advance_fields(entry,30,120)
			samples.append((Time.get_ticks_usec()-started)/16384.0)
		phases.append({"reference":use_reference,"samples":8,"calls_per_sample":16384,"median_us_per_call":median(samples)})
	var report={"checks":checks,"failures":failures,"phases":phases,"method":"Bounded headless ABBA64 supplied-actor field helper CPU comparison. Exact serialized dictionary bytes include types and floating bits; reference preserves previous Simulation prefix. Existing independent original freeze/speed and simulation fixtures remain separate gates. Reference helper call versus wrapper/native call does not prove a whole live inter-build speedup or original whole-game parity."}
	var file=FileAccess.open("res://../builds/creep-fields-benchmark-r127.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CREEP_FIELDS_BENCHMARK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
