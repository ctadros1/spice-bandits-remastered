extends Control

# CTransitionScreen0xb1ee0..0xb2c44. State and geometry follow the original
# float32 updates. The seed replaces the unrecovered global rand stream.
signal covered
signal revealed
var phase=3
var type=9
var start=Vector2.ZERO
var left=0.0
var duration=0.0
var circle_left=0.0
var radius=0.0
var opacity=0.0
var nodes:Array=[]
var texture:Texture2D
var rng=RandomNumberGenerator.new()

static func f32(value:float) -> float:
	return PackedFloat32Array([value])[0]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	visible=false

func initialize_nodes(random_values:Array=[]) -> void:
	nodes.clear()
	var spacing=Vector2(f32(size.x/3),f32(size.y/3))
	var point=Vector2.ZERO
	var count=(int(f32(size.x/spacing.x))+1)*(int(f32(size.y/spacing.y))+1)
	var cursor=0
	for i in range(count):
		var numbers=[]
		for j in range(3):
			numbers.append(int(random_values[cursor])%100 if cursor<random_values.size() else rng.randi()%100)
			cursor+=1
		var jitter=Vector2(f32(f32(numbers[0]/100.0)*f32(size.x/4)),f32(f32(numbers[1]/100.0)*f32(size.y/4)))
		nodes.append({"pos":Vector2(f32(point.x+jitter.x),f32(point.y+jitter.y)),"scale":0.0,"left":0.0,"duration":0.0,"max_scale":f32(f32(f32(numbers[2]/100.0)*8.0)+8.0),"visible":true,"phase":3})
		point.x=f32(point.x+spacing.x)
		if point.x>size.x:point.x=0;point.y=f32(point.y+spacing.y)

func open(style:int=9,texture_index:int=-1,random_values:Array=[]) -> void:
	if phase not in [2,3]:return
	type=style
	var index=texture_index if texture_index>=0 else int(rng.randi()%4)
	texture=get_node("/root/Content").tex("assets/transition/transition_%d.png"%index)
	initialize_nodes(random_values)
	var corners=[Vector2(0,0),Vector2(0.5,0),Vector2(1,0),Vector2(0,0.5),Vector2(1,0),Vector2(0,1),Vector2(0.5,1),Vector2(1,1)]
	var corner=style if style<8 else int(rng.randi()%8)
	start=corners[corner]*size
	phase=0;left=0.320000022649765;duration=left;circle_left=f32(0.92);radius=0
	opacity=1.0 if style==12 else 0.0
	visible=true;mouse_filter=Control.MOUSE_FILTER_STOP
	if style==10:
		phase=1;left=0;radius=f32(size.length())
		for node in nodes:node.phase=1;node.left=0;node.scale=node.max_scale
	queue_redraw()

func close(style:int=9) -> void:
	if phase!=1:return
	start=size-start
	phase=2;left=f32(0.512);duration=left;circle_left=f32(0.52);type=style
	if style==12:opacity=1.0
	elif style==11:opacity=0.0
	queue_redraw()

func advance(delta:float) -> void:
	if phase==3:return
	var previous=phase
	var dt=f32(delta)
	var diagonal_squared=f32(size.x*size.x+size.y*size.y)
	var diagonal=f32(sqrt(diagonal_squared))
	if phase in [0,2]:
		left=f32(left-dt)
		var progress=f32(left/duration)
		if type==13:pass
		elif phase==0 and type==11:
			opacity=f32(1.0-progress)
			if opacity>=1:opacity=1;phase=1
		elif phase==2 and type==12:
			opacity=progress
			if opacity<=0:opacity=0;phase=3
		else:
			circle_left=f32(circle_left-dt)
			var asset_diagonal=f32(texture.get_size().length())
			var busy=false
			if phase==0:
				var growth=f32(1.0-progress)
				opacity=minf(growth,1.0)
				radius=f32(diagonal*f32(1.0-f32(circle_left/f32(0.92))))
				var threshold=f32(diagonal_squared*opacity)
				for node in nodes:
					var distance_squared=f32(f32(pow(f32(node.pos.x-start.x),2))+f32(pow(f32(node.pos.y-start.y),2)))
					if distance_squared<threshold:
						if node.phase==3:node.phase=0;node.duration=0.240000009536743;node.left=node.duration;node.visible=true
						if sqrt(distance_squared)+f32(node.scale*asset_diagonal)<radius:node.left=0;node.visible=false
						if node.phase!=1:busy=true
				if not busy and progress<0:phase=1
			else:
				opacity=0
				var circle_progress=f32(circle_left/f32(0.52))
				radius=0 if circle_progress<0 else f32(diagonal*circle_progress)
				var threshold=maxf(0,f32(diagonal_squared*progress))
				for node in nodes:
					var distance_squared=f32(f32(pow(f32(node.pos.x-start.x),2))+f32(pow(f32(node.pos.y-start.y),2)))
					if threshold<distance_squared:
						if node.phase==0:node.phase=2;node.duration=0.384000033140182;node.left=f32(node.duration-node.left)
						elif node.phase==1:node.phase=2;node.duration=0.384000033140182;node.left=node.duration
						if node.phase!=3:busy=true
					if radius<f32(f32(sqrt(distance_squared))+f32(node.scale*asset_diagonal)):node.visible=true
				if threshold==0 and not busy and circle_progress<0:phase=3
	for node in nodes:
		if node.phase in [0,2]:
			node.left=f32(node.left-dt)
			var progress=f32(node.left/node.duration)
			node.scale=f32(node.max_scale*(progress if node.phase==2 else f32(1-progress)))
			if node.left<0:node.scale=0 if node.phase==2 else node.max_scale;node.phase=3 if node.phase==2 else 1
	if phase==3:visible=false;mouse_filter=Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	if phase!=previous:
		if phase==1:covered.emit()
		elif phase==3:revealed.emit()

func _process(delta:float) -> void:
	advance(delta)

func _draw() -> void:
	if phase==3 or type==13:return
	if phase==1:draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK);return
	if type not in [11,12]:
		draw_circle(start,maxf(0,radius),Color.BLACK)
		for node in nodes:
			if node.phase!=3 and node.visible:
				var dimensions=texture.get_size()*maxf(0,node.scale)
				draw_texture_rect(texture,Rect2(node.pos-dimensions/2,dimensions),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,clampf(opacity,0,1)))
