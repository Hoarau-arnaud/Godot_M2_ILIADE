class_name Interceptor
extends PatrolDrone

signal fired(projectile: EnemyLaser)

const ENEMY_LASER_SCENE: PackedScene = preload("res://scenes/enemy_laser.tscn")
enum InterceptorState { PATROL, PURSUIT, DISENGAGE, AVOIDING, DESTROYED }

@export_category("Interception locale")
@export var target_detection_radius: float = 80.0
@export var target_prediction_time: float = 0.35
@export var max_pursuit_duration: float = 8.0
@export var disengage_duration: float = 4.0
@export var pursuit_distance: float = 24.0

@export_category("Rafales frontales")
@export var combat_enabled: bool = true
@export var firing_range: float = 52.0
@export var firing_cone_angle: float = 10.0
@export var burst_size: int = 3
@export var burst_interval: float = 0.2
@export var burst_cooldown: float = 1.6
@export var shot_spread_angle: float = 0.75
@export var pursuit_max_speed: float = 23.0

var interceptor_state: InterceptorState = InterceptorState.PATROL
var target: BlueShip = null
var projectile_container: Node3D = null
var shots_fired: int = 0
var pursuits_started: int = 0
var disengagements: int = 0
var _mission_state: InterceptorState = InterceptorState.PATROL
var _pursuit_time: float = 0.0
var _disengage_time: float = 0.0
var _escape_direction: Vector3 = Vector3.RIGHT
var _shot_timer: float = 0.0
var bursts_started: int = 0
var _burst_remaining: int = 0
var _fire_random: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _muzzle: Marker3D = $Visuals/Muzzle


func _ready() -> void:
	super._ready()
	_fire_random.seed = individual_seed + 41011
	_shot_timer = _fire_random.randf_range(0.0, 0.6)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	_update_mission(delta)
	var desired: Vector3 = Vector3(sin(_time * 0.6 + _phase) * 3.8, cos(_time * 0.43 + _phase) * 2.8, -forward_speed)
	if _mission_state == InterceptorState.PURSUIT and is_instance_valid(target):
		var offset: Vector3 = target.global_position + target.velocity * target_prediction_time - global_position
		# Correction locale limitée : conserver une distance de combat, sans coller la cible.
		desired = target.velocity + offset.normalized() * clampf((offset.length() - pursuit_distance) * 0.6, -4.0, 7.0)
		desired.z = clampf(desired.z, -pursuit_max_speed, -2.0)
	elif _mission_state == InterceptorState.DISENGAGE:
		desired = _escape_direction * 5.0 + Vector3.FORWARD * (forward_speed + 3.0)
	var collision_steering: Vector3 = _obstacle_avoidance() * avoidance_weight
	collision_steering += _ship_avoidance() * ship_avoidance_weight
	collision_steering += _hostile_separation()
	var priority: float = clampf(collision_steering.length() / maxf(max_side_speed, 0.1), 0.0, 1.0)
	interceptor_state = InterceptorState.AVOIDING if collision_steering.length_squared() > 0.001 else _mission_state
	if interceptor_state == InterceptorState.AVOIDING:
		avoidance_ticks += 1
	var side: Vector2 = (Vector2(desired.x, desired.y) * (1.0 - priority * 0.85) + Vector2(collision_steering.x, collision_steering.y)).limit_length(max_side_speed)
	velocity = velocity.move_toward(Vector3(side.x, side.y, desired.z), maxf(acceleration, 0.1) * delta)
	var facing: Vector3 = velocity.normalized()
	if interceptor_state == InterceptorState.PURSUIT and is_instance_valid(target):
		facing = (target.global_position + target.velocity * target_prediction_time - global_position).normalized()
	if facing.length_squared() > 0.001:
		var up: Vector3 = Vector3.RIGHT if absf(facing.dot(Vector3.UP)) > 0.98 else Vector3.UP
		_visuals.quaternion = _visuals.quaternion.slerp(Basis.looking_at(facing, up).get_rotation_quaternion(), 1.0 - exp(-3.2 * delta))
	_left_exhaust.scale.y = 1.0 + 0.15 * sin(_time * 6.0 + _phase)
	_right_exhaust.scale.y = 1.0 + 0.15 * sin(_time * 6.4 + _phase)
	var collision: KinematicCollision3D = move_and_collide(velocity * delta, false, 0.001, true)
	if collision != null and collision.get_collider() is SpaceAsteroid:
		_die()
	if alive:
		_update_fire(delta)


func _update_mission(delta: float) -> void:
	match _mission_state:
		InterceptorState.PATROL:
			target = _nearest_blue_ship()
			if target != null:
				var callback: Callable = _forget_target.bind(target)
				if not target.tree_exiting.is_connected(callback):
					target.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
				_mission_state = InterceptorState.PURSUIT
				_pursuit_time = 0.0
				pursuits_started += 1
		InterceptorState.PURSUIT:
			_pursuit_time += delta # Le temps continue pendant un évitement.
			if not is_instance_valid(target) or not target.alive or target.is_queued_for_deletion() or global_position.distance_to(target.global_position) > target_detection_radius or _pursuit_time >= max_pursuit_duration:
				_begin_disengage()
		InterceptorState.DISENGAGE:
			_disengage_time += delta
			if _disengage_time >= disengage_duration:
				_mission_state = InterceptorState.PATROL


func _nearest_blue_ship() -> BlueShip:
	var selected: BlueShip = null
	var candidates: Array[BlueShip] = []
	var nearest: float = maxf(target_detection_radius, 0.0)
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var ship: BlueShip = node as BlueShip
		if ship == null or not ship.alive or ship.is_queued_for_deletion():
			continue
		var distance: float = global_position.distance_to(ship.global_position)
		if readable_threats and distance <= target_detection_radius:
			candidates.append(ship)
		if distance <= nearest:
			selected = ship
			nearest = distance
	if readable_threats and not candidates.is_empty():
		return (get_parent().get_parent() as SpaceSimulation).balanced_target(candidates)
	return selected


func _begin_disengage() -> void:
	_escape_direction = _preferred_avoidance
	if is_instance_valid(target):
		var away: Vector3 = global_position - target.global_position
		away.z = 0.0
		if away.length_squared() > 0.01:
			_escape_direction = away.normalized()
	target = null
	_mission_state = InterceptorState.DISENGAGE
	_disengage_time = 0.0
	_burst_remaining = 0
	disengagements += 1


func _forget_target(ship: BlueShip) -> void:
	if target == ship:
		target = null


func _hostile_separation() -> Vector3:
	var result: Vector3 = Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group("hostile_agents"):
		var other: CharacterBody3D = node as CharacterBody3D
		if other == null or other == self or not bool(other.get("alive")) or other.is_queued_for_deletion():
			continue
		var away: Vector3 = global_position - other.global_position
		var distance: float = away.length()
		if distance >= 9.0:
			continue
		away.z = 0.0
		result += (away.normalized() if away.length_squared() > 0.01 else _preferred_avoidance) * (1.0 - distance / 9.0) * 4.0
	return result.limit_length(3.0)


func _has_clear_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_muzzle.global_position, target.global_position, 2)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_fire(delta: float) -> void:
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	if not combat_enabled or interceptor_state != InterceptorState.PURSUIT or not is_instance_valid(target) or not target.alive:
		return
	var offset: Vector3 = target.global_position - _muzzle.global_position
	var forward: Vector3 = -_muzzle.global_basis.z.normalized()
	if offset.length() > firing_range or offset.length_squared() < 0.001 or offset.normalized().dot(forward) < cos(deg_to_rad(firing_cone_angle)) or not _has_clear_line_of_sight() or _shot_timer > 0.0:
		return
	if _burst_remaining == 0:
		bursts_started += 1
		_burst_remaining = maxi(burst_size, 1)
	# Une estimation imparfaite au départ ; le projectile garde ensuite sa direction.
	var spread: Vector2 = Vector2(_fire_random.randf_range(-1.0, 1.0), _fire_random.randf_range(-1.0, 1.0)) * tan(deg_to_rad(shot_spread_angle))
	var aim: Vector3 = CombatPrediction.aim(_muzzle.global_position, target.global_position, target.velocity, 85 * presentation_projectile_speed) if predictive_targeting else target.global_position
	var category_value: int = ThreatPattern.Category.TARGETED
	if readable_threats:
		var sim: SpaceSimulation = get_parent().get_parent() as SpaceSimulation
		category_value = ThreatPattern.category(sim._threat_serial)
		aim += ThreatPattern.error(category_value, _fire_random)
	var direction: Vector3 = ((aim - _muzzle.global_position).normalized() + _muzzle.global_basis.x * spread.x + _muzzle.global_basis.y * spread.y).normalized()
	var departure_cone: float = firing_cone_angle
	if readable_threats and category_value != ThreatPattern.Category.TARGETED:
		departure_cone = 55 if category_value == ThreatPattern.Category.SUPPRESSION else 32
	if direction.dot(forward) < cos(deg_to_rad(departure_cone)):
		return
	if ArtilleryZone.dangerous_count(get_tree()) >= dangerous_projectile_limit:
		return
	var projectile: EnemyLaser = ENEMY_LASER_SCENE.instantiate() as EnemyLaser
	projectile.visual_variant = [EnemyLaser.VisualVariant.BOLT, EnemyLaser.VisualVariant.BOLT if predictive_targeting or burst_size >= 4 else EnemyLaser.VisualVariant.PULSE, EnemyLaser.VisualVariant.SPEAR][shots_fired % 3]
	projectile.projectile_speed = 85 if predictive_targeting else 45
	projectile.lifetime = 2.5 if predictive_targeting else 3.5
	projectile.damage = 2 if readable_threats else 1
	projectile.targeted = predictive_targeting and category_value == ThreatPattern.Category.TARGETED
	projectile.threat_category = category_value
	projectile.target_seed = target.individual_seed
	projectile.set_meta("weapon_family", "Bolt")
	projectile.initial_target_position = target.global_position
	projectile.initial_target_velocity = target.velocity
	projectile.flight_direction = direction
	var container: Node3D = projectile_container if is_instance_valid(projectile_container) else get_parent() as Node3D
	container.add_child(projectile)
	projectile.global_transform = Transform3D(Basis.looking_at(direction, _muzzle.global_basis.y.normalized()), _muzzle.global_position)
	shots_fired += 1
	if readable_threats:
		(get_parent().get_parent() as SpaceSimulation).next_threat_category()
	_burst_remaining -= 1
	_shot_timer = (maxf(burst_interval, 0.05) if _burst_remaining > 0 else maxf(burst_cooldown, 0.1)) / fire_intensity
	fired.emit(projectile)


func _die(combat_kill: bool = false) -> void:
	if not alive:
		return
	interceptor_state = InterceptorState.DESTROYED
	_mission_state = InterceptorState.DESTROYED
	target = null
	_burst_remaining = 0
	remove_from_group("interceptors")
	super._die(combat_kill)
