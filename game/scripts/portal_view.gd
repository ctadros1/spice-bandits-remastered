extends RefCounted

# Full original CPortal/Gates constructors, Connect and Update arithmetic.
# Transfer internals, animator clocks and the mutable map registry are separate.
static func f32(value:float) -> float:return Vector2(value,0).x

static func gate(reload_ms:float) -> Dictionary:
	return {"state":0,"active":false,"scale":f32(0.3),"opening":true,"open_remaining":f32(f32(reload_ms)*0.5),"close_remaining":f32(reload_ms)}

static func create(reload_ms:float,duration_ms:float,permanent:bool=false) -> Dictionary:
	return {"remaining":f32(duration_ms),"connected":false,"deleted":false,"permanent":permanent,"reload":f32(reload_ms),"gates":[gate(reload_ms),gate(reload_ms)],"transfer_checks":0}

static func connect_gates(pair:Dictionary,active:bool=true) -> void:
	pair.connected=true
	for g in pair.gates:g.state=2;g.active=active

static func interpolate(start:float,target:float,amount:float) -> float:
	var value=f32(start+f32(f32(target-start)*amount))
	if start<target and value>target:return target
	if target<start and value<target:return target
	return value

static func advance(pair:Dictionary,elapsed_ms:float) -> void:
	pair.transfer_checks=0
	if pair.deleted or not pair.connected:return
	var dt=f32(elapsed_ms)
	if not pair.permanent:
		pair.remaining=f32(float(pair.remaining)-dt)
		if pair.remaining<=0:
			for g in pair.gates:g.state=4
	for g in pair.gates:
		if not g.active:continue
		if g.state==2:
			if g.opening:
				g.open_remaining=f32(float(g.open_remaining)-dt)
				var amount=f32(1+f32(float(g.open_remaining)/f32(float(pair.reload)*-0.5)))
				g.scale=interpolate(0.5,1,amount)
				if g.scale>=1:g.opening=false;g.scale=1.0
			pair.transfer_checks+=1
		if g.state==4:
			g.close_remaining=f32(float(g.close_remaining)-dt)
			g.scale=interpolate(1,0,f32(1-f32(float(g.close_remaining)/float(pair.reload))))
			if g.scale<=0:g.state=3
	if pair.gates[0].state==3 and pair.gates[1].state==3:pair.deleted=true
