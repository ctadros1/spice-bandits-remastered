extends RefCounted

# Original declarations; Core Animation interpolation is reconstructed below.
const ROTATIONS={
	"logoFastRotateView":{"to":0.6366197466850281,"duration":0.05000000074505806,"cumulative":true,"reverse":false,"timing":"easeInEaseOut"},
	"logoView":{"to":0.03099999949336052,"duration":2.0,"cumulative":true,"reverse":true,"timing":"easeInEaseOut"},
	"logoWiresView":{"to":0.029999999329447746,"duration":2.0,"cumulative":true,"reverse":true,"timing":"easeInEaseOut"},
	"chainView":{"to":0.10000000149011612,"duration":5.0,"cumulative":true,"reverse":true,"timing":"easeInEaseOut"},
	"gear1ImageView":{"to":6.2831854820251465,"duration":15.0,"cumulative":false,"reverse":false,"timing":"linear"},
	"gear2ImageView":{"to":-6.2831854820251465,"duration":6.0,"cumulative":false,"reverse":false,"timing":"linear"},
	"gear3ImageView":{"to":6.2831854820251465,"duration":20.0,"cumulative":false,"reverse":false,"timing":"linear"},
	"spinnerImageView":{"to":6.2831854820251465,"duration":0.5,"cumulative":false,"reverse":false,"timing":"linear"},
	"starsImageView":{"to":6.2831854820251465,"duration":100.0,"cumulative":false,"reverse":false,"timing":"linear"},
	"earthImageView":{"to":-6.2831854820251465,"duration":150.0,"cumulative":false,"reverse":false,"timing":"linear"}}
const MOTIONS={
	"chain2View":[{"keypath":"transform.scale.x","from":1.0,"to":1.1299999952316284,"duration":3.0,"reverse":true,"timing":"easeInEaseOut"},{"keypath":"transform.scale.y","from":1.0,"to":1.1299999952316284,"duration":3.0,"reverse":true,"timing":"easeInEaseOut"}],
	"earthImageView":[{"keypath":"transform.translation.y","from":0.0,"to":10.0,"duration":10.0,"reverse":true,"timing":"easeInEaseOut"},{"keypath":"transform.scale.x","from":1.0,"to":0.8999999761581421,"duration":7.0,"reverse":true,"timing":"easeInEaseOut"},{"keypath":"transform.scale.y","from":1.0,"to":0.8999999761581421,"duration":7.0,"reverse":true,"timing":"easeInEaseOut"}],
	"moonImageView":[{"keypath":"transform.translation.y","from":0.0,"to":-17.0,"duration":14.0,"reverse":true,"timing":"easeInEaseOut"}]}
const ANCHORS={"logoView":Vector2(0.5,0.10000000149011612),"chainView":Vector2.ZERO}
const LIGHT_VALUES=[1.0,1.0,0.05000000074505806,1.0,0.6000000238418579,1.0,0.4000000059604645]
const LIGHT_TIMES=[0.0,0.10000000149011612,0.15000000596046448,0.15000000596046448,0.5,0.550000011920929,0.6000000238418579]
const EYE_VALUES=[0.0,1.0,1.0,0.0]
const EYE_TIMES=[0.10000000149011612,0.20000000298023224,0.8999999761581421,1.0]
const LIGHT_TARGETS=["logoTextLightView","logoLightView","logoWiresLightView"]
const ROCKET_DURATION=0.3
const NOTE_INTERVAL=0.699999988079071
var age=0.0
var note_until=NOTE_INTERVAL
var eye_index=-1
var eye_age=0.0
var eye_duration=0.0
var rng=RandomNumberGenerator.new()

func reset(seed_value:int=-1) -> void:
	age=0.0;note_until=NOTE_INTERVAL;eye_index=-1;eye_age=0.0;eye_duration=0.0
	if seed_value<0:rng.randomize()
	else:rng.seed=seed_value

func trigger_eye(choice:int,duration_random:int) -> bool:
	if eye_duration>0 and eye_age<eye_duration:return false
	var index=choice%3
	if index==eye_index:index=(index+1)%3
	eye_index=index;eye_age=0.0;eye_duration=2.0+duration_random%3
	return true

func advance(seconds:float) -> void:
	var remaining=maxf(seconds,0)
	while remaining>=note_until:
		age+=note_until;eye_age+=note_until;remaining-=note_until;note_until=NOTE_INTERVAL
		if eye_duration==0 or eye_age>=eye_duration:trigger_eye(rng.randi()&0x7fffffff,rng.randi()&0x7fffffff)
	age+=remaining;eye_age+=remaining;note_until-=remaining

static func curve(value:float,timing:String) -> float:
	var x=clampf(value,0,1)
	if timing=="linear" or x==0 or x==1:return x
	var a=0.42
	var b=0.58 if timing=="easeInEaseOut" else 1.0
	# Invert the cubic x coordinate before evaluating y. Control points were
	# also read from the local Core Animation framework; no pixel claim follows.
	var low=0.0;var high=1.0;var t=x
	for _i in range(24):
		t=(low+high)/2.0
		var bx=3*(1-t)*(1-t)*t*a+3*(1-t)*t*t*b+t*t*t
		if bx<x:low=t
		else:high=t
	return 3*(1-t)*t*t+t*t*t

static func keyframe(values:Array,times:Array,progress:float) -> float:
	var valid=times.size()==values.size() and times[0]==0.0 and times[-1]==1.0
	if valid:
		for i in range(1,times.size()):
			if times[i]<times[i-1]:valid=false;break
	# Apple's keyTimes contract ignores invalid arrays. Both recovered light
	# and eye arrays violate an endpoint, so use evenly spaced keyframes.
	var at=clampf(progress,0,1)
	for i in range(1,values.size()):
		var right=float(times[i]) if valid else float(i)/(values.size()-1)
		var left=float(times[i-1]) if valid else float(i-1)/(values.size()-1)
		if at<=right:return lerpf(values[i-1],values[i],clampf((at-left)/(right-left),0,1)) if right>left else float(values[i])
	return float(values[-1])

func light_alpha() -> float:
	return keyframe(LIGHT_VALUES,LIGHT_TIMES,curve(fposmod(age,2.0)/2.0,"easeIn"))

func eye_amount() -> float:
	if eye_index<0 or eye_duration<=0 or eye_age>=eye_duration:return 0.0
	return keyframe(EYE_VALUES,EYE_TIMES,eye_age/eye_duration)

func rotation(outlet:String) -> float:
	if outlet=="logoRocket2":return PI
	if not ROTATIONS.has(outlet):return 0.0
	var spec=ROTATIONS[outlet]
	var cycles=age/float(spec.duration)
	var phase=fposmod(cycles,2.0) if spec.reverse else fposmod(cycles,1.0)
	if spec.reverse and phase>1:phase=2-phase
	var amount=curve(phase,spec.timing)
	if spec.cumulative and not spec.reverse:amount+=floorf(cycles)
	return float(spec.to)*amount

func transform_for(outlet:String,rect:Rect2) -> Transform2D:
	var scale=Vector2.ONE
	var translation=Vector2.ZERO
	for spec in MOTIONS.get(outlet,[]):
		var phase=fposmod(age/float(spec.duration),2.0)
		if phase>1:phase=2-phase
		var value=lerpf(spec.from,spec.to,curve(phase,spec.timing))
		match spec.keypath:
			"transform.scale.x":scale.x=value
			"transform.scale.y":scale.y=value
			"transform.translation.y":translation.y=value
	var anchor:Vector2=ANCHORS.get(outlet,Vector2(0.5,0.5))
	var effect=Transform2D(rotation(outlet),scale,0,rect.get_center()+translation)
	return effect*Transform2D(0,-rect.position-rect.size*anchor)
