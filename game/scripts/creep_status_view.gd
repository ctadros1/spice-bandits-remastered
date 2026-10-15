extends RefCounted
# Full CCreep.Render0x7f5c8 calls RenderFrame directly, after both normal
# animators. Its status color ignores animator opacity and resource air class.
static func coefficient(light:float) -> float:
	return Vector2(0.5+Vector2(light*0.5,0).x,0).x
static func active(state:int,freeze_remaining:int,slow_pending:float) -> bool:
	return state not in [2,3] and (freeze_remaining>0 or slow_pending>0)
static func layers(source:Array) -> Array:
	if source.is_empty():return []
	var result=[source[0]]
	if source.size()>1 and float(source[1].alpha)!=0:result.append(source[1])
	return result

static func draw(canvas:CanvasItem,texture:Texture2D,rect:Rect2,coefficient:float) -> void:
	canvas.draw_lcd_texture_rect_region(texture,rect,Rect2(Vector2.ZERO,texture.get_size()),Color(1,1,1,coefficient))
