class_name BlueShip
extends CharacterBody3D

signal evasive_boost_started
signal critical_threat_detected
signal near_miss_recorded(asteroid: bool)
signal damage_received(amount: int)
signal died(ship: BlueShip)
signal fired(projectile: BlueLaser)
signal projectile_dodge_started
signal moving_asteroid_dodge_started

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/explosion.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/blue_laser.tscn")
const SHIP_CLEARANCE: float = 2.5

enum BehaviorState { NAVIGATION, AVOIDANCE, REGROUPING, DESTROYED, EVASIVE_BOOST }
enum CombatState { NO_TARGET, TARGET_VISIBLE, COOLDOWN }

@export_category("Vol permanent")
@export var forward_speed: float = 16.0
@export var max_side_speed: float = 15.0
@export var acceleration: float = 22.0
@export var turn_speed: float = 3.2
@export_category("Orientation visuelle")
@export var visual_pitch_limit_degrees: float = 8.0
@export var visual_yaw_limit_degrees: float = 10.0
@export var visual_roll_limit_degrees: float = 30.0
@export var max_forward_variation: float = 3.0
@export var individual_seed: int = 1
var demo_movement_multiplier: float = 1.0
var demo_spacing_multiplier: float = 1.0
var environment_perception_interval: float = 0
var _environment_sample_in: float = 0
var _cached_rock_avoidance: Vector3 = Vector3.ZERO
var _cached_mobile_avoidance: Vector3 = Vector3.ZERO
var _cached_projectile_avoidance: Vector3 = Vector3.ZERO
var _demo_movement_current: float = 1.0
var _demo_spacing_current: float = 1.0

@export_category("Wander 3D")
@export var wander_strength: float = 2.8
@export var vertical_wander_strength: float = 2.4
@export var longitudinal_wander_strength: float = 2.6
@export var wander_frequency: float = 0.7

@export_category("Regles locales")
@export var neighbor_radius: float = 32.0
@export var separation_distance: float = 11.0
@export var critical_separation_distance: float = 7.0
@export var critical_separation_multiplier: float = 4.0
@export var separation_weight: float = 9.0
@export var cohesion_comfort_radius: float = 12.0
@export var cohesion_weight: float = 0.16
@export var alignment_weight: float = 0.5

@export_category("Recuperation locale")
@export var recovery_radius: float = 50.0
@export var recovery_weight: float = 0.8
@export var recovery_speed: float = 5.0
@export_range(1, 5, 1) var recovery_neighbor_threshold: int = 2

@export_category("Anticipation des obstacles")
@export var obstacle_detection_radius: float = 44.0
@export var obstacle_clearance: float = 1.8
@export var avoidance_weight: float = 6.0
@export_range(1, 3, 1) var max_avoidance_threats: int = 3

@export_category("Dangers mobiles")
@export var mobile_detection_radius: float = 44.0
@export var mobile_prediction_time: float = 3.0
@export var mobile_avoidance_weight: float = 7.0

@export_category("Survie aux tirs ennemis")
@export var max_health: int = 3
@export var hostile_projectile_detection_radius: float = 80.0
@export var projectile_prediction_time: float = 4.0
@export var projectile_safety_distance: float = 4.0
@export var projectile_avoidance_weight: float = 8.0
@export var projectile_direction_memory: float = 0.45

@export_category("Combat frontal")
@export var combat_enabled: bool = true
@export var combat_detection_radius: float = 60.0
@export var firing_range: float = 44.0
@export var firing_cone_angle: float = 6.0 # Demi-angle en degrés autour du nez visuel.
@export var fire_cooldown: float = 0.7

@export_category("Boost local de survie")
@export var evasive_boost_enabled: bool = true
@export var evasive_boost_duration: float = 0.65 # Secondes simulées.
@export var evasive_boost_cooldown: float = 1.1 # Après la fin du boost.
@export var boost_forward_multiplier: float = 1.35
@export var boost_lateral_multiplier: float = 1.9
@export var boost_acceleration_multiplier: float = 2.2
@export var boost_roll_degrees: float = 55
@export var blue_laser_speed: float = 100
var evasive_boost_remaining: float = 0
var boost_cooldown_remaining: float = 0
var boost_direction: Vector3 = Vector3.ZERO
var evasive_boost_count: int = 0
var critical_threat_count: int = 0
var near_miss_count: int = 0
var asteroid_near_miss_count: int = 0
var _boost_blend: float = 0
var _boost_threat_id: int = 0
var _critical_candidate: Dictionary = {}
var _critical_ids: Dictionary[int, WeakRef] = {}
var _near_passes: Dictionary[int, Dictionary] = {}
var _boost_streak: MeshInstance3D
var _boost_material: StandardMaterial3D

var alive: bool = true
var health: int = 3
var projectile_avoidance_active: bool = false
var projectile_threat_count: int = 0
var projectile_dodge_count: int = 0
var projectile_dodge_ticks: int = 0
var _projectile_directions: Dictionary[Node3D, Vector3] = {}
var _projectile_memory_until: Dictionary[Node3D, float] = {}
var _hit_flash_time: float = 0.0
var behavior_state: BehaviorState = BehaviorState.NAVIGATION
var neighbor_count: int = 0
var critical_separation_active: bool = false
var combat_state: CombatState = CombatState.NO_TARGET
var combat_target: Node3D = null
var projectile_container: Node3D = null
var shots_fired: int = 0
var _personal_cooldown: float = 0.7
var _fire_timer: float = 0.0
var mobile_threat_count: int = 0
var mobile_avoidance_ticks: int = 0
var moving_asteroid_threat_count: int = 0
var moving_asteroid_avoidance_ticks: int = 0
var _visual_angles: Vector3 = Vector3.ZERO
var _drone_directions: Dictionary[CharacterBody3D, Vector3] = {}
var _time: float = 0.0
var _phases: Vector3 = Vector3.ZERO
var _personal_frequency: float = 1.0
var _personal_amplitude: float = 1.0
var _speed_factor: float = 1.0
var _preferred_avoidance: Vector3 = Vector3.RIGHT
var _threats: Array[SpaceAsteroid] = []
var _avoid_directions: Dictionary[SpaceAsteroid, Vector3] = {}
var _separation: Vector3 = Vector3.ZERO
var _critical_separation: Vector3 = Vector3.ZERO
var _cohesion: Vector3 = Vector3.ZERO
var _alignment: Vector3 = Vector3.ZERO
var _recovery: Vector3 = Vector3.ZERO

@onready var _visuals: Node3D = $Visuals
@onready var _right_exhaust: MeshInstance3D = $Visuals/RightExhaust
@onready var _left_exhaust: MeshInstance3D = $Visuals/LeftExhaust
@onready var _muzzle: Marker3D = $Visuals/Muzzle
@onready var _hit_flash: OmniLight3D = $Visuals/HitFlash


func _ready() -> void:
	health = maxi(max_health, 1)
	_build_boost_visual()
	_demo_movement_current = demo_movement_multiplier
	_demo_spacing_current = demo_spacing_multiplier
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = individual_seed
	_phases = Vector3(random.randf(), random.randf(), random.randf()) * TAU
	_personal_frequency = random.randf_range(0.82, 1.18)
	_personal_amplitude = random.randf_range(0.8, 1.2)
	_speed_factor = random.randf_range(0.97, 1.03)
	var angle: float = random.randf_range(0.0, TAU)
	_preferred_avoidance = Vector3(cos(angle), sin(angle), 0.0)
	velocity = Vector3.FORWARD * maxf(forward_speed * _speed_factor, 0.1)
	# Flux séparé : les nouveaux tirages ne changent pas le wander validé.
	var combat_random: RandomNumberGenerator = RandomNumberGenerator.new()
	combat_random.seed = individual_seed + 31003
	_personal_cooldown = maxf(fire_cooldown, 0.05) * combat_random.randf_range(0.85, 1.15)
	_fire_timer = combat_random.randf_range(0.0, _personal_cooldown)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	var adjustment: float = 1.0 - exp(-4.0 * delta)
	_demo_movement_current = lerpf(_demo_movement_current, demo_movement_multiplier, adjustment)
	_demo_spacing_current = lerpf(_demo_spacing_current, demo_spacing_multiplier, adjustment)
	_update_neighbor_rules()
	var steering: Vector3 = (
		_natural_wander()
		+ _separation * separation_weight
		+ _cohesion * cohesion_weight
		+ _alignment * alignment_weight
		+ _recovery * recovery_weight
	)
	_environment_sample_in -= delta
	if _environment_sample_in <= 0:
		_critical_candidate.clear()
		_cleanup_local_metrics()
		_cached_rock_avoidance = _obstacle_avoidance()
		_cached_mobile_avoidance = _mobile_avoidance()
		_cached_projectile_avoidance = _projectile_avoidance()
		_environment_sample_in = environment_perception_interval
	_update_evasive_boost(delta)
	var avoidance: Vector3 = _cached_rock_avoidance * avoidance_weight
	avoidance += _cached_mobile_avoidance * mobile_avoidance_weight
	var collision_priority: float = clampf(avoidance.length() / maxf(max_side_speed, 0.1), 0.0, 1.0)
	var projectile_steering: Vector3 = _cached_projectile_avoidance * projectile_avoidance_weight
	var projectile_priority: float = clampf(projectile_steering.length() / maxf(max_side_speed, 0.1), 0.0, 1.0)
	avoidance += projectile_steering * (1.0 - collision_priority)
	_update_behavior_state(avoidance)
	# Les règles du banc cèdent progressivement la priorité au contournement.
	var avoidance_priority: float = clampf(avoidance.length() / maxf(max_side_speed, 0.1), 0.0, 1.0)
	steering = steering * (1.0 - avoidance_priority * 0.75) + avoidance
	# Pendant une esquive, la séparation cède elle aussi devant les deux dangers.
	var separation_priority: float = 1.0
	if projectile_avoidance_active:
		separation_priority = (1.0 - projectile_priority) * (1.0 - collision_priority)
	steering += _critical_separation * separation_weight * avoidance_priority * 0.75 * separation_priority
	var side_limit: float = max_side_speed * lerpf(1, boost_lateral_multiplier, _boost_blend)
	var boost_steering: Vector3 = boost_direction * side_limit
	steering = steering.lerp(boost_steering, _boost_blend)
	var side_velocity: Vector2 = Vector2(steering.x, steering.y).limit_length(maxf(side_limit, 0.0))
	var base_speed: float = maxf(forward_speed * _speed_factor, 0.1) * lerpf(1, boost_forward_multiplier, _boost_blend)
	var variation_limit: float = maxf(max_forward_variation, 0.0)
	var forward_variation: float = clampf(steering.z, -variation_limit, minf(variation_limit, base_speed * 0.6))
	var desired_velocity: Vector3 = Vector3(side_velocity.x, side_velocity.y, -base_speed + forward_variation)
	velocity = velocity.move_toward(desired_velocity, maxf(acceleration, 0.1) * lerpf(1, boost_acceleration_multiplier, _boost_blend) * delta)
	_update_orientation(delta)
	_update_exhausts()
	# Le balayage physique détecte le contact, même si le déplacement dépasse une petite roche.
	var collision: KinematicCollision3D = move_and_collide(velocity * delta, false, 0.001, true)
	if collision != null:
		var obstacle: SpaceAsteroid = collision.get_collider() as SpaceAsteroid
		var collider: Node = collision.get_collider() as Node
		if obstacle != null or (collider != null and collider.is_in_group("hostile_agents")):
			_die()
	if alive:
		_update_combat(delta)


func _firing_forward() -> Vector3:
	return -_muzzle.global_basis.z.normalized()


func _combat_aim_position(target: Node3D) -> Vector3:
	return target.call("combat_aim_position", _muzzle.global_position) if target.has_method("combat_aim_position") else target.global_position


func _find_combat_target() -> Node3D:
	var selected: Node3D = null
	var nearest: float = maxf(combat_detection_radius, 0.0)
	var forward: Vector3 = _firing_forward()
	var minimum_dot: float = cos(deg_to_rad(clampf(firing_cone_angle, 0.0, 89.0)))
	for node: Node in get_tree().get_nodes_in_group("hostile_agents"):
		var target: Node3D = node as Node3D
		if target == null or target.is_queued_for_deletion() or not target.has_method("take_damage") or not bool(target.get("alive")):
			continue
		var offset: Vector3 = _combat_aim_position(target) - _muzzle.global_position
		var distance: float = offset.length()
		if distance < 0.001 or distance > nearest or offset.normalized().dot(forward) < minimum_dot:
			continue
		# Chercher aussi derrière une première cible masquée : seul un hostile visible est retenu.
		if not _has_clear_line_of_sight(target):
			continue
		selected = target
		nearest = distance
	return selected


func _has_clear_line_of_sight(target: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_muzzle.global_position, _combat_aim_position(target), 2)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_combat(delta: float) -> void:
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	combat_target = null
	if not combat_enabled or not alive:
		combat_state = CombatState.NO_TARGET
		return
	combat_target = _find_combat_target()
	if _fire_timer > 0.0:
		combat_state = CombatState.COOLDOWN
	else:
		combat_state = CombatState.TARGET_VISIBLE if combat_target != null else CombatState.NO_TARGET
	if combat_target == null:
		return
	var callback: Callable = _forget_combat_target.bind(combat_target)
	if not combat_target.tree_exiting.is_connected(callback):
		combat_target.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	# Le combat ne modifie aucune vitesse, force ou orientation de navigation.
	if _fire_timer > 0.0 or behavior_state in [BehaviorState.AVOIDANCE, BehaviorState.EVASIVE_BOOST] or projectile_avoidance_active or critical_separation_active:
		return
	if _muzzle.global_position.distance_to(_combat_aim_position(combat_target)) > maxf(firing_range, 0.0):
		return
	var projectile: BlueLaser = LASER_SCENE.instantiate() as BlueLaser
	projectile.projectile_speed = blue_laser_speed
	# Estimation unique au départ, sans guidage du projectile ni rotation du chasseur.
	var target_velocity: Vector3 = Vector3.ZERO
	if combat_target is CharacterBody3D:
		target_velocity = (combat_target as CharacterBody3D).velocity
	var offset: Vector3 = _combat_aim_position(combat_target) - _muzzle.global_position
	var closing_speed: float = maxf(projectile.projectile_speed - target_velocity.dot(offset.normalized()), 1.0)
	var flight_time: float = offset.length() / closing_speed
	var direction: Vector3 = (offset + target_velocity * flight_time).normalized()
	if direction.dot(_firing_forward()) < cos(deg_to_rad(clampf(firing_cone_angle, 0.0, 89.0))):
		projectile.free()
		return
	projectile.flight_direction = direction
	var container: Node3D = projectile_container if is_instance_valid(projectile_container) else get_parent() as Node3D
	container.add_child(projectile)
	projectile.global_transform = Transform3D(Basis.looking_at(projectile.flight_direction, Vector3.UP), _muzzle.global_position)
	shots_fired += 1
	_fire_timer = _personal_cooldown
	combat_state = CombatState.COOLDOWN
	fired.emit(projectile)


func _forget_combat_target(target: Node3D) -> void:
	if combat_target == target:
		combat_target = null
		combat_state = CombatState.COOLDOWN if _fire_timer > 0.0 else CombatState.NO_TARGET


func _natural_wander() -> Vector3:
	var time: float = _time * wander_frequency * _personal_frequency
	return Vector3(
		(sin(time + _phases.x) + 0.35 * sin(time * 1.83 + _phases.z)) * wander_strength,
		(cos(time * 0.79 + _phases.y) + 0.3 * sin(time * 1.41 + _phases.x)) * vertical_wander_strength,
		(sin(time * 0.62 + _phases.z) + 0.22 * sin(time * 1.13 + _phases.x)) * longitudinal_wander_strength
	) * _personal_amplitude * _demo_movement_current


func _update_neighbor_rules() -> void:
	var separation_radius: float = separation_distance * _demo_spacing_current
	var critical_radius: float = critical_separation_distance * _demo_spacing_current
	var comfort_radius: float = cohesion_comfort_radius * _demo_spacing_current
	critical_separation_active = false
	_separation = Vector3.ZERO
	_critical_separation = Vector3.ZERO
	_cohesion = Vector3.ZERO
	_alignment = Vector3.ZERO
	_recovery = Vector3.ZERO
	var center: Vector3 = Vector3.ZERO
	var average_velocity: Vector3 = Vector3.ZERO
	var count: int = 0
	var recovery_neighbor: BlueShip = null
	var recovery_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var other: BlueShip = node as BlueShip
		if other == null or other == self or not other.alive or other.is_queued_for_deletion():
			continue
		var away: Vector3 = global_position - other.global_position
		var distance: float = away.length()
		if distance > maxf(neighbor_radius, 0.0):
			if distance <= maxf(recovery_radius, neighbor_radius) and distance < recovery_distance:
				recovery_neighbor = other
				recovery_distance = distance
			continue
		center += other.global_position
		average_velocity += other.velocity
		count += 1
		if distance < maxf(critical_radius, 0.0):
			critical_separation_active = true
		if distance < separation_radius:
			if distance > 0.001:
				var strength: float = 1.0 - distance / maxf(separation_radius, 0.001)
				var critical: float = maxf(1.0 - distance / maxf(critical_radius, 0.001), 0.0)
				strength += critical * critical * maxf(critical_separation_multiplier, 0.0)
				_separation += (away / distance) * strength
				_critical_separation += (away / distance) * critical * critical * maxf(critical_separation_multiplier, 0.0)
			else:
				# Une superposition exacte reçoit aussi une correction non nulle.
				var sign_value: float = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
				_separation += Vector3.RIGHT * sign_value
				_critical_separation += Vector3.RIGHT * sign_value
	if count > 0:
		var to_center: Vector3 = center / float(count) - global_position
		var center_distance: float = to_center.length()
		# Rester dans la même zone, sans attirer les voisins déjà confortablement proches.
		if center_distance > maxf(comfort_radius, 0.0) and center_distance > 0.001:
			_cohesion = (to_center / center_distance) * minf(center_distance - maxf(comfort_radius, 0.0), 8.0)
		_alignment = (average_velocity / float(count) - velocity).limit_length(3.0)
	neighbor_count = count
	# Un petit groupe peut aussi chercher un voisin plus loin, sans coller son voisin proche.
	if count < recovery_neighbor_threshold and recovery_neighbor != null:
		var toward_neighbor: Vector3 = recovery_neighbor.global_position - global_position
		if toward_neighbor.length_squared() > 0.001:
			_recovery = toward_neighbor.normalized() * maxf(recovery_speed, 0.0)


func _update_behavior_state(avoidance: Vector3) -> void:
	if evasive_boost_remaining > 0:
		behavior_state = BehaviorState.EVASIVE_BOOST
		return
	if avoidance.length_squared() > 0.001:
		behavior_state = BehaviorState.AVOIDANCE
	elif _recovery.length_squared() > 0.001 and recovery_weight > 0.0:
		behavior_state = BehaviorState.REGROUPING
	else:
		behavior_state = BehaviorState.NAVIGATION


func _find_threats() -> void:
	_threats.clear()
	# Une clé peut contenir un Node libéré : vérifier sa validité avant tout cast typé.
	for key: Variant in _avoid_directions.keys():
		if not is_instance_valid(key):
			_avoid_directions.erase(key)
			continue
		var remembered: SpaceAsteroid = key as SpaceAsteroid
		var passed: bool = global_position.z < remembered.global_position.z - remembered.avoidance_radius - SHIP_CLEARANCE
		if remembered.motion_type != SpaceAsteroid.MotionType.STATIC:
			var offset: Vector3 = remembered.global_position - global_position
			passed = offset.dot(remembered.velocity - velocity) >= 0 and offset.length() > remembered.avoidance_radius + SHIP_CLEARANCE + obstacle_clearance + 2.0
		if remembered.is_queued_for_deletion() or passed:
			_avoid_directions.erase(remembered)
	var heading: Vector3 = velocity.normalized() if velocity.length_squared() > 0.001 else Vector3.FORWARD
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var obstacle: SpaceAsteroid = node as SpaceAsteroid
		if obstacle == null or obstacle.is_queued_for_deletion():
			continue
		var offset: Vector3 = obstacle.global_position - global_position
		if offset.length() > maxf(obstacle_detection_radius, 0.0):
			continue
		if evasive_boost_enabled:
			var danger_radius: float = obstacle.avoidance_radius + SHIP_CLEARANCE + obstacle_clearance
			_consider_boost(obstacle, offset, obstacle.velocity - velocity, danger_radius, 3, 1.4, true)
			_track_near_pass(obstacle, offset, obstacle.velocity - velocity, danger_radius + 2, true)
		var remembered: bool = _avoid_directions.has(obstacle)
		var clearance: float = obstacle.avoidance_radius + SHIP_CLEARANCE + maxf(obstacle_clearance, 0.0)
		if obstacle.motion_type != SpaceAsteroid.MotionType.STATIC:
			var prediction: Vector2 = MobileAvoidance.approach(offset, obstacle.velocity - velocity, mobile_prediction_time)
			if prediction.y < clearance + 1.0 or remembered:
				_insert_threat(obstacle)
			continue
		if offset.z >= 0.0 and not remembered:
			continue
		var ahead: float = offset.dot(heading)
		var predicted_miss: float = (offset - heading * maxf(ahead, 0.0)).length()
		var forward_miss: float = Vector2(offset.x, offset.y).length()
		if not remembered and minf(predicted_miss, forward_miss) > clearance + 1.0:
			continue
		_insert_threat(obstacle)


func _insert_threat(obstacle: SpaceAsteroid) -> void:
	var entry_distance: float = _obstacle_urgency(obstacle)
	var index: int = 0
	while index < _threats.size():
		var other_entry: float = _obstacle_urgency(_threats[index])
		if entry_distance < other_entry:
			break
		index += 1
	var limit: int = clampi(max_avoidance_threats, 1, 3)
	if index >= limit:
		return
	_threats.insert(index, obstacle)
	if _threats.size() > limit:
		_threats.pop_back()


func _obstacle_urgency(obstacle: SpaceAsteroid) -> float:
	if obstacle.motion_type == SpaceAsteroid.MotionType.STATIC:
		return global_position.z - obstacle.global_position.z - obstacle.avoidance_radius
	var prediction: Vector2 = MobileAvoidance.approach(obstacle.global_position - global_position, obstacle.velocity - velocity, mobile_prediction_time)
	return prediction.x * maxf(-velocity.z, 0.1) - obstacle.avoidance_radius


func _obstacle_avoidance() -> Vector3:
	var was_mobile: bool = moving_asteroid_threat_count > 0
	moving_asteroid_threat_count = 0
	_find_threats()
	var result: Vector3 = Vector3.ZERO
	var primary_force: Vector3 = Vector3.ZERO
	for index: int in range(_threats.size()):
		var obstacle: SpaceAsteroid = _threats[index]
		if obstacle.motion_type != SpaceAsteroid.MotionType.STATIC:
			moving_asteroid_threat_count += 1
		if not _avoid_directions.has(obstacle):
			_avoid_directions[obstacle] = _choose_avoidance_direction(obstacle)
			obstacle.tree_exiting.connect(_forget_obstacle.bind(obstacle), CONNECT_ONE_SHOT)
		var force: Vector3 = _avoidance_force(obstacle, _avoid_directions[obstacle])
		if index == 0:
			primary_force = force
		result += force / (1.0 + float(index) * 0.7)
	if moving_asteroid_threat_count > 0:
		moving_asteroid_avoidance_ticks += 1
		if not was_mobile:
			moving_asteroid_dodge_started.emit()
	# Deux corrections opposées ne doivent pas annuler la menace la plus urgente.
	if primary_force.length_squared() > 0.001:
		var primary_direction: Vector3 = primary_force.normalized()
		var missing: float = primary_force.length() * 0.7 - result.dot(primary_direction)
		result += primary_direction * maxf(missing, 0.0)
	return result.limit_length(3.0)


func _mobile_avoidance() -> Vector3:
	mobile_threat_count = 0
	for key: Variant in _drone_directions.keys():
		if not is_instance_valid(key):
			_drone_directions.erase(key)
			continue
		var drone: CharacterBody3D = key as CharacterBody3D
		if not bool(drone.get("alive")) or global_position.distance_to(drone.global_position) > maxf(mobile_detection_radius, 0.0):
			_drone_directions.erase(drone)
	var result: Vector3 = Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group("hostile_agents"):
		var drone: CharacterBody3D = node as CharacterBody3D
		if drone == null or not bool(drone.get("alive")) or drone.is_queued_for_deletion():
			continue
		var offset: Vector3 = drone.global_position - global_position
		if offset.length() > maxf(mobile_detection_radius, 0.0):
			continue
		var relative_velocity: Vector3 = drone.velocity - velocity
		var body_radius: Variant = drone.get("body_clearance")
		var clearance: float = SHIP_CLEARANCE + (float(body_radius) if body_radius != null else 2.2) + maxf(obstacle_clearance, 0.0)
		var prediction: Vector2 = MobileAvoidance.approach(offset, relative_velocity, mobile_prediction_time)
		if prediction.y >= clearance or (prediction.x <= 0.0 and offset.dot(relative_velocity) >= 0.0 and offset.length() > clearance):
			continue
		if not _drone_directions.has(drone):
			_drone_directions[drone] = MobileAvoidance.direction(offset, relative_velocity, prediction.x, Vector3.UP)
			var callback: Callable = _forget_drone.bind(drone)
			if not drone.tree_exiting.is_connected(callback):
				drone.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
		result += MobileAvoidance.steering(offset, relative_velocity, prediction.x, clearance, _drone_directions[drone])
		mobile_threat_count += 1
	if mobile_threat_count > 0:
		mobile_avoidance_ticks += 1
	return result.limit_length(3.0)


func _forget_drone(drone: CharacterBody3D) -> void:
	_drone_directions.erase(drone)


func _projectile_avoidance() -> Vector3:
	var was_active: bool = projectile_avoidance_active
	projectile_threat_count = 0
	var result: Vector3 = Vector3.ZERO
	for key: Variant in _projectile_directions.keys():
		if not is_instance_valid(key):
			_projectile_directions.erase(key)
			_projectile_memory_until.erase(key)
			continue
		var remembered: Node3D = key as Node3D
		if remembered.is_queued_for_deletion() or _time > _projectile_memory_until[remembered]:
			_forget_projectile(remembered)
	for node: Node in get_tree().get_nodes_in_group("hostile_projectiles"):
		var projectile: Node3D = node as Node3D
		if projectile == null or projectile.is_queued_for_deletion():
			continue
		var offset: Vector3 = projectile.global_position - global_position
		var danger_radius: float = maxf(float(projectile.get("avoidance_radius")), 0.1)
		var clearance: float = maxf(projectile_safety_distance, danger_radius)
		if offset.length() > maxf(hostile_projectile_detection_radius, 0.0) + maxf(clearance - projectile_safety_distance, 0):
			continue
		var relative_velocity: Vector3 = Vector3(projectile.get("velocity")) - velocity
		if evasive_boost_enabled:
			_consider_boost(projectile, offset, relative_velocity, clearance, projectile_prediction_time, 1.2 if projectile is ArtilleryProjectile else 1, false)
			_track_near_pass(projectile, offset, relative_velocity, clearance + 2, false)
		# Seuls les tirs entrants dont le passage prédit est trop proche comptent.
		if offset.dot(relative_velocity) >= 0.0:
			continue
		var prediction: Vector2 = MobileAvoidance.approach(offset, relative_velocity, projectile_prediction_time)
		if prediction.x <= 0.0:
			continue
		var dangerous: bool = prediction.y < clearance
		# Une courte persistance évite d'alterner esquive/navigation à la frontière de 4 m.
		if not dangerous and not _projectile_directions.has(projectile):
			continue
		if not _projectile_directions.has(projectile):
			_projectile_directions[projectile] = MobileAvoidance.direction(offset, relative_velocity, prediction.x, _preferred_avoidance)
			var callback: Callable = _forget_projectile.bind(projectile)
			if not projectile.tree_exiting.is_connected(callback):
				projectile.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
		if dangerous:
			_projectile_memory_until[projectile] = _time + maxf(projectile_direction_memory, 0.05)
		var force: Vector3 = MobileAvoidance.steering(offset, relative_velocity, prediction.x, clearance, _projectile_directions[projectile])
		# Garder la première menace si deux rafales demandent des corrections opposées.
		if result.length_squared() > 0.01 and force.dot(result) < 0.0:
			force *= 0.25
		result += force
		projectile_threat_count += 1
	for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
		var zone: ArtilleryZone = node as ArtilleryZone
		var force: Vector3 = zone.avoidance_force(global_position, velocity)
		if evasive_boost_enabled and not force.is_zero_approx() and zone.delay - zone.age <= 1.0:
			_consider_zone_boost(zone, force)
		if not force.is_zero_approx():
			result = force # Zone télégraphiée prioritaire devant les petits bolts.
			projectile_threat_count += 1
	projectile_avoidance_active = projectile_threat_count > 0
	if projectile_avoidance_active:
		projectile_dodge_ticks += 1
		if not was_active:
			projectile_dodge_count += 1
			projectile_dodge_started.emit()
	return result.limit_length(3.0)


func _forget_projectile(projectile: Node3D) -> void:
	_projectile_directions.erase(projectile)
	_projectile_memory_until.erase(projectile)


func take_damage(amount: int) -> void:
	if not alive or amount <= 0:
		return
	damage_received.emit(amount)
	health = maxi(health - amount, 0)
	if health == 0:
		_die()
	else:
		_hit_flash_time = 0.14
		_hit_flash.light_energy = 2.5


func _process(delta: float) -> void:
	_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
	_hit_flash.light_energy = 2.5 * _hit_flash_time / 0.14


func _forget_obstacle(obstacle: SpaceAsteroid) -> void:
	_avoid_directions.erase(obstacle)
	_threats.erase(obstacle)


func _avoidance_force(obstacle: SpaceAsteroid, direction: Vector3) -> Vector3:
	var offset: Vector3 = obstacle.global_position - global_position
	var clearance: float = obstacle.avoidance_radius + SHIP_CLEARANCE + maxf(obstacle_clearance, 0.0)
	if obstacle.motion_type != SpaceAsteroid.MotionType.STATIC:
		var relative_velocity: Vector3 = obstacle.velocity - velocity
		var prediction: Vector2 = MobileAvoidance.approach(offset, relative_velocity, mobile_prediction_time)
		return MobileAvoidance.steering(offset, relative_velocity, prediction.x, clearance + 0.5, direction)
	var lateral_offset: Vector3 = Vector3(-offset.x, -offset.y, 0.0)
	var remaining: float = clearance + 0.5 - lateral_offset.dot(direction)
	var time_before_contact: float = maxf((-offset.z - obstacle.avoidance_radius - SHIP_CLEARANCE) / maxf(-velocity.z, 0.1), 0.4)
	# La direction est mémorisée jusqu'au dépassement ; seule l'intensité évolue.
	return direction * clampf(remaining / time_before_contact, 0.0, 2.5)


func _choose_avoidance_direction(obstacle: SpaceAsteroid) -> Vector3:
	var offset: Vector3 = obstacle.global_position - global_position
	var time_to_obstacle: float = maxf(-offset.z / maxf(-velocity.z, 0.1), 0.0)
	if obstacle.motion_type != SpaceAsteroid.MotionType.STATIC:
		time_to_obstacle = MobileAvoidance.approach(offset, obstacle.velocity - velocity, mobile_prediction_time).x
	var future_offset: Vector3 = global_position + velocity * time_to_obstacle - (obstacle.global_position + obstacle.velocity * time_to_obstacle)
	future_offset.z = 0.0
	var preferred: Vector3 = future_offset.normalized() if future_offset.length_squared() > 0.04 else _preferred_avoidance
	var best: Vector3 = preferred
	var best_score: float = _route_score(obstacle, best, preferred)
	# Huit directions simples suffisent pour choisir un côté moins encombré.
	for index: int in range(1, 8):
		var candidate: Vector3 = preferred.rotated(Vector3.BACK, TAU * float(index) / 8.0)
		var score: float = _route_score(obstacle, candidate, preferred)
		if score > best_score:
			best = candidate
			best_score = score
	return best


func _route_score(obstacle: SpaceAsteroid, direction: Vector3, preferred: Vector3) -> float:
	var clearance: float = obstacle.avoidance_radius + SHIP_CLEARANCE + maxf(obstacle_clearance, 0.0)
	var waypoint: Vector3 = obstacle.global_position + direction * (clearance + 0.5)
	var score: float = direction.dot(preferred) * 1.5
	for other: SpaceAsteroid in _threats:
		if other == obstacle or absf(other.global_position.z - obstacle.global_position.z) > 12.0:
			continue
		var offset: Vector3 = waypoint - other.global_position
		var gap: float = Vector2(offset.x, offset.y).length() - other.avoidance_radius - SHIP_CLEARANCE - maxf(obstacle_clearance, 0.0)
		score += clampf(gap, -8.0, 3.0) * 0.8
	return score


func _update_orientation(delta: float) -> void:
	# Le nez reste dominé par -Z ; ces angles n'entrent jamais dans le steering physique.
	var lateral: Vector2 = Vector2(velocity.x, velocity.y) / maxf(max_side_speed, 0.1)
	var target: Vector3 = Vector3(
		clampf(lateral.y, -1, 1) * deg_to_rad(visual_pitch_limit_degrees),
		-clampf(lateral.x, -1, 1) * deg_to_rad(visual_yaw_limit_degrees),
		-clampf(lateral.x, -1, 1) * deg_to_rad(boost_roll_degrees if evasive_boost_remaining > 0 else visual_roll_limit_degrees)
	)
	_visual_angles.x = lerpf(_visual_angles.x, target.x, 1.0 - exp(-turn_speed * 0.55 * delta))
	_visual_angles.y = lerpf(_visual_angles.y, target.y, 1.0 - exp(-turn_speed * delta))
	_visual_angles.z = lerpf(_visual_angles.z, target.z, 1.0 - exp(-turn_speed * 1.8 * delta))
	_visuals.basis = Basis.from_euler(_visual_angles)


func _update_exhausts() -> void:
	var boost_scale: float = lerpf(1, 2.2, _boost_blend)
	_boost_material.emission_energy_multiplier = lerpf(1.5, 5.0, _boost_blend)
	_boost_streak.visible = _boost_blend > 0.15
	_boost_streak.scale.z = lerpf(0.5, 1.3, _boost_blend)
	var thrust: float = 0.65 + clampf(velocity.length() / maxf(forward_speed, 0.1), 0.4, 1.8) * 0.5
	_right_exhaust.scale.y = thrust * boost_scale * (1.0 + 0.14 * sin(_time * 6.1 + _phases.x))
	_left_exhaust.scale.y = thrust * boost_scale * (1.0 + 0.14 * sin(_time * 5.7 + _phases.y))


func retire() -> void:
	if not alive:
		return
	_stop_navigation()
	hide()
	queue_free()


func _stop_navigation() -> void:
	alive = false
	combat_target = null
	combat_state = CombatState.NO_TARGET
	behavior_state = BehaviorState.DESTROYED
	_threats.clear()
	_avoid_directions.clear()
	_drone_directions.clear()
	_projectile_directions.clear()
	_projectile_memory_until.clear()
	_near_passes.clear()
	_critical_ids.clear()
	_critical_candidate.clear()
	evasive_boost_remaining = 0
	projectile_avoidance_active = false
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process(false)
	remove_from_group("blue_ships")
	collision_layer = 0
	collision_mask = 0


func _die() -> void:
	if not alive:
		return
	_stop_navigation()
	health = 0
	var explosion: Node3D = EXPLOSION_SCENE.instantiate() as Node3D
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	died.emit(self)
	hide()
	queue_free()


func _build_boost_visual() -> void:
	_boost_material = (_right_exhaust.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	_right_exhaust.material_override = _boost_material
	_left_exhaust.material_override = _boost_material
	_boost_streak = MeshInstance3D.new()
	_boost_streak.name = "EmergencyCyanStreak"
	var trail: BoxMesh = BoxMesh.new()
	trail.size = Vector3(0.18, 0.18, 7)
	_boost_streak.mesh = trail
	_boost_streak.material_override = _boost_material
	_boost_streak.position = Vector3(0, 0, 6)
	_boost_streak.hide()
	_visuals.add_child(_boost_streak)


func _consider_boost(node: Node3D, offset: Vector3, relative: Vector3, clearance: float, horizon: float, weight: float, asteroid: bool) -> void:
	var danger: Dictionary = CombatPrediction.threat(offset, relative, clearance, horizon, weight)
	if danger.is_empty():
		return
	var urgent: bool = danger.impact_time <= 0.8 if asteroid else danger.time <= 1.0
	if not urgent or danger.score < (0.8 if asteroid else 1.0):
		return
	danger.node = weakref(node)
	danger.id = node.get_instance_id()
	danger.offset = offset
	danger.preferred = Vector3.ZERO
	_register_critical(danger)


func _consider_zone_boost(zone: ArtilleryZone, direction: Vector3) -> void:
	_register_critical({"node": weakref(zone), "id": zone.get_instance_id(), "score": 4.0, "time": maxf(zone.delay - zone.age, 0), "miss": 0.0, "relative_velocity": Vector3.BACK, "offset": zone.global_position - global_position, "preferred": direction.normalized()})


func _register_critical(danger: Dictionary) -> void:
	var id: int = danger.id
	if not _critical_ids.has(id):
		_critical_ids[id] = danger.node
		critical_threat_count += 1
		critical_threat_detected.emit()
	if _critical_candidate.is_empty() or danger.score > _critical_candidate.score:
		_critical_candidate = danger


func _update_evasive_boost(delta: float) -> void:
	if not evasive_boost_enabled:
		return
	boost_cooldown_remaining = maxf(boost_cooldown_remaining - delta, 0)
	var previous: float = evasive_boost_remaining
	evasive_boost_remaining = maxf(evasive_boost_remaining - delta, 0)
	if previous > 0 and evasive_boost_remaining == 0:
		boost_cooldown_remaining = evasive_boost_cooldown
	if evasive_boost_remaining <= 0 and not _critical_candidate.is_empty():
		var danger_node: Object = (_critical_candidate.node as WeakRef).get_ref()
		var lethal_override: bool = _critical_candidate.time < 0.25 and _critical_candidate.miss < 1.8 and int(_critical_candidate.id) != _boost_threat_id
		if is_instance_valid(danger_node) and (boost_cooldown_remaining <= 0 or lethal_override):
			boost_direction = _choose_boost_direction(_critical_candidate)
			_boost_threat_id = _critical_candidate.id
			evasive_boost_remaining = evasive_boost_duration
			evasive_boost_count += 1
			evasive_boost_started.emit()
	_boost_blend = move_toward(_boost_blend, 1 if evasive_boost_remaining > 0 else 0, delta * (12 if evasive_boost_remaining > 0 else 2.8))


func _choose_boost_direction(danger: Dictionary) -> Vector3:
	var incoming: Vector3 = Vector3(danger.relative_velocity).normalized()
	var preferred: Vector3 = danger.preferred
	if preferred.is_zero_approx():
		preferred = -Vector3(danger.offset) - Vector3(danger.relative_velocity) * float(danger.time)
		preferred.z = 0
		preferred = preferred.normalized() if preferred.length_squared() > 0.04 else _preferred_avoidance
	var obstacles: Array[Node] = get_tree().get_nodes_in_group("asteroids")
	var projectiles: Array[Node] = get_tree().get_nodes_in_group("hostile_projectiles")
	var blues: Array[Node] = get_tree().get_nodes_in_group("blue_ships")
	var best: Vector3 = preferred
	var best_score: float = -INF
	for index: int in range(8):
		var direction: Vector3 = Vector3(cos(index * TAU / 8), sin(index * TAU / 8), 0)
		var point: Vector3 = global_position + velocity * 0.4 + direction * 10
		var score: float = direction.dot(preferred) * 2 - absf(direction.dot(incoming)) * 3
		for other: Node in blues:
			if other == self:
				continue
			var ship: BlueShip = other as BlueShip
			score -= maxf(12 - point.distance_to(ship.global_position + ship.velocity * 0.4), 0) * 1.5
		for other: Node in obstacles:
			var rock: SpaceAsteroid = other as SpaceAsteroid
			if rock.global_position.distance_squared_to(global_position) < 3600:
				score -= maxf(rock.avoidance_radius + 6 - point.distance_to(rock.global_position + rock.velocity * 0.4), 0) * 2
		for other: Node in projectiles:
			var projectile: Node3D = other as Node3D
			if projectile.is_queued_for_deletion() or projectile.global_position.distance_squared_to(global_position) > 6400:
				continue
			var closest: Vector2 = MobileAvoidance.approach(projectile.global_position - point, Vector3(projectile.get("velocity")) - velocity, 0.7)
			score -= maxf(float(projectile.get("avoidance_radius")) + 2 - closest.y, 0)
		if score > best_score:
			best_score = score
			best = direction
	return best


func _track_near_pass(node: Node3D, offset: Vector3, relative: Vector3, radius_value: float, asteroid: bool) -> void:
	var id: int = node.get_instance_id()
	if not _near_passes.has(id):
		_near_passes[id] = {"node": weakref(node), "previous": offset, "minimum": offset.length(), "counted": false}
	var pass_data: Dictionary = _near_passes[id]
	var previous: Vector3 = pass_data.previous
	var segment: Vector3 = offset - previous
	var nearest: Vector3 = previous + segment * clampf(-previous.dot(segment) / maxf(segment.length_squared(), 0.00001), 0, 1)
	pass_data.minimum = minf(pass_data.minimum, nearest.length())
	pass_data.previous = offset
	if not pass_data.counted and offset.dot(relative) > 0 and pass_data.minimum < radius_value:
		pass_data.counted = true
		if asteroid:
			asteroid_near_miss_count += 1
		else:
			near_miss_count += 1
		near_miss_recorded.emit(asteroid)


func _cleanup_local_metrics() -> void:
	for id: int in _near_passes.keys():
		var object: Object = (_near_passes[id].node as WeakRef).get_ref()
		if not is_instance_valid(object) or (object as Node3D).global_position.distance_squared_to(global_position) > 14400:
			_near_passes.erase(id)
	for id: int in _critical_ids.keys():
		if not is_instance_valid(_critical_ids[id].get_ref()):
			_critical_ids.erase(id)
