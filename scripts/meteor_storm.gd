class_name MeteorStorm
extends RefCounted

# Données pures : aucun RNG global, aucun agent, aucun emplacement de grille.
static func sample(random: RandomNumberGenerator, center: Vector3, complex_motion: bool) -> Dictionary:
	var size_roll: float = random.randf()
	var diameter: float = random.randf_range(0.6, 2) if size_roll < 0.55 else random.randf_range(2, 5) if size_roll < 0.83 else random.randf_range(5, 10) if size_roll < 0.97 else random.randf_range(10, 16)
	var speed_roll: float = random.randf()
	var speed: float = random.randf_range(4, 8) if diameter >= 5 or speed_roll < 0.25 else random.randf_range(8, 16) if speed_roll < 0.65 else random.randf_range(16, 28) if speed_roll < 0.95 or diameter >= 2 else random.randf_range(30, 45)
	var offset: Vector3 = Vector3(random.randf_range(-70, 70), random.randf_range(-45, 45), -random.randf_range(30, 280))
	var direction: Vector3 = Vector3(-offset.x * random.randf_range(0.005, 0.025) + random.randf_range(-0.6, 0.6), -offset.y * random.randf_range(0.005, 0.025) + random.randf_range(-0.6, 0.6), random.randf_range(-0.22, 0.55)).normalized()
	var plane: Basis = Basis.from_euler(Vector3(random.randf_range(-1.2, 1.2), random.randf_range(-1.2, 1.2), random.randf_range(-PI, PI)))
	return {"position": center + offset, "diameter": diameter, "velocity": direction * speed, "rotation": Vector3(random.randf_range(-PI, PI), random.randf_range(-PI, PI), random.randf_range(-PI, PI)), "motion": random.randi_range(2, 5) if complex_motion else 1, "axis_u": plane.x, "axis_v": plane.y, "amplitude": Vector2(random.randf_range(12, 28), random.randf_range(10, 22)), "period": random.randf_range(12, 24), "phase": random.randf_range(0, TAU), "seed": random.randi()}


static func clear(candidate: Dictionary, center: Vector3, rocks: Array[Node], ships: Array[Node]) -> bool:
	var point: Vector3 = candidate.position
	var radius: float = float(candidate.diameter) * 0.65
	# Couloir sinueux continu, sans rangées de trous ; seules les grosses masses
	# sont rejetées près de son centre. Les petits météores peuvent le traverser.
	var ahead: float = center.z - point.z
	var corridor: Vector2 = Vector2(sin(ahead * 0.026) * 18, cos(ahead * 0.019) * 12)
	if float(candidate.diameter) > 5 and Vector2(point.x - center.x, point.y - center.y).distance_to(corridor) < radius + 9:
		return false
	for node: Node in ships:
		if point.distance_to((node as Node3D).global_position) < radius + 14:
			return false
	var close_count: int = 0
	for node: Node in rocks:
		var rock: SpaceAsteroid = node as SpaceAsteroid
		var distance: float = point.distance_to(rock.global_position)
		if distance < radius + rock.avoidance_radius + 4:
			return false
		if distance < 18:
			close_count += 1
	return close_count < 4
