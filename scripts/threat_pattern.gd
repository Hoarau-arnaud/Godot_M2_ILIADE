class_name ThreatPattern
extends RefCounted

# Pure données de tir : aucun acteur supplémentaire ni commande de navigation.
enum Category { TARGETED, NEAR_PASS, SUPPRESSION, ZONE }

static func category(index: int) -> Category:
	var slot: int = (index * 7) % 20
	return Category.TARGETED if slot < 16 else Category.NEAR_PASS if slot < 19 else Category.SUPPRESSION


static func error(kind: int, random: RandomNumberGenerator) -> Vector3:
	if kind == Category.TARGETED:
		return Vector3(random.randf_range(-1.3, 1.3), random.randf_range(-1.3, 1.3), 0)
	var angle: float = random.randf_range(0, TAU)
	var radius: float = random.randf_range(5, 12) if kind == Category.NEAR_PASS else random.randf_range(22, 35)
	return Vector3(cos(angle), sin(angle), 0) * radius
