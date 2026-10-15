class_name BlueShip
extends CharacterBody3D

signal evasive_boost_started
signal critical_threat_detected
signal near_miss_recorded(asteroid: bool)
signal damage_received(amount: int)
signal threat_reaction(family: String)
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
var arcade_visuals_enabled: bool = false
var death_cause: String = ""
var gate_opening_choices: int = 0
var gate_opening_changes: int = 0
var presentation_death_effect: bool = false
var presentation_combat_interval: float = 0
var _combat_sample_at: float = -INF
var _gate_memory: Dictionary[MovingLaserGate, Dictionary] = {}
var _aura_blend: float = 0
var _aura: MeshInstance3D
var _aura_material: StandardMaterial3D
var _aura_ring_material: StandardMaterial3D
var _boost_rings: Array[MeshInstance3D] = []
var adaptive_threat_response: bool = false
var reinforcement_glow_remaining: float = 0
var _boost_strength: float = 1
var _boost_blend: float = 0
var _boost_threat_id: int = 0
var _critical_candidate: Dictionary = {}
var _reaction_ids: Dictionary[int, WeakRef] = {}
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
	_hit_flash.hide()
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
	reinforcement_glow_remaining = maxf(reinforcement_glow_remaining - delta, 0)
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
	var side_limit: float = max_side_speed * lerpf(1, boost_lateral_multiplier * _boost_strength, _boost_blend)
	var boost_steering: Vector3 = boost_direction * side_limit
	steering = steering.lerp(boost_steering, _boost_blend)
	var side_velocity: Vector2 = Vector2(steering.x, steering.y).limit_length(maxf(side_limit, 0.0))
	var base_speed: float = maxf(forward_speed * _speed_factor, 0.1) * lerpf(1, boost_forward_multiplier, _boost_blend)
	var variation_limit: float = maxf(max_forward_variation, 0.0)
	var forward_variation: float = clampf(steering.z, -variation_limit, minf(variation_limit, base_speed * 0.6))
	var desired_velocity: Vector3 = Vector3(side_velocity.x, side_velocity.y, -base_speed + forward_variation)
	velocity = velocity.move_toward(desired_velocity, maxf(acceleration, 0.1) * lerpf(1, boost_acceleration_multiplier, _boost_blend) * delta)
	_update_orientation(delta)
	# Le balayage physique détecte le contact, même si le déplacement dépasse une petite roche.
	var collision: KinematicCollision3D = move_and_collide(velocity * delta, false, 0.001, true)
	if collision != null:
		var obstacle: SpaceAsteroid = collision.get_collider() as SpaceAsteroid
		var collider: Node = collision.get_collider() as Node
		if obstacle != null or (collider != null and collider.is_in_group("hostile_agents")):
			if obstacle != null and obstacle.presentation_meteor:
				obstacle.meteor_blue_contact.emit(self)
			_die("asteroid" if obstacle != null else "hostile_contact")
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
	if _time - _combat_sample_at < presentation_combat_interval:
		return
	_combat_sample_at = _time
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
		if offset.length() > effective_obstacle_detection(obstacle):
			continue
		if evasive_boost_enabled:
			var danger_radius: float = obstacle.avoidance_radius + SHIP_CLEARANCE + obstacle_clearance
			_consider_boost(obstacle, offset, obstacle.velocity - velocity, danger_radius, 3, 1.4, true)
			_track_near_pass(obstacle, offset, obstacle.velocity - velocity, danger_radius + 2, true)
		var remembered: bool = _avoid_directions.has(obstacle)
		var clearance: float = obstacle.avoidance_radius + SHIP_CLEARANCE + maxf(obstacle_clearance, 0.0)
		if obstacle.motion_type != SpaceAsteroid.MotionType.STATIC:
			var prediction: Vector2 = MobileAvoidance.approach(offset, obstacle.velocity - velocity, 12.0 if adaptive_threat_response and obstacle.diameter >= 60 else 7.0 if adaptive_threat_response and obstacle.diameter >= 20 else mobile_prediction_time)
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
			_record_reaction(obstacle)
			_avoid_directions[obstacle] = _choose_avoidance_direction(obstacle)
			var callback: Callable = _forget_obstacle.bind(obstacle)
			if not obstacle.tree_exiting.is_connected(callback):
				obstacle.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
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
			_record_reaction(projectile)
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
		if zone is MovingLaserGate:
			var gate: MovingLaserGate = zone as MovingLaserGate
			var gate_force: Vector3 = _gate_passage_force(gate)
			if not gate_force.is_zero_approx():
				_record_reaction(gate)
				result = gate_force
				projectile_threat_count += 1
				var until: float = gate.crossing_time(global_position, velocity)
				if evasive_boost_enabled and until < 0.7 and gate.beam_clearance(global_position + velocity * until, until) < SHIP_CLEARANCE + 2:
					_consider_zone_boost(gate, gate_force)
			continue
		var force: Vector3 = zone.avoidance_force(global_position, velocity)
		if evasive_boost_enabled and not force.is_zero_approx() and zone.delay - zone.age <= 1.0:
			_consider_zone_boost(zone, force)
		if not force.is_zero_approx():
			_record_reaction(zone)
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
		_hit_flash.show()
		_hit_flash.light_energy = 2.5


func _process(delta: float) -> void:
	if alive:
		_update_exhausts(delta)
	_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
	_hit_flash.light_energy = 2.5 * _hit_flash_time / 0.14
	# Une lumière d'énergie nulle ne doit pas rester dans les passes de rendu.
	_hit_flash.visible = _hit_flash_time > 0


func _forget_obstacle(obstacle: SpaceAsteroid) -> void:
	_avoid_directions.erase(obstacle)
	_threats.erase(obstacle)


func _avoidance_force(obstacle: SpaceAsteroid, direction: Vector3) -> Vector3:
	var offset: Vector3 = obstacle.global_position - global_position
	var clearance: float = obstacle.avoidance_radius + SHIP_CLEARANCE + maxf(obstacle_clearance, 0.0)
	if obstacle.motion_type != SpaceAsteroid.MotionType.STATIC:
		var relative_velocity: Vector3 = obstacle.velocity - velocity
		var prediction: Vector2 = MobileAvoidance.approach(offset, relative_velocity, 12.0 if adaptive_threat_response and obstacle.diameter >= 60 else 7.0 if adaptive_threat_response and obstacle.diameter >= 20 else mobile_prediction_time)
		return MobileAvoidance.steering(offset, relative_velocity, prediction.x, clearance + (7 if adaptive_threat_response and obstacle.diameter >= 20 else 0.5), direction)
	var lateral_offset: Vector3 = Vector3(-offset.x, -offset.y, 0.0)
	var remaining: float = clearance + 0.5 - lateral_offset.dot(direction)
	var time_before_contact: float = maxf((-offset.z - obstacle.avoidance_radius - SHIP_CLEARANCE) / maxf(-velocity.z, 0.1), 0.4)
	# La direction est mémorisée jusqu'au dépassement ; seule l'intensité évolue.
	return direction * clampf(remaining / time_before_contact, 0.0, 2.5)


func _choose_avoidance_direction(obstacle: SpaceAsteroid) -> Vector3:
	var offset: Vector3 = obstacle.global_position - global_position
	var time_to_obstacle: float = maxf(-offset.z / maxf(-velocity.z, 0.1), 0.0)
	if obstacle.motion_type != SpaceAsteroid.MotionType.STATIC:
		time_to_obstacle = MobileAvoidance.approach(offset, obstacle.velocity - velocity, 12.0 if adaptive_threat_response and obstacle.diameter >= 60 else 7.0 if adaptive_threat_response and obstacle.diameter >= 20 else mobile_prediction_time).x
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


func _update_exhausts(delta: float = 0) -> void:
	var visual_boost: float = maxf(_boost_blend, 0.65 if reinforcement_glow_remaining > 0 else 0)
	var boost_scale: float = lerpf(1, 2.8 if arcade_visuals_enabled else 2.2, visual_boost)
	_boost_material.emission_energy_multiplier = lerpf(1.5, 7.0 if arcade_visuals_enabled else 5.0, visual_boost)
	if arcade_visuals_enabled:
		_update_arcade_boost(visual_boost, delta if delta > 0 else get_physics_process_delta_time())
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
	_gate_memory.clear()
	_near_passes.clear()
	_critical_ids.clear()
	_reaction_ids.clear()
	_critical_candidate.clear()
	evasive_boost_remaining = 0
	projectile_avoidance_active = false
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process(false)
	remove_from_group("blue_ships")
	collision_layer = 0
	collision_mask = 0


func _die(cause: String = "damage") -> void:
	if not alive:
		return
	death_cause = cause
	_stop_navigation()
	health = 0
	var explosion: Node3D = EXPLOSION_SCENE.instantiate() as Node3D
	if presentation_death_effect:
		explosion.configure_blue_ship_death()
	explosion.position = (get_parent() as Node3D).to_local(global_position)
	get_parent().add_child(explosion)
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
	if arcade_visuals_enabled:
		_build_arcade_boost()


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
		var node: Node = (danger.node as WeakRef).get_ref() as Node
		if is_instance_valid(node):
			_record_reaction(node as Node3D)
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
			var strength_value: Variant = danger_node.get("threat_strength")
			_boost_strength = clampf(float(strength_value), 1, 1.6) if adaptive_threat_response and strength_value != null else 1.0
			evasive_boost_remaining = evasive_boost_duration * _boost_strength
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
	for key: Variant in _gate_memory.keys():
		if not is_instance_valid(key) or (key as MovingLaserGate).is_queued_for_deletion():
			# erase() rejette une clé Objet libérée dans un dictionnaire typé.
			# Reconstruire uniquement lors d'une expiration conserve les mémoires vivantes.
			var live: Dictionary[MovingLaserGate, Dictionary] = {}
			for candidate: Variant in _gate_memory.keys():
				if is_instance_valid(candidate) and not (candidate as MovingLaserGate).is_queued_for_deletion():
					live[candidate] = _gate_memory[candidate]
			_gate_memory = live
			break
	for id: int in _reaction_ids.keys():
		var node: Node3D = _reaction_ids[id].get_ref() as Node3D
		if not is_instance_valid(node) or node.global_position.distance_to(global_position) > 240:
			_reaction_ids.erase(id)
	for id: int in _near_passes.keys():
		var object: Object = (_near_passes[id].node as WeakRef).get_ref()
		if not is_instance_valid(object) or (object as Node3D).global_position.distance_squared_to(global_position) > 14400:
			_near_passes.erase(id)
	for id: int in _critical_ids.keys():
		if not is_instance_valid(_critical_ids[id].get_ref()):
			_critical_ids.erase(id)


func effective_obstacle_detection(obstacle: SpaceAsteroid) -> float:
	if not adaptive_threat_response or obstacle_detection_radius <= 0:
		return maxf(obstacle_detection_radius, 0)
	if obstacle.diameter >= 60:
		return clampf(110 + obstacle.avoidance_radius * 2.4, 150, 250)
	return clampf(obstacle_detection_radius + obstacle.avoidance_radius * 3.8, obstacle_detection_radius, 140)


func _record_reaction(node: Node3D) -> void:
	var id: int = node.get_instance_id()
	if _reaction_ids.has(id):
		return
	_reaction_ids[id] = weakref(node)
	threat_reaction.emit(str(node.get_meta("weapon_family", "Mega" if node is SpaceAsteroid and (node as SpaceAsteroid).diameter >= 20 else "Small")))


func _gate_passage_force(gate: MovingLaserGate) -> Vector3:
	var time: float = gate.crossing_time(global_position, velocity)
	if time < 0 or time > 6 or global_position.distance_to(gate.global_position) > gate.detection_radius:
		_gate_memory.erase(gate)
		return Vector3.ZERO
	var openings: Array[Vector3] = gate.safe_openings(time)
	var selected: int = -1
	if _gate_memory.has(gate):
		selected = int(_gate_memory[gate].index)
		var gap: Vector3 = openings[selected] - global_position
		var reachable: bool = Vector2(gap.x, gap.y).length() / maxf(time, 0.4) <= max_side_speed * 1.3
		if _time < float(_gate_memory[gate].until) or (reachable and _opening_clear(openings[selected], time)):
			return Vector3(gap.x, gap.y, 0).limit_length(max_side_speed * maxf(time, 0.4)) / maxf(time, 0.4) / projectile_avoidance_weight
	var best_score: float = INF
	var previous: int = selected
	for index: int in range(openings.size()):
		var opening: Vector3 = openings[index]
		var gap: Vector3 = opening - global_position
		var score: float = Vector2(gap.x, gap.y).length()
		score += Vector2(gap.x - velocity.x * time, gap.y - velocity.y * time).length() * 0.3
		if not _opening_clear(opening, time):
			score += 120
		for node: Node in get_tree().get_nodes_in_group("blue_ships"):
			var other: BlueShip = node as BlueShip
			if other != self:
				score += maxf(11 - opening.distance_to(other.global_position + other.velocity * time), 0) * 2
		if score < best_score:
			best_score = score
			selected = index
	if previous != selected:
		gate_opening_choices += 1
		gate.opening_choices += 1
		if previous >= 0:
			gate_opening_changes += 1
			gate.opening_changes += 1
	_gate_memory[gate] = {"index": selected, "until": _time + 1.0}
	var toward: Vector3 = openings[selected] - global_position
	return Vector3(toward.x, toward.y, 0).limit_length(max_side_speed * maxf(time, 0.4)) / maxf(time, 0.4) / projectile_avoidance_weight


func _opening_clear(point: Vector3, time: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		if point.distance_to(rock.global_position + rock.velocity * time) < rock.avoidance_radius + SHIP_CLEARANCE + 3:
			return false
	return true


func _build_arcade_boost() -> void:
	_aura_material = StandardMaterial3D.new()
	_aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura_material.albedo_color = Color(1, 0.75, 0.12, 0)
	_aura_material.emission_enabled = true
	_aura_material.emission = Color(1, 0.48, 0.03)
	_aura_material.emission_energy_multiplier = 4
	_aura_ring_material = _aura_material.duplicate() as StandardMaterial3D
	_aura = MeshInstance3D.new()
	_aura.name = "GoldenBoostAura"
	var shell: SphereMesh = SphereMesh.new()
	shell.radius = 1
	shell.height = 2
	shell.radial_segments = 12
	shell.rings = 6
	_aura.mesh = shell
	_aura.material_override = _aura_material
	_aura.hide()
	_visuals.add_child(_aura)
	for index: int in range(2):
		var display: MeshInstance3D = MeshInstance3D.new()
		display.name = "ReusableBoostRing_%d" % index
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 1.6
		ring.outer_radius = 1.78
		ring.rings = 16
		ring.ring_segments = 5
		display.mesh = ring
		display.material_override = _aura_ring_material
		display.rotation_degrees.x = 90
		display.hide()
		_visuals.add_child(display)
		_boost_rings.append(display)


func _update_arcade_boost(visual_boost: float, delta: float) -> void:
	var desired: float = visual_boost if evasive_boost_remaining > 0 or reinforcement_glow_remaining > 0 else 0
	_aura_blend = move_toward(_aura_blend, desired, delta * (12 if desired > _aura_blend else 2.5))
	_aura.visible = _aura_blend > 0.025
	_aura_material.albedo_color.a = 0.22 * _aura_blend
	_aura_ring_material.albedo_color.a = 0.8 * _aura_blend
	_aura_ring_material.emission_energy_multiplier = 5
	_aura_material.emission_energy_multiplier = 3 + _aura_blend * 3
	_aura.scale = Vector3(1.8, 0.7, 2.4) * (0.92 + _aura_blend * 0.16 + sin(_time * 13) * _aura_blend * 0.025)
	var width: float = 1 + _aura_blend * 0.18 + clampf(velocity.length() / forward_speed - 1, 0, 0.3)
	_right_exhaust.scale.x = width
	_left_exhaust.scale.x = width
	for index: int in range(_boost_rings.size()):
		var ring: MeshInstance3D = _boost_rings[index]
		var phase: float = fposmod(_time * 2.2 + index * 0.5, 1)
		ring.visible = _aura.visible
		ring.position.z = 3 + phase * 6
		ring.scale = Vector3.ONE * (0.65 + phase * 0.6) * _aura_blend
