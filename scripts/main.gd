class_name SpaceSimulation
extends Node3D

const SHIP_SCENE: PackedScene = preload("res://scenes/blue_ship.tscn")
const DIFFICULTY_NAMES: Array[String] = ["Facile", "Intermédiaire", "Difficile"]

@export_range(1, 30, 1) var ship_count: int = 10
@export var initial_ship_spacing: float = 8.5
@export var streaming_enabled: bool = true
@export var simulation_seed: int = 20261012
@export var camera_follow_speed: float = 3.0
@export var metrics_update_interval: float = 0.4

var initial_agent_count: int = 0
var living_agent_count: int = 0
var death_count: int = 0
var distance_travelled: float = 0.0
var difficulty_level: int = 1
var average_spacing: float = 0.0
var dispersion: float = 0.0
var isolated_agent_count: int = 0
var ships: Array[BlueShip] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_center: Vector3 = Vector3.ZERO
var _origin_z: float = 0.0
var _measurement_timer: float = 0.0

@onready var ship_container: Node3D = $Ships
@onready var asteroid_container: ObstacleField = $Asteroids
@onready var camera: SimulationCamera = $Camera3D
@onready var space_decor: SpaceEnvironment = $SpaceDecor
@onready var statistics: Label = $HUD/Panel/Lines/Statistics
@onready var end_message: Label = $HUD/Panel/Lines/EndMessage
@onready var camera_mode_label: Label = $HUD/Panel/Lines/CameraMode
@onready var progression_label: Label = $HUD/Panel/Lines/Progression
@onready var group_metrics_label: Label = $HUD/Panel/Lines/GroupMetrics


func _ready() -> void:
	_random.seed = simulation_seed
	_create_ships()
	_last_center = _fleet_center()
	_origin_z = _last_center.z
	var z_bounds: Vector2 = _fleet_z_bounds()
	asteroid_container.initialize_field(simulation_seed, _last_center, z_bounds.x)
	if streaming_enabled:
		asteroid_container.advance(_last_center, z_bounds.x, z_bounds.y)
	camera.follow_speed = camera_follow_speed
	camera.mode_changed.connect(_on_camera_mode_changed)
	camera.initialize_view(_last_center)
	_on_camera_mode_changed(false)
	_measure_group(_last_center)
	_update_hud()


func _physics_process(delta: float) -> void:
	if ships.is_empty():
		return
	var center: Vector3 = _fleet_center()
	# La progression ne recule pas si la perte d'un survivant déplace légèrement le barycentre.
	distance_travelled = maxf(distance_travelled, _origin_z - center.z)
	difficulty_level = asteroid_container.difficulty_for_distance(distance_travelled)
	if streaming_enabled:
		var z_bounds: Vector2 = _fleet_z_bounds()
		asteroid_container.advance(center, z_bounds.x, z_bounds.y)
	_measurement_timer += delta
	if _measurement_timer >= maxf(metrics_update_interval, 0.1):
		_measure_group(center)
		_update_hud()
		_measurement_timer = 0.0


func _process(delta: float) -> void:
	var center: Vector3 = _fleet_center()
	_update_camera(center, delta)
	space_decor.recycle_stars(camera.global_position)


func _create_ships() -> void:
	for index: int in range(maxi(ship_count, 0)):
		var ship: BlueShip = SHIP_SCENE.instantiate() as BlueShip
		ship.name = "BlueShip_%02d" % (index + 1)
		ship.individual_seed = simulation_seed + (index + 1) * 997
		ship.position = _random_ship_position()
		ship.died.connect(_on_ship_died)
		ship_container.add_child(ship)
		ships.append(ship)
	initial_agent_count = ships.size()
	living_agent_count = initial_agent_count


func _random_ship_position() -> Vector3:
	var candidate: Vector3 = Vector3.ZERO
	for attempt: int in range(500):
		var expansion: float = 1.0 + float(attempt) / 100.0 * 0.15
		candidate = Vector3(_random.randf_range(-15.0, 15.0), _random.randf_range(-9.0, 9.0), _random.randf_range(-12.0, 12.0)) * expansion
		if _ship_position_is_clear(candidate):
			return candidate
	# Cas extrême d'un nombre important d'agents : chercher une place libre en élargissant le volume.
	while not _ship_position_is_clear(candidate):
		candidate += Vector3(1.3, 1.1, 0.7) * maxf(initial_ship_spacing, 1.0)
	return candidate


func _ship_position_is_clear(candidate: Vector3) -> bool:
	for other: BlueShip in ships:
		if candidate.distance_to(other.position) < maxf(initial_ship_spacing, 0.1):
			return false
	return true


func _fleet_z_bounds() -> Vector2:
	var front_z: float = INF
	var rear_z: float = -INF
	for ship: BlueShip in ships:
		if is_instance_valid(ship) and ship.alive:
			front_z = minf(front_z, ship.global_position.z)
			rear_z = maxf(rear_z, ship.global_position.z)
	if front_z == INF:
		return Vector2(_last_center.z, _last_center.z)
	return Vector2(front_z, rear_z)


func _measure_group(center: Vector3) -> void:
	var total_nearest: float = 0.0
	var sample_count: int = 0
	dispersion = 0.0
	isolated_agent_count = 0
	for ship: BlueShip in ships:
		if not is_instance_valid(ship) or not ship.alive:
			continue
		dispersion = maxf(dispersion, center.distance_to(ship.global_position))
		var nearest: float = INF
		for other: BlueShip in ships:
			if other != ship and is_instance_valid(other) and other.alive:
				nearest = minf(nearest, ship.global_position.distance_to(other.global_position))
		if nearest > ship.neighbor_radius:
			isolated_agent_count += 1
		if nearest != INF:
			total_nearest += nearest
			sample_count += 1
	average_spacing = total_nearest / float(sample_count) if sample_count > 0 else 0.0


func _on_ship_died(ship: BlueShip) -> void:
	if not ships.has(ship):
		return
	ships.erase(ship)
	death_count += 1
	living_agent_count = ships.size()
	_measure_group(_fleet_center())
	_update_hud()


func _update_hud() -> void:
	statistics.text = "Vaisseaux vivants : %d\nMorts : %d" % [living_agent_count, death_count]
	progression_label.text = "Distance : %.0f m\nDifficulté : %d - %s" % [distance_travelled, difficulty_level, DIFFICULTY_NAMES[difficulty_level - 1]]
	group_metrics_label.text = "Espacement : %.1f m · Dispersion : %.1f m" % [average_spacing, dispersion]
	end_message.visible = living_agent_count == 0


func _on_camera_mode_changed(free_camera: bool) -> void:
	camera_mode_label.text = "Mode caméra : %s" % ("Libre" if free_camera else "Suivi")


func _fleet_center() -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for ship: BlueShip in ships:
		if is_instance_valid(ship) and ship.alive and not ship.is_queued_for_deletion():
			sum += ship.global_position
			count += 1
	if count > 0:
		_last_center = sum / float(count)
	return _last_center


func _update_camera(center: Vector3, delta: float) -> void:
	var spread: float = 0.0
	for ship: BlueShip in ships:
		if is_instance_valid(ship) and ship.alive:
			spread = maxf(spread, center.distance_to(ship.global_position))
	camera.observe_group(center, spread, delta)
