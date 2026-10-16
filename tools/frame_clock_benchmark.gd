extends SceneTree
const Clock=preload("res://scripts/tower_preview_view.gd")
var failures=[]
var checks=0
func _initialize() -> void:run.call_deferred()
func median(values:Array) -> float:
	values.sort();return float(values[values.size()/2])
func run() -> void:
	for count in [1,2,8,12]:
		for speed in [0.0,5.0,17.0]:
			for loop in [false,true]:
				for divisor in [.5,1.0,2.0,INF]:
					var reference=Clock.initial(count,speed,loop,1,divisor)
					var native=reference.duplicate()
					for dt in [0.0,16.666667,30.0,60.0,1000.0,1000.0]:
						Clock.reference_advance(reference,dt);Clock.advance(native,dt)
						checks+=1
						if native!=reference:failures.append("clock state "+str([count,speed,loop,divisor,dt]))
	var phases=[]
	for reference in [true,false,false,true]:
		var clocks=[]
		for i in range(64):clocks.append(Clock.initial(12,17,true,0 if i%4==0 else 1,2 if i%3==0 else 1))
		var samples=[]
		for sample in range(8):
			var started=Time.get_ticks_usec()
			for repeat in range(250):
				for state in clocks:
					if reference:Clock.reference_advance(state,30)
					else:Clock.advance(state,30)
			samples.append((Time.get_ticks_usec()-started)/16000.0)
		phases.append({"reference":reference,"samples":8,"calls_per_sample":16000,"median_us_per_call":median(samples)})
	var report={"checks":checks,"failures":failures,"phases":phases,"method":"Headless Godot4.7.2 ABBA64-supplied-clock CPU microbenchmark. Exact full clock-state equality across count/speed/loop/divisor/overflow inputs. Native helper also checked against independent original ARM fixtures in animator and creep units. No GPU or live inter-build speedup claim."}
	var f=FileAccess.open("res://../builds/frame-clock-benchmark-r119.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("FRAME_CLOCK_BENCHMARK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
