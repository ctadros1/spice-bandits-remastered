extends RefCounted

static func has_unlock(expression: String, owned: Array) -> bool:
	# TDPlayer::hasUnlock0x44558 uses OR for ordinary comma-separated tokens.
	# A leading ! within a list means a required POSITIVE unlock: missing any
	# such token returns false immediately. It does not mean logical negation.
	# Without a comma, hasSingleUnlock0x4449c compares the literal expression.
	if not expression.contains(","): return expression.is_empty() or expression in owned
	var result = false
	for token in expression.split(",", true):
		if token.length() >= 2 and token.begins_with("!"):
			if token.substr(1) not in owned: return false
			result = true
		elif token.is_empty() or token in owned: result = true
	return result
