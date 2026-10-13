class_name CapitalShip
extends CharacterBody3D

signal destroyed(ship: CapitalShip)
signal salvo_started(pattern: int)
signal fired(projectile: ArtilleryProjectile)

enum State { ENTRY, OBSERVE, PREPARE, FIRE, COOLDOWN, REPOSITION, AVOIDING, DESTROYED }
enum ArtilleryPattern { HEAVY_SHOT, SPREAD, ARC_SALVO, CROSS_FIRE, SEEKER_SALVO, RAPID_BARRAGE, BOMB_CLUSTER, LASER_CURTAIN, LASER_GRID, MISSILE_SWARM }
const EXPLOSION: PackedScene = preload("res://scenes/explosion.tscn")
const BODY_CLEARANCE: float = 38.0
const LAUNCHERS: Array[Vector3] = [Vector3(-23, 5.5, 18), Vector3(23, 5.5, 18)]

@export var individual_seed: int = 1
@export var max_health: int = 24
@export var normal_distance: float = 190.0
@export var vulnerable_distance: float = 65.0
@export var artillery_limit: int = 50
@export var combat_enabled: bool = true
@export var demonstration_cycle: bool = false
@export var predictive_targeting: bool = true
var _target_cursor: int = 0
var readable_arsenal: bool = false
var choreographed: bool = false
var _category_cursor: int = 0
var spectacle_enabled: bool = false
var fire_intensity: float = 1.0
var fleet_offset: Vector2 = Vector2.ZERO
var fleet_role: int = 0
var _flash_time: float = 0
var demonstration_attack_order: Array[int] = []
var projectile_container: Node3D
var health: int = 24
var alive: bool = true
var body_clearance: float = BODY_CLEARANCE
var state: State = State.ENTRY
var state_history: Array[int] = [State.ENTRY]
var selected_pattern: ArtilleryPattern = ArtilleryPattern.HEAVY_SHOT
var pattern_history: Array[int] = []
var salvos_fired: int = 0
var shots_fired: int = 0
var obstacle_contacts: int = 0
var observed_center: Vector3 = Vector3.ZERO
var observed_velocity: Vector3 = Vector3.FORWARD * 10.5
var observed_dispersion: float = 0
var observed_count: int = 0
var group_distance: float = 190
var vulnerable: bool = false
var prepare_duration: float = 1.3
var cooldown_duration: float = 4.5
var _time: float = 0
var _state_time: float = 0
var _perception_timer: float = 0
var _resume_state: State = State.ENTRY
var _safe_time: float = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _patterns: Array[int] = []
var _pending: Array[Dictionary] = []
var _drift: Vector2 = Vector2.ZERO
var _vulnerability_time: float = 0
var _avoid_direction: Vector3 = Vector3.ZERO
var _critical_obstacle: bool = false
var _destroy_time: float = 0
var _explosion_index: int = 0


func _ready() -> void:
	health = max_health
	_random.seed = individual_seed
	_drift = fleet_offset if spectacle_enabled else Vector2(_random.randf_range(-24, 24), _random.randf_range(-10, 14))
	observe_group()
	velocity = observed_velocity


func observe_group() -> void:
	observed_count = 0
	var sum: Vector3 = Vector3.ZERO
	var speed: Vector3 = Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var ship: BlueShip = node as BlueShip
		if ship == null or not ship.alive or ship.is_queued_for_deletion():
			continue
		sum += ship.global_position
		speed += ship.velocity
		observed_count += 1
	if observed_count == 0:
		return
	observed_center = sum / observed_count
	observed_velocity = speed / observed_count
	observed_dispersion = 0
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		observed_dispersion = maxf(observed_dispersion, observed_center.distance_to((node as Node3D).global_position))
	group_distance = global_position.distance_to(observed_center)


func _transition(next: State) -> void:
	state = next
	_state_time = 0
	state_history.append(next)
	# Historique de diagnostic borné pour les sessions infinies.
	if state_history.size() > 64:
		state_history.pop_front()
	if next == State.PREPARE:
		selected_pattern = _choose_pattern()
		prepare_duration = (1.2 if spectacle_enabled else 0.9 if demonstration_cycle else _random.randf_range(0.8, 1.8)) / fire_intensity
	elif next == State.FIRE:
		_pending = build_salvo(selected_pattern)
	elif next == State.COOLDOWN:
		cooldown_duration = (3.2 if spectacle_enabled else 0.7 if demonstration_cycle else _random.randf_range(3, 6)) / fire_intensity
	elif next == State.REPOSITION:
		vulnerable = not spectacle_enabled and not demonstration_cycle and salvos_fired > 0 and salvos_fired % 3 == 0
		_vulnerability_time = 0
		_drift = fleet_offset if spectacle_enabled else Vector2.ZERO if vulnerable else Vector2(_random.randf_range(-30, 30), _random.randf_range(-14, 18))


func _choose_pattern() -> ArtilleryPattern:
	if spectacle_enabled:
		var orders: Array[Array] = [[5, 0, 5], [6, 2], [7, 5], [8, 1], [9, 4]]
		var order: Array = orders[fleet_role % orders.size()]
		return int(order[salvos_fired % order.size()]) as ArtilleryPattern
	if demonstration_cycle and not demonstration_attack_order.is_empty():
		return demonstration_attack_order.pop_front() as ArtilleryPattern
	if _patterns.is_empty():
		_patterns.assign([0, 1, 2, 3, 4])
		# Fisher–Yates avec le RNG personnel, sans RNG global ni reroll par tick.
		for index: int in range(4, 0, -1):
			var other: int = _random.randi_range(0, index)
			var old: int = _patterns[index]
			_patterns[index] = _patterns[other]
			_patterns[other] = old
	# Une forte dispersion privilégie l'éventail s'il reste dans ce cycle.
	var index: int = _patterns.find(ArtilleryPattern.SPREAD) if observed_dispersion > 40 else 0
	index = maxi(index, 0)
	var choice: int = _patterns[index]
	_patterns.remove_at(index)
	return choice as ArtilleryPattern


func _physics_process(delta: float) -> void:
	_time += delta
	if not alive:
		_update_destruction(delta)
		return
	_perception_timer -= delta
	if _perception_timer <= 0:
		observe_group()
		_perception_timer = 0.25
	var correction: Vector3 = _obstacle_correction()
	if _critical_obstacle and state in [State.ENTRY, State.REPOSITION, State.AVOIDING]:
		_safe_time = 0
		if state != State.AVOIDING:
			_resume_state = state
			state = State.AVOIDING
			state_history.append(state)
	else:
		_safe_time += delta
		if state == State.AVOIDING and _safe_time > 0.6:
			state = _resume_state # Reprendre aussi le timer, l'attaque et la salve interrompus.
			state_history.append(state)
	if state != State.AVOIDING:
		_state_time += delta
		_update_state(delta)
	_move(delta, correction)
	var charge: float = clampf(_state_time / prepare_duration, 0, 1) if state == State.PREPARE else 0.0
	_flash_time = maxf(_flash_time - delta, 0)
	$Visuals.show_charge(maxf(charge, 1.5 if _flash_time > 0 else 0), _time, alive)
	while state_history.size() > 64:
		state_history.pop_front()


func _update_state(delta: float) -> void:
	match state:
		State.ENTRY:
			if _state_time >= 2:
				_transition(State.OBSERVE)
		State.OBSERVE:
			if choreographed:
				return
			if demonstration_cycle and demonstration_attack_order.is_empty():
				return
			if _state_time >= (0.4 if demonstration_cycle else 1.0) and observed_count > 0 and combat_enabled:
				_transition(State.PREPARE)
		State.PREPARE:
			if _state_time >= prepare_duration:
				_transition(State.FIRE)
		State.FIRE:
			if spectacle_enabled:
				_fire_spectacle()
				return
			if not _pending.is_empty() and _state_time >= float(_pending[0]["delay"]):
				# Réserver la salve entière ; ne jamais dépasser le plafond partagé.
				if get_tree().get_nodes_in_group("artillery_projectiles").size() + _pending.size() > artillery_limit:
					_pending.clear()
					_transition(State.COOLDOWN)
					return
				if _state_time - delta <= float(_pending[0]["delay"]) and int(_pending[0]["index"]) == 0:
					salvos_fired += 1
					pattern_history.append(selected_pattern)
					if pattern_history.size() > 64:
						pattern_history.pop_front()
					salvo_started.emit(selected_pattern)
				_launch(_pending.pop_front())
			if _pending.is_empty() and _state_time >= 0.5:
				_transition(State.COOLDOWN)
		State.COOLDOWN:
			if _state_time >= cooldown_duration:
				_transition(State.REPOSITION)
		State.REPOSITION:
			if vulnerable:
				if absf(observed_center.z - global_position.z - vulnerable_distance) < 12:
					_vulnerability_time += delta
				if _vulnerability_time >= 10 or _state_time > 38:
					vulnerable = false
					_transition(State.OBSERVE)
			elif _state_time >= (0.7 if spectacle_enabled else 0.5 if demonstration_cycle else 3.0) and absf(observed_center.z - global_position.z - normal_distance) < 18:
				_transition(State.OBSERVE)


func _move(delta: float, correction: Vector3) -> void:
	var ahead: float = vulnerable_distance if vulnerable else normal_distance
	var desired: Vector3 = observed_center + Vector3(_drift.x + sin(_time * 0.12) * 6, _drift.y + sin(_time * 0.09) * 4, -ahead)
	var offset: Vector3 = desired - global_position
	var side: Vector2 = (Vector2(offset.x, offset.y) * 0.3).limit_length(3)
	var cruise: float = clampf(observed_velocity.z, -26 if predictive_targeting else -14, -7)
	var wanted: Vector3 = Vector3(side.x, side.y, cruise + clampf(offset.z * 0.35, -6, 6)) + correction
	velocity = velocity.move_toward(wanted, 4 * delta)
	var contact: KinematicCollision3D = move_and_collide(velocity * delta, false, 0.02, true)
	if contact != null:
		obstacle_contacts += 1
		velocity = velocity.slide(contact.get_normal())
		move_and_collide(contact.get_remainder().slide(contact.get_normal()))


func _obstacle_correction() -> Vector3:
	var result: Vector3 = Vector3.ZERO
	_critical_obstacle = false
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var obstacle: SpaceAsteroid = node as SpaceAsteroid
		var offset: Vector3 = obstacle.global_position - global_position
		var clearance: float = obstacle.avoidance_radius + BODY_CLEARANCE + 6
		if offset.length() > clearance + 65:
			continue
		var relative: Vector3 = obstacle.velocity - velocity
		var prediction: Vector2 = MobileAvoidance.approach(offset, relative, 6)
		if prediction.y >= clearance or (offset.dot(relative) >= 0 and offset.length() > clearance):
			continue
		# Correction douce à six secondes ; seul un contact imminent suspend l'artillerie.
		if prediction.x < 2 and prediction.y < clearance - 8:
			_critical_obstacle = true
		var away: Vector3 = -(offset + relative * prediction.x)
		away.z = 0
		if away.length_squared() < 1:
			away = Vector3.UP
		if _avoid_direction.is_zero_approx():
			_avoid_direction = away.normalized()
		result += _avoid_direction * clampf((clearance - prediction.y) / maxf(prediction.x, 1), 1, 7)
	if result.is_zero_approx():
		_avoid_direction = Vector3.ZERO
	return result.limit_length(7)


func build_salvo(pattern: int) -> Array[Dictionary]:
	var salvo: Array[Dictionary] = []
	if readable_arsenal:
		return _build_readable_salvo(pattern)
	if predictive_targeting:
		return _build_targeted_salvo(pattern)
	if pattern >= ArtilleryPattern.RAPID_BARRAGE:
		return _build_spectacle_salvo(pattern)
	var count: int = [1, 5, 4, 6, 3][pattern]
	for index: int in range(count):
		var origin: Vector3 = global_position + (Vector3(0, 4, 35) if pattern == ArtilleryPattern.HEAVY_SHOT else LAUNCHERS[index % 2])
		var speed: float = 27 if pattern == ArtilleryPattern.HEAVY_SHOT else 30
		var travel: float = origin.distance_to(observed_center) / maxf(speed + maxf(-observed_velocity.z, 0), 1)
		var aim: Vector3 = observed_center + observed_velocity * travel
		if pattern == ArtilleryPattern.SPREAD:
			var spread: float = clampf(observed_dispersion * 0.6, 12, 24)
			var offsets: Array[Vector3] = [Vector3.ZERO, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]
			aim += offsets[index] * spread
		elif pattern == ArtilleryPattern.ARC_SALVO:
			aim += Vector3((index - 1.5) * 7, 0, 0)
		elif pattern == ArtilleryPattern.CROSS_FIRE:
			aim += Vector3(0, (index / 2 - 1) * 7, 0)
		var chosen: BlueShip = null
		if pattern == ArtilleryPattern.SEEKER_SALVO:
			var targets: Array[Node] = get_tree().get_nodes_in_group("blue_ships")
			if not targets.is_empty():
				chosen = targets[_random.randi_range(0, targets.size() - 1)] as BlueShip
				aim = chosen.global_position + chosen.velocity * travel
		salvo.append({"index": index, "delay": index * (0.28 if pattern == ArtilleryPattern.CROSS_FIRE else 0.18), "origin": origin, "local_origin": origin - global_position, "aim": aim, "speed": speed, "travel": travel, "target": chosen, "pattern": pattern})
	return salvo


func _launch(spec: Dictionary) -> void:
	var projectile: ArtilleryProjectile = ArtilleryProjectile.new()
	projectile.batch_visuals_enabled = predictive_targeting
	var origin: Vector3 = global_position + Vector3(spec["local_origin"])
	var aim: Vector3 = spec.aim
	var chosen: BlueShip = spec.target if is_instance_valid(spec.target) else null
	projectile.targeted = bool(spec.get("targeted", false)) and chosen != null and chosen.alive
	projectile.threat_category = int(spec.get("category", ThreatPattern.Category.TARGETED if projectile.targeted else ThreatPattern.Category.SUPPRESSION))
	projectile.target_seed = chosen.individual_seed if chosen != null else 0
	if readable_arsenal:
		projectile.set_meta("weapon_family", family_for_pattern(int(spec.pattern)))
		projectile.threat_strength = 1.6 if int(spec.pattern) in [0, 4, 9] else 1.0
	if chosen != null and chosen.alive and (projectile.targeted or projectile.threat_category == ThreatPattern.Category.NEAR_PASS):
		projectile.initial_target_position = chosen.global_position
		projectile.initial_target_velocity = chosen.velocity
		aim = CombatPrediction.aim(origin, chosen.global_position, chosen.velocity, spec.speed) + Vector3(spec.aim_error)
	elif predictive_targeting and not (readable_arsenal and int(spec.pattern) == ArtilleryPattern.BOMB_CLUSTER):
		aim = CombatPrediction.aim(origin, observed_center, observed_velocity, spec.speed) + Vector3(spec.aim_error)
	projectile.kind = int(spec["pattern"]) as ArtilleryProjectile.Kind
	projectile.projectile_speed = spec["speed"]
	projectile.flight_direction = (aim - origin).normalized()
	projectile.damage = 2 if projectile.kind == ArtilleryProjectile.Kind.HEAVY_SHOT else 1
	projectile.avoidance_radius = (16 if readable_arsenal else 10) if projectile.damage == 2 else 5 if projectile.kind == ArtilleryProjectile.Kind.SEEKER_SALVO else 4
	projectile.lifetime = 18 if predictive_targeting else 22 if spectacle_enabled else 14
	projectile.turn_rate_degrees = 12 if predictive_targeting else 6
	projectile.target = chosen if (projectile.targeted or not readable_arsenal) and projectile.kind in [ArtilleryProjectile.Kind.SEEKER_SALVO, ArtilleryProjectile.Kind.MISSILE_SWARM] else null
	if projectile.kind == ArtilleryProjectile.Kind.BOMB_CLUSTER:
		var zone: ArtilleryZone = ArtilleryZone.new()
		zone.kind = ArtilleryZone.Kind.BOMB
		zone.set_meta("weapon_family", "Bomb")
		zone.delay = origin.distance_to(aim) / projectile.projectile_speed
		zone.warning_time = 5.0
		zone.position = projectile_container.to_local(aim)
		projectile_container.add_child(zone)
		projectile.bomb_zone = zone
		projectile.lifetime = zone.delay
	projectile.arc_duration = maxf(aim.distance_to(origin) / projectile.projectile_speed, 0.1)
	projectile.arc_axis = Vector3.UP if int(spec["index"]) % 2 == 0 else Vector3.RIGHT
	var container: Node3D = projectile_container if is_instance_valid(projectile_container) else get_parent() as Node3D
	projectile.position = container.to_local(origin)
	container.add_child(projectile)
	shots_fired += 1
	_flash_time = 0.25
	fired.emit(projectile)


func combat_aim_position(from: Vector3) -> Vector3:
	# Le blindage arrière appartient au même corps ; aucune portée BlueShip modifiée.
	return global_position + Vector3(clampf(from.x - global_position.x, -10, 10), clampf(from.y - global_position.y, -4, 4), 32)


func take_damage(amount: int) -> void:
	if not alive or amount <= 0:
		return
	health = maxi(health - amount, 0)
	if health == 0:
		alive = false
		_transition(State.DESTROYED)
		_pending.clear()
		remove_from_group("hostile_agents")
		remove_from_group("capital_ships")
		collision_layer = 0
		collision_mask = 0
		$Visuals.show_charge(0, _time, false)
		destroyed.emit(self)


func _update_destruction(delta: float) -> void:
	_destroy_time += delta
	global_position += velocity * delta
	if _explosion_index < 6 and _destroy_time >= _explosion_index * 0.35:
		_explode(Vector3(_random.randf_range(-23, 23), _random.randf_range(-4, 10), _random.randf_range(-24, 24)), 3)
		_explosion_index += 1
	if _destroy_time >= 2.5 and _explosion_index == 6:
		_explode(Vector3.ZERO, 14)
		_explosion_index += 1
		hide()
	if _destroy_time >= 3.4:
		queue_free()


func _explode(offset: Vector3, size: float) -> void:
	var effect: Node3D = EXPLOSION.instantiate() as Node3D
	get_parent().add_child(effect)
	effect.global_position = global_position + offset
	effect.scale = Vector3.ONE * size
	effect.add_to_group("capital_explosions")


func retire() -> void:
	alive = false
	remove_from_group("hostile_agents")
	remove_from_group("capital_ships")
	queue_free()


func _build_spectacle_salvo(pattern: int) -> Array[Dictionary]:
	var salvo: Array[Dictionary] = []
	var count: int = 24 if pattern == ArtilleryPattern.RAPID_BARRAGE else 3 if pattern == ArtilleryPattern.BOMB_CLUSTER else 18 if pattern == ArtilleryPattern.MISSILE_SWARM else 1
	for index: int in range(count):
		var origin: Vector3 = global_position + LAUNCHERS[index % 2]
		# Temps en secondes SIMULÉES : environ 5–8 secondes réelles à 1,9x.
		var travel: float = 10.5 if pattern == ArtilleryPattern.RAPID_BARRAGE else 14.0 if pattern == ArtilleryPattern.BOMB_CLUSTER else 12.0
		var aim: Vector3 = observed_center + observed_velocity * travel
		if pattern in [ArtilleryPattern.RAPID_BARRAGE, ArtilleryPattern.MISSILE_SWARM]:
			aim += Vector3(_random.randf_range(-35, 35), _random.randf_range(-24, 24), _random.randf_range(-8, 8))
		elif pattern == ArtilleryPattern.BOMB_CLUSTER:
			aim += Vector3((index - 1) * 27, _random.randf_range(-12, 12), _random.randf_range(-7, 7))
		var chosen: BlueShip = null
		var targets: Array[Node] = get_tree().get_nodes_in_group("blue_ships")
		if pattern == ArtilleryPattern.MISSILE_SWARM and index % 3 == 0 and not targets.is_empty():
			chosen = targets[index % targets.size()] as BlueShip
		var speed: float = origin.distance_to(aim) / travel
		salvo.append({"index": index, "delay": index * (0.085 if pattern == ArtilleryPattern.RAPID_BARRAGE else 0.06 if pattern == ArtilleryPattern.MISSILE_SWARM else 0.3), "origin": origin, "local_origin": origin - global_position, "aim": aim, "speed": speed, "travel": travel, "target": chosen, "pattern": pattern})
	return salvo


func _fire_spectacle() -> void:
	while not _pending.is_empty() and _state_time >= float(_pending[0].delay):
		var spec: Dictionary = _pending.pop_front()
		var pattern: int = spec.pattern
		if int(spec.index) == 0:
			salvos_fired += 1
			pattern_history.append(pattern)
			if pattern_history.size() > 64:
				pattern_history.pop_front()
			salvo_started.emit(pattern)
		var needed: int = 6 if pattern == ArtilleryPattern.LASER_GRID else 4 if pattern == ArtilleryPattern.LASER_CURTAIN else 1
		# Réserver six places aux beams en finale, même pendant les rafales locales.
		var limit: int = artillery_limit - 6 if artillery_limit <= 60 and pattern not in [ArtilleryPattern.LASER_GRID, ArtilleryPattern.LASER_CURTAIN] else artillery_limit
		if ArtilleryZone.dangerous_count(get_tree()) + needed > limit:
			continue # Plafond global ; aucune file d'attente retardée sans limite.
		if pattern in [ArtilleryPattern.LASER_CURTAIN, ArtilleryPattern.LASER_GRID]:
			if readable_arsenal and pattern == ArtilleryPattern.LASER_GRID and _grid_exists():
				continue
			if get_tree().get_nodes_in_group("combat_hazards").size() >= 6:
				continue
			var zone: ArtilleryZone = ArtilleryZone.new()
			zone.kind = ArtilleryZone.Kind.GRID if pattern == ArtilleryPattern.LASER_GRID else ArtilleryZone.Kind.CURTAIN
			zone.set_meta("weapon_family", "Laser")
			zone.delay = spec.travel
			zone.source = global_position + Vector3(spec.local_origin)
			zone.position = projectile_container.to_local(spec.aim)
			projectile_container.add_child(zone)
			_flash_time = 0.4
		else:
			_launch(spec)
	if _pending.is_empty() and _state_time >= 1:
		_transition(State.COOLDOWN)


func _build_targeted_salvo(pattern: int) -> Array[Dictionary]:
	var salvo: Array[Dictionary] = []
	var counts: Array[int] = [1, 5, 4, 6, 3, 24, 3, 1, 1, 18]
	var speeds: Array[float] = [52, 80, 62, 80, 65, 88, 48, 60, 60, 65]
	var targets: Array[BlueShip] = []
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var blue: BlueShip = node as BlueShip
		if blue.alive and not blue.is_queued_for_deletion():
			targets.append(blue)
	# L'ordre de création/seed répartit les cibles, sans RNG global.
	for index: int in range(counts[pattern]):
		var origin: Vector3 = global_position + LAUNCHERS[index % 2]
		var targeted: bool = pattern not in [ArtilleryPattern.BOMB_CLUSTER, ArtilleryPattern.LASER_CURTAIN, ArtilleryPattern.LASER_GRID]
		if pattern == ArtilleryPattern.RAPID_BARRAGE:
			targeted = (index * 7) % 24 < 17 # 17/24 = 70,8 %, répartis dans la salve.
		elif pattern == ArtilleryPattern.MISSILE_SWARM:
			targeted = index % 4 != 3 and index != 17 # 13/18 = 72,2 %.
		elif pattern == ArtilleryPattern.SPREAD:
			targeted = index < 3
		elif pattern == ArtilleryPattern.ARC_SALVO:
			targeted = index < 2
		elif pattern == ArtilleryPattern.CROSS_FIRE:
			targeted = index < 4
		var chosen: BlueShip = null
		if targeted and not targets.is_empty():
			chosen = targets[(_target_cursor + fleet_role * 3) % targets.size()]
			_target_cursor += 1
		else:
			targeted = false
		var speed: float = speeds[pattern]
		var position_value: Vector3 = chosen.global_position if chosen != null else observed_center
		var velocity_value: Vector3 = chosen.velocity if chosen != null else observed_velocity
		var aim_error: Vector3 = Vector3(_random.randf_range(-1.8, 1.8), _random.randf_range(-1.8, 1.8), 0)
		if not targeted:
			aim_error = Vector3(_random.randf_range(-14, 14), _random.randf_range(-10, 10), 0)
		var aim: Vector3 = CombatPrediction.aim(origin, position_value, velocity_value, speed) + aim_error
		var travel: float = origin.distance_to(aim) / speed
		salvo.append({"index": index, "delay": index * (0.085 if pattern == ArtilleryPattern.RAPID_BARRAGE else 0.06 if pattern == ArtilleryPattern.MISSILE_SWARM else 0.18), "origin": origin, "local_origin": origin - global_position, "aim": aim, "speed": speed, "travel": travel, "target": chosen, "targeted": targeted, "aim_error": aim_error, "pattern": pattern})
	return salvo


static func family_for_pattern(pattern: int) -> String:
	return "Heavy" if pattern == 0 else "Seeker" if pattern == 4 else "Bomb" if pattern == 6 else "Laser" if pattern in [7, 8] else "Swarm" if pattern == 9 else "Rapid"


func _grid_exists() -> bool:
	for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
		if (node as ArtilleryZone).kind == ArtilleryZone.Kind.GRID and not node.is_queued_for_deletion():
			return true
	return false


func _build_readable_salvo(pattern: int) -> Array[Dictionary]:
	var salvo: Array[Dictionary] = []
	var counts: Array[int] = [3, 5, 4, 6, 6, 10, 2, 1, 1, 10]
	var speeds: Array[float] = [72, 80, 62, 80, 65, 88, 48, 60, 60, 65]
	var targets: Array[BlueShip] = []
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		var blue: BlueShip = node as BlueShip
		if blue.alive and not blue.is_queued_for_deletion():
			targets.append(blue)
	for index: int in range(counts[pattern]):
		var category_value: int = ThreatPattern.Category.ZONE if pattern in [6, 7, 8] else ThreatPattern.Category.TARGETED if pattern in [0, 4] else ThreatPattern.category(_category_cursor)
		if pattern not in [0, 4, 6, 7, 8]:
			_category_cursor += 1
		var chosen: BlueShip = null
		if not targets.is_empty():
			chosen = targets[_target_cursor % targets.size()]
			_target_cursor += 1
		var targeted_value: bool = category_value == ThreatPattern.Category.TARGETED and chosen != null
		var origin: Vector3 = global_position + LAUNCHERS[index % 2]
		var error_value: Vector3 = ThreatPattern.error(category_value, _random)
		if category_value == ThreatPattern.Category.ZONE:
			error_value = Vector3((index * 2 - 1) * 9, 0, 0)
		var aim: Vector3 = CombatPrediction.aim(origin, chosen.global_position if chosen != null and category_value != ThreatPattern.Category.ZONE else observed_center, chosen.velocity if chosen != null and category_value != ThreatPattern.Category.ZONE else observed_velocity, speeds[pattern]) + error_value
		if pattern == ArtilleryPattern.BOMB_CLUSTER:
			var cluster: Dictionary = _dense_cluster(targets)
			aim = CombatPrediction.aim(origin, cluster.position, cluster.velocity, speeds[pattern]) + error_value
		salvo.append({"index": index, "delay": index * 0.16, "origin": origin, "local_origin": origin - global_position, "aim": aim, "speed": speeds[pattern], "travel": origin.distance_to(aim) / speeds[pattern], "target": chosen, "targeted": targeted_value, "category": category_value, "aim_error": error_value, "pattern": pattern})
	return salvo


func _dense_cluster(targets: Array[BlueShip]) -> Dictionary:
	var best: Array[BlueShip] = []
	for blue: BlueShip in targets:
		var neighbors: Array[BlueShip] = []
		for other: BlueShip in targets:
			if blue.global_position.distance_to(other.global_position) < 24:
				neighbors.append(other)
		if neighbors.size() > best.size():
			best = neighbors
	var point: Vector3 = Vector3.ZERO
	var speed: Vector3 = Vector3.ZERO
	for blue: BlueShip in best:
		point += blue.global_position
		speed += blue.velocity
	return {"position": point / best.size() if not best.is_empty() else observed_center, "velocity": speed / best.size() if not best.is_empty() else observed_velocity}
