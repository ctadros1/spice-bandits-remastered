extends RefCounted
# Selected original CTower.UpdatePoisons traversal. Object updates and
# destructors are supplied adapters; full tower/room scheduling is separate.
static func update(clouds:Array,bubbles:Array,dt_ms:float,argument_b:bool,adapters:Dictionary) -> void:
	var i=0
	while i<clouds.size():
		var cloud:Dictionary=clouds[i]
		if int(cloud.active)&1:
			adapters.cloud_update.call(cloud,dt_ms,argument_b)
			i+=1
		else:
			adapters.cloud_destroy.call(cloud)
			clouds.remove_at(i)
	i=0
	while i<bubbles.size():
		var bubble:Dictionary=bubbles[i]
		if (int(bubble.active)&1) or int(adapters.bubble_particles.call(bubble))!=0:
			adapters.bubble_update.call(bubble,dt_ms,argument_b)
			i+=1
		else:
			# Original0xe7724..0xe7738 detaches the first non-null parent.
			# It does not compare that pointer with this removed bubble.
			for cloud in clouds:
				if not cloud.parent30.is_empty():cloud.parent30={};break
			adapters.bubble_destroy.call(bubble)
			bubbles.remove_at(i)
