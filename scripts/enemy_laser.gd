class_name EnemyLaser
extends Node3D

signal hit_blue_ship(target: BlueShip, amount: int)

const HIT_MASK: int = 3 # BlueShip (1) et astéroïdes (2), jamais les hostiles (4).

@export var projectile_speed: float = 45.0
@export var lifetime: float = 3.5
@export var damage: int = 1

var flight_direction: Vector3 = Vector3.FORWARD
var velocity: Vector3:
	get:
		return flight_direction.normalized() * maxf(projectile_speed, 0.0)
var _age: float = 0.0
var _spent: bool = false


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step_time: float = minf(delta, maxf(lifetime - _age, 0.0))
	var destination: Vector3 = global_position + velocity * step_time
	if global_position.distance_squared_to(destination) > 0.000001:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, destination, HIT_MASK)
		query.hit_from_inside = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
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
