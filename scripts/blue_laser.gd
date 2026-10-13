class_name BlueLaser
extends Node3D

signal hit_hostile(target: Node3D, amount: int)

const HIT_MASK: int = 6 # Couche 2 astéroïdes + couche 3 hostiles, jamais les BlueShip.

@export var projectile_speed: float = 100.0
@export var lifetime: float = 3.0
@export var damage: int = 1

var flight_direction: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _spent: bool = false


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var remaining_lifetime: float = maxf(lifetime - _age, 0.0)
	var step_time: float = minf(delta, remaining_lifetime)
	var destination: Vector3 = global_position + flight_direction.normalized() * maxf(projectile_speed, 0.0) * step_time
	if global_position.distance_squared_to(destination) > 0.000001:
		# Balayage du segment : pas de tunneling, même pour un bolt rapide.
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, destination, HIT_MASK)
		query.hit_from_inside = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
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
