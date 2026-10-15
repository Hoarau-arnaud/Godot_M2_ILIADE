class_name BlueLaser
extends Node3D

signal hit_hostile(target: Node3D, amount: int)

const HIT_MASK: int = 6 # Couche 2 astéroïdes + couche 3 hostiles, jamais les BlueShip.

@export var projectile_speed: float = 100.0
@export var lifetime: float = 3.0
@export var damage: int = 1
@export var base_hit_radius: float = 0.7
var _hit_shape: SphereShape3D = SphereShape3D.new()
var _hit_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

var flight_direction: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _spent: bool = false


func _ready() -> void:
	_hit_shape.radius = maxf(base_hit_radius, 0.001)
	_hit_query.shape = _hit_shape
	_hit_query.collision_mask = HIT_MASK
	_hit_query.margin = 0.001


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var remaining_lifetime: float = maxf(lifetime - _age, 0.0)
	var step_time: float = minf(delta, remaining_lifetime)
	var destination: Vector3 = global_position + flight_direction.normalized() * maxf(projectile_speed, 0.0) * step_time
	if global_position.distance_squared_to(destination) > 0.000001:
		var hit: Dictionary = _swept_collision(destination)
		if not hit.is_empty():
			_spent = true
			global_position = hit["position"]
			var target: Node3D = hit["collider"] as Node3D
			if target != null and target.is_in_group("hostile_agents") and target.has_method("take_damage") and bool(target.get("alive")):
				target.call("take_damage", maxi(damage, 1))
				hit_hostile.emit(target, maxi(damage, 1))
			# Un rocher arrête aussi le tir, sans dégâts ni score.
			queue_free()
			return
	global_position = destination
	_age += delta
	if _age >= maxf(lifetime, 0.0):
		_spent = true
		queue_free()


func _swept_collision(destination: Vector3) -> Dictionary:
	_hit_shape.radius = maxf(base_hit_radius, 0.001)
	_hit_query.transform = Transform3D(Basis.IDENTITY, global_position)
	_hit_query.motion = Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = space.intersect_shape(_hit_query, 1)
	if not overlaps.is_empty():
		overlaps[0]["position"] = global_position
		return overlaps[0]
	_hit_query.motion = destination - global_position
	var fractions: PackedFloat32Array = space.cast_motion(_hit_query)
	if fractions.size() >= 2 and fractions[1] < 1:
		_hit_query.transform.origin = global_position.lerp(destination, minf(fractions[1] + 0.002 / maxf(global_position.distance_to(destination), 0.001), 1))
		_hit_query.motion = Vector3.ZERO
		overlaps = space.intersect_shape(_hit_query, 1)
		if not overlaps.is_empty():
			overlaps[0]["position"] = _hit_query.transform.origin
			return overlaps[0]
	return {}
