class_name BlueShip
extends CharacterBody3D

signal died(ship: BlueShip)

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/explosion.tscn")
const SHIP_CLEARANCE: float = 2.5

@export_category("Vol permanent")
@export var forward_speed: float = 10.5
@export var max_side_speed: float = 9.0
@export var acceleration: float = 12.0
@export var turn_speed: float = 3.2
@export var max_forward_variation: float = 3.0
@export var individual_seed: int = 1

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

@export_category("Anticipation des obstacles")
@export var obstacle_detection_radius: float = 44.0
@export var obstacle_clearance: float = 1.8
@export var avoidance_weight: float = 6.0
@export_range(1, 3, 1) var max_avoidance_threats: int = 3

var alive: bool = true
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

@onready var _visuals: Node3D = $Visuals
@onready var _right_exhaust: MeshInstance3D = $Visuals/RightExhaust
@onready var _left_exhaust: MeshInstance3D = $Visuals/LeftExhaust


func _ready() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = individual_seed
	_phases = Vector3(random.randf(), random.randf(), random.randf()) * TAU
	_personal_frequency = random.randf_range(0.82, 1.18)
	_personal_amplitude = random.randf_range(0.8, 1.2)
	_speed_factor = random.randf_range(0.97, 1.03)
	var angle: float = random.randf_range(0.0, TAU)
	_preferred_avoidance = Vector3(cos(angle), sin(angle), 0.0)
	velocity = Vector3.FORWARD * maxf(forward_speed * _speed_factor, 0.1)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	_update_neighbor_rules()
	var steering: Vector3 = (
		_natural_wander()
		+ _separation * separation_weight
		+ _cohesion * cohesion_weight
		+ _alignment * alignment_weight
	)
	var avoidance: Vector3 = _obstacle_avoidance() * avoidance_weight
	# Les règles du banc cèdent progressivement la priorité au contournement.
	var avoidance_priority: float = clampf(avoidance.length() / maxf(max_side_speed, 0.1), 0.0, 1.0)
	steering = steering * (1.0 - avoidance_priority * 0.75) + avoidance
	steering += _critical_separation * separation_weight * avoidance_priority * 0.75
	var side_velocity: Vector2 = Vector2(steering.x, steering.y).limit_length(maxf(max_side_speed, 0.0))
	var base_speed: float = maxf(forward_speed * _speed_factor, 0.1)
	var variation_limit: float = maxf(max_forward_variation, 0.0)
	var forward_variation: float = clampf(steering.z, -variation_limit, minf(variation_limit, base_speed * 0.6))
	var desired_velocity: Vector3 = Vector3(side_velocity.x, side_velocity.y, -base_speed + forward_variation)
	velocity = velocity.move_toward(desired_velocity, maxf(acceleration, 0.1) * delta)
	_update_orientation(delta)
	_update_exhausts()
	# Le balayage physique détecte le contact, même si le déplacement dépasse une petite roche.
	var collision: KinematicCollision3D = move_and_collide(velocity * delta, false, 0.001, true)
	if collision != null:
		var obstacle: SpaceAsteroid = collision.get_collider() as SpaceAsteroid
		if obstacle != null:
			_die()


func _natural_wander() -> Vector3:
	var time: float = _time * wander_frequency * _personal_frequency
	return Vector3(
		(sin(time + _phases.x) + 0.35 * sin(time * 1.83 + _phases.z)) * wander_strength,
		(cos(time * 0.79 + _phases.y) + 0.3 * sin(time * 1.41 + _phases.x)) * vertical_wander_strength,
		(sin(time * 0.62 + _phases.z) + 0.22 * sin(time * 1.13 + _phases.x)) * longitudinal_wander_strength
	) * _personal_amplitude


func _update_neighbor_rules() -> void:
	_separation = Vector3.ZERO
	_critical_separation = Vector3.ZERO
	_cohesion = Vector3.ZERO
	_alignment = Vector3.ZERO
	var center: Vector3 = Vector3.ZERO
	var average_velocity: Vector3 = Vector3.ZERO
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var other: BlueShip = node as BlueShip
		if other == null or other == self or not other.alive or other.is_queued_for_deletion():
			continue
		var away: Vector3 = global_position - other.global_position
		var distance: float = away.length()
		if distance > maxf(neighbor_radius, 0.0):
			continue
		center += other.global_position
		average_velocity += other.velocity
		count += 1
		if distance < separation_distance:
			if distance > 0.001:
				var strength: float = 1.0 - distance / maxf(separation_distance, 0.001)
				var critical: float = maxf(1.0 - distance / maxf(critical_separation_distance, 0.001), 0.0)
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
		if center_distance > maxf(cohesion_comfort_radius, 0.0) and center_distance > 0.001:
			_cohesion = (to_center / center_distance) * minf(center_distance - maxf(cohesion_comfort_radius, 0.0), 8.0)
		_alignment = (average_velocity / float(count) - velocity).limit_length(3.0)


func _find_threats() -> void:
	_threats.clear()
	for remembered: SpaceAsteroid in _avoid_directions.keys():
		if not is_instance_valid(remembered) or remembered.is_queued_for_deletion():
			_avoid_directions.erase(remembered)
		elif global_position.z < remembered.global_position.z - remembered.avoidance_radius - SHIP_CLEARANCE:
			_avoid_directions.erase(remembered)
	var heading: Vector3 = velocity.normalized() if velocity.length_squared() > 0.001 else Vector3.FORWARD
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var obstacle: SpaceAsteroid = node as SpaceAsteroid
		if obstacle == null or obstacle.is_queued_for_deletion():
			continue
		var offset: Vector3 = obstacle.global_position - global_position
		if offset.length() > maxf(obstacle_detection_radius, 0.0):
			continue
		var remembered: bool = _avoid_directions.has(obstacle)
		if offset.z >= 0.0 and not remembered:
			continue
		var clearance: float = obstacle.avoidance_radius + SHIP_CLEARANCE + maxf(obstacle_clearance, 0.0)
		var ahead: float = offset.dot(heading)
		var predicted_miss: float = (offset - heading * maxf(ahead, 0.0)).length()
		var forward_miss: float = Vector2(offset.x, offset.y).length()
		if not remembered and minf(predicted_miss, forward_miss) > clearance + 1.0:
			continue
		_insert_threat(obstacle)


func _insert_threat(obstacle: SpaceAsteroid) -> void:
	var entry_distance: float = global_position.z - obstacle.global_position.z - obstacle.avoidance_radius
	var index: int = 0
	while index < _threats.size():
		var other_entry: float = global_position.z - _threats[index].global_position.z - _threats[index].avoidance_radius
		if entry_distance < other_entry:
			break
		index += 1
	var limit: int = clampi(max_avoidance_threats, 1, 3)
	if index >= limit:
		return
	_threats.insert(index, obstacle)
	if _threats.size() > limit:
		_threats.pop_back()


func _obstacle_avoidance() -> Vector3:
	_find_threats()
	var result: Vector3 = Vector3.ZERO
	var primary_force: Vector3 = Vector3.ZERO
	for index: int in range(_threats.size()):
		var obstacle: SpaceAsteroid = _threats[index]
		if not _avoid_directions.has(obstacle):
			_avoid_directions[obstacle] = _choose_avoidance_direction(obstacle)
		var force: Vector3 = _avoidance_force(obstacle, _avoid_directions[obstacle])
		if index == 0:
			primary_force = force
		result += force / (1.0 + float(index) * 0.7)
	# Deux corrections opposées ne doivent pas annuler la menace la plus urgente.
	if primary_force.length_squared() > 0.001:
		var primary_direction: Vector3 = primary_force.normalized()
		var missing: float = primary_force.length() * 0.7 - result.dot(primary_direction)
		result += primary_direction * maxf(missing, 0.0)
	return result.limit_length(3.0)


func _avoidance_force(obstacle: SpaceAsteroid, direction: Vector3) -> Vector3:
	var offset: Vector3 = obstacle.global_position - global_position
	var clearance: float = obstacle.avoidance_radius + SHIP_CLEARANCE + maxf(obstacle_clearance, 0.0)
	var lateral_offset: Vector3 = Vector3(-offset.x, -offset.y, 0.0)
	var remaining: float = clearance + 0.5 - lateral_offset.dot(direction)
	var time_before_contact: float = maxf((-offset.z - obstacle.avoidance_radius - SHIP_CLEARANCE) / maxf(-velocity.z, 0.1), 0.4)
	# La direction est mémorisée jusqu'au dépassement ; seule l'intensité évolue.
	return direction * clampf(remaining / time_before_contact, 0.0, 2.5)


func _choose_avoidance_direction(obstacle: SpaceAsteroid) -> Vector3:
	var offset: Vector3 = obstacle.global_position - global_position
	var time_to_obstacle: float = maxf(-offset.z / maxf(-velocity.z, 0.1), 0.0)
	var future_offset: Vector3 = global_position + velocity * time_to_obstacle - obstacle.global_position
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
	if velocity.length_squared() < 0.001:
		return
	var direction: Vector3 = velocity.normalized()
	var target_basis: Basis = Basis.looking_at(direction, Vector3.UP)
	var bank: float = clampf(-velocity.x * 0.035, -0.28, 0.28)
	target_basis = target_basis.rotated(direction, bank)
	_visuals.quaternion = _visuals.quaternion.slerp(target_basis.get_rotation_quaternion(), 1.0 - exp(-maxf(turn_speed, 0.0) * delta))


func _update_exhausts() -> void:
	_right_exhaust.scale.y = 1.0 + 0.14 * sin(_time * 6.1 + _phases.x)
	_left_exhaust.scale.y = 1.0 + 0.14 * sin(_time * 5.7 + _phases.y)


func _die() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	set_physics_process(false)
	remove_from_group("blue_ships")
	collision_layer = 0
	collision_mask = 0
	var explosion: Node3D = EXPLOSION_SCENE.instantiate() as Node3D
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	died.emit(self)
	hide()
	queue_free()
