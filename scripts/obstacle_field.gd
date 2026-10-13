class_name ObstacleField
extends Node3D

const ASTEROID_SCENE: PackedScene = preload("res://scenes/asteroid.tscn")

enum Pattern { SINGLE, OFFSET_PAIR, HORIZONTAL_PAIR, VERTICAL_PAIR, STAGGERED_CLUSTER, LARGE_WITH_COMPANIONS, ASTEROID_GATE, OFFSET_GATE, DIAGONAL_BARRAGE, DOUBLE_CURTAIN, DIVE, ASTEROID_CANYON, DEMO_SLALOM_TUNNEL, DEMO_METEOR_STORM }

@export_category("Streaming")
@export var spawn_ahead_distance: float = 320.0
@export var start_distance: float = 55.0
@export var cleanup_distance: float = 100.0
@export_range(16, 220, 1) var max_active_asteroids: int = 96
@export var horizontal_spread: float = 56.0
@export var vertical_spread: float = 36.0
@export var cinematic_patterns_enabled: bool = true
@export_category("Astéroïdes mobiles")
@export var moving_asteroids_enabled: bool = true
@export_range(0.0, 1.0) var easy_mobile_ratio: float = 0.05
@export_range(0.0, 1.0) var intermediate_mobile_ratio: float = 0.20
@export_range(0.0, 1.0) var hard_mobile_ratio: float = 0.42

@export_category("Difficulte selon la distance")
@export var intermediate_distance: float = 500.0
@export var hard_distance: float = 1100.0
@export var easy_spacing: float = 56.0
@export var intermediate_spacing: float = 44.0
@export var hard_spacing: float = 34.0
@export var easy_gap: float = 22.0
@export var intermediate_gap: float = 18.0
@export var hard_gap: float = 14.0

var density_multiplier: float = 1.0
var irregular_barrages: bool = true
var storm_enabled: bool = false
var storm_complex: bool = false
var storm_target: int = 180
var storm_samples: Array[Dictionary] = []
var storm_speed_min: float = INF
var storm_speed_max: float = 0
var storm_size_bins: Array[int] = [0, 0, 0, 0]
var mega_generated: int = 0
var mega_types: Dictionary[int, int] = {}
var _storm_serial: int = 0
var _storm_container: Node3D
var _storm_visuals: StormRockVisuals
var configurations: Array[Node3D] = []
var active_asteroid_count: int = 0
var maximum_active_observed: int = 0
var active_mobile_count: int = 0
var maximum_mobile_observed: int = 0
var motions_generated: Dictionary[int, int] = {}
var _motion_totals_by_level: Dictionary[int, Vector2i] = {}
var generated_configuration_count: int = 0
var removed_configuration_count: int = 0
var patterns_generated: Dictionary[int, int] = {}
var difficulty_override: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0
var _origin_z: float = 0.0
var _next_z: float = 0.0
var _pending_pattern: int = -1
var _pending_level: int = 1


func initialize_field(seed_value: int, center: Vector3, front_z: float) -> void:
	_seed = seed_value
	_random.seed = seed_value + 73013
	_origin_z = center.z
	_next_z = front_z - maxf(start_distance, 50.0)
	_pending_pattern = -1
	_storm_serial = 0
	mega_generated = 0
	mega_types.clear()
	_storm_container = null
	_storm_visuals = null
	storm_samples.clear()
	storm_speed_min = INF
	storm_speed_max = 0
	storm_size_bins.assign([0, 0, 0, 0])
	_motion_totals_by_level.clear()


func difficulty_for_distance(distance: float) -> int:
	var second_threshold: float = maxf(intermediate_distance, 1.0)
	var third_threshold: float = maxf(hard_distance, second_threshold + 1.0)
	if distance >= third_threshold:
		return 3
	if distance >= second_threshold:
		return 2
	return 1


func spacing_for_level(level: int) -> float:
	match level:
		1:
			return maxf(easy_spacing, 24.0)
		2:
			return maxf(intermediate_spacing, 24.0)
		_:
			return maxf(hard_spacing, 24.0)


func allowed_patterns(level: int) -> Array[int]:
	match level:
		1:
			return [Pattern.SINGLE, Pattern.OFFSET_PAIR]
		2:
			var medium: Array[int] = [Pattern.OFFSET_PAIR, Pattern.HORIZONTAL_PAIR, Pattern.VERTICAL_PAIR, Pattern.STAGGERED_CLUSTER]
			if cinematic_patterns_enabled:
				medium.append(Pattern.ASTEROID_GATE)
			return medium
		_:
			var hard: Array[int] = [Pattern.HORIZONTAL_PAIR, Pattern.VERTICAL_PAIR, Pattern.STAGGERED_CLUSTER, Pattern.LARGE_WITH_COMPANIONS]
			if cinematic_patterns_enabled:
				hard.append_array([Pattern.ASTEROID_GATE, Pattern.OFFSET_GATE, Pattern.DIAGONAL_BARRAGE, Pattern.DOUBLE_CURTAIN, Pattern.DIVE, Pattern.ASTEROID_CANYON])
			return hard


func _choose_pattern(level: int) -> int:
	var choices: Array[int] = allowed_patterns(level)
	if cinematic_patterns_enabled and level >= 2:
		var originals: Array[int] = choices.slice(0, 4)
		# Niveau 2 : gate rare (1/25). Niveau 3 : deux tiers de patterns classiques.
		for _repeat: int in range(5 if level == 2 else 2):
			choices.append_array(originals)
	return choices[_random.randi_range(0, choices.size() - 1)]


func advance(center: Vector3, front_z: float, rear_z: float) -> void:
	if storm_enabled:
		advance_storm(center)
		return
	_cleanup_passed(rear_z)
	var safety_limit: int = 0
	while _next_z >= front_z - maxf(spawn_ahead_distance, 80.0):
		var effective_level: int = difficulty_for_distance(maxf(_origin_z - _next_z, 0.0)) if difficulty_override == 0 else clampi(difficulty_override, 1, 3)
		if _pending_pattern >= 0 and _pending_level != effective_level:
			_pending_pattern = -1
		if _pending_pattern < 0:
			_pending_level = difficulty_for_distance(maxf(_origin_z - _next_z, 0.0))
			if difficulty_override > 0:
				_pending_level = clampi(difficulty_override, 1, 3)
			_pending_pattern = _choose_pattern(_pending_level)
		var pattern: int = _pending_pattern
		var level: int = _pending_level
		var gap: float = easy_gap if level == 1 else (intermediate_gap if level == 2 else hard_gap)
		var offsets: Array[Vector3] = pattern_offsets(pattern, maxf(gap, 14.0))
		if active_asteroid_count + offsets.size() > max_active_asteroids:
			break # Conserver le tirage pendant l'attente : pas de reroll à chaque frame.
		_spawn_configuration(pattern, level, center, _next_z)
		_pending_pattern = -1
		var depth: float = 0.0
		for point: Vector3 in offsets:
			depth = maxf(depth, -point.z)
		_next_z -= spacing_for_level(level) / maxf(density_multiplier, 0.5) + (depth if pattern >= Pattern.ASTEROID_GATE else 0.0)
		safety_limit += 1
		if safety_limit >= 12:
			break


func _spawn_configuration(pattern: int, level: int, center: Vector3, z_position: float) -> void:
	var configuration: Node3D = Node3D.new()
	configuration.name = "Configuration_%05d" % generated_configuration_count
	configuration.position = Vector3(
		center.x + _random.randf_range(-horizontal_spread, horizontal_spread) * (0.25 if pattern >= Pattern.ASTEROID_GATE else 0.45),
		center.y + _random.randf_range(-vertical_spread, vertical_spread) * (0.25 if pattern >= Pattern.ASTEROID_GATE else 0.45),
		z_position
	)
	configuration.set_meta("pattern", pattern)
	configuration.set_meta("difficulty", level)
	configuration.set_meta("generation_index", generated_configuration_count)
	add_child(configuration)
	var gap: float = easy_gap if level == 1 else (intermediate_gap if level == 2 else hard_gap)
	var offsets: Array[Vector3] = pattern_offsets(pattern, maxf(gap, 14.0))
	var inverted: bool = pattern == Pattern.DIVE and generated_configuration_count % 2 == 1
	configuration.set_meta("inverted", inverted)
	configuration.set_meta("passages", passage_points(pattern, inverted))
	var cleanup_z: float = z_position
	var ratios: Array[float] = [easy_mobile_ratio, intermediate_mobile_ratio, hard_mobile_ratio]
	var mobile_ratio: float = ratios[level - 1] if moving_asteroids_enabled else 0.0
	var totals: Vector2i = _motion_totals_by_level.get(level, Vector2i.ZERO)
	var barrage_mobile: int = -1
	if pattern >= Pattern.ASTEROID_GATE:
		var desired_mobile: int = roundi((totals.x + offsets.size()) * mobile_ratio)
		barrage_mobile = int(absi(totals.y + offsets.size() - desired_mobile) < absi(totals.y - desired_mobile))
	for index: int in range(offsets.size()):
		var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
		asteroid.name = "Asteroid_%d" % index
		asteroid.diameter = _diameter_for_pattern(pattern, level, index)
		asteroid.size_category = _size_category(asteroid.diameter)
		asteroid.shape_seed = _seed + generated_configuration_count * 193 + index * 53
		asteroid.position = offsets[index] + Vector3(_random.randf_range(-0.25, 0.25), _random.randf_range(-0.25, 0.25), 0.0)
		if irregular_barrages and pattern >= Pattern.ASTEROID_GATE:
			# Jitter XYZ important, conservateur près des passages existants.
			asteroid.position += Vector3(_random.randf_range(-3, 3), _random.randf_range(-3, 3), _random.randf_range(-9, 9))
		if inverted:
			asteroid.position.y *= -1.0
		asteroid.rotation = Vector3(_random.randf_range(-PI, PI), _random.randf_range(-PI, PI), _random.randf_range(-PI, PI))
		# Un barrage partage son mouvement : ses ouvertures restent géométriquement ouvertes.
		var motion_seed: int = _seed + generated_configuration_count * 997 + (0 if pattern >= Pattern.ASTEROID_GATE else index * 67)
		# Quota cumulatif, pas effectif vivant : les types ne dépendent pas du nettoyage.
		var mobile_decision: int = barrage_mobile if barrage_mobile >= 0 else int(totals.y < roundi((totals.x + 1) * mobile_ratio))
		_configure_motion(asteroid, level, motion_seed, maxf(center.z - z_position, 0.0), mobile_decision)
		configuration.add_child(asteroid)
		cleanup_z = minf(cleanup_z, z_position + asteroid.motion_center.z - asteroid.avoidance_radius - asteroid.motion_depth_margin())
		active_asteroid_count += 1
		totals.x += 1
		if asteroid.motion_type != SpaceAsteroid.MotionType.STATIC:
			active_mobile_count += 1
			totals.y += 1
		motions_generated[asteroid.motion_type] = motions_generated.get(asteroid.motion_type, 0) + 1
	configuration.set_meta("cleanup_z", cleanup_z)
	_motion_totals_by_level[level] = totals
	configurations.append(configuration)
	generated_configuration_count += 1
	patterns_generated[pattern] = patterns_generated.get(pattern, 0) + 1
	maximum_active_observed = maxi(maximum_active_observed, active_asteroid_count)
	maximum_mobile_observed = maxi(maximum_mobile_observed, active_mobile_count)


func _configure_motion(asteroid: SpaceAsteroid, level: int, seed_value: int, distance: float, mobile_decision: int = -1) -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value + 171037
	var ratios: Array[float] = [easy_mobile_ratio, intermediate_mobile_ratio, hard_mobile_ratio]
	var probability: float = random.randf()
	if not moving_asteroids_enabled or mobile_decision == 0 or (mobile_decision < 0 and probability >= ratios[clampi(level, 1, 3) - 1]):
		return
	asteroid.motion_type = random.randi_range(1, 5) as SpaceAsteroid.MotionType
	var side: float = -1.0 if random.randf() < 0.5 else 1.0
	var vertical: float = -1.0 if random.randf() < 0.5 else 1.0
	asteroid.motion_duration = random.randf_range(12, 16)
	asteroid.motion_start_delay = maxf(distance / 10.5 - asteroid.motion_duration * 0.5, 0.0)
	asteroid.motion_velocity = Vector3(side * random.randf_range(4, 7), 0, 0)
	match asteroid.motion_type:
		SpaceAsteroid.MotionType.LINEAR:
			if random.randf() < 0.35:
				asteroid.motion_velocity = Vector3(0, vertical * random.randf_range(4, 6), 0)
		SpaceAsteroid.MotionType.DIAGONAL:
			asteroid.motion_velocity.y = vertical * random.randf_range(2, 4)
			asteroid.motion_velocity.z = random.randf_range(-2, 2)
		SpaceAsteroid.MotionType.VERTICAL_SWEEP:
			asteroid.motion_velocity = Vector3(side * 1.0, vertical * random.randf_range(5, 7), random.randf_range(-1, 1))
		SpaceAsteroid.MotionType.CIRCULAR:
			var planes: Array[Basis] = [Basis.IDENTITY, Basis(Vector3.RIGHT, PI * 0.5), Basis(Vector3.UP, PI * 0.5), Basis(Vector3(1, 1, 0).normalized(), 0.7)]
			var plane: Basis = planes[random.randi_range(0, 3)]
			asteroid.orbit_axis_u = plane * Vector3.RIGHT
			asteroid.orbit_axis_v = plane * Vector3.UP
			asteroid.motion_amplitude = Vector2(random.randf_range(12, 18), random.randf_range(8, 14))
			asteroid.motion_period = random.randf_range(16, 24)
			asteroid.motion_phase = random.randf_range(0, TAU)
		SpaceAsteroid.MotionType.ARC:
			asteroid.motion_velocity.y = vertical * 1.5
			asteroid.orbit_axis_v = Vector3.UP * vertical
			asteroid.motion_amplitude.y = random.randf_range(8, 14)


func pattern_offsets(pattern: int, gap: float) -> Array[Vector3]:
	match pattern:
		Pattern.DEMO_SLALOM_TUNNEL:
			return _demo_tunnel_offsets()
		Pattern.SINGLE:
			return [Vector3.ZERO]
		Pattern.OFFSET_PAIR:
			return [Vector3(-gap * 0.6, -gap * 0.25, 0), Vector3(gap * 0.6, gap * 0.3, -8)]
		Pattern.HORIZONTAL_PAIR:
			return [Vector3(-gap * 0.7, 0, 0), Vector3(gap * 0.7, 0, 0)]
		Pattern.VERTICAL_PAIR:
			return [Vector3(0, -gap * 0.7, 0), Vector3(0, gap * 0.7, 0)]
		Pattern.STAGGERED_CLUSTER:
			return [Vector3(-gap * 0.7, -gap * 0.35, 0), Vector3(gap * 0.7, gap * 0.35, -8), Vector3(0, gap * 0.8, -16)]
		Pattern.ASTEROID_GATE:
			return _gate_offsets(Vector3.ZERO)
		Pattern.OFFSET_GATE:
			return _gate_offsets(Vector3(18, 8, 0))
		Pattern.DIAGONAL_BARRAGE:
			var diagonal: Array[Vector3] = []
			for index: int in range(7):
				diagonal.append(Vector3(-27 + index * 9, -18 + index * 6, -index * 2))
			return diagonal
		Pattern.DOUBLE_CURTAIN:
			var curtains: Array[Vector3] = _gate_offsets(Vector3(-16, 0, 0))
			curtains.append_array(_gate_offsets(Vector3(16, 0, -50)))
			return curtains
		Pattern.DIVE:
			var dive: Array[Vector3] = []
			for x: int in [-24, -12, 0, 12, 24]:
				for y: int in [6, 18]:
					dive.append(Vector3(x, y, 0))
			return dive
		Pattern.ASTEROID_CANYON:
			var canyon: Array[Vector3] = []
			for x: int in [-26, 26]:
				for z: int in [0, -28]:
					for y: int in [-12, 0, 12]:
						canyon.append(Vector3(x, y, z))
			return canyon
		_:
			return [Vector3.ZERO, Vector3(-gap * 0.8, gap * 0.6, -8), Vector3(gap * 0.8, -gap * 0.6, -16)]


func _gate_offsets(center: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x: int in [-21, 21]:
		for y: int in [-14, 0, 14]:
			result.append(center + Vector3(x, y, 0))
	result.append(center + Vector3(0, -26, 0))
	result.append(center + Vector3(0, 26, 0))
	return result


func passage_points(pattern: int, inverted: bool = false) -> Array[Vector3]:
	match pattern:
		Pattern.ASTEROID_GATE: return [Vector3.ZERO]
		Pattern.OFFSET_GATE: return [Vector3(18, 8, 0)]
		Pattern.DIAGONAL_BARRAGE: return [Vector3(0, -27, -6), Vector3(0, 27, -6)]
		Pattern.DOUBLE_CURTAIN: return [Vector3(-16, 0, 0), Vector3(16, 0, -50)]
		Pattern.DIVE: return [Vector3(0, 18 if inverted else -18, 0)]
		Pattern.ASTEROID_CANYON: return [Vector3(0, 0, 0), Vector3(0, 0, -28)]
	return []


func _demo_tunnel_offsets() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var openings: Array[Vector2] = [Vector2(-12, 0), Vector2(0, 12), Vector2(12, 0), Vector2(0, -12), Vector2(-12, 0)]
	for row: int in range(openings.size()):
		for x: int in [-36, -24, -12, 0, 12, 24, 36]:
			for y: int in [-24, -12, 0, 12, 24]:
				if absf(x - openings[row].x) <= 18 and absf(y - openings[row].y) <= 18:
					continue
				points.append(Vector3(x, y, -55 - row * 48))
	return points


func create_demonstration_field(phase: int, center: Vector3, seed_value: int) -> void:
	var configuration: Node3D = Node3D.new()
	configuration.name = "DemonstrationField"
	configuration.position = center
	configuration.set_meta("pattern", Pattern.DEMO_SLALOM_TUNNEL if phase == 0 else -1)
	configuration.set_meta("difficulty", 3)
	configuration.set_meta("passages", [Vector3(-12, 0, -55), Vector3(0, 12, -103), Vector3(12, 0, -151), Vector3(0, -12, -199), Vector3(-12, 0, -247)] if phase == 0 else [])
	add_child(configuration)
	configurations.append(configuration)
	var index: int = 0
	if phase == 0:
		for point: Vector3 in _demo_tunnel_offsets():
			_add_demonstration_rock(configuration, point, 4.8, SpaceAsteroid.MotionType.STATIC, Vector3.ZERO, seed_value + index * 67)
			index += 1
		var angles: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.DOWN, Vector3.UP, Vector3(1, -1, 0).normalized()]
		for direction: Vector3 in angles:
			var point: Vector3 = -direction * 35 + Vector3(0, 0, -65 - index % 5 * 42)
			_add_demonstration_rock(configuration, point, 5.5, SpaceAsteroid.MotionType.LINEAR, direction * 5, seed_value + index * 67)
			index += 1
	elif phase == 1:
		var types: Array[int] = [SpaceAsteroid.MotionType.DIAGONAL, SpaceAsteroid.MotionType.VERTICAL_SWEEP, SpaceAsteroid.MotionType.CIRCULAR, SpaceAsteroid.MotionType.ARC]
		for row: int in range(4):
			for column: int in range(4):
				var motion: int = types[column]
				var side: float = -1 if row % 2 == 0 else 1
				var point: Vector3 = Vector3((-1.5 + column) * 22, side * 25, -65 - row * 55)
				var travel: Vector3 = Vector3(side * 5, -side * 4, 0) if motion == SpaceAsteroid.MotionType.DIAGONAL else Vector3(0, -side * 5, 0) if motion == SpaceAsteroid.MotionType.VERTICAL_SWEEP else Vector3(side * 5, -side, 0)
				_add_demonstration_rock(configuration, point, 7 if column == 0 else 5.5, motion, travel, seed_value + index * 67)
				index += 1
	else:
		for point: Vector3 in [Vector3(-55, 28, -90), Vector3(55, -26, -150), Vector3(-52, -28, -220)]:
			_add_demonstration_rock(configuration, point, 5, SpaceAsteroid.MotionType.STATIC, Vector3.ZERO, seed_value + index * 67)
			index += 1
	var cleanup_z: float = center.z
	for child: Node in configuration.get_children():
		var rock: SpaceAsteroid = child as SpaceAsteroid
		cleanup_z = minf(cleanup_z, center.z + rock.motion_center.z - rock.avoidance_radius - rock.motion_depth_margin())
	configuration.set_meta("cleanup_z", cleanup_z)
	generated_configuration_count += 1
	maximum_active_observed = maxi(maximum_active_observed, active_asteroid_count)
	maximum_mobile_observed = maxi(maximum_mobile_observed, active_mobile_count)
	if phase == 0:
		patterns_generated[Pattern.DEMO_SLALOM_TUNNEL] = 1


func _add_demonstration_rock(parent: Node3D, initial_position: Vector3, diameter: float, motion: int, travel: Vector3, seed_value: int) -> void:
	var rock: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	rock.diameter = diameter
	rock.size_category = _size_category(diameter)
	rock.shape_seed = seed_value
	rock.motion_type = motion as SpaceAsteroid.MotionType
	rock.motion_velocity = travel
	rock.motion_duration = 16
	rock.motion_period = 16
	rock.motion_amplitude = Vector2(18, 12)
	rock.orbit_axis_u = Vector3(1, 0, 0.35).normalized()
	rock.orbit_axis_v = Vector3(0, 1, 0.25).normalized()
	rock.position = initial_position - rock.trajectory_offset(0)
	parent.add_child(rock)
	active_asteroid_count += 1
	if motion != SpaceAsteroid.MotionType.STATIC:
		active_mobile_count += 1
	motions_generated[motion] = motions_generated.get(motion, 0) + 1


func _diameter_for_pattern(pattern: int, level: int, index: int) -> float:
	if pattern >= Pattern.ASTEROID_GATE:
		return _random.randf_range(4.8, 6.2) if level == 3 else _random.randf_range(3.5, 4.8)
	if pattern == Pattern.LARGE_WITH_COMPANIONS:
		return _random.randf_range(5.5, 7.0) if index == 0 else _random.randf_range(1.2, 2.2)
	match level:
		1:
			return _random.randf_range(1.2, 3.7)
		2:
			return _random.randf_range(2.0, 5.5)
		_:
			return _random.randf_range(4.0, 6.5)


func _size_category(diameter: float) -> SpaceAsteroid.SizeCategory:
	if diameter < 2.0:
		return SpaceAsteroid.SizeCategory.SMALL
	if diameter < 4.0:
		return SpaceAsteroid.SizeCategory.MEDIUM
	return SpaceAsteroid.SizeCategory.LARGE


func _cleanup_passed(rear_z: float) -> void:
	for index: int in range(configurations.size() - 1, -1, -1):
		var configuration: Node3D = configurations[index]
		var cleanup_z: float = float(configuration.get_meta("cleanup_z"))
		if cleanup_z <= rear_z + maxf(cleanup_distance, 70.0):
			continue
		for child: Node in configuration.get_children():
			if (child as SpaceAsteroid).motion_type != SpaceAsteroid.MotionType.STATIC:
				active_mobile_count -= 1
			child.remove_from_group("asteroids")
		active_asteroid_count -= configuration.get_child_count()
		configurations.remove_at(index)
		configuration.queue_free()
		removed_configuration_count += 1


func advance_storm(center: Vector3) -> void:
	if not is_instance_valid(_storm_container):
		_storm_container = Node3D.new()
		_storm_container.name = "RandomMeteorStorm"
		add_child(_storm_container)
		_storm_visuals = StormRockVisuals.new()
		_storm_visuals.name = "PhysicalMeteorMultiMesh"
		add_child(_storm_visuals)
	for node: Node in _storm_container.get_children():
		var rock: SpaceAsteroid = node as SpaceAsteroid
		if rock.is_queued_for_deletion():
			continue
		var relative: Vector3 = rock.global_position - center
		if relative.z > 80 or relative.z < -340 or absf(relative.x) > 110 or absf(relative.y) > 85:
			rock.remove_from_group("asteroids")
			rock.collision_layer = 0
			active_asteroid_count -= 1
			active_mobile_count -= 1
			rock.queue_free()
	var rocks: Array[Node] = get_tree().get_nodes_in_group("asteroids")
	var ships: Array[Node] = get_tree().get_nodes_in_group("blue_ships")
	var target_count: int = mini(storm_target, max_active_asteroids)
	var added: int = 0
	for _attempt: int in range(1200):
		if active_asteroid_count >= target_count or added >= 180:
			break
		var spec: Dictionary = MeteorStorm.sample(_random, center, storm_complex)
		if not MeteorStorm.clear(spec, center, rocks, ships):
			continue
		var rock: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
		rock.name = "Meteor_%d" % _storm_serial
		rock.diameter = spec.diameter
		rock.size_category = _size_category(rock.diameter)
		rock.shape_seed = spec.seed
		rock.single_convex_envelope = true
		rock.motion_type = int(spec.motion) as SpaceAsteroid.MotionType
		rock.motion_velocity = spec.velocity
		rock.motion_duration = 80
		rock.orbit_axis_u = spec.axis_u
		rock.orbit_axis_v = spec.axis_v
		rock.motion_amplitude = spec.amplitude
		rock.motion_phase = spec.phase
		rock.motion_period = spec.period
		rock.rotation = spec.rotation
		rock.position = _storm_container.to_local(spec.position) - rock.trajectory_offset(0)
		_storm_container.add_child(rock)
		rocks.append(rock)
		active_asteroid_count += 1
		active_mobile_count += 1
		added += 1
		_storm_serial += 1
		motions_generated[rock.motion_type] = motions_generated.get(rock.motion_type, 0) + 1
		storm_speed_min = minf(storm_speed_min, rock.motion_velocity.length())
		storm_speed_max = maxf(storm_speed_max, rock.motion_velocity.length())
		storm_size_bins[0 if rock.diameter < 2 else 1 if rock.diameter < 5 else 2 if rock.diameter < 10 else 3] += 1
		if storm_samples.size() < 512:
			storm_samples.append(spec)
	maximum_active_observed = maxi(maximum_active_observed, active_asteroid_count)
	maximum_mobile_observed = maxi(maximum_mobile_observed, active_mobile_count)
	patterns_generated[Pattern.DEMO_METEOR_STORM] = _storm_serial


func spawn_mega(center: Vector3, fleet_velocity: Vector3, trajectory: int, diameter_value: float = 40) -> bool:
	if not is_instance_valid(_storm_container) or active_asteroid_count >= max_active_asteroids:
		return false
	for node: Node in _storm_container.get_children():
		if node is SpaceAsteroid and (node as SpaceAsteroid).diameter >= 20 and not node.is_queued_for_deletion():
			return false # Un seul danger principal à la fois.
	var motions: Array[Vector3] = [Vector3(9, 0, 8), Vector3(-7, -5, 7), Vector3(0, -10, 5), Vector3(5, 0, 3)]
	var travel: Vector3 = motions[trajectory % motions.size()]
	var prediction_time: float = 6
	var crossing: Vector3 = center + fleet_velocity * prediction_time + Vector3(12, 4, 0)
	var candidate: Vector3 = crossing - travel * prediction_time
	# Aucun changement de vitesse après ce calcul : pas de poursuite.
	for node: Node in get_tree().get_nodes_in_group("blue_ships"):
		if candidate.distance_to((node as Node3D).global_position) < diameter_value * 0.65 + 20:
			return false
	var rock: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	rock.name = "Mega_%d" % mega_generated
	rock.diameter = diameter_value
	rock.size_category = SpaceAsteroid.SizeCategory.MEGA
	rock.mega_trajectory = trajectory as SpaceAsteroid.MegaTrajectory
	rock.shape_seed = _seed + 14777 + mega_generated * 997
	rock.threat_strength = 1.6
	rock.single_convex_envelope = true
	rock.motion_type = SpaceAsteroid.MotionType.LINEAR
	rock.motion_velocity = travel
	rock.motion_duration = 80
	rock.position = _storm_container.to_local(candidate) - rock.trajectory_offset(0)
	_storm_container.add_child(rock)
	active_asteroid_count += 1
	active_mobile_count += 1
	mega_generated += 1
	mega_types[trajectory] = mega_types.get(trajectory, 0) + 1
	maximum_active_observed = maxi(maximum_active_observed, active_asteroid_count)
	maximum_mobile_observed = maxi(maximum_mobile_observed, active_mobile_count)
	return true


func spawn_fast_crossing(center: Vector3) -> void:
	for index: int in range(3):
		if active_asteroid_count >= max_active_asteroids or not is_instance_valid(_storm_container):
			return
		var rock: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
		rock.diameter = 1.2
		rock.size_category = SpaceAsteroid.SizeCategory.SMALL
		rock.shape_seed = _seed + 14501 + index
		rock.single_convex_envelope = true
		rock.motion_type = SpaceAsteroid.MotionType.LINEAR
		rock.motion_velocity = Vector3(34, -8 + index * 8, 8)
		rock.motion_duration = 80
		rock.position = _storm_container.to_local(center + Vector3(-60, -8 + index * 8, -75)) - rock.trajectory_offset(0)
		_storm_container.add_child(rock)
		active_asteroid_count += 1
		active_mobile_count += 1
