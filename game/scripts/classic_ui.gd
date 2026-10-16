extends RefCounted
const Wallet=preload("res://scripts/hud_wallet_view.gd")

# Geometry recovered from CRoom::LoadGUI/Resize/RenderTowerDock (1.14).
# UI art stays in original iPad points; only authored repeating strips stretch.
const ATLAS = "assets/gui/ingame_menus.png"
const MAGIC = ["m_freeze", "m_lsd", "m_actdef", "m_mine", "m_portal"]
const MAGIC_ICON_Y = {"m_portal":272,"m_freeze":312,"m_mine":352,"m_actdef":392,"m_lsd":432}
const Wave=preload("res://scripts/wave_view.gd")
const ModeItem=preload("res://scripts/mode_item_view.gd")
const PromotionView=preload("res://scripts/promotion_view.gd")

static func shortcuts(app) -> Array:
	# UpdateItems0x97628 explicitly pins these three in Training. Other
	# tablet battles have four slots ordered by last use (NSUserDefaults).
	if app.tutorial!=null:return ["m_lsd","m_actdef","m_mine"]
	return app.magic_shortcuts

static func region(app, source: Rect2, target: Rect2, tint: Color = Color.WHITE) -> void:
	app.draw_texture_rect_region(Content.tex(ATLAS), target, source, tint)

static func dock_origin(app) -> Vector2:
	return Vector2(app.view_size().x/2.0-228.0+37.0, app.view_size().y-66.0)

static func tower_rect(app, index: int) -> Rect2:
	return Rect2(dock_origin(app)+Vector2(19+index*59, -9), Vector2(59,75))

static func tower_icon(app, type: int, gray:bool=false) -> Dictionary:
	var definition = app.sim.tower_data(type,1)
	return Content.extra_frame("towers/"+str(definition.filename), "icon_gray" if gray else "icon")

static func magic_rect(app, index: int) -> Rect2:
	return Rect2(Vector2(804+index*60-20.8,app.view_size().y-44.8),Vector2(41.6,41.6))

static func hud_region(app,canvas:CanvasItem,source:Rect2,target:Rect2,tint:Color=Color.WHITE) -> void:
	canvas.draw_texture_rect_region(Content.tex(ATLAS),target,source,tint)

static func hud_text(app,canvas:CanvasItem,pos:Vector2,value:String,size:int=18,color:Color=Color.WHITE) -> void:
	canvas.draw_string(app.bold,pos+Vector2.ONE,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,0.8))
	canvas.draw_string(app.bold,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func wallet_pose(app) -> Dictionary:
	return Wallet.pose(app.view_size().x,app.font,int(app.sim.money),int(Profile.data.spice))

static func wallet_text(app,canvas:CanvasItem,position:Vector2,value:String,points:int,ink:Color=Color(1,1,1,.8)) -> void:
	var baseline=position+Vector2(0,app.font.get_ascent(points))
	canvas.draw_string(app.font,baseline+Wallet.MONEY_SHADOW_OFFSET,value,HORIZONTAL_ALIGNMENT_LEFT,-1,points,Color(0,0.2540000081062317,0.6039000153541565,0.800000011920929))
	canvas.draw_string(app.font,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,points,ink)

static func draw_hud(app,canvas:CanvasItem) -> void:
	var size=app.view_size()
	var origin=dock_origin(app)
	hud_region(app,canvas,Rect2(0,9,456,66),Rect2(origin,Vector2(456,66)))
	hud_region(app,canvas,Rect2(456,9,56,66),Rect2(origin+Vector2(456,0),Vector2(size.x-origin.x-456,66)))
	for i in range(6):
		var type=app.Simulation.ROOT_TYPES[i]
		var definition=app.sim.tower_data(type,1)
		var enabled=app.sim.can_unlock(definition) and app.sim.money>=int(definition.price)
		var icon=tower_icon(app,type,not enabled)
		if icon.is_empty():continue
		var texture:Texture2D=icon.texture
		var pos=Vector2(origin.x+19+i*59,size.y-texture.get_height())+icon.offset
		if app.build_type==type:
			hud_region(app,canvas,Rect2(408,246,33,33),Rect2(pos+Vector2(10,18),Vector2(33,33)))
		canvas.draw_texture_rect(texture,Rect2(pos,texture.get_size()),false)
		var ink=Color(0.0745,0.27,0.443,1 if app.sim.can_unlock(definition) else 0.3) if app.sim.money>=int(definition.price) else Color(1,1,1,0.36)
		var price=str(int(definition.price))
		canvas.draw_string(app.font,Vector2(origin.x+19+i*59+45,size.y-13+app.font.get_ascent(14)),price,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	# Wand opens the complete original ability inventory; three shortcuts stay
	# beside the tower tray, as in the tablet recording.
	hud_region(app,canvas,Rect2(580,468,44,44),Rect2(origin+Vector2(387,15),Vector2(44,44)),Color(1,1,1,0.6))
	var shortcut_keys=shortcuts(app)
	for i in range(shortcut_keys.size()):
		var key=shortcut_keys[i]
		var rect=magic_rect(app,i)
		var highlighted={12:"m_lsd",14:"m_actdef",16:"m_mine"}.get(app.tutorial.display_page,"") if app.tutorial!=null else ""
		var alpha=0.3 if not highlighted.is_empty() and highlighted!=key else 1.0
		var tint=Color(1,1,1,alpha)
		hud_region(app,canvas,Rect2(758,MAGIC_ICON_Y[key],40,40),Rect2(rect.get_center()-Vector2(16,16),Vector2(32,32)),tint)
		hud_region(app,canvas,Rect2(512,375,52,52),rect,tint)
		var amount=int(app.sim.abilities.get(key,0))
		hud_region(app,canvas,Rect2(543,272,35,25) if amount>0 else Rect2(630,273,59,25),Rect2(rect.get_center()+Vector2(-14,0),Vector2(28,20)) if amount>0 else Rect2(rect.get_center()+Vector2(-23.6,0),Vector2(47.2,20)),tint)
		if amount>0:
			var value=str(amount);var width=app.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			canvas.draw_string(app.font,rect.get_center()+Vector2(-width/2,3+app.font.get_ascent(16)),value,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,1,1,alpha))
		else:
			var price=int(magic_offer(key).get("pricespice",0));var value="%dsp"%price if price<10 else "%ds"%price
			var width=app.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x*0.8
			# RenderMagicItems0x99190 splits the zero and refill price on the
			# wide badge; it scales the original14pt price text by0.8.
			canvas.draw_string(app.font,rect.get_center()+Vector2(6,3+app.font.get_ascent(16)),"0",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,1,1,alpha))
			canvas.draw_set_transform(rect.get_center()+Vector2(-10-width/2,6),0,Vector2.ONE*0.8)
			canvas.draw_string(app.font,Vector2(0,app.font.get_ascent(14)),value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0,1,1,alpha))
			canvas.draw_set_transform(Vector2.ZERO)
	# Single-player info bar: black repeating strip, blue money/spice plate,
	# source menu art and the original narrow XP meter.
	var wallet=wallet_pose(app)
	hud_region(app,canvas,Rect2(0,297,87,38),Rect2(0,0,size.x,38))
	hud_region(app,canvas,Rect2(0,335,400,41),Rect2(wallet.plate_position,Vector2(400,41)))
	hud_region(app,canvas,Rect2(441,208,71,45),Rect2(size.x-71,0,71,45))
	hud_region(app,canvas,Rect2(798,272,38,38),Rect2(0,0,38,38))
	hud_text(app,canvas,Vector2(6,22),"%dx"%app.speed,17,Color("#6e7b83"))
	wallet_text(app,canvas,wallet.money_position,wallet.money,Wallet.MONEY_SIZE,Wallet.flash_color(app.hud_money_flash))
	wallet_text(app,canvas,wallet.spice_position,wallet.spice,Wallet.SPICE_SIZE)
	var xp=float(app.displayed_xp())
	var next=Profile.level_threshold(int(Profile.data.level))
	var lower=Profile.level_threshold(int(Profile.data.level)-1)
	var xp_text="xp: "+SpiceNative.format_xp(xp)+"/"+SpiceNative.format_xp(next)
	var xp_width=app.font.get_string_size(xp_text,HORIZONTAL_ALIGNMENT_LEFT,-1,Wallet.XP_SIZE).x
	var xp_pose=Wallet.xp_pose(size.x,Wallet.f32(xp),Wallet.f32(next-xp),int(lower),int(Profile.data.level),xp_width)
	hud_region(app,canvas,Rect2(368,318,80,17),xp_pose.frame)
	if xp_pose.fill.size.x>0:hud_region(app,canvas,Rect2(302,328,xp_pose.fill.size.x,7),xp_pose.fill)
	var baseline=xp_pose.text+Vector2(0,app.font.get_ascent(Wallet.XP_SIZE))
	canvas.draw_string(app.font,baseline+Vector2(0,1),xp_text,HORIZONTAL_ALIGNMENT_LEFT,-1,Wallet.XP_SIZE,Color(0.6392,0.854,1,0.7))
	canvas.draw_string(app.font,baseline,xp_text,HORIZONTAL_ALIGNMENT_LEFT,-1,Wallet.XP_SIZE,Color(0,0.09,0.2745,1))
	# Wave numbers and their authored type symbols are separate cells. The
	# previous text incorrectly showed the next-wave timer in this strip.
	var indicators=[Rect2(664,436,14,14),Rect2(520,440,18,14),Rect2(490,440,16,6),Rect2(470,440,14,14)]
	for row in Wave.battle_rows(app.sim,app.wave_collapse):
		var x=int(row.x)
		if x<-60 or x>=size.x-280:continue
		var wave=app.sim.config.waves[row.number-1]
		var segment_x=float(x)
		for segment in Wave.indicators(wave.creep_ids):
			canvas.draw_rect(Rect2(segment_x,0,segment.width,4),segment.color)
			segment_x=Wave.f32(segment_x+segment.width)
		hud_region(app,canvas,Rect2(390,460,60,26),Rect2(x,0,60,26))
		var indicator=int(wave.get("indicator",4))
		if indicator<4:
			var source:Rect2=indicators[indicator]
			hud_region(app,canvas,source,Rect2(Vector2(x+10,16-source.size.y/2),source.size))
		canvas.draw_string(app.font,Vector2(x+35,6+app.font.get_ascent(20)),str(row.number),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)

static func magic_offer(key:String) -> Dictionary:
	for offer in Content.catalog.shopList:
		if int(offer.itemtype)==0 and str(offer.tag)==key:return offer
	return {}

static func info_text(app,point:Vector2,value:String,points:int,color:Color=Color.WHITE,canvas:CanvasItem=null) -> void:
	if canvas==null:canvas=app
	canvas.draw_string(app.font,point+Vector2(0,app.font.get_ascent(points)),value,HORIZONTAL_ALIGNMENT_LEFT,-1,points,color)

static func draw_tower_info(app,canvas:CanvasItem=null) -> void:
	if canvas==null:canvas=app
	# RenderTowerInfoPanel0xf2e60 and SetupTowerInfoLabels0xedc14. This
	# authored sloping panel overlaps beneath the tower tray at its right edge.
	var tower=app.sim.find_tower(app.selected_tower)
	var type=app.build_type if app.build_type>0 else app.hovered_tower_type
	var definition=tower.def if not tower.is_empty() else app.sim.tower_data(type,1) if type>0 else {}
	if definition.is_empty():return
	var height=app.view_size().y
	var alpha=app.tower_panel_alpha() if not tower.is_empty() else 1.0
	var white=Color(1,1,1,alpha)
	region(canvas,Rect2(0,376,377,110),Rect2(0,height-110,377,110),white)
	var center=Vector2(49,height-70)
	app.extra_sprite("towers/"+str(definition.filename),"pad1",center,"",Vector2.ONE,white)
	app.draw_sprite_frame(Content.frame("towers/"+str(definition.filename),"Idle",0),center,white,0,Vector2.ONE)
	info_text(app,Vector2(98,height-98),str(definition.name),20,white,canvas)
	info_text(app,Vector2(98,height-78),str(definition.get("description","")),13,white,canvas)
	var form=int(definition.type)
	var support=form in [16,17,18]
	var damage=""
	if support:damage="+%d%%"%int(definition.get("dmg_bonus",0))
	elif form in [7,9]:damage=str(int(definition.get("poison_damage",0)))
	elif form not in [8,11]:damage=str(int(definition.get("damage",0)))
	var reload=float(definition.get("rof",0))
	var rof="+%d%%"%int(definition.get("rof_bonus",0)) if support else "%.1f"%((int(1000.0/reload*100)+0.5)/100.0) if reload>0 else ""
	var range="+%d%%"%int(definition.get("range_bonus",0)) if support else "%.1f"%((int(float(definition.get("range",0))/1000.0*100)+0.5)/100.0)
	if form not in [8,11]:region(canvas,Rect2(360,124,26,21),Rect2(96,height-29,26,21),white)
	region(canvas,Rect2(360,101,26,20),Rect2(173,height-28,26,20),white)
	region(canvas,Rect2(363,75,20,21),Rect2(248,height-28,20,21),white)
	for row in [[122,damage],[203,rof],[275,range]]:info_text(app,Vector2(row[0],height-25),str(row[1]),17,white,canvas)
	var upgrade_price=int(definition.price)
	if not tower.is_empty():
		var options=app.sim.upgrade_options(tower)
		if not options.is_empty():upgrade_price=int(app.sim.tower_data(options[0][0],options[0][1]).price)
		info_text(app,Vector2(9,height-27),"$%d"%app.sim.sell_price(tower),20,Color(1,0.09,0,alpha),canvas)
	info_text(app,Vector2(53,height-27),"$%d"%upgrade_price,20,Color(0,0.706,1,alpha),canvas)

static func centered(app, path: String, position: Vector2, angle: float=0.0, scale: float=1.0, pivot:Vector2=Vector2.ZERO) -> void:
	var texture=Content.tex(path)
	if texture==null:return
	app.draw_set_transform(position+pivot*scale,deg_to_rad(angle),Vector2.ONE*scale)
	app.draw_texture_rect(texture,Rect2(-texture.get_size()/2.0-pivot,texture.get_size()),false)
	app.draw_set_transform(Vector2.ZERO)

static func draw_loading(app, time: float) -> void:
	var size=app.view_size()
	var center=app.view_center()
	var root="assets/gui/loader/loadinger_"
	app.draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
	var noise=Content.tex(root+"noise.png")
	for y in range(-1,int(size.y/128)+2):
		for x in range(-1,int(size.x/128)+2):
			app.draw_texture_rect(noise,Rect2(x*128,y*128,128,128),false)
	centered(app,root+"light.png",center,0,2.3)
	centered(app,root+"space.png",center,time*2)
	# Render0xa7a58: scale min(1,t/40+.5); diagonal offset60-33.3333*scale.
	var earth_scale=minf(1,time/40.0+0.5)
	var offset=60-earth_scale*33.333335876464844
	centered(app,root+"earth.png",center+Vector2(-offset,offset),0,earth_scale)
	centered(app,root+"illumi.png",center+Vector2.ONE*0.5)
	centered(app,root+"wire.png",center+Vector2(-64,64),-5,1,Vector2(-16,0))
	var swing=sin(time*PI)
	centered(app,root+"elka.png",center+Vector2(68.5,20),swing,1,Vector2(-17,0))
	centered(app,root+"picture.png",center+Vector2(-65,-38),swing,1,Vector2(-47,0))
	var destination="Next stop: %s!"%app.loading_name
	var width=app.font.get_string_size(destination,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	app.text(Vector2(center.x-width/2,size.y-144),destination,18)
	var fact="Did you know that tea was invented by space pirates?"
	width=app.font.get_string_size(fact,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	app.text(Vector2(center.x-width/2,size.y-74),fact,18,Color(0.65,0.65,0.65,clampf(time-0.4,0,1)))

static func mode_rows(app) -> Array:
	var loc=Content.location(app.selected_location)
	var p=app.world_origin()+Vector2(float(loc.x),float(loc.y))*app.world_zoom+Vector2(0,-15)
	# CChooseConfigPanel constructor0x87f68 supplies the six fan offsets.
	var rows=[]
	var offsets=[Vector2(51,-224),Vector2(20,-151),Vector2(4,-78),Vector2(4,78),Vector2(20,151),Vector2(51,224)]
	var types=["1","3","6","5","4","2"]
	var names=["Normal","Sudden Death","Air Attack","Camps","Cooperative","Competition"]
	var icons=["norm","sd","air","cmp","coo","mp"]
	for i in range(6):
		if app.selected_location=="1" and i!=0:continue
		var configs=Content.catalog.offlineConfigs.filter(func(c):return str(c.location)==app.selected_location and str(c.gametype)==types[i] and not c.waves.is_empty())
		var config=configs[0] if not configs.is_empty() else {}
		var metadata=Content.catalog.configs.filter(func(c):return str(c.location)==app.selected_location and str(c.gametype)==types[i])
		var player_count=int(metadata[0].get("numplayers",1)) if not metadata.is_empty() else 1
		var enabled=i<3 and not config.is_empty() and Profile.available(config)
		var offset=Vector2(4,-78) if app.selected_location=="1" else offsets[i]
		var won=not config.is_empty() and Profile.unlocked(str(config.get("grantsunlock","")))
		rows.append({"point":p+offset,"rect":Rect2(p+offset-Vector2(35,35),Vector2(364,98)),"name":"Training" if app.selected_location=="1" else names[i],"icon":icons[i],"enabled":enabled,"config":config,"player_count":player_count,"index":i,"mode":1 if not enabled else 3 if won else 2,"star":not config.is_empty() and int(Profile.data.completed.get(str(config.configid),0))>0})
	return rows

static func modes_controls(app) -> void:
	var marker=app.world_origin()+Vector2(float(Content.location(app.selected_location).x),float(Content.location(app.selected_location).y))*app.world_zoom+Vector2(0,-15)
	var animation_key=app.selected_location+":"+str(app.fan_opened)
	if animation_key!=app.mode_animation_key:app.mode_animation_key=animation_key;app.mode_states.clear()
	for row in mode_rows(app):
		var group=Control.new();group.mouse_filter=Control.MOUSE_FILTER_IGNORE;group.set_meta("fan_offset",row.point-marker);group.set_meta("fan_point",row.point);group.set_meta("fan_index",row.index);app.ui.add_child(group)
		if not app.mode_states.has(row.index):
			var state=ModeItem.initial()
			if app.fan_opened<0:state.phase=1.0;state.geometry_alpha=1.0;state.text_phase=1.0;state.text_alpha=1.0
			app.mode_states[row.index]=state
		var copy=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;group.add_child(copy)
		var pose=ModeItem.render_pose(app.mode_states[row.index],row.point,row.mode,row.star)
		group.set_meta("fan_mode",row.mode);group.set_meta("fan_star",row.star)
		var plate=TextureRect.new();plate.texture=app.atlas("assets/lobby/choose_level.png",pose.plate_region);plate.position=pose.plate_rect.position;plate.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.set_meta("mode_part","plate")
		if row.enabled:
			var material=CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;plate.material=material
		else:
			var shader=Shader.new()
			shader.code="shader_type canvas_item; render_mode blend_disabled; uniform sampler2D scene: hint_screen_texture, repeat_disable, filter_nearest; varying float opacity; void vertex(){opacity=COLOR.a;} void fragment(){ vec4 mask=texture(TEXTURE,UV); COLOR=vec4(max(vec3(0.0),texture(scene,SCREEN_UV).rgb-mask.rgb*mask.a*opacity),1.0); }"
			var material=ShaderMaterial.new();material.shader=shader;plate.material=material
		group.add_child(plate)
		if row.enabled:
			var circle=TextureRect.new();circle.texture=app.atlas("assets/lobby/choose_level.png",pose.circle_region);circle.position=pose.circle_rect.position;circle.mouse_filter=Control.MOUSE_FILTER_IGNORE;circle.set_meta("mode_part","circle")
			var material=CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;circle.material=material;group.add_child(circle)
		else:
			var circle_copy=BackBufferCopy.new();circle_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;group.add_child(circle_copy)
			var circle=TextureRect.new();circle.texture=app.atlas("assets/lobby/choose_level.png",pose.circle_region);circle.position=pose.circle_rect.position;circle.mouse_filter=Control.MOUSE_FILTER_IGNORE;circle.material=plate.material;circle.set_meta("mode_part","circle");group.add_child(circle)
		var icon_path=("assets/derived/gray50/lobby/icons/%s_1.png" if row.mode==1 else "assets/lobby/icons/%s_1.png" if row.mode==3 else "assets/lobby/icons/%s_0.png")%row.icon
		var icon=app.image_control(group,icon_path,pose.icon_rect);icon.set_meta("mode_part","icon")
		var title_color=ModeItem.title_ink(row.mode,1)
		var shadow_entry=Content.mode_text.entries.filter(func(e):return e.text==row.name)[0]
		var shadow_position=pose.title_point-Vector2.ONE*float(shadow_entry.padding)+Vector2(0,app.bold.get_ascent(ModeItem.TITLE_SIZE)-float(shadow_entry.baseline))
		var shadow=app.image_control(group,shadow_entry.path,Rect2(shadow_position,Vector2(shadow_entry.size[0],shadow_entry.size[1])));shadow.set_meta("mode_part","title_shadow")
		var title=app.label(group,row.name,Rect2(pose.title_point,Vector2(260,36)),ModeItem.TITLE_SIZE,title_color);title.add_theme_font_override("font",app.bold);title.set_meta("mode_part","title");title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		var captions=Content.interface_tutorials.mode_texts
		if row.player_count>1:
			var count_text=str(row.player_count)+" "+str(captions.players)
			var title_width=app.bold.get_string_size(row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,ModeItem.TITLE_SIZE).x
			var counts=ModeItem.count_pose(row.point,row.mode,row.star,title_width)
			var count_shadow=Content.mode_text.entries.filter(func(e):return e.text==count_text)[0]
			var count_shadow_point=counts.players_shadow-Vector2.ONE*float(count_shadow.padding)+Vector2(0,app.bold.get_ascent(ModeItem.PLAYER_COUNT_SIZE)-float(count_shadow.baseline))
			var underlay=app.image_control(group,count_shadow.path,Rect2(count_shadow_point,Vector2(count_shadow.size[0],count_shadow.size[1])));underlay.set_meta("mode_part","player_count_shadow")
			var players=app.label(group,count_text,Rect2(counts.players,Vector2(120,20)),ModeItem.PLAYER_COUNT_SIZE,title_color);players.add_theme_font_override("font",app.bold);players.autowrap_mode=TextServer.AUTOWRAP_OFF;players.set_meta("mode_part","player_count");players.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		var caption=str(captions.training) if app.selected_location=="1" else str(captions.normal) if row.index==0 else str(captions.sudden_death) if row.index==1 else str(captions.air_attack)
		if not row.enabled:caption=str(captions.offline) if row.player_count>1 else str(captions.locked)
		var caption_color=ModeItem.caption_ink(1)
		var description=app.label(group,caption,Rect2(pose.subtitle_point,Vector2(260,22)),ModeItem.CAPTION_SIZE,caption_color);description.add_theme_font_override("font",app.bold);description.autowrap_mode=TextServer.AUTOWRAP_OFF;description.set_meta("mode_part","subtitle");description.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		if row.mode==3 and row.star:
			var star=TextureRect.new();star.texture=app.atlas("assets/lobby/level_indicators_atlas.png",Rect2(110,326,32,32));star.position=pose.star_rect.position;star.mouse_filter=Control.MOUSE_FILTER_IGNORE;star.set_meta("mode_part","star");group.add_child(star)
		var hit=app.invisible_button(group,row.name,row.rect,app.start_mission.bind(str(row.config.get("configid",""))))
		hit.disabled=not row.enabled;hit.set_meta("mode_enabled",row.enabled)
	update_modes(app)

static func interpolate_ease(value:float) -> float:
	# Original InterpolateEase0x110674: x^3(10-15x+6x^2).
	var x=clampf(value,0,1)
	return x*x*x*(10.0+x*(-15.0+6.0*x))

static func update_modes(app,dt_ms:float=0) -> void:
	if app.selected_location.is_empty():return
	var loc=Content.location(app.selected_location)
	var marker=app.world_origin()+Vector2(float(loc.x),float(loc.y))*app.world_zoom+Vector2(0,-15)
	for group in app.ui.get_children():
		if group.has_meta("fan_offset"):
			var state=app.mode_states[group.get_meta("fan_index")]
			ModeItem.advance(state,dt_ms,marker,Vector2(group.get_meta("fan_offset")))
			var pose=ModeItem.render_pose(state,Vector2(group.get_meta("fan_point")),group.get_meta("fan_mode"),group.get_meta("fan_star"))
			group.position=Vector2(state.x,state.y)-Vector2(group.get_meta("fan_point"))
			for child in group.get_children():
				if child is Button:child.disabled=not child.get_meta("mode_enabled") or not state.opened or state.phase<1.0
				elif child is CanvasItem:
					match str(child.get_meta("mode_part","")):
						"plate":child.visible=pose.plate_visible and pose.plate_rect.size.x>0;child.size=pose.plate_rect.size;child.modulate.a=pose.plate_alpha
						"circle":child.modulate.a=pose.circle_alpha
						"icon":child.modulate.a=pose.icon_alpha
						"title","player_count":
							var ink=ModeItem.title_ink(group.get_meta("fan_mode"),state.text_alpha)
							child.add_theme_color_override("font_color",Color(ink.r,ink.g,ink.b,1));child.modulate.a=ink.a
						"title_shadow","player_count_shadow":child.modulate=ModeItem.shadow_ink(group.get_meta("fan_mode"),state.text_alpha)
						"subtitle":child.modulate.a=pose.subtitle_alpha
						"star":child.modulate.a=state.text_alpha

static func result_bar(app, canvas:CanvasItem) -> void:
	var origin=app.results_origin()
	var finish=float(app.displayed_xp())
	var current=result_xp(app)
	var level=1
	while current>=Profile.level_threshold(level):level+=1
	var lower=Profile.level_threshold(level-1)
	var upper=Profile.level_threshold(level)
	var fraction=clampf((current-lower)/maxf(1,upper-lower),0,1)
	var pos=origin+Vector2(332,315)
	canvas.draw_texture_rect_region(Content.tex(ATLAS),Rect2(pos,Vector2(176,28)),Rect2(579,384,176,28))
	var width=172*fraction
	if width>0:canvas.draw_texture_rect_region(Content.tex(ATLAS),Rect2(pos+Vector2(2,2),Vector2(width,24)),Rect2(579,412,width,24))
	canvas.draw_string(app.font,pos+Vector2(181,19),str(int(upper)),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#7a8486"))
	canvas.draw_string(app.font,origin+Vector2(332,363),"your XP: "+SpiceNative.format_xp(finish,false),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#465050"))

static func result_bar_tip(app) -> Vector2:
	var age=maxf(0,app.elapsed_ui-app.result_started)
	var current=result_xp(app)
	var level=1
	while current>=Profile.level_threshold(level):level+=1
	var lower=Profile.level_threshold(level-1)
	var upper=Profile.level_threshold(level)
	var width=172*clampf((current-lower)/maxf(1,upper-lower),0,1)
	return app.results_origin()+Vector2(334+width,329)

static func result_xp(app) -> float:
	# Native float32 update clocks are kept separate from rendered XP.
	var total=0.0
	for medal in app.battle_medals:total+=float(medal.get("xp_award",0))/10.0
	var start=float(app.battle_initial_xp)
	var finish=float(app.displayed_xp())
	if app.sim.outcome!="victory":return finish
	var current=lerpf(start,maxf(start,finish-total),clampf(app.result_clock.get("xp_phase",0),0,1))
	for i in range(app.battle_medals.size()):
		current+=float(app.battle_medals[i].get("xp_award",0))/10.0*clampf((app.result_clock.get("medal_clock",0)-i*1.5)*2.0,0,1)
	return minf(finish,current)

static func departure_positions(app,time:float) -> Dictionary:
	# CByeScreen::Update0xa0288, authored millisecond clock and integer drift.
	var ms=time*1000.0
	var offset=200.0+ms/300.0
	var drift=float(int(100.0*ms/(ms+3000.0)))
	var center=app.view_center()
	return {"earth":center+Vector2(0,offset)*0.7,"moon":center+Vector2(maxf(-60,260-offset),offset+10)*0.7,"rocket":center+Vector2(40+drift,134-drift)*0.7,"drift":drift,"offset":offset}

static func draw_departure(app,time:float) -> void:
	app.draw_rect(Rect2(Vector2.ZERO,app.view_size()),Color.BLACK)
	var p=departure_positions(app,time)
	var root="assets/gui/loader/bye_loading_"
	centered(app,root+"stars.png",p.earth,0,0.7)
	centered(app,root+"earth.png",p.earth,time*1000.0/300.0,0.7)
	centered(app,root+"moon.png",p.moon,-time*1000.0/300.0*1.3,0.7)
	var beam=Content.tex(root+"beam.png")
	app.draw_texture_rect(beam,Rect2(p.rocket+Vector2(-11,19)*0.7-beam.get_size()*0.35,beam.get_size()*0.7),false,Color(1,1,1,0.5 if int(time*10)%2 else 1.0))
	centered(app,root+"rocket.png",p.rocket,0,0.7)

static func chrome_controls(app) -> void:
	var origin=Vector2(128,0)
	var links={101:"world",102:"career",103:"shop",104:"upgrades",105:"spicery"}
	for entry in Content.interface_layouts.lobby_top.entries:
		var rect=app.entry_rect(entry,origin)
		var tag=int(entry.get("tag",0))
		if tag==100:
			var home=app.image_button(app.ui,"Home",rect,app.navigate.bind("menu"),entry.button_images["0"],entry.button_images["1"])
			home.set_meta("native_menu_navigation",true)
		elif links.has(tag):
			var target=links[tag]
			var caption=str(entry.button_titles.get("0",""))
			var control=app.invisible_button(app.ui,caption,rect,app.navigate.bind(target))
			control.set_meta("original_tab",target)
			control.set_meta("native_menu_navigation",true)
			var selected=app.screen==target or app.screen=="dress" and target=="career"
			var text=app.label(app.ui,caption,rect,32,Color(1,1,1,1 if selected else 0.5))
			text.add_theme_font_override("font",app.bold)
			text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			if selected:app.image_control(app.ui,"assets/menu_active_tab.png",Rect2(rect.get_center().x-5.5,60,11,7))
		elif entry.get("outlet","") in ["playerSpiceLabelTop","playerUpgradePointsLabelTop"]:
			var spice=entry.outlet=="playerSpiceLabelTop"
			app.label(app.ui,"%d%s"%[int(Profile.data.spice if spice else Profile.data.specpoints),"sp" if spice else "up"],rect,14,Color("#80b933") if spice else Color("#2fbad7"))
		elif entry.get("image","")=="assets/menu_divider.png":app.image_control(app.ui,entry.image,rect)
	origin=Vector2(128,app.view_size().y-75)
	var gold=app.screen in ["upgrades","spicery"]
	var xp=float(Profile.data.xp)
	var lower=Profile.level_threshold(int(Profile.data.level)-1)
	var upper=Profile.level_threshold(int(Profile.data.level))
	var xp_pose=preload("res://scripts/xp_view.gd").footer(xp,Profile.f32(upper-xp),lower,int(Profile.data.level),82)
	for entry in Content.interface_layouts.lobby_bottom.entries:
		if int(entry.id) in [12,54,57,114]:continue
		var rect=app.entry_rect(entry,origin)
		if entry.has("image"):
			var path=str(entry.image)
			if gold and path in ["assets/shop_info_panel.png","assets/xp_bar_0.png"]:path=path.trim_suffix(".png")+"_2.png"
			var art=app.image_control(app.ui,path,rect);art.set_meta("lobby_footer_source",int(entry.id))
		elif entry.has("text"):
			var caption=str(entry.text)
			match str(entry.outlet):
				"playerSpiceLabelBottom":caption="%dsp"%int(Profile.data.spice)
				"playerUpgradePointsLabel":caption=str(int(Profile.data.specpoints))
				"playerLevel":caption=str(int(Profile.data.level))
				"playerRank":caption="rank: "+PromotionView.rank_name(int(Profile.data.level)).to_lower()
				"playerXpStatus":caption="xp: "+SpiceNative.format_xp(xp_pose.current)+" / "+SpiceNative.format_xp(xp_pose.upper)
			var rgba=entry.color
			var tint=Color(rgba[0],rgba[1],rgba[2],rgba[3])
			if str(entry.outlet)=="yourBalanceLabel":tint=Color(1,0.9,0.015,1) if gold else Color(0,0.67,0.039,1)
			elif str(entry.outlet)=="playerRank":tint=Color(1,0.9,0.015,1) if gold else Color(0,1,1,1)
			var control=app.label(app.ui,caption,rect,int(entry.font_size),tint)
			if int(entry.get("line_count",1))==1:
				control.autowrap_mode=TextServer.AUTOWRAP_OFF
				control.clip_text=true
				control.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			control.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
			control.horizontal_alignment=int(entry.get("alignment",0))
	var fill=float(xp_pose.width)
	if fill>0:
		var texture=app.atlas("assets/xp_bar_1_2.png" if gold else "assets/xp_bar_1.png",Rect2(0,0,fill,14))
		var image=TextureRect.new();image.texture=texture;image.position=origin+Vector2(665,42);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;app.ui.add_child(image)
