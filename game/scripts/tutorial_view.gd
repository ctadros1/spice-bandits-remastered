extends RefCounted

# TutorialView.nib and -adjustFrame 0x64d38. GL callouts are authored by
# CTutorialInterface::SwitchPage 0xb31c8, in screen pixels after projection.
# The main iPad recording uses darker ink than the later 1.14 executable's
# (0.239,0.5411,1). Keep that observed presentation variant explicit.
const INK = Color("#24547d")
const CALLOUT_FONT_SIZE = 27 # SwitchPage's tablet CTextObject constructors.
const CALLOUT_TEXT_WIDTH = 180
# Earlier iPad recording: preserve glyph/art proportions while matching its
# leading, minimum short-message column and four-pixel higher portrait.
# This is an observed presentation selection, not an old UIKit metric oracle.
const GUIDE_LINE_SPACING=2
const GUIDE_MIN_COLUMN=161.0
const GUIDE_Y_OFFSET=-4.0

static func wrapped_callout(font:Font,value:String) -> String:
	return wrap_words(font,value,CALLOUT_TEXT_WIDTH,CALLOUT_FONT_SIZE)

static func wrap_words(font:Font,value:String,width:float,points:int) -> String:
	# Native text bounds exclude trailing whitespace. Godot's automatic word
	# wrapping counts it at the right edge, splitting otherwise fitting lines.
	var lines=PackedStringArray()
	for paragraph in value.split("\n",true):
		var line=""
		for word in paragraph.split(" ",false):
			var candidate=word if line.is_empty() else line+" "+word
			if not line.is_empty() and font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x>width:
				lines.append(line);line=word
			else:line=candidate
		lines.append(line)
	return "\n".join(lines)

static func portrait_measure(font:Font,value:String,width:float,points:int) -> Vector2:
	var measure=font.get_multiline_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,width,points)
	var lines=roundi(measure.y/font.get_height(points))
	measure.y+=lines*GUIDE_LINE_SPACING
	return measure

static func portrait(app, value: String, top: bool) -> Dictionary:
	var source = app.get_node("/root/Content").tutorial_layout
	var hint = source.entries.filter(func(e): return e.id == 22)[0]
	var measure = Vector2.ZERO
	var width = 27.0
	while width <= 4096:
		measure = portrait_measure(app.font,value,width,int(hint.font_size))
		if measure.y <= float(hint.rect[3]): break
		width += 27.0
	var panel_width = minf(app.view_size().x, maxf(GUIDE_MIN_COLUMN,maxf(measure.x, measure.y))+166.0)
	# UILabel and FreeType wrap whitespace differently. Check the text that
	# will actually be drawn so long first-visit messages stay in the227px
	# hint area; use the same27px width steps, preserving art proportions.
	var formatted=wrap_words(app.font,value,panel_width-166,int(hint.font_size))
	while panel_width<app.view_size().x and portrait_measure(app.font,formatted,-1,int(hint.font_size)).y>float(hint.rect[3]):
		panel_width=minf(app.view_size().x,panel_width+27)
		formatted=wrap_words(app.font,value,panel_width-166,int(hint.font_size))
	var origin = Vector2(app.view_size().x-panel_width, app.view_size().y-260.0-70.0)
	if top: origin.y = 30.0 # -adjustFrame, then position4: -height+360.
	origin.y+=GUIDE_Y_OFFSET
	var hit=source.hint_rect
	var result = {"images": [], "labels": [], "hit_rect": Rect2(origin+Vector2(hit[0],hit[1]), Vector2(panel_width,hit[3]))}
	for entry in source.entries:
		var id = int(entry.id)
		var r = entry.rect
		var rect = Rect2(Vector2(r[0], r[1]), Vector2(r[2], r[3]))
		if id == 13: rect.position.x += panel_width-768.0
		elif id in [17, 22]: rect.size.x += panel_width-768.0
		rect.position += origin
		if entry.has("image"): result.images.append({"path": entry.image, "rect": rect,"uikit":true})
		else: result.labels.append({"value": formatted, "rect": rect, "size": int(hint.font_size), "color": Color.BLACK,"center":true,"uikit":true,"line_spacing":GUIDE_LINE_SPACING})
	return result

# All GL declarations below are derived from original SwitchPage instructions.
# The UIKit portrait remains a separate view and lifecycle above.
static func original_visible(app,item:Dictionary,page:int) -> bool:
	if not bool(item.visible):return false
	var key=str(item.id)
	if page==3:
		if key.begins_with("drag_arrow_"):return app.tutorial.CELLS.all(func(cell):return app.sim.tower_at(cell).is_empty())
		var number=0
		if key.begins_with("towers"):number=key.trim_prefix("towers").get_slice("_",0).to_int()
		elif key.begins_with("build_towers_txt_"):number=key.get_slice("_",3).to_int()
		if number>0:return app.sim.tower_at(app.tutorial.CELLS[number-1]).is_empty()
	if page==8 and key.begins_with("towers"):
		var number=key.trim_prefix("towers").get_slice("_",0).to_int()
		var tower=app.sim.tower_at(app.tutorial.CELLS[number-1])
		return tower.is_empty() or int(tower.level)<2
	return true

static func anchor(app,key) -> Vector2:
	match str(key):
		"base":return app.sim.bases[0].pos
		"source":return app.sim.sources[0].pos
		"dock":return app.ClassicUI.dock_origin(app)
		"wallet":return app.ClassicUI.wallet_pose(app).money_position
	return Vector2.ZERO

static func layout(app) -> Dictionary:
	var result={"images":[],"labels":[],"gl_items":[],"hit_rect":Rect2()}
	var flow=app.tutorial
	if flow==null or flow.display_page>=17:return result
	var page=int(flow.display_page)
	if flow.hint_visible and page in [0,4,5,6,8,9,12,13,14,15,16]:
		result=portrait(app,flow.PROMPTS[page-1 if page in [13,15] else page],page in [12,13,14,15,16])
		result["gl_items"]=[]
	elif flow.hint_visible and page in [7,10,11]:
		result=portrait(app,flow.PROMPTS[6 if page==7 else 9],false);result["gl_items"]=[]
	var entries=app.get_node("/root/Content").tutorial_gl_layout.pages.get(str(page),[])
	for declaration in entries:
		if not original_visible(app,declaration,page):continue
		var attached=declaration.anchor!=null
		var origin=anchor(app,declaration.anchor)+Vector2(declaration.offset[0],declaration.offset[1]) if attached else Vector2(declaration.absolute[0],declaration.absolute[1])+Vector2(declaration.offset[0],declaration.offset[1])
		var world=bool(declaration.world)
		var factor=app.map_scale() if world else 1.0
		var position=app.map_origin()+origin*factor if world else origin
		var phase="terrain" if world and declaration.below_objects else "before_hud" if world else "screen"
		var item={"id":declaration.id,"world":world,"phase":phase,"factor":factor,"kind":declaration.kind}
		if declaration.kind=="image":
			var size=Vector2(declaration.size[0],declaration.size[1])
			item.merge({"path":"assets/"+declaration.path,"rect":Rect2(position,size*factor),"native_rect":Rect2(origin,size),"flip_h":declaration.flip_h,"flip_v":declaration.flip_v})
			result.images.append(item)
		else:
			var size=Vector2(declaration.bounds[0],declaration.bounds[1])
			item.merge({"value":declaration.text,"size":int(declaration.font_size),"color":Color.BLACK if int(declaration.font_size)==20 else INK,"rect":Rect2(position,size),"native_rect":Rect2(origin,size)})
			item["formatted"]=wrap_words(app.font,str(item.value),size.x,int(item.size))
			result.labels.append(item)
		result.gl_items.append(item)
	return result

static func image_geometry(rect:Rect2,flip_h:bool,flip_v:bool) -> Dictionary:
	return {"transform":Transform2D(0,Vector2(-1 if flip_h else 1,-1 if flip_v else 1),0,rect.get_center()),"rect":Rect2(-rect.size/2,rect.size)}

static func draw_phase(app,canvas:CanvasItem,phase:String) -> void:
	if app.screen!="game" or app.sim==null or app.sim.paused or app.tutorial==null or app.tutorial.display_page>=17:return
	var alpha=float(app.tutorial.fade_state.alpha)
	for item in app.tutorial_layout.get("gl_items",[]):
		if item.phase!=phase:continue
		canvas.draw_set_transform(app.map_origin() if item.world else Vector2.ZERO,0,Vector2.ONE*(app.map_scale() if item.world else 1.0))
		var rect:Rect2=item.native_rect
		if item.kind=="image":
			var base=Transform2D(0,Vector2.ONE*(app.map_scale() if item.world else 1.0),0,app.map_origin() if item.world else Vector2.ZERO)
			var geometry=image_geometry(rect,item.flip_h,item.flip_v)
			canvas.draw_set_transform_matrix(base*geometry.transform)
			canvas.draw_texture_rect(app.get_node("/root/Content").tex(item.path),geometry.rect,false,Color(1,1,1,alpha))
		else:
			var value=str(item.formatted)
			var color:Color=item.color;color.a*=alpha
			canvas.draw_multiline_string(app.font,rect.position+Vector2(0,app.font.get_ascent(item.size)),value,HORIZONTAL_ALIGNMENT_LEFT,-1,item.size,-1,color)
	canvas.draw_set_transform(Vector2.ZERO)
