class_name EnemyLaser
extends Node3D

signal hit_blue_ship(target: BlueShip, amount: int)

const HIT_MASK: int = 3 # BlueShip (1) et astéroïdes (2), jamais les hostiles (4).
enum VisualVariant { BOLT, SPEAR, PULSE }

@export var projectile_speed: float = 85.0
@export var lifetime: float = 3.5
@export var damage: int = 1
@export var avoidance_radius: float = 4.0
@export var visual_variant: VisualVariant = VisualVariant.BOLT
@export var patrol_pulse: bool = false

static var _green_material: StandardMaterial3D
static var _white_material: StandardMaterial3D
static var _white_cores: Dictionary[int, BoxMesh] = {}
static var _pulse_trail_mesh: CylinderMesh
static var _pulse_ring_mesh: TorusMesh

var flight_direction: Vector3 = Vector3.FORWARD
var velocity: Vector3:
	get:
		return flight_direction.normalized() * maxf(projectile_speed, 0.0)
var threat_strength: float = 1.0
var threat_category: int = ThreatPattern.Category.TARGETED
var target_seed: int = 0
var targeted: bool = false
var initial_target_position: Vector3
var initial_target_velocity: Vector3
var _age: float = 0.0
var _spent: bool = false
var battle_radius: float = 0
var _battle_nominal: Dictionary = {}
var _battle_shape: SphereShape3D
var _battle_query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	if patrol_pulse:
		visual_variant = VisualVariant.PULSE
		if _green_material == null:
			_green_material = StandardMaterial3D.new()
			_green_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_green_material.albedo_color = Color(0.3, 1, 0.42)
			_green_material.emission_enabled = true
			_green_material.emission = Color(0.12, 1, 0.28)
			_green_material.emission_energy_multiplier = 2.5
		var green: StandardMaterial3D = _green_material
		$Pulse.material_override = green
		$PulseTrail.material_override = green
		$Pulse.scale = Vector3.ONE * 2.25
		if _pulse_trail_mesh == null:
			_pulse_trail_mesh = CylinderMesh.new()
			_pulse_trail_mesh.top_radius = 0.28
			_pulse_trail_mesh.bottom_radius = 0.16
			_pulse_trail_mesh.height = 4.5
			_pulse_trail_mesh.radial_segments = 8
		$PulseTrail.mesh = _pulse_trail_mesh
		$PulseTrail.rotation_degrees.x = 90
		$PulseTrail.position.z = 2.4
		var halo: MeshInstance3D = MeshInstance3D.new()
		halo.name = "PulseHalo"
		if _pulse_ring_mesh == null:
			_pulse_ring_mesh = TorusMesh.new()
			_pulse_ring_mesh.inner_radius = 0.78
			_pulse_ring_mesh.outer_radius = 1
			_pulse_ring_mesh.rings = 16
			_pulse_ring_mesh.ring_segments = 6
		halo.mesh = _pulse_ring_mesh
		halo.material_override = green
		halo.rotation_degrees.x = 90
		add_child(halo)
	if visual_variant != VisualVariant.PULSE:
		var core: MeshInstance3D = MeshInstance3D.new()
		if _white_material == null:
			_white_material = StandardMaterial3D.new()
			_white_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_white_material.albedo_color = Color.WHITE
			_white_material.emission_enabled = true
			_white_material.emission = Color.WHITE
			_white_material.emission_energy_multiplier = 3
		if not _white_cores.has(visual_variant):
			var streak: BoxMesh = BoxMesh.new()
			streak.size = Vector3(0.18, 0.18, 6 if visual_variant == VisualVariant.BOLT else 8)
			streak.material = _white_material
			_white_cores[visual_variant] = streak
		core.mesh = _white_cores[visual_variant]
		core.position.z = 1.1 if visual_variant == VisualVariant.BOLT else 2
		add_child(core)
	$Bolt.visible = visual_variant == VisualVariant.BOLT
	$Spear.visible = visual_variant == VisualVariant.SPEAR
	$Pulse.visible = visual_variant == VisualVariant.PULSE
	$PulseTrail.visible = visual_variant == VisualVariant.PULSE


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step_time: float = minf(delta, maxf(lifetime - _age, 0.0))
	var destination: Vector3 = global_position + velocity * step_time
	if global_position.distance_squared_to(destination) > 0.000001:
		var hit: Dictionary
		if battle_radius > 0:
			hit = _battle_collision(destination)
		else:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, destination, HIT_MASK)
			query.hit_from_inside = true
			hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_spent = true
			global_position = hit["position"]
			var ship: BlueShip = hit["collider"] as BlueShip
			if ship != null and ship.alive:
				ship.take_damage(maxi(damage, 1))
				hit_blue_ship.emit(ship, maxi(damage, 1))
			queue_free()
			return
	global_position = destination
	_age += delta
	if _age >= maxf(lifetime, 0.0):
		_spent = true
		queue_free()


func set_battle_parameters(width: float, speed: float, level: int) -> void:
	if _battle_nominal.is_empty():
		_battle_nominal = {"speed": projectile_speed, "avoidance": avoidance_radius, "damage": damage}
		_battle_shape = SphereShape3D.new()
		_battle_query = PhysicsShapeQueryParameters3D.new()
		_battle_query.shape = _battle_shape
		_battle_query.collision_mask = HIT_MASK
		_battle_query.margin = 0.01
	var base_width: float = 1.5 if patrol_pulse else 1.75
	battle_radius = (0.65 if patrol_pulse else 0.22) * base_width * width
	_battle_shape.radius = battle_radius
	projectile_speed = float(_battle_nominal.speed) * speed
	avoidance_radius = battle_radius + 1.4 # Volume du projectile + marge du corps Blue, sans halo artificiel.
	damage = level # Les armes légères PRESENTATION commencent à un point.
	scale = Vector3(base_width * width, base_width * width, 1)


func _battle_collision(destination: Vector3) -> Dictionary:
	var query: PhysicsShapeQueryParameters3D = _battle_query
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.motion = destination - global_position
	query.collision_mask = HIT_MASK
	query.margin = 0.01
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() >= 2 and fractions[1] < 1:
		query.transform.origin = global_position.lerp(destination, minf(fractions[1] + 0.002, 1))
	query.motion = Vector3.ZERO
	var collisions: Array[Dictionary] = space.intersect_shape(query, 1)
	if not collisions.is_empty():
		var hit: Dictionary = collisions[0]
		hit["position"] = query.transform.origin
		return hit
	return {}
