class_name SpaceSimulation
extends Node3D

const SHIP_SCENE: PackedScene = preload("res://scenes/blue_ship.tscn")
const ASTEROID_SCENE: PackedScene = preload("res://scenes/asteroid.tscn")

@export_range(1, 30, 1) var ship_count: int = 10
@export_range(0, 60, 1) var asteroid_rows: int = 24
@export var initial_ship_spacing: float = 8.5
@export var asteroid_row_spacing: float = 34.0
@export var asteroid_start_distance: float = 55.0
@export var asteroid_horizontal_spread: float = 18.0
@export var asteroid_vertical_spread: float = 12.0
@export var simulation_seed: int = 20261012
@export var camera_follow_speed: float = 3.0

var initial_agent_count: int = 0
var living_agent_count: int = 0
var death_count: int = 0
var ships: Array[BlueShip] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_center: Vector3 = Vector3.ZERO

@onready var ship_container: Node3D = $Ships
@onready var asteroid_container: Node3D = $Asteroids
@onready var camera: SimulationCamera = $Camera3D
@onready var space_decor: SpaceEnvironment = $SpaceDecor
@onready var statistics: Label = $HUD/Panel/Lines/Statistics
@onready var end_message: Label = $HUD/Panel/Lines/EndMessage
@onready var camera_mode_label: Label = $HUD/Panel/Lines/CameraMode


func _ready() -> void:
	_random.seed = simulation_seed
	_create_ships()
	_create_asteroid_field()
	_last_center = _fleet_center()
	camera.follow_speed = camera_follow_speed
	camera.mode_changed.connect(_on_camera_mode_changed)
	camera.initialize_view(_last_center)
	_on_camera_mode_changed(false)
	_update_hud()


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


func _create_asteroid_field() -> void:
	for row: int in range(maxi(asteroid_rows, 0)):
		var row_rocks: Array[SpaceAsteroid] = []
		for column: int in range(2):
			var category: int = (row * 2 + column) % 3
			var diameter: float = _category_diameter(category)
			var candidate: Vector3 = Vector3.ZERO
			var clear: bool = false
			for _attempt: int in range(80):
				candidate = Vector3(
					_random.randf_range(-asteroid_horizontal_spread, asteroid_horizontal_spread),
					_random.randf_range(-asteroid_vertical_spread, asteroid_vertical_spread),
					-asteroid_start_distance - float(row) * maxf(asteroid_row_spacing, 20.0) + _random.randf_range(-3.0, 3.0)
				)
				clear = true
				for other: SpaceAsteroid in row_rocks:
					if candidate.distance_to(other.position) < diameter * 0.6 + other.avoidance_radius + 10.0:
						clear = false
						break
				if clear:
					break
			if not clear:
				continue
			var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
			asteroid.name = "Asteroid_%02d_%d" % [row + 1, column + 1]
			asteroid.size_category = category as SpaceAsteroid.SizeCategory
			asteroid.diameter = diameter
			asteroid.shape_seed = simulation_seed + row * 53 + column * 193
			asteroid.position = candidate
			asteroid.rotation = Vector3(_random.randf_range(-PI, PI), _random.randf_range(-PI, PI), _random.randf_range(-PI, PI))
			asteroid_container.add_child(asteroid)
			row_rocks.append(asteroid)


func _category_diameter(category: int) -> float:
	match category:
		SpaceAsteroid.SizeCategory.SMALL:
			return _random.randf_range(1.0, 2.0)
		SpaceAsteroid.SizeCategory.MEDIUM:
			return _random.randf_range(2.0, 4.0)
		_:
			return _random.randf_range(4.0, 7.0)


func _on_ship_died(ship: BlueShip) -> void:
	if not ships.has(ship):
		return
	ships.erase(ship)
	death_count += 1
	living_agent_count = ships.size()
	_update_hud()


func _update_hud() -> void:
	statistics.text = "Vaisseaux vivants : %d\nMorts : %d" % [living_agent_count, death_count]
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
