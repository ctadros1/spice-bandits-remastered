extends RefCounted

# WinLose Update creates an idle system; Render sets the release count for
# the next Update. Keep it alive at count0, as the original pointer persists.
static func create(particles,original:Dictionary,texture:Texture2D) -> void:
	particles.reset()
	var definition=original.duplicate(true)
	definition.name=str(original.name)+"::WinLoseXP"
	definition.num_release=0
	particles.emit_definition("XpBarGrow",definition,texture,Vector2.ZERO,"","",-1)

static func after_render(particles,previous:Vector2,current:Vector2) -> bool:
	var releasing=current.x!=previous.x
	var found=false
	for system in particles.systems:
		if system.name!="XpBarGrow":continue
		found=true
		system.pos=current
		system.definition.num_release=2 if releasing else 0
	return releasing and found
