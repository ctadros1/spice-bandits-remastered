extends Node2D
# QA-only colored swatches independently checked against T+(1-T)*D.
const Status=preload("res://scripts/creep_status_view.gd")
var samples=[]
var texture:Texture2D
func _init():
	var image=Image.create(4,1,false,Image.FORMAT_RGBA8)
	for x in range(4):image.set_pixel(x,0,[Color8(0,0,0),Color8(92,37,166),Color8(17,73,41),Color8(255,255,255)][x])
	texture=ImageTexture.create_from_image(image)
	for coefficient in [0.0,0.25,Status.coefficient(0.3),1.0]:
		for background in [Color8(0,0,0),Color8(31,87,151),Color8(255,255,255),Color8(137,41,201)]:samples.append({"coefficient":coefficient,"background":background})
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=4000
func _draw():
	for index in range(samples.size()):
		var pos=Vector2(index%4*128+256,index/4*32+200)
		var sample=samples[index]
		draw_rect(Rect2(pos,Vector2(128,32)),sample.background)
		Status.draw(self,texture,Rect2(pos,Vector2(128,32)),sample.coefficient)
		# An opaque later actor must cover the second half of each swatch.
		draw_rect(Rect2(pos+Vector2(0,16),Vector2(128,16)),Color8(28,157,69))
func audit(image:Image,stretch:Transform2D) -> Dictionary:
	var maximum=0.0;var cover_exact=true;var channels=0
	for index in range(samples.size()):
		var sample=samples[index]
		for x in range(4):
			var pos=Vector2(index%4*128+256+x*32+16,index/4*32+200+8)
			var actual=image.get_pixelv(Vector2i(stretch*pos))
			var source=texture.get_image().get_pixel(x,0)
			for channel in range(3):
				var term=source[channel]*sample.coefficient
				var expected=term+sample.background[channel]*(1-term)
				maximum=maxf(maximum,absf(actual[channel]-expected)*255);channels+=1
			cover_exact=cover_exact and image.get_pixelv(Vector2i(stretch*(pos+Vector2(0,16))))==Color8(28,157,69)
	return {"sampled_rgb_channels":channels,"maximum_formula_byte_error":maximum,"later_actor_exact_cover":cover_exact,"tolerance_reason":"One RGBA8 fixed-function rounding step; no original GPU pixel parity claim."}
