class_name GuidedDemonstration
extends Node

signal mode_changed(mode: int)
signal phase_changed(index: int)
signal completed

enum DemoMode { FREE, GUIDED }
const TITLES: Array[String] = ["TEMPÊTE DE MÉTÉORES", "ASTÉROÏDES ORBITAUX", "DRONES DE PATROUILLE", "INTERCEPTEURS", "FLOTTE D'ARTILLERIE", "ASSAUT FINAL"]
const GAME_GROUPS: Array[String] = ["blue_ships", "asteroids", "patrol_drones", "interceptors", "capital_ships", "hostile_agents", "blue_lasers", "hostile_projectiles", "artillery_projectiles", "explosions", "capital_explosions", "combat_hazards"]

@export var demo_phase_duration: float = 15.0
@export var capital_phase_duration: float = 20.0
@export var finale_phase_duration: float = 20.0
@export var finale_relief_duration: float = 5.0
@export var spectacle_phase_duration: float = 18.0
@export var spectacle_capital_duration: float = 28.0
@export var spectacle_finale_duration: float = 30.0
@export var demonstration_seed: int = 20261012
var game_over: bool = false
var mode: DemoMode = DemoMode.FREE
var phase_index: int = -1
var phase_elapsed: float = 0
var elapsed_real: float = 0
var phase_results: Array[Dictionary] = []
var last_duration: float = 0
var _saved: Array[Dictionary] = []
var _saved_roots: Array[Dictionary] = []
var _saved_colliders: Array[Dictionary] = []
var _saved_root_ids: Dictionary[int, bool] = {}
var _markers: Node3D
var _phase_sample: Dictionary = {}
var _marker_drones: Array[PatrolDrone] = []
var _marker_nodes: Array[MeshInstance3D] = []
var tracers: BattleTracers
var bomb_explosions: int = 0
var grid_activations: int = 0
var curtain_activations: int = 0
var missile_count: int = 0
var _arrived_ids: Dictionary[int, bool] = {}
var _phase_deaths: int = 0
var _ui_visibility: Vector2i
var _camera_transform: Transform3D
var _camera_fov: float

@onready var simulation: SpaceSimulation = get_parent() as SpaceSimulation


func _ready() -> void:
	process_priority = -10


func is_guided() -> bool:
	return mode == DemoMode.GUIDED


func toggle() -> void:
	if is_guided():
		stop()
	else:
		start()


func spectacle() -> bool:
	return not simulation.demonstration_legacy_fixture


func phase_duration(index: int) -> float:
	if spectacle():
		return spectacle_capital_duration if index == 4 else spectacle_finale_duration if index == 5 else spectacle_phase_duration
	return maxf(capital_phase_duration if index == 4 else finale_phase_duration if index == 5 else demo_phase_duration, 1)


func start() -> void:
	if is_guided():
		restart()
		return
	_save_free_scene()
	mode = DemoMode.GUIDED
	game_over = false
	simulation.demo_controls.show_game_over(false)
	phase_results.clear()
	elapsed_real = 0
	simulation.simulation_seed = demonstration_seed
	simulation.distance_travelled = 0
	simulation.elapsed_simulation_time = 0
	simulation.death_count = 0
	simulation.reset_threat_metrics()
	simulation.blue_ship_hits = 0
	simulation.ship_spawn_count = 0
	simulation.ship_retired_count = 0
	simulation.blue_shots_fired = 0
	simulation.enemy_shots_fired = 0
	simulation.projectile_dodge_count = 0
	simulation.moving_asteroid_dodge_count = 0
	simulation.capital_salvos.assign([0, 0, 0, 0, 0, 0, 0, 0, 0, 0] if spectacle() else [0, 0, 0, 0, 0])
	simulation.maximum_active_projectiles = 0
	simulation.maximum_artillery_projectiles = 0
	simulation.capitals_destroyed = 0
	simulation.enemies_destroyed = 0
	simulation.artillery_hits = 0
	simulation.artillery_obstacle_hits = 0
	simulation._last_center = Vector3.ZERO
	simulation._origin_z = 0
	simulation.camera.initialize_view(Vector3.ZERO, demonstration_seed)
	simulation.demo_controls.panel.hide()
	simulation.demo_controls.help_panel.hide()
	_begin_phase(0, Vector3.ZERO)
	mode_changed.emit(mode)


func restart() -> void:
	if is_guided():
		stop()
	start()


func stop() -> void:
	if not is_guided():
		return
	game_over = false
	simulation.demo_controls.show_game_over(false)
	last_duration = elapsed_real
	_clear_stage()
	mode = DemoMode.FREE
	phase_index = -1
	for item: Dictionary in _saved_roots:
		var entity: Node3D = item.node
		if is_instance_valid(entity):
			entity.process_mode = item.process_mode
			entity.visible = item.visible
	for item: Dictionary in _saved_colliders:
		var node: Node = item.node
		if not is_instance_valid(node):
			continue
		for group: String in item.groups:
			node.add_to_group(group)
		if node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = item.layer
			(node as CollisionObject3D).collision_mask = item.mask
	for item: Dictionary in _saved:
		_restore_properties(item.object, item.properties)
	_saved.clear()
	_saved_roots.clear()
	_saved_colliders.clear()
	_saved_root_ids.clear()
	simulation.set_simulation_speed(simulation.simulation_speed_multiplier)
	simulation.camera.global_transform = _camera_transform
	simulation.camera.fov = _camera_fov
	simulation.demo_controls.panel.visible = bool(_ui_visibility.x)
	simulation.demo_controls.help_panel.visible = bool(_ui_visibility.y)
	simulation.demo_controls.set_phase(-1, "")
	simulation._update_hud()
	mode_changed.emit(mode)


func _stage_containers() -> Array[Node3D]:
	return [simulation.ship_container, simulation.asteroid_container, simulation.drone_container, simulation.interceptor_container, simulation.capital_container, simulation.projectile_container]


func _save_free_scene() -> void:
	_camera_transform = simulation.camera.global_transform
	_camera_fov = simulation.camera.fov
	_ui_visibility = Vector2i(int(simulation.demo_controls.panel.visible), int(simulation.demo_controls.help_panel.visible))
	for object: Object in [simulation, simulation.asteroid_container, simulation.camera]:
		_saved.append({"object": object, "properties": _capture_properties(object)})
	for container: Node3D in _stage_containers():
		for entity: Node in container.get_children():
			if entity.is_queued_for_deletion():
				continue
			_saved_roots.append({"node": entity, "process_mode": entity.process_mode, "visible": (entity as Node3D).visible})
			_saved_root_ids[entity.get_instance_id()] = true
			_save_entity(entity)
			# Garder le parent évite tree_exiting et conserve les cibles/mémoires SMA.
			(entity as Node3D).hide()
			entity.process_mode = Node.PROCESS_MODE_DISABLED
	simulation.ships.clear()
	simulation.drones.clear()
	simulation.interceptors.clear()
	simulation.capitals.clear()
	simulation.asteroid_container.configurations.clear()


func _save_entity(node: Node) -> void:
	var groups: Array[String] = []
	for group: String in GAME_GROUPS:
		if node.is_in_group(group):
			groups.append(group)
			node.remove_from_group(group)
	var item: Dictionary = {"node": node, "groups": groups}
	if node is CollisionObject3D:
		item.layer = (node as CollisionObject3D).collision_layer
		item.mask = (node as CollisionObject3D).collision_mask
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	_saved_colliders.append(item)
	for child: Node in node.get_children():
		_save_entity(child)


func _capture_properties(object: Object) -> Dictionary:
	var properties: Dictionary = {}
	for info: Dictionary in object.get_property_list():
		if (int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = object.get(info.name)
		if value is RandomNumberGenerator:
			properties[info.name] = {"rng_state": (value as RandomNumberGenerator).state, "rng_seed": (value as RandomNumberGenerator).seed}
		elif typeof(value) != TYPE_OBJECT:
			properties[info.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return properties


func _restore_properties(object: Object, properties: Dictionary) -> void:
	for key: String in properties:
		var value: Variant = properties[key]
		if object.get(key) is RandomNumberGenerator:
			var random: RandomNumberGenerator = object.get(key) as RandomNumberGenerator
			random.seed = value.rng_seed
			random.state = value.rng_state
		else:
			object.set(key, value)


func _clear_stage() -> void:
	simulation.ship_retired_count += simulation.ships.size()
	for container: Node3D in _stage_containers():
		for entity: Node in container.get_children():
			if _saved_root_ids.has(entity.get_instance_id()):
				continue
			_disable_entity(entity)
			entity.queue_free()
	simulation.ships.clear()
	simulation.drones.clear()
	simulation.interceptors.clear()
	simulation.capitals.clear()
	var field: ObstacleField = simulation.asteroid_container
	field.configurations.clear()
	field.active_asteroid_count = 0
	field.active_mobile_count = 0
	field.maximum_active_observed = 0
	field.maximum_mobile_observed = 0
	field.generated_configuration_count = 0
	field.removed_configuration_count = 0
	field.motions_generated.clear()
	field.patterns_generated.clear()
	if is_instance_valid(_markers):
		_markers.queue_free()
	_markers = null
	_marker_drones.clear()
	_marker_nodes.clear()


func _disable_entity(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for group: String in GAME_GROUPS:
		node.remove_from_group(group)
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is Node3D:
		(node as Node3D).hide()
	for child: Node in node.get_children():
		_disable_entity(child)


func _begin_phase(index: int, center: Vector3) -> void:
	_clear_stage()
	phase_index = index
	phase_elapsed = 0
	_phase_deaths = simulation.death_count
	simulation.manual_difficulty = 3
	simulation.streaming_enabled = index in [0, 1, 5] if spectacle() else index == 5
	simulation.drones_enabled = true
	simulation.interceptors_enabled = true
	simulation.capital_ships_enabled = true
	simulation.combat_enabled = index >= 3
	simulation.set_simulation_speed((1.9 if simulation.legacy_flight_profile else simulation.guided_simulation_speed) if spectacle() else 1.7)
	simulation.set_movement_multiplier((1.6 if index == 5 else 1.35 if index in [2, 3] else 1.5) if spectacle() else 1.3 if index == 5 else 1.2)
	simulation.set_spacing_multiplier(1.05 if index == 5 else 1.0)
	simulation.manual_drone_count_override = 5 if index == 5 else 4 if index == 2 else 0
	simulation.manual_interceptor_count_override = (5 if spectacle() else 4) if index in [3, 5] else 0
	simulation.manual_capital_count_override = (5 if index == 4 else 4) if spectacle() and index in [4, 5] else 1 if index in [4, 5] else 0
	for ship_index: int in range(15):
		var offset: Vector3 = Vector3((ship_index % 3 - 1) * 9.5, (ship_index / 3 % 3 - 1) * 9.5, (ship_index / 9) * 12 + (ship_index % 3) * 2)
		if index == 5 and ship_index >= 13:
			# Deux voisins restent dans la portée de récupération, sans consigne de vol.
			offset = Vector3(45, 15, 10) if ship_index == 13 else Vector3(-45, -15, 10)
		simulation._add_ship(simulation.ship_container.to_local(center + offset))
		if spectacle():
			simulation.ships.back().environment_perception_interval = 0.05 if simulation.legacy_flight_profile else 0.06
	simulation.target_ship_count = 15
	simulation.living_agent_count = 15
	if not simulation.legacy_flight_profile:
		simulation.initial_agent_count = 15
	simulation._last_center = simulation._fleet_center()
	var field: ObstacleField = simulation.asteroid_container
	field.max_active_asteroids = 180 if spectacle() else 160 if index == 0 else 96
	field.storm_enabled = spectacle() and index in [0, 1, 5]
	field.storm_complex = index == 1
	field.storm_target = 84 if index == 1 else (150 if simulation.legacy_flight_profile else 110) if index == 5 else 180
	bomb_explosions = 0
	grid_activations = 0
	curtain_activations = 0
	missile_count = 0
	_arrived_ids.clear()
	tracers = null
	field.initialize_field(demonstration_seed + index * 1091, center, simulation._fleet_z_bounds().x)
	field.difficulty_override = 3
	if field.storm_enabled or index == 5:
		field.advance(center, simulation._fleet_z_bounds().x, simulation._fleet_z_bounds().y)
	elif index != 4:
		field.create_demonstration_field(index, center, demonstration_seed + index * 1091)
	for count: int in range(simulation.manual_drone_count_override):
		_spawn_patrol(center, count, index == 2)
	for count: int in range(simulation.manual_interceptor_count_override):
		_spawn_interceptor(center, count)
	if index in [4, 5]:
		for capital_index: int in range(simulation.manual_capital_count_override):
			_spawn_capital(center, index == 4, capital_index)
		if spectacle():
			tracers = BattleTracers.new()
			tracers.name = "DecorativeBattleTracers"
			tracers.rate = 90 if simulation.legacy_flight_profile else 30
			simulation.projectile_container.add_child(tracers)
	_set_camera_phase(index)
	simulation._measure_group(simulation._fleet_center())
	simulation._update_hud()
	if not simulation.legacy_flight_profile:
		simulation.set_fire_intensity(1.2 if index == 5 else 1.0)
	simulation.demo_controls.set_phase(index, TITLES[index])
	_phase_sample = {"phase": index + 1, "title": TITLES[index], "nodes_max": get_tree().get_node_count(), "projectiles_max": 0, "asteroids_max": field.active_asteroid_count, "dispersion_max": 0.0, "regroup_episodes": 0, "regrouping": {}, "lateral_excursion": 0.0, "origin": center, "green_shots": 0, "waypoints": 0, "routes": 0, "pursuits": 0, "disengagements": 0, "dodges_start": simulation.projectile_dodge_count, "blue_shots_start": simulation.blue_shots_fired, "enemy_shots_start": simulation.enemy_shots_fired, "salvos_start": simulation.capital_salvos.duplicate()}
	_phase_sample.metrics_start = simulation.threat_metrics()
	_phase_sample.initial_positions = {}
	for ship: BlueShip in simulation.ships:
		_phase_sample.initial_positions[ship.get_instance_id()] = ship.global_position
	phase_changed.emit(index)


func _safe_position(candidate: Vector3, clearance: float) -> Vector3:
	for _attempt: int in range(64):
		var safe: bool = true
		for node: Node in get_tree().get_nodes_in_group("asteroids"):
			var rock: SpaceAsteroid = node as SpaceAsteroid
			if candidate.distance_to(rock.global_position) < clearance + rock.avoidance_radius + 5:
				safe = false
				break
		if safe:
			return candidate
		candidate += Vector3(12 if candidate.x >= 0 else -12, 9, -4)
	return candidate


func _spawn_patrol(center: Vector3, index: int, markers: bool) -> void:
	var drone: PatrolDrone = SpaceSimulation.DRONE_SCENE.instantiate() as PatrolDrone
	drone.individual_seed = demonstration_seed + phase_index * 1091 + index * 401
	drone.demonstration_route = markers
	drone.patrol_fire_enabled = true
	drone.dangerous_projectile_limit = (54 if phase_index == 5 else 90) if spectacle() else 50
	drone.environment_perception_interval = (0.05 if simulation.legacy_flight_profile else 0.06) if spectacle() else 0
	drone.patrol_anchor = Vector2(center.x + (index - 1.5) * 9, center.y)
	drone.patrol_projectile_container = simulation.projectile_container
	var offset: Vector3 = Vector3((index - 1.5) * 12, -8 if index % 2 == 0 else 8, -42 - index * 12)
	if phase_index == 5:
		var starts: Array[Vector3] = [Vector3(-9.5, -9.5, -34), Vector3(0, 0, -34), Vector3(9.5, 9.5, -34), Vector3(-20, 8, -65), Vector3(20, -8, -80)]
		offset = starts[index]
	drone.position = simulation.drone_container.to_local(_safe_position(center + offset, 3))
	drone.died.connect(simulation._on_drone_died)
	drone.destroyed.connect(simulation._on_hostile_destroyed)
	drone.patrol_fired.connect(simulation._on_enemy_fired)
	if simulation.legacy_flight_profile:
		FlightTuning.legacy_actor(drone)
	simulation.drone_container.add_child(drone)
	simulation.drones.append(drone)
	if markers:
		_add_route_markers(drone)


func _spawn_interceptor(center: Vector3, index: int) -> void:
	var hostile: Interceptor = SpaceSimulation.INTERCEPTOR_SCENE.instantiate() as Interceptor
	hostile.individual_seed = demonstration_seed + phase_index * 1091 + index * 409
	hostile.projectile_container = simulation.projectile_container
	if spectacle():
		hostile.dangerous_projectile_limit = 54 if phase_index == 5 else 90
		hostile.environment_perception_interval = 0.05 if simulation.legacy_flight_profile else 0.06
		hostile.burst_size = 5
		hostile.burst_interval = 0.16
		hostile.burst_cooldown = 1.05
	hostile.position = simulation.interceptor_container.to_local(_safe_position(center + Vector3((index - 1.5) * 12, -6 if index % 2 == 0 else 6, 42), 3))
	hostile.died.connect(simulation._on_interceptor_died)
	hostile.destroyed.connect(simulation._on_hostile_destroyed)
	hostile.fired.connect(simulation._on_enemy_fired)
	if simulation.legacy_flight_profile:
		FlightTuning.legacy_actor(hostile)
	simulation.interceptor_container.add_child(hostile)
	simulation.interceptors.append(hostile)


func _spawn_capital(center: Vector3, teaching: bool, index: int = 0) -> void:
	var hostile: CapitalShip = SpaceSimulation.CAPITAL_SCENE.instantiate() as CapitalShip
	hostile.individual_seed = demonstration_seed + phase_index * 1091 + index * 431
	var positions: Array[Vector3] = [Vector3(-120, 35, -390), Vector3(-40, -58, -460), Vector3(58, 66, -515), Vector3(145, -12, -580), Vector3(12, 8, -630)]
	hostile.normal_distance = -positions[index].z if spectacle() else 230
	hostile.spectacle_enabled = spectacle()
	hostile.fleet_role = index if phase_index == 4 else [0, 1, 3, 4][index]
	hostile.fleet_offset = Vector2(positions[index].x, positions[index].y)
	hostile.artillery_limit = (60 if phase_index == 5 else 90) if spectacle() else 50
	hostile.demonstration_cycle = teaching and not spectacle()
	if teaching:
		hostile.demonstration_attack_order.assign([0, 1, 2, 3, 4])
	hostile.projectile_container = simulation.projectile_container
	hostile.position = simulation.capital_container.to_local(_safe_position(center + (positions[index] if spectacle() else Vector3(0, 5, -230)), CapitalShip.BODY_CLEARANCE))
	hostile.destroyed.connect(simulation._on_capital_destroyed)
	hostile.salvo_started.connect(func(pattern: int) -> void: simulation.capital_salvos[pattern] += 1)
	hostile.fired.connect(simulation._on_artillery_fired)
	hostile.fired.connect(func(projectile: ArtilleryProjectile) -> void:
		if projectile.kind == ArtilleryProjectile.Kind.MISSILE_SWARM:
			missile_count += 1
	)
	if simulation.legacy_flight_profile:
		FlightTuning.legacy_actor(hostile)
	simulation.capital_container.add_child(hostile)
	simulation.capitals.append(hostile)


func _set_camera_phase(index: int) -> void:
	var sequences: Array[Array] = [[SimulationCamera.Shot.CHASE, SimulationCamera.Shot.HIGH], [SimulationCamera.Shot.SIDE_LEFT, SimulationCamera.Shot.WIDE], [SimulationCamera.Shot.SIDE_RIGHT, SimulationCamera.Shot.CHASE], [SimulationCamera.Shot.CHASE], [SimulationCamera.Shot.WIDE], []]
	if spectacle():
		sequences = [[6, 7, 11, 3], [8, 11, 9, 5], [2, 7, 11, 0], [7, 11, 6, 2], [10, 8, 7, 10, 9], [10, 8, 11, 7, 9, 6]]
		simulation.camera.guided_spectacle = true
		simulation.camera._shot_duration = 4.5
	simulation.camera.guided_shots.assign(sequences[index])
	simulation.camera.guided_lock = true
	simulation.camera.cinematic_transition_time = 0.8
	simulation.camera.set_mode(SimulationCamera.Mode.CINEMATIC)
	simulation.camera.cinematic_shot = sequences[index][0] if not sequences[index].is_empty() else SimulationCamera.Shot.CHASE
	simulation.camera._sequence_index = 0
	simulation.camera._shot_time = 0


func _add_route_markers(drone: PatrolDrone) -> void:
	if _markers == null:
		_markers = Node3D.new()
		_markers.name = "PatrolRouteMarkers"
		simulation.add_child(_markers)
	_marker_drones.append(drone)
	for index: int in range(4):
		var marker: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.75
		sphere.height = 1.5
		sphere.radial_segments = 8
		sphere.rings = 4
		marker.mesh = sphere
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.2, 1, 0.45, 0.5)
		marker.material_override = material
		_markers.add_child(marker)
		_marker_nodes.append(marker)
		var label: Label3D = Label3D.new()
		label.text = ["A", "B", "C", "D"][index]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = 0.04
		label.modulate = Color(0.4, 1, 0.6)
		label.position.y = 1.4
		marker.add_child(label)


func _process(delta: float) -> void:
	if not is_guided() or game_over:
		return
	if simulation.ships.is_empty() and not simulation.legacy_flight_profile:
		end_squadron()
		return
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	phase_elapsed += real_delta
	elapsed_real += real_delta
	if simulation.legacy_flight_profile and phase_index == 5 and phase_elapsed >= phase_duration(5) - finale_relief_duration:
		# Une courte respiration laisse les tirs existants passer et la cohésion agir.
		for drone: PatrolDrone in simulation.drones:
			drone.patrol_fire_enabled = false
		for hostile: Interceptor in simulation.interceptors:
			hostile.combat_enabled = false
		for hostile: CapitalShip in simulation.capitals:
			hostile.combat_enabled = false
	for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
		if node.has_meta("sampled"):
			continue
		node.set_meta("sampled", true)
		var zone: ArtilleryZone = node as ArtilleryZone
		zone.damage_applied.connect(simulation._on_blue_ship_hit)
		zone.activated.connect(func() -> void:
			if zone.kind == ArtilleryZone.Kind.GRID:
				grid_activations += 1
			elif zone.kind == ArtilleryZone.Kind.CURTAIN:
				curtain_activations += 1
		)
		zone.detonated.connect(func() -> void: bomb_explosions += 1)
	_sample_phase()
	if phase_index in [0, 1, 2, 3] and not simulation.asteroid_container.storm_enabled:
		simulation.asteroid_container._cleanup_passed(simulation._fleet_z_bounds().y)
	_update_markers()
	if phase_elapsed >= phase_duration(phase_index) and (phase_index < 5 or simulation.legacy_flight_profile):
		_finish_phase()
		if phase_index == 5:
			stop()
			completed.emit()
		else:
			_begin_phase(phase_index + 1, simulation._fleet_center())


func _update_markers() -> void:
	for index: int in range(_marker_drones.size()):
		var drone: PatrolDrone = _marker_drones[index]
		for point: int in range(4):
			var marker: MeshInstance3D = _marker_nodes[index * 4 + point]
			marker.visible = is_instance_valid(drone) and drone.alive
			if marker.visible:
				marker.global_position = drone.route_waypoints[point]
				marker.scale = Vector3.ONE * (1.4 if point == drone.route_index - 1 else 0.7)


func _sample_phase() -> void:
	var metrics: Dictionary = simulation.threat_metrics()
	for key: String in metrics:
		_phase_sample[key] = int(metrics[key]) - int(_phase_sample.metrics_start[key])
	_phase_sample.nodes_max = maxi(_phase_sample.nodes_max, get_tree().get_node_count())
	_phase_sample.projectiles_max = maxi(_phase_sample.projectiles_max, ArtilleryZone.dangerous_count(get_tree()))
	_phase_sample.bombs = bomb_explosions
	_phase_sample.grids = grid_activations
	_phase_sample.curtains = curtain_activations
	_phase_sample.missiles = missile_count
	_phase_sample.mobile_max = simulation.asteroid_container.maximum_mobile_observed
	_phase_sample.speed_min = simulation.asteroid_container.storm_speed_min if simulation.asteroid_container.storm_enabled else 0
	_phase_sample.speed_max = simulation.asteroid_container.storm_speed_max
	_phase_sample.size_bins = simulation.asteroid_container.storm_size_bins.duplicate()
	_phase_sample.tracers_max = tracers.maximum_active if is_instance_valid(tracers) else 0
	_phase_sample.tracers_emitted = tracers.emitted if is_instance_valid(tracers) else 0
	_phase_sample.physical_projectiles_max = maxi(int(_phase_sample.get("physical_projectiles_max", 0)), get_tree().get_nodes_in_group("hostile_projectiles").size())
	var current_center: Vector3 = simulation._fleet_center()
	for node: Node in get_tree().get_nodes_in_group("artillery_projectiles"):
		if (node as Node3D).global_position.distance_to(current_center) < 65:
			_arrived_ids[node.get_instance_id()] = true
	_phase_sample.artillery_arrivals = _arrived_ids.size()
	_phase_sample.asteroids_max = maxi(_phase_sample.asteroids_max, simulation.asteroid_container.active_asteroid_count)
	_phase_sample.dispersion_max = maxf(_phase_sample.dispersion_max, simulation.dispersion)
	for ship: BlueShip in simulation.ships:
		var relative: Vector3 = ship.global_position - Vector3(_phase_sample.initial_positions[ship.get_instance_id()])
		_phase_sample.lateral_excursion = maxf(_phase_sample.lateral_excursion, Vector2(relative.x, relative.y).length())
		var regrouping: bool = ship.behavior_state == BlueShip.BehaviorState.REGROUPING
		if regrouping and not _phase_sample.regrouping.get(ship.get_instance_id(), false):
			_phase_sample.regroup_episodes += 1
		_phase_sample.regrouping[ship.get_instance_id()] = regrouping
	var waypoints: int = 0
	var routes: int = 0
	var shots: int = 0
	for drone: PatrolDrone in simulation.drones:
		waypoints += drone.waypoints_selected
		routes += drone.routes_completed
		shots += drone.patrol_shots_fired
	_phase_sample.waypoints = maxi(_phase_sample.waypoints, waypoints)
	_phase_sample.routes = maxi(_phase_sample.routes, routes)
	_phase_sample.green_shots = maxi(_phase_sample.green_shots, shots)
	var pursuits: int = 0
	var disengages: int = 0
	for hostile: Interceptor in simulation.interceptors:
		pursuits += hostile.pursuits_started
		disengages += hostile.disengagements
	_phase_sample.pursuits = maxi(_phase_sample.pursuits, pursuits)
	_phase_sample.disengagements = maxi(_phase_sample.disengagements, disengages)


func _finish_phase() -> void:
	var sample: Dictionary = _phase_sample.duplicate(true)
	sample.erase("regrouping")
	sample.erase("origin")
	sample.erase("initial_positions")
	sample.blue_alive = simulation.ships.size()
	sample.blue_deaths = simulation.death_count - _phase_deaths
	sample.total_deaths = simulation.death_count
	sample.green = simulation.drones.size()
	sample.red = simulation.interceptors.size()
	sample.capital = simulation.capitals.size()
	sample.real_seconds = phase_elapsed
	sample.dispersion_final = simulation.dispersion
	sample.dodges = simulation.projectile_dodge_count - int(sample.dodges_start)
	sample.blue_shots = simulation.blue_shots_fired - int(sample.blue_shots_start)
	sample.enemy_shots = simulation.enemy_shots_fired - int(sample.enemy_shots_start)
	var salvos: Array[int] = []
	for index: int in range(simulation.capital_salvos.size()):
		salvos.append(simulation.capital_salvos[index] - int(sample.salvos_start[index]))
	sample.salvos = salvos
	sample.motion_types = simulation.asteroid_container.motions_generated.duplicate()
	for key: String in ["dodges_start", "blue_shots_start", "enemy_shots_start", "salvos_start", "metrics_start"]:
		sample.erase(key)
	phase_results.append(sample.duplicate(true))


func end_squadron() -> void:
	if not is_guided() or game_over or simulation.legacy_flight_profile:
		return
	game_over = true
	simulation.streaming_enabled = false
	# Arrêt immédiat, y compris tirs/vols/émetteurs déjà actifs ; UI et caméra restent vivantes.
	for container: Node3D in _stage_containers():
		for entity: Node in container.get_children():
			if not _saved_root_ids.has(entity.get_instance_id()):
				entity.process_mode = Node.PROCESS_MODE_DISABLED
	_sample_phase()
	_finish_phase()
	simulation.demo_controls.show_game_over(true)
