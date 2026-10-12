class_name PatrolDrone
extends CharacterBody3D

signal died(drone: PatrolDrone)

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/explosion.tscn")
const BODY_CLEARANCE: float = 2.2

enum PatrolState { PATROL, AVOIDING, CHANGING_WAYPOINT, DESTROYED }

@export_category("Patrouille autonome")
@export var forward_speed: float = 9.2
@export var max_side_speed: float = 7.0
@export var acceleration: float = 10.0
@export var segment_length: float = 55.0
@export var waypoint_reach_distance: float = 7.0
@export var patrol_width: float = 25.0
@export var patrol_height: float = 15.0
@export var forward_variation: float = 1.0
@export var individual_seed: int = 1

@export_category("Perceptions locales")
@export var obstacle_detection_radius: float = 44.0
@export var obstacle_clearance: float = 2.0
@export var prediction_time: float = 4.0
@export var avoidance_weight: float = 6.0
@export var ship_safety_radius: float = 10.0
@export var ship_avoidance_weight: float = 1.2

var alive: bool = true
var patrol_state: PatrolState = PatrolState.PATROL
var patrol_anchor: Vector2 = Vector2.ZERO
var waypoint: Vector3 = Vector3.ZERO
var waypoints_selected: int = 0
var perceived_obstacle_count: int = 0
var perceived_ship_count: int = 0
var avoidance_ticks: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _phase: float = 0.0
var _preferred_avoidance: Vector3 = Vector3.UP
var _obstacle_directions: Dictionary[SpaceAsteroid, Vector3] = {}

@onready var _visuals: Node3D = $Visuals
@onready var _left_exhaust: MeshInstance3D = $Visuals/LeftExhaust
@onready var _right_exhaust: MeshInstance3D = $Visuals/RightExhaust


func _ready() -> void:
	_random.seed = individual_seed
	_phase = _random.randf_range(0.0, TAU)
	_preferred_avoidance = Vector3(0.0, 1.0 if _random.randf() > 0.5 else -1.0, 0.0)
	waypoint = global_position
	_choose_waypoint()
	velocity = Vector3.FORWARD * forward_speed


func _choose_waypoint() -> void:
	waypoint = Vector3(
		patrol_anchor.x + _random.randf_range(-patrol_width, patrol_width),
		patrol_anchor.y + _random.randf_range(-patrol_height, patrol_height),
		waypoint.z - maxf(segment_length, 20.0)
	)
	waypoints_selected += 1
	patrol_state = PatrolState.PATROL


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	if patrol_state == PatrolState.CHANGING_WAYPOINT:
		_choose_waypoint()
	elif global_position.distance_to(waypoint) <= maxf(waypoint_reach_distance, 0.1) or global_position.z <= waypoint.z:
		# Le passage du plan Z évite de revenir en arrière si un obstacle a dévié la route.
		patrol_state = PatrolState.CHANGING_WAYPOINT
	var to_target: Vector3 = waypoint - global_position
	var arrival_time: float = maxf(to_target.z / -maxf(forward_speed, 0.1), 0.8)
	var patrol_velocity: Vector3 = Vector3(to_target.x / arrival_time, to_target.y / arrival_time, 0.0)
	var obstacle_steering: Vector3 = _obstacle_avoidance() * avoidance_weight
	var ship_steering: Vector3 = _ship_avoidance() * ship_avoidance_weight
	var avoiding: bool = obstacle_steering.length_squared() + ship_steering.length_squared() > 0.001
	if avoiding:
		patrol_state = PatrolState.AVOIDING
		avoidance_ticks += 1
	elif patrol_state != PatrolState.CHANGING_WAYPOINT:
		patrol_state = PatrolState.PATROL
	var priority: float = clampf(obstacle_steering.length() / maxf(max_side_speed, 0.1), 0.0, 1.0)
	var side: Vector2 = Vector2(patrol_velocity.x, patrol_velocity.y) * (1.0 - priority * 0.85)
	side += Vector2(obstacle_steering.x + ship_steering.x, obstacle_steering.y + ship_steering.y)
	side = side.limit_length(maxf(max_side_speed, 0.0))
	var speed: float = maxf(forward_speed + sin(_time * 0.37 + _phase) * forward_variation, 1.0)
	velocity = velocity.move_toward(Vector3(side.x, side.y, -speed), maxf(acceleration, 0.1) * delta)
	_visuals.quaternion = _visuals.quaternion.slerp(Basis.looking_at(velocity.normalized(), Vector3.UP).get_rotation_quaternion(), 1.0 - exp(-3.0 * delta))
	_left_exhaust.scale.y = 1.0 + 0.12 * sin(_time * 5.0 + _phase)
	_right_exhaust.scale.y = 1.0 + 0.12 * sin(_time * 5.4 + _phase)
	var collision: KinematicCollision3D = move_and_collide(velocity * delta, false, 0.001, true)
	if collision != null and collision.get_collider() is SpaceAsteroid:
		_die()


func _obstacle_avoidance() -> Vector3:
	perceived_obstacle_count = 0
	for key: Variant in _obstacle_directions.keys():
		if not is_instance_valid(key):
			_obstacle_directions.erase(key)
			continue
		var remembered: SpaceAsteroid = key as SpaceAsteroid
		if global_position.z < remembered.global_position.z - remembered.avoidance_radius - BODY_CLEARANCE:
			_obstacle_directions.erase(remembered)
	var candidates: Array[SpaceAsteroid] = []
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var obstacle: SpaceAsteroid = node as SpaceAsteroid
		if obstacle == null or obstacle.is_queued_for_deletion():
			continue
		var offset: Vector3 = obstacle.global_position - global_position
		if offset.length() > maxf(obstacle_detection_radius, 0.0) or offset.z > 0.0:
			continue
		var clearance: float = obstacle.avoidance_radius + BODY_CLEARANCE + obstacle_clearance
		var prediction: Vector2 = MobileAvoidance.approach(offset, -velocity, prediction_time)
		if prediction.y >= clearance and not _obstacle_directions.has(obstacle):
			continue
		var index: int = 0
		while index < candidates.size() and global_position.distance_squared_to(candidates[index].global_position) < offset.length_squared():
			index += 1
		candidates.insert(index, obstacle)
		if candidates.size() > 3:
			candidates.pop_back()
	var result: Vector3 = Vector3.ZERO
	for obstacle: SpaceAsteroid in candidates:
		var offset: Vector3 = obstacle.global_position - global_position
		var clearance: float = obstacle.avoidance_radius + BODY_CLEARANCE + obstacle_clearance
		var prediction: Vector2 = MobileAvoidance.approach(offset, -velocity, prediction_time)
		if not _obstacle_directions.has(obstacle):
			_obstacle_directions[obstacle] = MobileAvoidance.direction(offset, -velocity, prediction.x, _preferred_avoidance)
			var callback: Callable = _forget_obstacle.bind(obstacle)
			if not obstacle.tree_exiting.is_connected(callback):
				obstacle.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
		result += MobileAvoidance.steering(offset, -velocity, prediction.x, clearance, _obstacle_directions[obstacle]) / (1.0 + float(perceived_obstacle_count) * 0.7)
		perceived_obstacle_count += 1
	return result.limit_length(3.0)


func _forget_obstacle(obstacle: SpaceAsteroid) -> void:
	_obstacle_directions.erase(obstacle)


func _ship_avoidance() -> Vector3:
	perceived_ship_count = 0
	var result: Vector3 = Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var ship: BlueShip = node as BlueShip
		if ship == null or not ship.alive or ship.is_queued_for_deletion():
			continue
		var away: Vector3 = global_position - ship.global_position
		var distance: float = away.length()
		if distance >= maxf(ship_safety_radius, 0.0):
			continue
		perceived_ship_count += 1
		away.z = 0.0
		var direction: Vector3 = away.normalized() if away.length_squared() > 0.01 else _preferred_avoidance
		result += direction * (1.0 - distance / maxf(ship_safety_radius, 0.1)) * 3.0
	return result.limit_length(3.0)


func _die() -> void:
	if not alive:
		return
	alive = false
	patrol_state = PatrolState.DESTROYED
	_obstacle_directions.clear()
	remove_from_group("patrol_drones")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	var explosion: Node3D = EXPLOSION_SCENE.instantiate() as Node3D
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	died.emit(self)
	hide()
	queue_free()
