class_name SpaceSimulation
extends Node3D

const SHIP_SCENE: PackedScene = preload("res://scenes/blue_ship.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/patrol_drone.tscn")
const INTERCEPTOR_SCENE: PackedScene = preload("res://scenes/interceptor.tscn")
const CAPITAL_SCENE: PackedScene = preload("res://scenes/capital_ship.tscn")
const DEFAULT_DEMO_SPEED: float = 1.7
const DEFAULT_MOVEMENT: float = 1.2
const DIFFICULTY_NAMES: Array[String] = ["Facile", "Intermédiaire", "Difficile"]

@export_range(1, 30, 1) var ship_count: int = 10
@export var initial_ship_spacing: float = 8.5
@export var streaming_enabled: bool = true
@export var simulation_seed: int = 20261012
@export var camera_follow_speed: float = 3.0
@export var metrics_update_interval: float = 0.4
@export_range(0, 3, 1) var manual_difficulty: int = 0
@export var combat_enabled: bool = true
@export var capital_ships_enabled: bool = true
@export_range(-1, 1, 1) var manual_capital_count_override: int = -1
@export var capital_replacement_delay: float = 25.0

@export_category("Démonstration")
@export_range(0.5, 2.5, 0.1) var simulation_speed_multiplier: float = DEFAULT_DEMO_SPEED
@export_range(0.5, 2.0, 0.1) var movement_multiplier: float = DEFAULT_MOVEMENT
@export_range(0.8, 1.4, 0.1) var spacing_multiplier: float = 1.0
@export_range(-1, 8, 1) var manual_drone_count_override: int = -1
@export_range(-1, 8, 1) var manual_interceptor_count_override: int = -1
@export var demo_spawn_interval: float = 0.4

@export_category("Drones de patrouille")
@export var drones_enabled: bool = true
@export_range(0, 3, 1) var easy_drone_count: int = 1
@export_range(0, 3, 1) var intermediate_drone_count: int = 2
@export_range(0, 3, 1) var hard_drone_count: int = 3
@export var drone_spawn_ahead_distance: float = 100.0
@export var drone_replacement_delay: float = 5.0
@export var drone_retire_distance: float = 120.0

@export_category("Intercepteurs")
@export var interceptors_enabled: bool = true
@export_range(0, 2, 1) var easy_interceptor_count: int = 0
@export_range(0, 2, 1) var intermediate_interceptor_count: int = 1
@export_range(0, 2, 1) var hard_interceptor_count: int = 2
@export var interceptor_spawn_ahead_distance: float = 115.0
@export var interceptor_replacement_delay: float = 8.0
@export var interceptor_retire_distance: float = 140.0

var initial_agent_count: int = 0
var ship_spawn_count: int = 0
var ship_retired_count: int = 0
var target_ship_count: int = 0
var living_agent_count: int = 0
var death_count: int = 0
var distance_travelled: float = 0.0
var elapsed_simulation_time: float = 0.0
var difficulty_level: int = 1
var average_spacing: float = 0.0
var dispersion: float = 0.0
var isolated_agent_count: int = 0
var ships: Array[BlueShip] = []
var drones: Array[PatrolDrone] = []
var interceptors: Array[Interceptor] = []
var capitals: Array[CapitalShip] = []
var capitals_destroyed: int = 0
var capital_spawn_count: int = 0
var capital_salvos: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var demonstration_legacy_fixture: bool = false
var rock_density: float = 1.0
var fire_intensity: float = 1.0
var artillery_hits: int = 0
var artillery_obstacle_hits: int = 0
var maximum_artillery_projectiles: int = 0
var _capital_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _capital_replacement_timer: float = 0
var interceptor_death_count: int = 0
var interceptor_retired_count: int = 0
var interceptor_spawn_count: int = 0
var drones_destroyed: int = 0
var interceptors_destroyed: int = 0
var enemy_shots_fired: int = 0
var blue_ship_hits: int = 0
var projectile_dodge_count: int = 0
var projectile_dodge_ticks: int = 0
var moving_asteroid_dodge_count: int = 0
var moving_asteroid_avoidance_ticks: int = 0
var drone_death_count: int = 0
var drone_retired_count: int = 0
var drone_spawn_count: int = 0
var enemies_destroyed: int = 0
var blue_shots_fired: int = 0
var hostile_hits: int = 0
var maximum_active_projectiles: int = 0
var action_intensity: float = 0.0
var _drone_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _replacement_timer: float = 0.0
var _interceptor_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _interceptor_replacement_timer: float = 0.0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_center: Vector3 = Vector3.ZERO
var _origin_z: float = 0.0
var _measurement_timer: float = 0.0
var _ship_spawn_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _ship_add_timer: float = 0.0
var _previous_time_scale: float = 1.0
var _previous_physics_rate: int = 60
var _engine_settings_owned: bool = false

@onready var ship_container: Node3D = $Ships
@onready var asteroid_container: ObstacleField = $Asteroids
@onready var drone_container: Node3D = $PatrolDrones
@onready var interceptor_container: Node3D = $Interceptors
@onready var capital_container: Node3D = $CapitalShips
@onready var projectile_container: Node3D = $Projectiles
@onready var camera: SimulationCamera = $Camera3D
@onready var space_decor: SpaceEnvironment = $SpaceDecor
@onready var statistics: Label = $HUD/Panel/Statistics
@onready var presentation_window: PresentationWindow = $PresentationWindow
@onready var demo_controls: DemoControls = $DemoControls
@onready var demonstration: GuidedDemonstration = $GuidedDemonstration


func _ready() -> void:
	_previous_time_scale = Engine.time_scale
	_previous_physics_rate = Engine.physics_ticks_per_second
	_engine_settings_owned = true
	camera.camera_mode_changed.connect(func(_mode: int) -> void: demo_controls.refresh(self))
	presentation_window.fullscreen_changed.connect(func(_enabled: bool) -> void: demo_controls.refresh(self))
	set_simulation_speed(simulation_speed_multiplier)
	_random.seed = simulation_seed
	_ship_spawn_random.seed = simulation_seed + 83003
	_drone_random.seed = simulation_seed + 91003
	_interceptor_random.seed = simulation_seed + 93037
	_capital_random.seed = simulation_seed + 103049
	_create_ships()
	_last_center = _fleet_center()
	_origin_z = _last_center.z
	var z_bounds: Vector2 = _fleet_z_bounds()
	asteroid_container.initialize_field(simulation_seed, _last_center, z_bounds.x)
	_update_difficulty()
	if streaming_enabled:
		asteroid_container.advance(_last_center, z_bounds.x, z_bounds.y)
	_maintain_drones(_last_center, 0.0)
	_maintain_interceptors(_last_center, 0.0)
	_maintain_capitals(_last_center, 0.0)
	camera.follow_speed = camera_follow_speed
	camera.initialize_view(_last_center, simulation_seed)
	_measure_group(_last_center)
	_update_hud()


func _physics_process(delta: float) -> void:
	elapsed_simulation_time += delta
	_maintain_requested_ships(delta)
	if ships.is_empty():
		return
	var center: Vector3 = _fleet_center()
	# La progression ne recule pas si la perte d'un survivant déplace légèrement le barycentre.
	distance_travelled = maxf(distance_travelled, _origin_z - center.z)
	_update_difficulty()
	if not demonstration.is_guided():
		_maintain_drones(center, delta)
		_maintain_interceptors(center, delta)
		_maintain_capitals(center, delta)
	maximum_artillery_projectiles = maxi(maximum_artillery_projectiles, get_tree().get_nodes_in_group("artillery_projectiles").size())
	for ship: BlueShip in ships:
		if ship.projectile_avoidance_active:
			projectile_dodge_ticks += 1
		if ship.moving_asteroid_threat_count > 0:
			moving_asteroid_avoidance_ticks += 1
	maximum_active_projectiles = maxi(maximum_active_projectiles, projectile_container.get_child_count())
	_update_action_intensity(center, delta)
	if streaming_enabled:
		var z_bounds: Vector2 = _fleet_z_bounds()
		var cleanup_rear: float = z_bounds.y
		for drone: PatrolDrone in drones:
			cleanup_rear = maxf(cleanup_rear, drone.global_position.z)
		for interceptor: Interceptor in interceptors:
			cleanup_rear = maxf(cleanup_rear, interceptor.global_position.z)
		for capital: CapitalShip in capitals:
			cleanup_rear = maxf(cleanup_rear, capital.global_position.z + 38)
		asteroid_container.advance(center, z_bounds.x, cleanup_rear)
	_measurement_timer += delta
	if _measurement_timer >= maxf(metrics_update_interval, 0.1):
		_measure_group(center)
		_update_hud()
		_measurement_timer = 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("guided_demo_toggle"):
		demonstration.toggle()
		get_viewport().set_input_as_handled()
		return
	# Les raccourcis de démonstration restent disponibles quand un contrôle est utilisé.
	if event.is_action_pressed("demo_panel_toggle"):
		demo_controls.toggle_panel()
		camera.cancel_orbit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("camera_help_toggle"):
		demo_controls.toggle_help()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("presentation_fullscreen"):
		presentation_window.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if demonstration.is_guided():
		return
	var actions: Array[String] = ["difficulty_auto", "difficulty_easy", "difficulty_medium", "difficulty_hard"]
	for level: int in range(actions.size()):
		if event.is_action_pressed(actions[level]):
			set_difficulty_mode(level)
			get_viewport().set_input_as_handled()
			return


func set_difficulty_mode(level: int) -> void:
	manual_difficulty = clampi(level, 0, 3)
	_update_difficulty()
	_update_hud()


func _update_difficulty() -> void:
	difficulty_level = manual_difficulty if manual_difficulty > 0 else asteroid_container.difficulty_for_distance(distance_travelled)
	asteroid_container.difficulty_override = manual_difficulty
	demo_controls.update_level(difficulty_level)


func target_drone_count() -> int:
	if not drones_enabled:
		return 0
	if manual_drone_count_override >= 0:
		return clampi(manual_drone_count_override, 0, 8)
	var counts: Array[int] = [easy_drone_count, intermediate_drone_count, hard_drone_count]
	return clampi(counts[difficulty_level - 1], 0, 3)


func _retire_drone(drone: PatrolDrone) -> void:
	drones.erase(drone)
	drone.retire()
	drone_retired_count += 1


func _maintain_drones(center: Vector3, delta: float) -> void:
	_replacement_timer = maxf(_replacement_timer - delta, 0.0)
	var rear_z: float = _fleet_z_bounds().y
	for drone: PatrolDrone in drones.duplicate():
		if drone.global_position.z <= rear_z + maxf(drone_retire_distance, 70.0):
			continue
		_retire_drone(drone)
		_replacement_timer = maxf(drone_replacement_delay, 0.0)
	# Un niveau plus bas retire les excédents sans mort ni score.
	while drones.size() > target_drone_count():
		_retire_drone(drones.back())
	if _replacement_timer > 0.0 or ships.is_empty():
		return
	while drones.size() < target_drone_count():
		if not _spawn_drone(center, _fleet_z_bounds().x):
			_replacement_timer = 1.0
			break
		if manual_drone_count_override >= 0:
			_replacement_timer = maxf(demo_spawn_interval, 0.3)
			break


func _spawn_drone(center: Vector3, front_z: float) -> bool:
	var position_candidate: Vector3 = Vector3.ZERO
	var clear: bool = false
	for _attempt: int in range(64):
		position_candidate = Vector3(center.x + _drone_random.randf_range(-32.0, 32.0), center.y + _drone_random.randf_range(-18.0, 18.0), front_z - maxf(drone_spawn_ahead_distance, 80.0) - _drone_random.randf_range(0.0, 45.0))
		clear = true
		for node: Node in get_tree().get_nodes_in_group("asteroids"):
			var obstacle: SpaceAsteroid = node as SpaceAsteroid
			if position_candidate.distance_to(obstacle.global_position) < obstacle.avoidance_radius + PatrolDrone.BODY_CLEARANCE + 8.0:
				clear = false
				break
		for other: PatrolDrone in drones:
			if position_candidate.distance_to(other.global_position) < 12.0:
				clear = false
		for other: Interceptor in interceptors:
			if position_candidate.distance_to(other.global_position) < 12.0:
				clear = false
		for other: CapitalShip in capitals:
			if position_candidate.distance_to(other.global_position) < CapitalShip.BODY_CLEARANCE + 8:
				clear = false
		if clear:
			break
	if not clear:
		return false
	var drone: PatrolDrone = DRONE_SCENE.instantiate() as PatrolDrone
	drone.name = "PatrolDrone_%03d" % drone_spawn_count
	drone.individual_seed = simulation_seed + 51001 + drone_spawn_count * 401
	drone.forward_speed = 9.2 + float(drone_spawn_count % 2) * 0.6
	drone.patrol_anchor = Vector2(center.x, center.y)
	drone.position = drone_container.to_local(position_candidate)
	drone.died.connect(_on_drone_died)
	drone.destroyed.connect(_on_hostile_destroyed)
	drone.patrol_projectile_container = projectile_container
	drone.fire_intensity = fire_intensity
	drone.patrol_fired.connect(_on_enemy_fired)
	drone_container.add_child(drone)
	drones.append(drone)
	drone_spawn_count += 1
	return true


func _on_hostile_destroyed(drone: PatrolDrone) -> void:
	if drones.has(drone):
		drones_destroyed += 1
		enemies_destroyed += 1
		_update_hud()
	elif interceptors.has(drone):
		interceptors_destroyed += 1
		enemies_destroyed += 1
		_update_hud()


func target_interceptor_count() -> int:
	if not interceptors_enabled:
		return 0
	if manual_interceptor_count_override >= 0:
		return clampi(manual_interceptor_count_override, 0, 8)
	var counts: Array[int] = [easy_interceptor_count, intermediate_interceptor_count, hard_interceptor_count]
	return clampi(counts[difficulty_level - 1], 0, 2)


func _retire_interceptor(interceptor: Interceptor) -> void:
	interceptors.erase(interceptor)
	interceptor.remove_from_group("interceptors")
	interceptor.target = null
	interceptor.retire()
	interceptor_retired_count += 1


func _maintain_interceptors(center: Vector3, delta: float) -> void:
	_interceptor_replacement_timer = maxf(_interceptor_replacement_timer - delta, 0.0)
	var rear_z: float = _fleet_z_bounds().y
	for interceptor: Interceptor in interceptors.duplicate():
		if interceptor.global_position.z > rear_z + maxf(interceptor_retire_distance, 70.0):
			_retire_interceptor(interceptor)
			_interceptor_replacement_timer = maxf(interceptor_replacement_delay, 0.0)
	while interceptors.size() > target_interceptor_count():
		_retire_interceptor(interceptors.back())
	if _interceptor_replacement_timer > 0.0 or ships.is_empty():
		return
	while interceptors.size() < target_interceptor_count():
		if not _spawn_interceptor(center, _fleet_z_bounds().x):
			_interceptor_replacement_timer = 1.0
			break
		if manual_interceptor_count_override >= 0:
			_interceptor_replacement_timer = maxf(demo_spawn_interval, 0.3)
			break


func _spawn_interceptor(center: Vector3, front_z: float) -> bool:
	var candidate: Vector3 = Vector3.ZERO
	var clear: bool = false
	for _attempt: int in range(64):
		var side: float = -1.0 if _interceptor_random.randf() < 0.5 else 1.0
		candidate = Vector3(center.x + side * _interceptor_random.randf_range(18.0, 38.0), center.y + _interceptor_random.randf_range(-18.0, 18.0), front_z - maxf(interceptor_spawn_ahead_distance, 80.0) - _interceptor_random.randf_range(0.0, 40.0))
		clear = true
		for node: Node in get_tree().get_nodes_in_group("asteroids"):
			var obstacle: SpaceAsteroid = node as SpaceAsteroid
			if candidate.distance_to(obstacle.global_position) < obstacle.avoidance_radius + PatrolDrone.BODY_CLEARANCE + 8.0:
				clear = false
				break
		for ship: BlueShip in ships:
			if candidate.distance_to(ship.global_position) < 25.0:
				clear = false
		for node: Node in get_tree().get_nodes_in_group("hostile_agents"):
			var hostile: Node3D = node as Node3D
			if candidate.distance_to(hostile.global_position) < _hostile_spawn_clearance(hostile):
				clear = false
		if clear:
			break
	if not clear:
		return false
	var interceptor: Interceptor = INTERCEPTOR_SCENE.instantiate() as Interceptor
	interceptor.name = "Interceptor_%03d" % interceptor_spawn_count
	interceptor.individual_seed = simulation_seed + 71003 + interceptor_spawn_count * 409
	interceptor.combat_enabled = combat_enabled
	interceptor.projectile_container = projectile_container
	interceptor.fire_intensity = fire_intensity
	interceptor.position = interceptor_container.to_local(candidate)
	interceptor.died.connect(_on_interceptor_died)
	interceptor.destroyed.connect(_on_hostile_destroyed)
	interceptor.fired.connect(_on_enemy_fired)
	interceptor_container.add_child(interceptor)
	interceptors.append(interceptor)
	interceptor_spawn_count += 1
	return true


func _on_interceptor_died(hostile: PatrolDrone) -> void:
	var interceptor: Interceptor = hostile as Interceptor
	if not interceptors.has(interceptor):
		return
	interceptors.erase(interceptor)
	interceptor_death_count += 1
	_interceptor_replacement_timer = maxf(interceptor_replacement_delay, 0.0)


func _on_enemy_fired(projectile: EnemyLaser) -> void:
	enemy_shots_fired += 1
	projectile.hit_blue_ship.connect(_on_blue_ship_hit)
	maximum_active_projectiles = maxi(maximum_active_projectiles, projectile_container.get_child_count())


func target_capital_count() -> int:
	if not capital_ships_enabled:
		return 0
	if manual_capital_count_override >= 0:
		if demonstration.is_guided():
			return manual_capital_count_override
		return clampi(manual_capital_count_override, 0, 1)
	return 1 if difficulty_level == 3 else 0


func set_capital_count_override(value: int) -> void:
	manual_capital_count_override = clampi(value, 0, 1)
	# Un override n'écourte pas le délai suivant une destruction.
	demo_controls.refresh(self)


func _maintain_capitals(center: Vector3, delta: float) -> void:
	_capital_replacement_timer = maxf(_capital_replacement_timer - delta, 0)
	while capitals.size() > target_capital_count():
		var ship: CapitalShip = capitals.pop_back()
		ship.retire()
	if capitals.size() >= target_capital_count() or _capital_replacement_timer > 0 or ships.is_empty():
		return
	for _attempt: int in range(96):
		var candidate: Vector3 = center + Vector3(_capital_random.randf_range(-60, 60), _capital_random.randf_range(-35, 40), -190)
		var clear: bool = true
		for node: Node in get_tree().get_nodes_in_group("asteroids"):
			var obstacle: SpaceAsteroid = node as SpaceAsteroid
			if candidate.distance_to(obstacle.global_position) < obstacle.avoidance_radius + CapitalShip.BODY_CLEARANCE + 8:
				clear = false
				break
		for node: Node in get_tree().get_nodes_in_group("hostile_agents"):
			if candidate.distance_to((node as Node3D).global_position) < 55:
				clear = false
		if not clear:
			continue
		var capital: CapitalShip = CAPITAL_SCENE.instantiate() as CapitalShip
		capital.individual_seed = simulation_seed + 151003 + capital_spawn_count * 419
		capital.combat_enabled = combat_enabled
		capital.projectile_container = projectile_container
		capital.fire_intensity = fire_intensity
		capital.position = capital_container.to_local(candidate)
		capital.destroyed.connect(_on_capital_destroyed)
		capital.salvo_started.connect(func(pattern: int) -> void: capital_salvos[pattern] += 1)
		capital.fired.connect(_on_artillery_fired)
		capital_container.add_child(capital)
		capitals.append(capital)
		capital_spawn_count += 1
		return
	_capital_replacement_timer = 1 # Volume encombré : réessayer sans apparition dangereuse.


func _on_artillery_fired(projectile: ArtilleryProjectile) -> void:
	enemy_shots_fired += 1
	projectile.hit_blue_ship.connect(func(ship: BlueShip, amount: int) -> void:
		artillery_hits += 1
		_on_blue_ship_hit(ship, amount))
	projectile.impacted.connect(func(obstacle: bool) -> void:
		if obstacle:
			artillery_obstacle_hits += 1)


func _on_capital_destroyed(ship: CapitalShip) -> void:
	if not capitals.has(ship):
		return
	capitals.erase(ship)
	capitals_destroyed += 1
	enemies_destroyed += 1
	_capital_replacement_timer = maxf(capital_replacement_delay, 20)
	_update_hud()


func _on_blue_ship_hit(_ship: BlueShip, _amount: int) -> void:
	blue_ship_hits += 1


func _on_projectile_dodge_started() -> void:
	projectile_dodge_count += 1


func _on_ship_fired(projectile: BlueLaser) -> void:
	blue_shots_fired += 1
	projectile.hit_hostile.connect(_on_hostile_hit)
	maximum_active_projectiles = maxi(maximum_active_projectiles, projectile_container.get_child_count())


func _on_hostile_hit(_target: Node3D, _amount: int) -> void:
	hostile_hits += 1


func _on_drone_died(drone: PatrolDrone) -> void:
	if not drones.has(drone):
		return
	drones.erase(drone)
	drone_death_count += 1
	_replacement_timer = maxf(drone_replacement_delay, 0.0)
	_update_hud()


func _process(delta: float) -> void:
	var center: Vector3 = _fleet_center()
	_update_camera(center, delta)
	space_decor.recycle_stars(camera.global_position, delta, simulation_speed_multiplier, camera.group_velocity)


func _create_ships() -> void:
	for _index: int in range(maxi(ship_count, 0)):
		_add_ship(_random_ship_position())
	initial_agent_count = ships.size()
	living_agent_count = initial_agent_count
	target_ship_count = living_agent_count


func _add_ship(local_position: Vector3) -> void:
	var ship: BlueShip = SHIP_SCENE.instantiate() as BlueShip
	ship.name = "BlueShip_%02d" % (ship_spawn_count + 1)
	ship.individual_seed = simulation_seed + (ship_spawn_count + 1) * 997
	ship.combat_enabled = combat_enabled
	ship.projectile_container = projectile_container
	ship.demo_movement_multiplier = movement_multiplier
	ship.demo_spacing_multiplier = spacing_multiplier
	ship.position = local_position
	ship.died.connect(_on_ship_died)
	ship.fired.connect(_on_ship_fired)
	ship.projectile_dodge_started.connect(_on_projectile_dodge_started)
	ship.moving_asteroid_dodge_started.connect(func() -> void: moving_asteroid_dodge_count += 1)
	ship_container.add_child(ship)
	ships.append(ship)
	ship_spawn_count += 1
	living_agent_count = ships.size()


func set_simulation_speed(value: float) -> void:
	simulation_speed_multiplier = clampf(value, 0.5, 2.5)
	# Multiples de 60 : petits pas physiques et cadence régulière sur une vue à 60 Hz.
	var base_rate: int = maxi(_previous_physics_rate, 60)
	Engine.physics_ticks_per_second = maxi(base_rate, int(ceil(float(base_rate) * simulation_speed_multiplier / 60.0)) * 60)
	Engine.time_scale = simulation_speed_multiplier
	if is_instance_valid(demo_controls):
		demo_controls.refresh(self)


func set_rock_density(value: float) -> void:
	rock_density = clampf(value, 0.5, 2.5)
	asteroid_container.density_multiplier = rock_density
	demo_controls.refresh(self)


func set_fire_intensity(value: float) -> void:
	fire_intensity = clampf(value, 0.5, 3.0)
	for drone: PatrolDrone in drones:
		drone.fire_intensity = fire_intensity
	for hostile: Interceptor in interceptors:
		hostile.fire_intensity = fire_intensity
	for capital: CapitalShip in capitals:
		capital.fire_intensity = fire_intensity
	demo_controls.refresh(self)


func set_movement_multiplier(value: float) -> void:
	movement_multiplier = clampf(value, 0.5, 2.0)
	for ship: BlueShip in ships:
		ship.demo_movement_multiplier = movement_multiplier
	demo_controls.refresh(self)


func set_spacing_multiplier(value: float) -> void:
	spacing_multiplier = clampf(value, 0.8, 1.4)
	for ship: BlueShip in ships:
		ship.demo_spacing_multiplier = spacing_multiplier
	demo_controls.refresh(self)


func set_ship_count(value: int) -> void:
	target_ship_count = clampi(value, 5, 20)
	while ships.size() > target_ship_count:
		var ship: BlueShip = ships.back()
		ships.erase(ship)
		ship.retire()
		ship_retired_count += 1
	living_agent_count = ships.size()
	_ship_add_timer = 0.0
	_measure_group(_fleet_center())
	_update_hud()


func _maintain_requested_ships(delta: float) -> void:
	_ship_add_timer = maxf(_ship_add_timer - delta, 0.0)
	if ships.size() >= target_ship_count or _ship_add_timer > 0.0:
		return
	var center: Vector3 = _fleet_center()
	var rear_z: float = _fleet_z_bounds().y
	for _attempt: int in range(96):
		var candidate: Vector3 = Vector3(center.x + _ship_spawn_random.randf_range(-22.0, 22.0), center.y + _ship_spawn_random.randf_range(-14.0, 14.0), rear_z + _ship_spawn_random.randf_range(10.0, 22.0))
		if not _runtime_ship_position_is_clear(candidate):
			continue
		_add_ship(ship_container.to_local(candidate))
		_ship_add_timer = maxf(demo_spawn_interval, 0.3)
		_update_hud()
		return
	_ship_add_timer = 0.5 # Réessayer plus tard si le volume est encombré.


func _runtime_ship_position_is_clear(candidate: Vector3) -> bool:
	for ship: BlueShip in ships:
		if candidate.distance_to(ship.global_position) < maxf(initial_ship_spacing, 7.0 * spacing_multiplier + 1.5):
			return false
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var obstacle: SpaceAsteroid = node as SpaceAsteroid
		if candidate.distance_to(obstacle.global_position) < obstacle.avoidance_radius + BlueShip.SHIP_CLEARANCE + 3.0:
			return false
	for node: Node in get_tree().get_nodes_in_group("hostile_agents"):
		var hostile: Node3D = node as Node3D
		if candidate.distance_to(hostile.global_position) < _hostile_spawn_clearance(hostile):
			return false
	return true


func _hostile_spawn_clearance(hostile: Node3D) -> float:
	var radius: Variant = hostile.get("body_clearance")
	return maxf(12, float(radius) + 8) if radius != null else 12.0


func set_drone_count_override(value: int) -> void:
	manual_drone_count_override = clampi(value, 0, 8)
	_replacement_timer = 0.0
	demo_controls.refresh(self)


func set_interceptor_count_override(value: int) -> void:
	manual_interceptor_count_override = clampi(value, 0, 8)
	_interceptor_replacement_timer = 0.0
	demo_controls.refresh(self)


func reset_population_overrides() -> void:
	manual_drone_count_override = -1
	manual_interceptor_count_override = -1
	manual_capital_count_override = -1
	demo_controls.refresh(self)


func apply_action_preset() -> void:
	set_difficulty_mode(3)
	set_simulation_speed(DEFAULT_DEMO_SPEED)
	set_movement_multiplier(1.3)
	set_spacing_multiplier(1.0)
	set_ship_count(15)
	set_drone_count_override(5)
	set_interceptor_count_override(4)
	set_capital_count_override(1)
	camera.set_mode(SimulationCamera.Mode.CINEMATIC)
	demo_controls.refresh(self)


func apply_normal_preset() -> void:
	set_simulation_speed(DEFAULT_DEMO_SPEED)
	set_movement_multiplier(DEFAULT_MOVEMENT)
	set_spacing_multiplier(1.0)
	reset_population_overrides()
	camera.set_mode(SimulationCamera.Mode.FOLLOW)
	demo_controls.refresh(self)


func _update_action_intensity(center: Vector3, delta: float) -> void:
	var activity: float = float(projectile_container.get_child_count()) * 0.035
	for ship: BlueShip in ships:
		if ship.behavior_state == BlueShip.BehaviorState.AVOIDANCE:
			activity += 0.045
	for node: Node in get_tree().get_nodes_in_group("hostile_agents"):
		var hostile: Node3D = node as Node3D
		if hostile.global_position.distance_to(center) < 70.0:
			activity += 0.06
	activity += get_tree().get_nodes_in_group("explosions").size() * 0.12
	activity += get_tree().get_nodes_in_group("capital_explosions").size() * 0.16
	for node: Node in get_tree().get_nodes_in_group("artillery_projectiles"):
		var projectile: ArtilleryProjectile = node as ArtilleryProjectile
		if projectile.global_position.distance_to(center) < 65:
			activity += 0.10 if projectile.kind == ArtilleryProjectile.Kind.HEAVY_SHOT else 0.07 if projectile.kind == ArtilleryProjectile.Kind.SEEKER_SALVO else 0.025
	action_intensity = lerpf(action_intensity, clampf(activity, 0.0, 1.0), 1.0 - exp(-3.0 * delta))


func _exit_tree() -> void:
	if _engine_settings_owned:
		Engine.time_scale = _previous_time_scale
		Engine.physics_ticks_per_second = _previous_physics_rate


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
	# Les pertes ne sont jamais remplacées automatiquement par la consigne du panneau.
	target_ship_count = maxi(target_ship_count - 1, 0)
	living_agent_count = ships.size()
	_measure_group(_fleet_center())
	_update_hud()


func _update_hud() -> void:
	statistics.text = "Vaisseaux détruits : %d" % death_count
	demo_controls.refresh(self)


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
	var positions: Array[Vector3] = []
	var mean_velocity: Vector3 = Vector3.ZERO
	for ship: BlueShip in ships:
		if is_instance_valid(ship) and ship.alive:
			spread = maxf(spread, center.distance_to(ship.global_position))
			positions.append(ship.global_position)
			mean_velocity += ship.velocity
	mean_velocity /= maxf(positions.size(), 1.0)
	camera.capital_preparing = false
	for capital: CapitalShip in capitals:
		if capital.state == CapitalShip.State.PREPARE and capital.selected_pattern == CapitalShip.ArtilleryPattern.HEAVY_SHOT:
			camera.capital_preparing = true
			camera.capital_focus = capital.global_position
	camera.observe_group(center, spread, delta, positions, action_intensity, mean_velocity, simulation_speed_multiplier)
