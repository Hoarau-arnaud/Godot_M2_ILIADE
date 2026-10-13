class_name ArtilleryProjectile
extends CharacterBody3D

signal hit_blue_ship(target: BlueShip, amount: int)
signal impacted(obstacle: bool)

enum Kind { HEAVY_SHOT, SPREAD, ARC_SALVO, CROSS_FIRE, SEEKER_SALVO, RAPID_BARRAGE, BOMB_CLUSTER, LASER_CURTAIN, LASER_GRID, MISSILE_SWARM }

@export var kind: Kind = Kind.HEAVY_SHOT
@export var projectile_speed: float = 27.0
@export var lifetime: float = 14.0
@export var damage: int = 2
@export var avoidance_radius: float = 10.0
@export var turn_rate_degrees: float = 6.0
var threat_strength: float = 1.0
var threat_category: int = ThreatPattern.Category.TARGETED
var target_seed: int = 0
var targeted: bool = false
var arcade_signature: bool = false
var batch_visuals_enabled: bool = true
var initial_target_position: Vector3
var initial_target_velocity: Vector3
var flight_direction: Vector3 = Vector3.BACK
var target: BlueShip
var arc_axis: Vector3 = Vector3.UP
var arc_amplitude: float = 24.0
var arc_duration: float = 5.0
var age: float = 0.0
var spent: bool = false
var bomb_zone: ArtilleryZone
var _origin: Vector3
var _shape: Shape3D


func _ready() -> void:
	add_to_group("hostile_projectiles")
	add_to_group("artillery_projectiles")
	collision_layer = 0
	collision_mask = 0 if kind == Kind.BOMB_CLUSTER else 3 # BlueShip et astéroïdes ; jamais le lanceur ou ses alliés.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	flight_direction = flight_direction.normalized()
	if flight_direction.is_zero_approx():
		flight_direction = Vector3.BACK
	velocity = flight_direction * projectile_speed
	_origin = global_position
	if arcade_signature and kind in [Kind.HEAVY_SHOT, Kind.SEEKER_SALVO, Kind.MISSILE_SWARM, Kind.ARC_SALVO]:
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = 1.25 if kind == Kind.HEAVY_SHOT else 0.85 if kind == Kind.ARC_SALVO else 0.6
		capsule.height = 8.5 if kind == Kind.HEAVY_SHOT else 4.4 if kind == Kind.ARC_SALVO else 4.8
		_shape = capsule
	else:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 2.8 if arcade_signature and kind == Kind.BOMB_CLUSTER else 1.8 if kind == Kind.HEAVY_SHOT else 0.35
		_shape = sphere
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = _shape
	if _shape is CapsuleShape3D:
		collider.rotation_degrees.x = 90
	add_child(collider)
	_build_visual()


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	return material


func _mesh(mesh: Mesh, color: Color, offset: Vector3) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _material(color)
	part.position = offset
	$Visual.add_child(part)
	return part


func _build_visual() -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var signature_key: int = int(kind) + (20 if arcade_signature else 0)
	if arcade_signature:
		_build_arcade_signature(visual, signature_key)
		_update_visual()
		return
	if batch_visuals_enabled and CombatMeshCache.has_signature(kind):
		CombatMeshCache.merge_parts(visual, kind)
		_update_visual()
		return
	var colors: Array[Color] = [Color(0.72, 0.16, 1), Color(1, 0.72, 0.08), Color(0.95, 0.08, 0.85), Color(1, 0.32, 0.06), Color(1, 0.08, 0.12), Color(1, 0.35, 0.08), Color(1, 0.6, 0.08), Color(1, 0.1, 0.05), Color(1, 0.1, 0.05), Color(0.1, 0.8, 1)]
	var core: SphereMesh = SphereMesh.new()
	core.radius = 2.3 if kind == Kind.BOMB_CLUSTER else 1.8 if kind == Kind.HEAVY_SHOT else 0.42
	core.height = core.radius * 2
	core.radial_segments = 12
	core.rings = 6
	if kind != Kind.HEAVY_SHOT:
		_mesh(core, colors[kind], Vector3.ZERO)
	var trail: BoxMesh = BoxMesh.new()
	trail.size = Vector3(0.4, 0.4, 12) if kind == Kind.HEAVY_SHOT else Vector3(0.24, 0.24, 7 if kind == Kind.CROSS_FIRE else 3)
	_mesh(trail, colors[kind] * Color(0.65, 0.65, 0.65), Vector3(0, 0, trail.size.z / 2))
	if kind == Kind.HEAVY_SHOT:
		var body: CapsuleMesh = CapsuleMesh.new()
		body.radius = 1.25
		body.height = 6.0
		body.radial_segments = 12
		body.rings = 4
		_mesh(body, Color(0.32, 0.12, 0.48), Vector3.ZERO).rotation_degrees.x = 90
		_add_fins(2.1, 1.4, colors[kind])
		var engine: SphereMesh = SphereMesh.new()
		engine.radius = 0.9
		engine.height = 1.8
		engine.radial_segments = 8
		engine.rings = 4
		_mesh(engine, Color(1, 0.35, 0.08), Vector3(0, 0, 2.8))
		var inner: SphereMesh = SphereMesh.new()
		inner.radius = 1.15
		inner.height = 2.3
		inner.radial_segments = 10
		inner.rings = 4
		_mesh(inner, Color(1, 0.65, 0.12), Vector3(0, 0, -2.8))
	elif kind in [Kind.SEEKER_SALVO, Kind.MISSILE_SWARM]:
		var hull: CapsuleMesh = CapsuleMesh.new()
		hull.radius = 0.48
		hull.height = 3.4
		hull.radial_segments = 8
		hull.rings = 3
		_mesh(hull, Color(0.48, 0.08, 0.12), Vector3.ZERO)
		($Visual.get_child($Visual.get_child_count() - 1) as MeshInstance3D).rotation_degrees.x = 90
		for segment: int in range(3):
			var flame: BoxMesh = BoxMesh.new()
			flame.size = Vector3(0.45 - segment * 0.1, 0.45 - segment * 0.1, 3.5)
			_mesh(flame, colors[kind], Vector3(0, 0, 3.2 + segment * 3.2))
		var engine: SphereMesh = SphereMesh.new()
		engine.radius = 0.45
		engine.height = 0.9
		engine.radial_segments = 8
		engine.rings = 4
		_mesh(engine, Color(1, 0.12, 0.08), Vector3(0, 0, 1.5))
		_add_fins(0.9, 0.6, Color(0.65, 0.16, 0.18))
		var nose: SphereMesh = SphereMesh.new()
		nose.radius = 0.45
		nose.height = 0.9
		nose.radial_segments = 8
		nose.rings = 4
		_mesh(nose, Color(1, 0.3, 0.15), Vector3(0, 0, -1.6))
	elif kind == Kind.ARC_SALVO:
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = 0.65
		capsule.height = 3.6
		capsule.radial_segments = 10
		capsule.rings = 4
		_mesh(capsule, colors[kind], Vector3.ZERO).rotation_degrees.x = 90
		for z: float in [-1.0, 1.0]:
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = 0.85
			ring.outer_radius = 1.05
			ring.rings = 16
			ring.ring_segments = 6
			_mesh(ring, Color(1, 0.5, 0.95), Vector3(0, 0, z)).rotation_degrees.x = 90
	if batch_visuals_enabled:
		CombatMeshCache.merge_parts(visual, kind)
	_update_visual()


func _physics_process(delta: float) -> void:
	if spent:
		return
	var step: float = minf(delta, maxf(lifetime - age, 0))
	var destination: Vector3
	if kind in [Kind.SEEKER_SALVO, Kind.MISSILE_SWARM]:
		if is_instance_valid(target) and target.alive and not target.is_queued_for_deletion():
			var desired: Vector3 = (target.global_position - global_position).normalized()
			var angle: float = flight_direction.angle_to(desired)
			if angle > 0.00001:
				flight_direction = flight_direction.slerp(desired, minf(1, deg_to_rad(turn_rate_degrees) * step / angle)).normalized()
		else:
			target = null
		velocity = flight_direction * projectile_speed
		destination = global_position + velocity * step
	elif kind == Kind.ARC_SALVO:
		destination = trajectory(age + step)
		velocity = trajectory_velocity(age + step)
	else:
		velocity = flight_direction * projectile_speed
		destination = global_position + velocity * step
	if arcade_signature and velocity.length_squared() > 0.001:
		global_basis = Basis.looking_at(velocity.normalized(), Vector3.RIGHT if absf(velocity.normalized().y) > 0.98 else Vector3.UP)
	# Le volume physique est balayé, y compris pour la capsule lourde.
	var contact: KinematicCollision3D = move_and_collide(destination - global_position, false, 0.001, true)
	age += step
	if contact != null:
		spent = true
		var ship: BlueShip = contact.get_collider() as BlueShip
		if ship != null and ship.alive:
			ship.take_damage(damage)
			hit_blue_ship.emit(ship, damage)
		impacted.emit(ship == null)
		queue_free()
		return
	_update_visual()
	if age >= lifetime:
		spent = true
		queue_free()


func trajectory(time: float) -> Vector3:
	var progress: float = clampf(time / maxf(arc_duration, 0.1), 0, 1)
	return _origin + flight_direction * projectile_speed * time + arc_axis * arc_amplitude * pow(sin(PI * progress), 2)


func trajectory_velocity(time: float) -> Vector3:
	var progress: float = clampf(time / maxf(arc_duration, 0.1), 0, 1)
	var bend_speed: float = arc_amplitude * PI / maxf(arc_duration, 0.1) * sin(TAU * progress) if time < arc_duration else 0.0
	return flight_direction * projectile_speed + arc_axis * bend_speed


func _update_visual() -> void:
	if kind == Kind.BOMB_CLUSTER:
		$Visual.scale = Vector3.ONE * (1 + sin(age * 8) * 0.12)
	if arcade_signature:
		if velocity.length_squared() > 0.001:
			global_basis = Basis.looking_at(velocity.normalized(), Vector3.RIGHT if absf(velocity.normalized().y) > 0.98 else Vector3.UP)
		$Visual.basis = Basis(Vector3.BACK, age * 0.6 if kind in [Kind.SEEKER_SALVO, Kind.MISSILE_SWARM] else 0)
		for node: Node in $Visual.get_children():
			if node is MeshInstance3D and node.name.begins_with("AnimatedEnergyRing"):
				var ring: MeshInstance3D = node as MeshInstance3D
				ring.rotation.z = age * (1.3 if ring.position.z < 0 else -1.3)
				ring.rotation.x = deg_to_rad(80 + sin(age * 1.5 + ring.position.z) * 10)
		return
	if velocity.length_squared() > 0.001:
		$Visual.basis = Basis.looking_at(velocity.normalized(), Vector3.RIGHT if absf(velocity.normalized().y) > 0.98 else Vector3.UP)


func _add_fins(width: float, z: float, color: Color) -> void:
	for index: int in range(4):
		var shape: BoxMesh = BoxMesh.new()
		shape.size = Vector3(width, 0.12, 1.3)
		var angle: float = index * PI / 2
		var fin: MeshInstance3D = _mesh(shape, color, Vector3(cos(angle) * width * 0.7, sin(angle) * width * 0.7, z))
		fin.rotation.z = angle


func _arcade_capsule(height_value: float, radius_value: float, color: Color, offset: Vector3 = Vector3.ZERO) -> void:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.height = height_value
	mesh.radius = radius_value
	mesh.radial_segments = 10
	mesh.rings = 4
	_mesh(mesh, color, offset).rotation_degrees.x = 90


func _arcade_cone(height_value: float, radius_value: float, color: Color, offset: Vector3) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = height_value
	mesh.top_radius = 0
	mesh.bottom_radius = radius_value
	mesh.radial_segments = 10
	_mesh(mesh, color, offset).rotation_degrees.x = -90


func _energy_ring(radius_value: float, z: float, color: Color) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = radius_value * 0.84
	mesh.outer_radius = radius_value
	mesh.rings = 14
	mesh.ring_segments = 5
	var ring: MeshInstance3D = _mesh(mesh, color, Vector3(0, 0, z))
	ring.rotation_degrees.x = 90
	return ring


func _build_arcade_signature(visual: Node3D, signature_key: int) -> void:
	if CombatMeshCache.has_signature(signature_key):
		CombatMeshCache.merge_parts(visual, signature_key)
	else:
		if kind == Kind.HEAVY_SHOT:
			_arcade_capsule(7.4, 1.25, Color(0.32, 0.15, 0.55))
			_arcade_cone(1.6, 1.15, Color(1, 0.6, 0.13), Vector3(0, 0, -4.2))
			_add_fins(1.8, 2.4, Color(0.8, 0.3, 1))
			_energy_ring(1.5, -1.7, Color(1, 0.75, 0.2))
			_arcade_capsule(1.8, 0.9, Color(1, 0.32, 0.05), Vector3(0, 0, 3.4))
			_arcade_capsule(8, 0.55, Color(0.9, 0.24, 0.06), Vector3(0, 0, 7.8))
		elif kind in [Kind.SEEKER_SALVO, Kind.MISSILE_SWARM]:
			_arcade_capsule(4.4, 0.6, Color(0.42, 0.08, 0.15))
			_arcade_cone(1.1, 0.6, Color(1, 0.35, 0.1), Vector3(0, 0, -2.3))
			_add_fins(0.9, 1.4, Color(0.8, 0.17, 0.22))
			_arcade_capsule(1.2, 0.5, Color(1, 0.18, 0.05), Vector3(0, 0, 2.1))
			_arcade_capsule(6, 0.3, Color(1, 0.1, 0.12), Vector3(0, 0, 5.2))
		elif kind == Kind.ARC_SALVO:
			_arcade_capsule(4.4, 0.85, Color(0.9, 0.05, 0.75))
			_arcade_capsule(4, 0.35, Color(1, 0.4, 0.9), Vector3(0, 0, 3.5))
		elif kind == Kind.BOMB_CLUSTER:
			_arcade_capsule(5.6, 2.8, Color(1, 0.45, 0.07))
			_energy_ring(3.2, 0, Color(1, 0.75, 0.1))
		else:
			_arcade_capsule(3.4, 0.35, Color(1, 0.85, 0.3))
			_arcade_capsule(2.6, 0.5, Color(0.8, 0.19, 0.04))
			_energy_ring(0.7, -0.6, Color(1, 0.65, 0.08))
		CombatMeshCache.merge_parts(visual, signature_key)
	if kind == Kind.ARC_SALVO:
		for z: float in [-1.2, 1.2]:
			var ring: MeshInstance3D = _energy_ring(1.3, z, Color(1, 0.55, 0.9))
			ring.name = "AnimatedEnergyRing_%d" % (0 if z < 0 else 1)
