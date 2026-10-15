extends RefCounted

var counter=50
var shape={"quads":[],"lines":[]}
func reset() -> void:
	counter=50;shape={"quads":[],"lines":[]}
func prepare(sim,selected:Vector2i,origin:Vector2,radius:float,valid:bool) -> Dictionary:
	if counter>3:
		var cells=[]
		var blocked={}
		var occupied={}
		for tower in sim.towers:occupied[tower.cell]=true
		for base in sim.bases:
			if base.hp>0:blocked[Vector2i(int(base.x),int(base.y))]=true
		for y in range(int(sim.map.hex_height)):
			for x in range(int(sim.map.hex_width)):
				var cell=Vector2i(x,y);var center=sim.center(x,y)
				var top=center-Vector2(int(sim.map.hex_base)/2,int(sim.map.hex_h)/2)
				cells.append({"cell":[x,y],"center":[center.x,center.y],"top":[top.x,top.y],"buildable":sim.buildable(cell) and not occupied.has(cell),"base_blocked":blocked.has(cell)})
		var b=int(sim.map.hex_base);var s=int(sim.map.hex_side);var h=int(sim.map.hex_h)
		shape=geometry(cells,origin,selected,radius,false,sim.within(selected),valid,[[0,0],[b,0],[b+s,h/2],[b,h],[0,h],[-s,h/2]])
		counter=0
	counter+=1
	return shape

# CHexMap::RenderHexLinesInRange0x1043b4. Geometry/color submissions are
# compared with the original routine; Godot's line rasterizer is separate.
static func f32(v:float) -> float:return PackedFloat32Array([v])[0]
static func oval(alpha:float,spacing:float,radius:float,bonus:float,visible:bool=true) -> Array:
	if not visible:return []
	var vertical=f32(f32(radius+bonus)*f32(spacing));var axes=Vector2(f32(vertical*f32(1.44)),vertical)
	var red=f32(f32(0.15)-f32(f32(1-alpha)*f32(0.15)))
	var green=f32(f32(0.55)-f32(f32(1-alpha)*f32(0.55)))
	return [{"filled":true,"axes":axes,"color":Color(red,green,red,f32(alpha*0.25))},
		{"filled":false,"axes":axes,"color":Color(f32(0.2),1,f32(0.2),f32(alpha/3))},
		{"filled":false,"axes":Vector2(f32(axes.x+f32(0.3)),f32(axes.y+f32(0.3))),"color":Color(f32(0.2),1,f32(0.2),f32(alpha*0.25))},
		{"filled":false,"axes":Vector2(f32(axes.x-f32(0.3)),f32(axes.y-f32(0.3))),"color":Color(f32(0.2),1,f32(0.2),f32(alpha*0.25))}]
static func draw_oval(canvas:CanvasItem,position:Vector2,draws:Array,line_width:float) -> void:
	for item in draws:
		var points=PackedVector2Array()
		for i in range(49):points.append(position+Vector2(cos(i*TAU/48)*item.axes.x,sin(i*TAU/48)*item.axes.y))
		if item.filled:canvas.draw_colored_polygon(points,item.color)
		else:canvas.draw_polyline(points,item.color,line_width)
static func distance(a:Vector2,b:Vector2) -> float:
	var dx=f32(a.x-b.x);var dy=f32(a.y-b.y)
	return f32(sqrt(f32(f32(dx*dx)+f32(dy*dy))))
static func in_ellipse(origin:Vector2,point:Vector2,horizontal:float,vertical:float) -> bool:
	var dx=f32(point.x-origin.x);var dy=f32(f32(point.y-origin.y)*f32(horizontal/vertical))
	return f32(f32(dx*dx)+f32(dy*dy))<=f32(horizontal*horizontal)
static func line(result:Array,start:Vector2,finish:Vector2,a:float,b:float) -> void:
	result.append({"start":start,"end":finish,"start_color":Color(1,1,1,a),"end_color":Color(1,1,1,b)})
static func edge(result:Array,start:Vector2,finish:Vector2,origin:Vector2,falloff:float) -> void:
	var a=maxf(0,f32(f32(0.8)-f32(distance(origin,start)/falloff)))
	var b=maxf(0,f32(f32(0.8)-f32(distance(origin,finish)/falloff)))
	line(result,start,finish,a,b)
	if start.x!=finish.x:
		for jitter in [-f32(0.3),f32(0.3)]:line(result,Vector2(f32(start.x+jitter),start.y),Vector2(f32(finish.x+jitter),finish.y),f32(a*0.5),f32(b*0.5))
	if start.y!=finish.y:
		# The native routine reuses the already-halved opacity for diagonals.
		var gain=0.25 if start.x!=finish.x else 0.5
		for jitter in [-f32(0.3),f32(0.3)]:line(result,Vector2(start.x,f32(start.y+jitter)),Vector2(finish.x,f32(finish.y+jitter)),f32(a*gain),f32(b*gain))
static func polygon(top:Vector2,corners:Array,offset:Vector2,color:Color) -> Dictionary:
	var points=PackedVector2Array()
	for corner in corners:points.append(top+Vector2(corner[0],corner[1])+offset)
	return {"points":points,"color":color}
static func geometry(cells:Array,origin:Vector2,selected:Vector2i,radius:float,active:bool,positioned:bool,valid:bool,corners:Array,offset:Vector2=Vector2.ZERO) -> Dictionary:
	var quads=[];var lines=[]
	var horizontal=f32(radius*f32(1.44));var falloff=f32(horizontal*f32(0.8))
	if not active:
		var cell=cells.filter(func(c):return Vector2i(c.cell[0],c.cell[1])==selected)
		if not cell.is_empty():quads.append(polygon(Vector2(cell[0].top[0],cell[0].top[1]),corners,offset,Color(0,1,0,127.0/255) if positioned and valid else Color(1,0,0,127.0/255)))
	for cell in cells:
		var center=Vector2(cell.center[0],cell.center[1])
		if not in_ellipse(origin,center,horizontal,radius):continue
		var top=Vector2(cell.top[0],cell.top[1])+offset
		var pts=[]
		for p in corners:pts.append(top+Vector2(p[0],p[1]))
		edge(lines,pts[0],pts[1],origin,falloff);edge(lines,pts[1],pts[2],origin,falloff)
		if not cell.buildable or bool(cell.get("base_blocked",false)):
			var d=distance(origin,center)
			var opacity=f32(f32(0.68)-f32(d/f32(horizontal*f32(0.68))))
			if opacity>0:quads.append(polygon(Vector2(cell.top[0],cell.top[1]),corners,offset,Color(1,0,0,int(f32(opacity*255))/255.0)))
			opacity=f32(1-f32(d/f32(horizontal*0.5)))
			if opacity>0:
				# Native crosses use the cell center without the submitted offset.
				line(lines,center-Vector2(4,4),center+Vector2(3,3),opacity,opacity)
				line(lines,center+Vector2(-4,3),center+Vector2(3,-4),opacity,opacity)
		edge(lines,pts[5],pts[0],origin,falloff)
	return {"quads":quads,"lines":lines}

static func draw(canvas:CanvasItem,shape:Dictionary,line_width:float) -> void:
	for quad in shape.quads:canvas.draw_colored_polygon(quad.points,quad.color)
	for item in shape.lines:
		if item.start_color.a<=0 and item.end_color.a<=0:continue
		var normal=(item.end-item.start).orthogonal().normalized()*line_width/2
		canvas.draw_polygon(PackedVector2Array([item.start-normal,item.start+normal,item.end+normal,item.end-normal]),PackedColorArray([item.start_color,item.start_color,item.end_color,item.end_color]))
