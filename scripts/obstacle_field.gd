class_name ObstacleField
extends Node3D

const ASTEROID_SCENE: PackedScene = preload("res://scenes/asteroid.tscn")

enum Pattern { SINGLE, OFFSET_PAIR, HORIZONTAL_PAIR, VERTICAL_PAIR, STAGGERED_CLUSTER, LARGE_WITH_COMPANIONS }

@export_category("Streaming")
@export var spawn_ahead_distance: float = 320.0
@export var start_distance: float = 55.0
@export var cleanup_distance: float = 100.0
@export_range(9, 180, 1) var max_active_asteroids: int = 72
@export var horizontal_spread: float = 18.0
@export var vertical_spread: float = 12.0

@export_category("Difficulte selon la distance")
@export var intermediate_distance: float = 500.0
@export var hard_distance: float = 1100.0
@export var easy_spacing: float = 56.0
@export var intermediate_spacing: float = 44.0
@export var hard_spacing: float = 34.0
@export var easy_gap: float = 22.0
@export var intermediate_gap: float = 18.0
@export var hard_gap: float = 14.0

var configurations: Array[Node3D] = []
var active_asteroid_count: int = 0
var maximum_active_observed: int = 0
var generated_configuration_count: int = 0
var removed_configuration_count: int = 0
var patterns_generated: Dictionary[int, int] = {}
var difficulty_override: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0
var _origin_z: float = 0.0
var _next_z: float = 0.0


func initialize_field(seed_value: int, center: Vector3, front_z: float) -> void:
	_seed = seed_value
	_random.seed = seed_value + 73013
	_origin_z = center.z
	_next_z = front_z - maxf(start_distance, 50.0)


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
			return [Pattern.OFFSET_PAIR, Pattern.HORIZONTAL_PAIR, Pattern.VERTICAL_PAIR, Pattern.STAGGERED_CLUSTER]
		_:
			return [Pattern.HORIZONTAL_PAIR, Pattern.VERTICAL_PAIR, Pattern.STAGGERED_CLUSTER, Pattern.LARGE_WITH_COMPANIONS]


func advance(center: Vector3, front_z: float, rear_z: float) -> void:
	_cleanup_passed(rear_z)
	# Trois corps au maximum par configuration : réserver la place avant de tirer le pattern.
	var safety_limit: int = 0
	while _next_z >= front_z - maxf(spawn_ahead_distance, 80.0) and active_asteroid_count + 3 <= max_active_asteroids:
		var level: int = difficulty_for_distance(maxf(_origin_z - _next_z, 0.0))
		if difficulty_override > 0:
			level = clampi(difficulty_override, 1, 3)
		var choices: Array[int] = allowed_patterns(level)
		var pattern: int = choices[_random.randi_range(0, choices.size() - 1)]
		_spawn_configuration(pattern, level, center, _next_z)
		_next_z -= spacing_for_level(level)
		safety_limit += 1
		if safety_limit >= 12:
			break


func _spawn_configuration(pattern: int, level: int, center: Vector3, z_position: float) -> void:
	var configuration: Node3D = Node3D.new()
	configuration.name = "Configuration_%05d" % generated_configuration_count
	configuration.position = Vector3(
		center.x + _random.randf_range(-horizontal_spread, horizontal_spread) * 0.45,
		center.y + _random.randf_range(-vertical_spread, vertical_spread) * 0.45,
		z_position
	)
	configuration.set_meta("pattern", pattern)
	configuration.set_meta("difficulty", level)
	configuration.set_meta("generation_index", generated_configuration_count)
	add_child(configuration)
	var gap: float = easy_gap if level == 1 else (intermediate_gap if level == 2 else hard_gap)
	var offsets: Array[Vector3] = pattern_offsets(pattern, maxf(gap, 14.0))
	var cleanup_z: float = z_position
	for index: int in range(offsets.size()):
		var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
		asteroid.name = "Asteroid_%d" % index
		asteroid.diameter = _diameter_for_pattern(pattern, level, index)
		asteroid.size_category = _size_category(asteroid.diameter)
		asteroid.shape_seed = _seed + generated_configuration_count * 193 + index * 53
		asteroid.position = offsets[index] + Vector3(_random.randf_range(-0.25, 0.25), _random.randf_range(-0.25, 0.25), 0.0)
		asteroid.rotation = Vector3(_random.randf_range(-PI, PI), _random.randf_range(-PI, PI), _random.randf_range(-PI, PI))
		configuration.add_child(asteroid)
		cleanup_z = minf(cleanup_z, asteroid.global_position.z - asteroid.avoidance_radius)
		active_asteroid_count += 1
	configuration.set_meta("cleanup_z", cleanup_z)
	configurations.append(configuration)
	generated_configuration_count += 1
	patterns_generated[pattern] = patterns_generated.get(pattern, 0) + 1
	maximum_active_observed = maxi(maximum_active_observed, active_asteroid_count)


func pattern_offsets(pattern: int, gap: float) -> Array[Vector3]:
	match pattern:
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
		_:
			return [Vector3.ZERO, Vector3(-gap * 0.8, gap * 0.6, -8), Vector3(gap * 0.8, -gap * 0.6, -16)]


func _diameter_for_pattern(pattern: int, level: int, index: int) -> float:
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
			child.remove_from_group("asteroids")
		active_asteroid_count -= configuration.get_child_count()
		configurations.remove_at(index)
		configuration.queue_free()
		removed_configuration_count += 1
