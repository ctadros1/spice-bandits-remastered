extends Control

# IntroSequenceView: Chillingo fades in for 1s, holds 3s, fades for 1s;
# the randomly selected On5 movie begins at 5s. At movie time 5s the
# original 1024-square mask replaces it in 0.5s, then flies at scale 20.
# The missing remote narrative movie is an explicit offline difference.
signal finished

var elapsed = 0.0
var variant = 1
var player: VideoStreamPlayer
var white: ColorRect
var chillingo: TextureRect
var mask: TextureRect
var done = false
var started = false
var mask_elapsed = -1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	white = ColorRect.new()
	white.color = Color.WHITE
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.stream = load("res://assets/on5_splash_%d.ogv" % variant)
	player.volume = 1.0 if Profile.data.settings.sound else 0.0
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.finished.connect(finish)
	add_child(player)
	chillingo = TextureRect.new()
	chillingo.texture = Content.tex("assets/chillingo_splash_hd.png")
	chillingo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chillingo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chillingo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chillingo)
	mask = TextureRect.new()
	mask.texture = Content.tex("assets/o5_mask.png")
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mask)
	resized.connect(layout)
	layout()
	update_visuals()
	if player.stream == null: finish()

func layout() -> void:
	if player == null: return
	white.size = size
	chillingo.size = size
	var factor = minf(size.x/1024.0, size.y/768.0)
	player.size = Vector2(600, 532)*factor
	player.position = (size-player.size)/2.0
	mask.size = Vector2(1024, 1024)*factor
	mask.position = (size-mask.size)/2.0
	mask.pivot_offset = mask.size/2.0

func _process(delta: float) -> void:
	if done: return
	elapsed += delta
	if elapsed >= 5.0 and not started:
		started = true
		player.play()
	if started and mask_elapsed < 0.0 and player.stream_position >= 5.0: mask_elapsed = 0.0
	if mask_elapsed >= 0.0: mask_elapsed += delta
	update_visuals()
	if mask_elapsed >= 1.0: finish()

func update_visuals() -> void:
	white.visible = mask_elapsed < 0.0
	chillingo.visible = elapsed < 5.0
	chillingo.modulate.a = clampf(minf(elapsed, 5.0-elapsed), 0.0, 1.0)
	player.visible = elapsed >= 5.0 and mask_elapsed < 0.5
	player.modulate.a = 1.0 if mask_elapsed < 0.0 else clampf(1.0-mask_elapsed*2.0, 0.0, 1.0)
	mask.visible = mask_elapsed >= 0.0
	var fly = clampf((mask_elapsed-0.5)*2.0, 0.0, 1.0)
	# UIKit default animation is eased; interpolation is provisional pending
	# original device capture. Dimensions, duration and scale are code traced.
	var eased = fly*fly*(3.0-2.0*fly)
	mask.scale = Vector2.ONE*lerpf(1.0, 20.0, eased)
	mask.modulate.a = 1.0-eased

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: finish()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if done: return
	done = true
	if player != null: player.stop()
	finished.emit()
	queue_free()
