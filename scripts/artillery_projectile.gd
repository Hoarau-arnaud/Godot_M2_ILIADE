class_name ArtilleryProjectile
extends CharacterBody3D

signal hit_blue_ship(target: BlueShip, amount: int)
signal impacted(obstacle: bool)

enum Kind { HEAVY_SHOT, SPREAD, ARC_SALVO, CROSS_FIRE, SEEKER_SALVO }

@export var kind: Kind = Kind.HEAVY_SHOT
@export var projectile_speed: float = 27.0
@export var lifetime: float = 14.0
@export var damage: int = 2
@export var avoidance_radius: float = 10.0
@export var turn_rate_degrees: float = 6.0
var flight_direction: Vector3 = Vector3.BACK
var target: BlueShip
var arc_axis: Vector3 = Vector3.UP
var arc_amplitude: float = 24.0
var arc_duration: float = 5.0
var age: float = 0.0
var spent: bool = false
var _origin: Vector3
var _shape: SphereShape3D


func _ready() -> void:
	add_to_group("hostile_projectiles")
	add_to_group("artillery_projectiles")
	collision_layer = 0
	collision_mask = 3 # BlueShip et astéroïdes ; jamais le lanceur ou ses alliés.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	flight_direction = flight_direction.normalized()
	if flight_direction.is_zero_approx():
		flight_direction = Vector3.BACK
	velocity = flight_direction * projectile_speed
	_origin = global_position
	_shape = SphereShape3D.new()
	_shape.radius = 1.8 if kind == Kind.HEAVY_SHOT else 0.35
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = _shape
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


func _mesh(mesh: Mesh, color: Color, offset: Vector3) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _material(color)
	part.position = offset
	$Visual.add_child(part)


func _build_visual() -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var colors: Array[Color] = [Color(0.72, 0.16, 1), Color(1, 0.72, 0.08), Color(0.95, 0.08, 0.85), Color(1, 0.32, 0.06), Color(1, 0.08, 0.12)]
	var core: SphereMesh = SphereMesh.new()
	core.radius = 1.8 if kind == Kind.HEAVY_SHOT else 0.42
	core.height = core.radius * 2
	core.radial_segments = 12
	core.rings = 6
	_mesh(core, colors[kind], Vector3.ZERO)
	var trail: BoxMesh = BoxMesh.new()
	trail.size = Vector3(0.4, 0.4, 12) if kind == Kind.HEAVY_SHOT else Vector3(0.24, 0.24, 7 if kind == Kind.CROSS_FIRE else 3)
	_mesh(trail, colors[kind] * Color(0.65, 0.65, 0.65), Vector3(0, 0, trail.size.z / 2))
	if kind == Kind.HEAVY_SHOT:
		var inner: SphereMesh = SphereMesh.new()
		inner.radius = 0.7
		inner.height = 1.4
		inner.radial_segments = 10
		inner.rings = 4
		_mesh(inner, Color(1, 0.65, 0.12), Vector3(0, 0, -1.6))
	elif kind == Kind.SEEKER_SALVO:
		var hull: BoxMesh = BoxMesh.new()
		hull.size = Vector3(0.6, 0.55, 2.6)
		_mesh(hull, Color(0.48, 0.08, 0.12), Vector3.ZERO)
		var engine: SphereMesh = SphereMesh.new()
		engine.radius = 0.45
		engine.height = 0.9
		engine.radial_segments = 8
		engine.rings = 4
		_mesh(engine, Color(1, 0.55, 0.12), Vector3(0, 0, 1.5))
	_update_visual()


func _physics_process(delta: float) -> void:
	if spent:
		return
	var step: float = minf(delta, maxf(lifetime - age, 0))
	var destination: Vector3
	if kind == Kind.SEEKER_SALVO:
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
	# Le volume physique est balayé, y compris pour le noyau lourd de 3,6 m.
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
	if velocity.length_squared() > 0.001:
		$Visual.basis = Basis.looking_at(velocity.normalized(), Vector3.RIGHT if absf(velocity.normalized().y) > 0.98 else Vector3.UP)
