class_name MovingLaserGate
extends ArtilleryZone

# Danger environnemental : translation/rotation fixées au lancement, aucune IA.
signal ship_passed(ship: BlueShip)
signal ship_bypassed(ship: BlueShip)
enum Variant { LASER_GATE, ROTATING_LASER_GRID }
enum RotationProfile { SLOW_ROTATION, MEDIUM_ROTATION, REVERSE_ROTATION }
enum GateGeometry { RECTANGULAR, DIAGONAL_X, DIAMOND, OFFSET_CROSS, HEXAGONAL, RADIAL, ASYMMETRIC }
var geometry: GateGeometry = GateGeometry.RECTANGULAR
var geometry_seed: int = 0
var presentation_grid_scale: float = 1
var variant: Variant = Variant.LASER_GATE
var rotation_profile: RotationProfile = RotationProfile.SLOW_ROTATION
var width: float = 110
var height: float = 80
var velocity: Vector3 = Vector3(0, 0, 45)
var angular_speed_degrees: float = 15
var initial_tilt_degrees: float = 20
var detection_radius: float = 230
var passage_count: int = 0
var bypass_count: int = 0
var opening_choices: int = 0
var opening_changes: int = 0
var safe_points: Array[Vector3] = []
var _heading: Basis
var _previous_transform: Transform3D
var _previous_blues: Dictionary[int, Vector3] = {}
var _passed: Dictionary[int, bool] = {}


static func beam_count(grid_variant: int) -> int:
	return 8 if grid_variant == Variant.ROTATING_LASER_GRID else 6


func _ready() -> void:
	kind = Kind.GRID if variant == Variant.ROTATING_LASER_GRID else Kind.CURTAIN
	beam_width = 1.6 * presentation_grid_scale
	delay = 0.8
	active_time = maxf(active_time, 14)
	set_meta("weapon_family", "Laser")
	_heading = Basis.looking_at(-velocity.normalized(), Vector3.UP)
	global_basis = _heading * Basis(Vector3.BACK, deg_to_rad(initial_tilt_degrees))
	super._ready()
	_packet.hide()
	_material.albedo_color = Color(1, 0.7, 0.08, 0.85)
	_material.emission = Color(1, 0.45, 0.04)
	_material.emission_energy_multiplier = 3
	_previous_transform = global_transform
	for blue: Node in get_tree().get_nodes_in_group("blue_ships"):
		_previous_blues[blue.get_instance_id()] = (blue as Node3D).global_position


func _build_beams() -> void:
	if geometry != GateGeometry.RECTANGULAR:
		_build_geometry()
		return
	for x: float in [-width * 0.5, -18.0, 18.0, width * 0.5]:
		beam_segments.append(Vector3(x, -height * 0.5, 0))
		beam_segments.append(Vector3(x, height * 0.5, 0))
	for y: float in [-height * 0.5, height * 0.5]:
		beam_segments.append(Vector3(-width * 0.5, y, 0))
		beam_segments.append(Vector3(width * 0.5, y, 0))
	if variant == Variant.ROTATING_LASER_GRID:
		for y: float in [-18.0, 18.0]:
			beam_segments.append(Vector3(-width * 0.5, y, 0))
			beam_segments.append(Vector3(width * 0.5, y, 0))
	for x: float in [-(width * 0.5 + 18) * 0.5, 0.0, (width * 0.5 + 18) * 0.5]:
		if variant == Variant.LASER_GATE:
			safe_points.append(Vector3(x, 0, 0))
		else:
			for y: float in [-(height * 0.5 + 18) * 0.5, 0.0, (height * 0.5 + 18) * 0.5]:
				safe_points.append(Vector3(x, y, 0))
	# Contournements ouverts, même si un rocher occupe une cellule intérieure.
	safe_points.append_array([Vector3(-width * 0.5 - 14, 0, 0), Vector3(width * 0.5 + 14, 0, 0), Vector3(0, -height * 0.5 - 14, 0), Vector3(0, height * 0.5 + 14, 0)])
	for index: int in range(0, beam_segments.size(), 2):
		var from: Vector3 = beam_segments[index]
		var to: Vector3 = beam_segments[index + 1]
		var dimensions: Vector3 = Vector3(beam_width, from.distance_to(to), 3) if absf(from.x - to.x) < 1 else Vector3(from.distance_to(to), beam_width, 3)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = dimensions
		var part: MeshInstance3D = _part(mesh)
		part.position = (from + to) * 0.5
		_visuals.append(part)
		var area: Area3D = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		area.position = part.position
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = dimensions
		shape.shape = box
		area.add_child(shape)
		add_child(area)
		areas.append(area)


func future_transform(seconds: float) -> Transform3D:
	return Transform3D(_heading * Basis(Vector3.BACK, deg_to_rad(initial_tilt_degrees + angular_speed_degrees * (age + seconds))), global_position + velocity * seconds)


func safe_openings(seconds: float = 0) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var pose: Transform3D = future_transform(seconds)
	for point: Vector3 in safe_points:
		result.append(pose * point)
	return result


func crossing_time(point: Vector3, speed: Vector3) -> float:
	var distance: float = (point - global_position).dot(_heading.z)
	var closing: float = (velocity - speed).dot(_heading.z)
	return distance / closing if closing > 0.1 else -1


func _physics_process(delta: float) -> void:
	_previous_transform = global_transform
	age += delta
	global_position += velocity * delta
	global_basis = _heading * Basis(Vector3.BACK, deg_to_rad(initial_tilt_degrees + angular_speed_degrees * age))
	if not active and age >= delay:
		active = true
		_material.albedo_color = Color(1, 0.12, 0.055, 0.9)
		_material.emission = Color(1, 0.06, 0.02)
		_material.emission_energy_multiplier = 4
		activated.emit()
	var live_ids: Dictionary[int, bool] = {}
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var blue: BlueShip = node as BlueShip
		var id: int = blue.get_instance_id()
		live_ids[id] = true
		var previous: Vector3 = _previous_blues.get(id, blue.global_position - blue.velocity * delta)
		var before: float = (previous - _previous_transform.origin).dot(_heading.z)
		var after: float = (blue.global_position - global_position).dot(_heading.z)
		if active and not _hit_ids.has(id) and _swept_beam_contact(previous, blue.global_position):
			_hit_ids[id] = true
			blue.take_damage(3)
			damage_events += 1
			damage_applied.emit(blue, 3)
		if blue.alive and before > 0 and after <= 0 and not _passed.has(id):
			_passed[id] = true
			var fraction: float = clampf(before / maxf(before - after, 0.001), 0, 1)
			var pose: Transform3D = _previous_transform.interpolate_with(global_transform, fraction)
			var local: Vector3 = pose.affine_inverse() * previous.lerp(blue.global_position, fraction)
			if absf(local.x) < width * 0.5 and absf(local.y) < height * 0.5:
				passage_count += 1
				ship_passed.emit(blue)
			else:
				bypass_count += 1
				ship_bypassed.emit(blue)
		_previous_blues[id] = blue.global_position
	for id: int in _previous_blues.keys():
		if not live_ids.has(id):
			_previous_blues.erase(id)
	if age >= active_time:
		queue_free()


func _swept_beam_contact(previous: Vector3, current: Vector3) -> bool:
	# En complément des Area3D, trois poses interpolées balayent les barres rotatives.
	for sample: int in range(3):
		var pose: Transform3D = _previous_transform.interpolate_with(global_transform, float(sample) * 0.5)
		var inverse: Transform3D = pose.affine_inverse()
		var from: Vector3 = inverse * previous
		var to: Vector3 = inverse * current
		for index: int in range(areas.size()):
			var area: Area3D = areas[index]
			var box: BoxShape3D = (area.get_child(0) as CollisionShape3D).shape as BoxShape3D
			var local_from: Vector3 = from
			var local_to: Vector3 = to
			var bounds: AABB = AABB(area.position - box.size * 0.5, box.size).grow(1.1)
			if geometry != GateGeometry.RECTANGULAR:
				local_from = area.transform.affine_inverse() * from
				local_to = area.transform.affine_inverse() * to
				bounds = AABB(-box.size * 0.5, box.size).grow(1.1)
			if bounds.has_point(local_from) or bounds.has_point(local_to) or bounds.intersects_segment(local_from, local_to) != null:
				return true
	return false


func avoidance_force(_point: Vector3, _speed: Vector3) -> Vector3:
	# Les BlueShip choisissent une ouverture ; la répulsion statique ne s'applique pas.
	return Vector3.ZERO


func beam_clearance(point: Vector3, seconds: float) -> float:
	var local: Vector3 = future_transform(seconds).affine_inverse() * point
	local.z = 0
	var minimum: float = INF
	for index: int in range(0, beam_segments.size(), 2):
		var from: Vector3 = beam_segments[index]
		var segment: Vector3 = beam_segments[index + 1] - from
		var nearest: Vector3 = from + segment * clampf((local - from).dot(segment) / segment.length_squared(), 0, 1)
		minimum = minf(minimum, local.distance_to(nearest) - beam_width * 0.5)
	return minimum


func _segment(from: Vector2, to: Vector2) -> void:
	beam_segments.append(Vector3(from.x * width * 0.5, from.y * height * 0.5, 0))
	beam_segments.append(Vector3(to.x * width * 0.5, to.y * height * 0.5, 0))


func _build_geometry() -> void:
	match geometry:
		GateGeometry.DIAGONAL_X:
			_segment(Vector2(-1, -1), Vector2(1, 1))
			_segment(Vector2(-1, 1), Vector2(1, -1))
			_segment(Vector2(-1, 0.6), Vector2(-1, 1))
			_segment(Vector2(1, -1), Vector2(1, -0.6))
		GateGeometry.DIAMOND:
			_segment(Vector2(-0.92, 0.08), Vector2(-0.08, 0.92))
			_segment(Vector2(0.08, 0.92), Vector2(0.92, 0.08))
			_segment(Vector2(0.92, -0.08), Vector2(0.08, -0.92))
			_segment(Vector2(-0.08, -0.92), Vector2(-0.92, -0.08))
			_segment(Vector2(-0.55, -0.1), Vector2(-0.25, -0.1))
			_segment(Vector2(0.3, 0.35), Vector2(0.65, 0.35))
		GateGeometry.OFFSET_CROSS:
			_segment(Vector2(0.28, -1), Vector2(0.28, -0.45))
			_segment(Vector2(0.28, 0.15), Vector2(0.28, 1))
			_segment(Vector2(-1, -0.22), Vector2(-0.18, -0.22))
			_segment(Vector2(0.55, -0.22), Vector2(1, -0.22))
			_segment(Vector2(-0.95, 0.85), Vector2(-0.5, 0.6))
		GateGeometry.HEXAGONAL:
			var vertices: Array[Vector2] = [Vector2(-1, 0), Vector2(-0.5, 1), Vector2(0.5, 1), Vector2(1, 0), Vector2(0.5, -1), Vector2(-0.5, -1)]
			for index: int in range(6):
				_segment(vertices[index], vertices[(index + 1) % 6])
			_segment(Vector2(-0.7, 0.2), Vector2(-0.2, 0.2))
			_segment(Vector2(0.3, -0.35), Vector2(0.65, -0.35))
		GateGeometry.RADIAL:
			var hub: Vector2 = Vector2(-0.38, 0.15)
			for edge: Vector2 in [Vector2(0.8, 1), Vector2(1, 0.1), Vector2(0.65, -1), Vector2(-0.8, -1)]:
				_segment(hub.lerp(edge, 0.24), edge)
		GateGeometry.ASYMMETRIC:
			_segment(Vector2(-1, -0.65), Vector2(-0.25, 0.7))
			_segment(Vector2(0.18, -0.9), Vector2(1, 0.45))
			_segment(Vector2(-0.65, 0.9), Vector2(0.2, 0.9))
			_segment(Vector2(0.62, 0.05), Vector2(0.62, 0.75))
	# Ouvertures vérifiées contre les segments réels, y compris à épaisseur maximale.
	var candidates: Array[Vector3] = []
	for x: float in [-0.8, -0.55, -0.3, 0, 0.3, 0.55, 0.8]:
		for y: float in [-0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75]:
			var point: Vector3 = Vector3(x * width * 0.5, y * height * 0.5, 0)
			if _local_clearance(point) >= 10:
				candidates.append(point)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _local_clearance(a) > _local_clearance(b))
	for point: Vector3 in candidates:
		if safe_points.all(func(other: Vector3) -> bool: return other.distance_to(point) >= 14):
			safe_points.append(point)
		if safe_points.size() >= 7:
			break
	safe_points.append_array([Vector3(-width * 0.5 - 14, 0, 0), Vector3(width * 0.5 + 14, 0, 0), Vector3(0, -height * 0.5 - 14, 0), Vector3(0, height * 0.5 + 14, 0)])
	for index: int in range(0, beam_segments.size(), 2):
		var from: Vector3 = beam_segments[index]
		var to: Vector3 = beam_segments[index + 1]
		var dimensions: Vector3 = Vector3(from.distance_to(to), beam_width, 3)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = dimensions
		var part: MeshInstance3D = _part(mesh)
		part.position = (from + to) * 0.5
		part.rotation.z = atan2(to.y - from.y, to.x - from.x)
		_visuals.append(part)
		var area: Area3D = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		area.transform = part.transform
		var collider: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = dimensions
		collider.shape = box
		area.add_child(collider)
		add_child(area)
		areas.append(area)


func _local_clearance(point: Vector3) -> float:
	var minimum: float = INF
	for index: int in range(0, beam_segments.size(), 2):
		var from: Vector3 = beam_segments[index]
		var segment: Vector3 = beam_segments[index + 1] - from
		var nearest: Vector3 = from + segment * clampf((point - from).dot(segment) / segment.length_squared(), 0, 1)
		minimum = minf(minimum, point.distance_to(nearest))
	return minimum


func set_battle_width(multiplier: float) -> void:
	var next_width: float = 1.6 * multiplier
	var ratio: float = next_width / beam_width
	for index: int in range(areas.size()):
		var part: MeshInstance3D = _visuals[index]
		var box: BoxShape3D = (areas[index].get_child(0) as CollisionShape3D).shape as BoxShape3D
		var dimensions: Vector3 = box.size
		var from: Vector3 = beam_segments[index * 2]
		var to: Vector3 = beam_segments[index * 2 + 1]
		if geometry == GateGeometry.RECTANGULAR and absf(from.x - to.x) < 1:
			dimensions.x *= ratio
		else:
			dimensions.y *= ratio
		box.size = dimensions
		(part.mesh as BoxMesh).size = dimensions
	beam_width = next_width
	presentation_grid_scale = multiplier
