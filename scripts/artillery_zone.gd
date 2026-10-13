class_name ArtilleryZone
extends Node3D

signal damage_applied(ship: BlueShip, amount: int)
signal activated
signal detonated
enum Kind { BOMB, CURTAIN, GRID }
var kind: Kind = Kind.BOMB
var delay: float = 10
var warning_time: float = 1.9
var active_time: float = 1.3
var radius: float = 13
var age: float = 0
var active: bool = false
var beam_width: float = 0.65
var source: Vector3
var beam_segments: Array[Vector3] = [] # Couples d'extrémités en espace local.
var areas: Array[Area3D] = []
var damage_events: int = 0
var _visuals: Array[MeshInstance3D] = []
var _hit_ids: Dictionary[int, bool] = {}
var _sphere: MeshInstance3D
var _ring: MeshInstance3D
var _shards: MultiMeshInstance3D
var _packet: MeshInstance3D
var _material: StandardMaterial3D


static func dangerous_count(tree: SceneTree) -> int:
	var count: int = tree.get_nodes_in_group("hostile_projectiles").size()
	for node: Node in tree.get_nodes_in_group("combat_hazards"):
		var zone: ArtilleryZone = node as ArtilleryZone
		if zone.kind != Kind.BOMB:
			count += zone.beam_segments.size() / 2
	return count


func _ready() -> void:
	add_to_group("combat_hazards")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1, 0.14, 0.045, 0.15)
	_material.emission_enabled = true
	_material.emission = Color(1, 0.07, 0.025)
	_material.emission_energy_multiplier = 0.4
	if kind == Kind.BOMB:
		_build_bomb()
	else:
		_build_beams()
		var packet: SphereMesh = SphereMesh.new()
		packet.radius = 1.5
		packet.height = 3
		packet.radial_segments = 8
		packet.rings = 4
		_packet = _part(packet)


func _part(shape: Mesh) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = shape
	part.material_override = _material
	add_child(part)
	return part


func _build_bomb() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	sphere.radial_segments = 16
	sphere.rings = 8
	_sphere = _part(sphere)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = radius * 0.94
	ring.outer_radius = radius
	ring.rings = 20
	ring.ring_segments = 6
	_ring = _part(ring)
	_ring.rotation_degrees.x = 90
	_shards = MultiMeshInstance3D.new()
	_shards.multimesh = MultiMesh.new()
	_shards.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var shard: BoxMesh = BoxMesh.new()
	shard.size = Vector3(0.25, 0.25, 1)
	shard.material = _material
	_shards.multimesh.mesh = shard
	_shards.multimesh.instance_count = 18
	add_child(_shards)
	_shards.hide()


func _build_beams() -> void:
	# Un espace central décalé de 24 m reste ouvert : pas de cage fermée.
	for x: float in [-38.0, -22.0, 22.0, 38.0]:
		beam_segments.append(Vector3(x, -45, 0))
		beam_segments.append(Vector3(x, 45, 0))
	if kind == Kind.GRID:
		for y: float in [-30.0, 30.0]:
			beam_segments.append(Vector3(-65, y, 0))
			beam_segments.append(Vector3(65, y, 0))
	for index: int in range(0, beam_segments.size(), 2):
		var from: Vector3 = beam_segments[index]
		var to: Vector3 = beam_segments[index + 1]
		var size_value: Vector3 = Vector3(beam_width, from.distance_to(to), 2.5) if absf(from.x - to.x) < 1 else Vector3(from.distance_to(to), beam_width, 2.5)
		var mesh_shape: BoxMesh = BoxMesh.new()
		mesh_shape.size = size_value
		var part: MeshInstance3D = _part(mesh_shape)
		part.position = (from + to) * 0.5
		_visuals.append(part)
		var area: Area3D = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		area.position = part.position
		var collider: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size_value
		collider.shape = box
		area.add_child(collider)
		add_child(area)
		areas.append(area)


func _physics_process(delta: float) -> void:
	age += delta
	if kind == Kind.BOMB:
		visible = age >= delay - warning_time
	else:
		for part: MeshInstance3D in _visuals:
			part.visible = age >= delay - warning_time
		_packet.visible = not active
		_packet.global_position = source.lerp(global_position, clampf(age / delay, 0, 1))
	if not active and age >= delay:
		active = true
		activated.emit()
		_material.emission_energy_multiplier = 4
		_material.albedo_color.a = 0.9
		if kind == Kind.BOMB:
			_explode()
	if active:
		if kind == Kind.BOMB:
			var progress: float = clampf((age - delay) / active_time, 0, 1)
			_sphere.scale = Vector3.ONE * maxf(progress, 0.05)
			_ring.scale = Vector3.ONE * (0.5 + progress * 1.6)
			_material.albedo_color.a = (1 - progress) * 0.65
			for index: int in range(18):
				var axis: Vector3 = Vector3(sin(index * 2.4), cos(index * 1.7), sin(index * 3.1)).normalized()
				_shards.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, axis * progress * radius * 1.7))
		else:
			for area: Area3D in areas:
				for body: Node3D in area.get_overlapping_bodies():
					if body is BlueShip and (body as BlueShip).alive and not _hit_ids.has(body.get_instance_id()):
						_hit_ids[body.get_instance_id()] = true
						(body as BlueShip).take_damage(3)
						damage_applied.emit(body as BlueShip, 3)
						damage_events += 1
	if age >= delay + active_time:
		queue_free()


func _explode() -> void:
	_shards.show()
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var ship: BlueShip = node as BlueShip
		var distance: float = ship.global_position.distance_to(global_position)
		if ship.alive and distance < radius:
			var amount: int = 3 if distance < radius * 0.35 else 2 if distance < radius * 0.7 else 1
			ship.take_damage(amount)
			damage_applied.emit(ship, amount)
			damage_events += 1
	detonated.emit()


func avoidance_force(point: Vector3, speed: Vector3) -> Vector3:
	if age < delay - warning_time or age > delay + active_time:
		return Vector3.ZERO
	var until: float = maxf(delay - age, 0)
	var predicted: Vector3 = point + speed * minf(until, 2.2)
	if kind == Kind.BOMB:
		var away: Vector3 = predicted - global_position
		if away.length() > radius + 6:
			return Vector3.ZERO
		away.z = 0
		return (away.normalized() if away.length() > 0.1 else Vector3.UP) * 3
	var result: Vector3 = Vector3.ZERO
	var relative: Vector3 = predicted - global_position
	if absf(relative.z) > 12:
		return result
	for index: int in range(0, beam_segments.size(), 2):
		var from: Vector3 = beam_segments[index]
		var segment: Vector3 = beam_segments[index + 1] - from
		var nearest: Vector3 = from + segment * clampf((relative - from).dot(segment) / segment.length_squared(), 0, 1)
		var away: Vector3 = relative - nearest
		away.z = 0
		if away.length() < 10:
			result += (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 3
	return result.limit_length(3)
