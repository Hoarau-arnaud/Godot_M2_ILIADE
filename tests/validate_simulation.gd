extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ASTEROID_SCENE: PackedScene = preload("res://scenes/asteroid.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/patrol_drone.tscn")

var _failures: int = 0
var _death_signals: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture_preview()
		return
	await _test_default_field()
	await _test_forced_hard_field()
	await _test_patrol_agent()
	await _test_drone_perceptions()
	await _test_mobile_crossing()
	await _test_mobile_collision()
	await _test_drone_replacement()
	await _test_difficulty_controls()
	await _test_flock_recovery()
	await _test_recovery_perception_limit()
	await _test_streaming_and_difficulty()
	await _test_removed_obstacle_memory()
	await _test_unobstructed_motion()
	await _test_separation()
	await _test_local_perception()
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]:
		await _test_avoidance(direction)
	await _test_multiple_obstacles()
	await _test_collision_and_statistics()
	await _test_camera_controls()
	await _test_camera_independence()
	await _test_starfield_recycling()
	await _test_long_field()
	if _failures == 0:
		print("PASS : navigation, drones et commandes du milestone 5.")
	else:
		printerr("FAIL : %d validation(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await physics_frame
	await process_frame


func _dispose(simulation: SpaceSimulation) -> void:
	simulation.queue_free()
	await process_frame
	await physics_frame
	_check(get_nodes_in_group("blue_ships").is_empty(), "Un chasseur supprimé reste dans le groupe.")
	_check(get_nodes_in_group("asteroids").is_empty(), "Un rocher supprimé reste dans le groupe.")
	_check(get_nodes_in_group("patrol_drones").is_empty(), "Un drone supprimé reste dans le groupe.")
	_check(get_nodes_in_group("hostile_agents").is_empty() and get_nodes_in_group("blue_lasers").is_empty(), "Hostile ou projectile conservé après suppression.")
	_check(get_nodes_in_group("interceptors").is_empty() and get_nodes_in_group("hostile_projectiles").is_empty(), "Objet M6 conservé après suppression.")


func _empty_field(count: int, seed_value: int = 20261012) -> SpaceSimulation:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	simulation.ship_count = count
	simulation.drones_enabled = false
	simulation.interceptors_enabled = false
	simulation.combat_enabled = false
	simulation.streaming_enabled = false
	simulation.simulation_seed = seed_value
	root.add_child(simulation)
	return simulation


func _test_default_field() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	root.add_child(simulation)
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main.tscn", "Scène principale incorrecte.")
	_check(simulation.initial_agent_count == 10 and simulation.living_agent_count == 10, "Le lancement ne crée pas dix chasseurs.")
	_check(simulation.statistics.text == "Vaisseaux détruits : 0" and simulation.statistics.visible, "Compteur minimal incorrect au démarrage.")
	_check(simulation.get_node("HUD").find_children("*", "Label", true, false).size() == 1, "Le HUD contient d'autres informations que le compteur de chasseurs détruits.")
	_check(get_nodes_in_group("blue_ships").size() == 10, "Groupe blue_ships incorrect.")
	_check(simulation.drones.size() == 1 and get_nodes_in_group("hostile_agents").size() == 1, "Un PatrolDrone hostile doit être présent au lancement facile.")
	var initial_configurations: int = simulation.asteroid_container.generated_configuration_count
	_check(get_nodes_in_group("asteroids").size() > 0, "Le streaming ne crée aucun obstacle initial.")
	var categories: Array[bool] = [false, false, false]
	var first_asteroid: SpaceAsteroid = get_nodes_in_group("asteroids")[0] as SpaceAsteroid
	var initial_rotation: Quaternion = first_asteroid.quaternion
	var initial_asteroid_position: Vector3 = first_asteroid.position
	for node: Node in get_nodes_in_group("asteroids"):
		var asteroid: SpaceAsteroid = node as SpaceAsteroid
		_check(asteroid.collision_layer == 2 and asteroid.collision_mask == 0, "Couches du rocher incorrectes.")
		_check(asteroid.avoidance_radius > 0.0 and asteroid.scale == Vector3.ONE, "Géométrie du rocher incorrecte.")
		categories[int(asteroid.size_category)] = true
	_check(categories[0] or categories[1], "La zone facile ne contient ni petits ni moyens rochers.")
	for ship: BlueShip in simulation.ships:
		_check(ship.collision_layer == 1 and ship.collision_mask == 6, "Couches du chasseur incorrectes.")
		_check(ship.died.is_connected(simulation._on_ship_died), "Signal de mort non connecté.")
		for wing_path: String in ["Visuals/RightWing", "Visuals/LeftWing"]:
			var wing: MeshInstance3D = ship.get_node(wing_path) as MeshInstance3D
			var bounds: AABB = wing.transform * wing.get_aabb()
			_check(bounds.size.y < 0.21 and bounds.size.x > 1.7, "Une aile n'est pas plate dans le plan X/Z.")
	var max_spread: float = 0.0
	var max_avoiding: int = 0
	var minimum_pair_distance: float = INF
	var nearest_total: float = 0.0
	var nearest_samples: int = 0
	var maximum_isolated: int = 0
	var isolated_names: Dictionary[String, bool] = {}
	var isolation_streaks: Dictionary[String, int] = {}
	var longest_isolation: int = 0
	var lowest_forward_speed: float = INF
	var mobile_reaction_ticks: int = 0
	var drone_waypoints_observed: bool = false
	for frame: int in range(5400):
		await physics_frame
		var avoiding: int = 0
		var center: Vector3 = simulation._fleet_center()
		var isolated_count: int = 0
		for drone: PatrolDrone in simulation.drones:
			_check(drone.alive and drone.velocity.z < 0.0 and drone.global_position.is_finite(), "Un drone normal est bloqué ou invalide.")
			drone_waypoints_observed = drone_waypoints_observed or drone.waypoints_selected > 1
		for ship: BlueShip in simulation.ships:
			_check(ship.velocity.z < 0.0, "Un chasseur a cessé de progresser vers l'avant.")
			_check(ship.global_position.is_finite() and ship.velocity.is_finite(), "Position ou vitesse non finie.")
			max_spread = maxf(max_spread, center.distance_to(ship.global_position))
			if not ship._threats.is_empty():
				avoiding += 1
			_check(ship._threats.size() <= 3, "Trop de menaces sont combinées.")
			var nearest: float = INF
			for other: BlueShip in simulation.ships:
				if other != ship:
					nearest = minf(nearest, ship.global_position.distance_to(other.global_position))
			minimum_pair_distance = minf(minimum_pair_distance, nearest)
			lowest_forward_speed = minf(lowest_forward_speed, -ship.velocity.z)
			if ship.mobile_threat_count > 0:
				mobile_reaction_ticks += 1
			var ship_name: String = str(ship.name)
			if nearest > ship.neighbor_radius:
				isolated_count += 1
				isolated_names[ship_name] = true
				isolation_streaks[ship_name] = isolation_streaks.get(ship_name, 0) + 1
				longest_isolation = maxi(longest_isolation, isolation_streaks[ship_name])
			else:
				isolation_streaks[ship_name] = 0
			if frame > 60 and frame % 12 == 0:
				nearest_total += nearest
				nearest_samples += 1
		max_avoiding = maxi(max_avoiding, avoiding)
		maximum_isolated = maxi(maximum_isolated, isolated_count)
		if frame == 120:
			_check(absf(first_asteroid.quaternion.dot(initial_rotation)) < 0.9999, "Les astéroïdes ne tournent pas.")
			_check(first_asteroid.position.is_equal_approx(initial_asteroid_position), "La rotation introduit une translation du rocher.")
			first_asteroid = null
	await process_frame
	_check(max_avoiding > 0, "Aucun rocher du champ n'a été anticipé.")
	_check(simulation.living_agent_count + simulation.death_count == 10, "Statistiques incohérentes après le parcours.")
	_check(simulation.living_agent_count >= 6, "Le parcours AUTO de 90 secondes ne conserve pas la majorité des chasseurs.")
	var average_nearest: float = nearest_total / float(maxi(nearest_samples, 1))
	_check(minimum_pair_distance > 5.5, "Deux chasseurs sont trop proches durant le parcours normal.")
	_check(average_nearest >= 9.0 and average_nearest <= 14.0, "L'espace personnel moyen n'est pas confortable.")
	_check(simulation.ships.size() == get_nodes_in_group("blue_ships").size(), "Références mortes dans Main.")
	_check(max_spread < 40.0, "Le groupe par défaut s'est trop dispersé.")
	_check(simulation.camera.global_position.is_finite(), "Caméra non finie.")
	_check(longest_isolation < 300 and lowest_forward_speed > 4.0, "Un chasseur reste isolé ou bloqué durablement.")
	_check(simulation.asteroid_container.generated_configuration_count > initial_configurations and simulation.asteroid_container.removed_configuration_count > 0, "Le streaming n'a pas renouvelé le champ.")
	_check(simulation.difficulty_level == simulation.asteroid_container.difficulty_for_distance(simulation.distance_travelled), "Difficulté incohérente avec la distance.")
	print("Champ par défaut, 90 s : vivants=%d, morts=%d, rayon maximal=%.2f m, évitements simultanés=%d, distance minimale=%.2f m, voisin le plus proche en moyenne=%.2f m" % [simulation.living_agent_count, simulation.death_count, max_spread, max_avoiding, minimum_pair_distance, average_nearest])
	print("M5 AUTO 90 s : distance=%.2f m, difficulté=%d, isolés max=%d, agents distincts isolés=%d, durée max=%.2f s, obstacles max=%d, configurations générées=%d / supprimées=%d" % [simulation.distance_travelled, simulation.difficulty_level, maximum_isolated, isolated_names.size(), float(longest_isolation) / 60.0, simulation.asteroid_container.maximum_active_observed, simulation.asteroid_container.generated_configuration_count, simulation.asteroid_container.removed_configuration_count])
	_check(drone_waypoints_observed and simulation.drones.size() <= simulation.target_drone_count(), "La patrouille ne renouvelle pas ses waypoints ou dépasse son effectif.")
	print("M5 AUTO 90 s : drones actifs=%d, détruits=%d, créés total=%d, ticks-agent avec anticipation mobile=%d" % [simulation.drones.size(), simulation.drone_death_count, simulation.drone_spawn_count, mobile_reaction_ticks])
	await _dispose(simulation)


func _fixture_drone(simulation: SpaceSimulation, position_value: Vector3, seed_value: int = 20261012) -> PatrolDrone:
	var drone: PatrolDrone = DRONE_SCENE.instantiate() as PatrolDrone
	drone.position = position_value
	drone.patrol_anchor = Vector2(position_value.x, position_value.y)
	drone.individual_seed = seed_value
	simulation.drone_container.add_child(drone)
	return drone


func _patrol_signature(seed_value: int) -> Array[Vector3]:
	var simulation: SpaceSimulation = _empty_field(1)
	simulation.ships[0].position = Vector3(200, 0, 0)
	simulation.ships[0].set_physics_process(false)
	var drone: PatrolDrone = _fixture_drone(simulation, Vector3.ZERO, seed_value)
	_check(drone.is_in_group("patrol_drones") and not drone.is_in_group("blue_ships"), "Groupe dédié du PatrolDrone incorrect.")
	_check(drone.collision_layer == 4 and drone.collision_mask == 2, "Couches du drone incorrectes.")
	var minimum: Vector3 = drone.global_position
	var maximum: Vector3 = drone.global_position
	var changing_observed: bool = false
	var signature: Array[Vector3] = [drone.waypoint]
	var last_selection: int = drone.waypoints_selected
	for _frame: int in range(1200):
		await physics_frame
		_check(is_instance_valid(drone) and drone.alive, "Un drone meurt dans une patrouille sans obstacle.")
		minimum = minimum.min(drone.global_position)
		maximum = maximum.max(drone.global_position)
		changing_observed = changing_observed or drone.patrol_state == PatrolDrone.PatrolState.CHANGING_WAYPOINT
		_check(drone.velocity.z < 0.0, "Le drone cesse de progresser vers Z négatif.")
		if drone.waypoints_selected > last_selection:
			_check(drone.waypoint.z < signature.back().z - 19.0, "Le nouveau waypoint ne poursuit pas la patrouille en avant.")
			signature.append(drone.waypoint)
			last_selection = drone.waypoints_selected
	var excursion: Vector3 = maximum - minimum
	_check(excursion.x > 5.0 and excursion.y > 3.0 and excursion.z > 150.0, "La patrouille manque de mouvement en X/Y/Z.")
	_check(changing_observed and drone.waypoints_selected >= 4, "Les changements de waypoint et d'état ne sont pas observables.")
	signature.append(drone.global_position)
	print("Patrouille 20 s : seed=%d, excursion=%s, waypoints=%d, changement d'état=%s" % [seed_value, excursion, drone.waypoints_selected, changing_observed])
	await _dispose(simulation)
	return signature


func _test_patrol_agent() -> void:
	var first: Array[Vector3] = await _patrol_signature(20261012)
	var repeated: Array[Vector3] = await _patrol_signature(20261012)
	var changed: Array[Vector3] = await _patrol_signature(20261013)
	_check(first == repeated and first != changed, "La route du drone n'est pas déterministe avec sa graine.")


func _test_drone_perceptions() -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3(5, 0, 0)
	ship.set_physics_process(false)
	var drone: PatrolDrone = _fixture_drone(simulation, Vector3.ZERO)
	drone.set_physics_process(false)
	var correction: Vector3 = drone._ship_avoidance()
	_check(correction.x < 0.0 and drone.perceived_ship_count == 1, "Le drone n'évite pas légèrement un BlueShip trop proche.")
	ship._update_neighbor_rules()
	simulation._measure_group(simulation._fleet_center())
	_check(ship.neighbor_count == 0 and ship._cohesion == Vector3.ZERO and ship._alignment == Vector3.ZERO and ship._recovery == Vector3.ZERO, "Le drone est inclus dans le flocking des chasseurs.")
	_check(simulation.average_spacing == 0.0 and simulation.dispersion == 0.0 and simulation._fleet_center() == ship.global_position, "Un drone influence les mesures ou le centre caméra bleu.")
	ship.position = Vector3(200, 0, 0)
	_check(drone._ship_avoidance() == Vector3.ZERO, "Le drone perçoit un BlueShip au-delà de sa portée locale.")
	var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	asteroid.diameter = 6.0
	asteroid.shape_seed = 88
	asteroid.position = Vector3(0, 0, -25)
	simulation.asteroid_container.add_child(asteroid)
	drone.waypoint = Vector3(0, 0, -55)
	drone.velocity = Vector3.FORWARD * drone.forward_speed
	drone._preferred_avoidance = Vector3.UP
	drone.set_physics_process(true)
	var maximum_excursion: float = 0.0
	var avoiding_observed: bool = false
	for _frame: int in range(480):
		await physics_frame
		if not is_instance_valid(drone):
			break
		maximum_excursion = maxf(maximum_excursion, absf(drone.global_position.y))
		avoiding_observed = avoiding_observed or drone.patrol_state == PatrolDrone.PatrolState.AVOIDING
	_check(is_instance_valid(drone) and drone.alive and avoiding_observed and maximum_excursion > 4.0, "Le drone échoue à éviter l'astéroïde.")
	print("Perceptions drone : proximité BlueShip, exclusion du flocking, évitement astéroïde, excursion=%.2f m" % maximum_excursion)
	await _dispose(simulation)


func _test_mobile_crossing() -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3.ZERO
	ship.wander_strength = 0.0
	ship.vertical_wander_strength = 0.0
	ship.longitudinal_wander_strength = 0.0
	ship._speed_factor = 1.0
	ship.velocity = Vector3.FORWARD * ship.forward_speed
	var drone: PatrolDrone = _fixture_drone(simulation, Vector3(-12, 0, -5))
	drone.set_physics_process(false)
	drone.velocity = Vector3(6, 0, -8)
	var detected: bool = false
	var anticipated: bool = false
	var minimum_distance: float = INF
	var maximum_excursion: float = 0.0
	for frame: int in range(360):
		drone.move_and_collide(drone.velocity / 60.0)
		await physics_frame
		if not is_instance_valid(ship):
			break
		detected = detected or ship.mobile_threat_count > 0
		if frame < 90 and Vector2(ship.velocity.x, ship.velocity.y).length() > 0.5:
			anticipated = true
		minimum_distance = minf(minimum_distance, ship.global_position.distance_to(drone.global_position))
		maximum_excursion = maxf(maximum_excursion, absf(ship.global_position.y))
	_check(detected and anticipated and simulation.living_agent_count == 1 and minimum_distance > 2.5, "L'anticipation mobile n'évite pas le croisement avant contact.")
	_check(ship._drone_directions.has(drone), "Le côté de contournement du danger mobile n'est pas mémorisé.")
	drone.queue_free()
	await _advance(2)
	_check(ship._drone_directions.is_empty(), "Une référence à un drone supprimé reste mémorisée.")
	print("Croisement mobile : anticipé avant 1,5 s, distance minimale=%.2f m, excursion verticale=%.2f m, survivants=%d" % [minimum_distance, maximum_excursion, simulation.living_agent_count])
	await _dispose(simulation)


func _test_mobile_collision() -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3.ZERO
	ship.wander_strength = 0.0
	ship.vertical_wander_strength = 0.0
	ship.longitudinal_wander_strength = 0.0
	ship.forward_speed = 35.0
	ship.mobile_detection_radius = 0.0
	_death_signals = 0
	ship.died.connect(_on_test_death)
	var drone: PatrolDrone = _fixture_drone(simulation, Vector3(0, 0, -8))
	drone.set_physics_process(false)
	await _advance(90)
	_check(_death_signals == 1 and simulation.death_count == 1 and simulation.living_agent_count == 0, "Le contact physique BlueShip/PatrolDrone ne détruit pas réellement le chasseur.")
	_check(drone.alive and is_instance_valid(drone) and not is_instance_valid(ship), "Le drone robuste ne reste pas actif après le contact.")
	print("Stress mobile : collision réelle, destruction unique BlueShip, drone intact, compteur mort=1.")
	await _dispose(simulation)


func _test_drone_replacement() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	simulation.streaming_enabled = false
	simulation.combat_enabled = false
	simulation.manual_difficulty = 2
	root.add_child(simulation)
	var drone: PatrolDrone = simulation.drones[0]
	drone.obstacle_detection_radius = 0.0
	var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	asteroid.position = drone.global_position + Vector3.FORWARD * 4.0
	asteroid.diameter = 7.0
	simulation.asteroid_container.add_child(asteroid)
	await _advance(120)
	_check(simulation.drone_death_count >= 1 and not is_instance_valid(drone), "Un drone traverse un rocher malgré sa collision réelle.")
	await _advance(300)
	_check(simulation.drones.size() == 2 and simulation.drone_spawn_count > 2 and get_nodes_in_group("patrol_drones").size() == 2, "Main ne remplace pas le drone détruit après le délai.")
	var retired: PatrolDrone = simulation.drones[0]
	retired.global_position.z = simulation._fleet_z_bounds().y + 200.0
	retired.set_physics_process(false)
	await _advance(2)
	_check(not is_instance_valid(retired) and simulation.drone_retired_count == 1, "Le drone très loin derrière n'est pas retiré proprement.")
	await _advance(310)
	_check(simulation.drones.size() == 2 and get_nodes_in_group("patrol_drones").size() == 2, "Le drone retiré n'est pas remplacé.")
	for current: PatrolDrone in simulation.drones:
		_check(current.global_position.z < simulation._fleet_z_bounds().x - 30.0, "Un drone remplacé apparaît trop près des chasseurs.")
	print("Cycle drone : collision astéroïde, explosion, délai de 5 s, remplacement sûr et retrait arrière validés.")
	await _dispose(simulation)


func _test_difficulty_controls() -> void:
	var simulation: SpaceSimulation = _empty_field(2)
	for ship: BlueShip in simulation.ships:
		ship.set_physics_process(false)
	var field: ObstacleField = simulation.asteroid_container
	field.advance(simulation._fleet_center(), simulation._fleet_z_bounds().x, simulation._fleet_z_bounds().y)
	for level: int in range(1, 4):
		var existing: Array[Node3D] = field.configurations.duplicate()
		_send_key(KEY_0 + level as Key, true)
		_send_key(KEY_0 + level as Key, false)
		await _advance(2)
		_check(simulation.manual_difficulty == level and simulation.difficulty_level == level, "Le clavier ne sélectionne pas le niveau manuel %d." % level)
		for configuration: Node3D in existing:
			_check(is_instance_valid(configuration) and not configuration.is_queued_for_deletion(), "Changer la difficulté supprime un obstacle existant.")
		var first_new: int = field.generated_configuration_count
		for ship: BlueShip in simulation.ships:
			ship.global_position.z -= 100.0
		field.advance(simulation._fleet_center(), simulation._fleet_z_bounds().x, simulation._fleet_z_bounds().y)
		_check(field.generated_configuration_count > first_new, "Le champ ne génère pas de configuration après le changement manuel.")
		for configuration: Node3D in field.configurations:
			if int(configuration.get_meta("generation_index")) >= first_new:
				_check(int(configuration.get_meta("difficulty")) == level and field.allowed_patterns(level).has(int(configuration.get_meta("pattern"))), "Une nouvelle configuration ignore la difficulté manuelle.")
	for ship: BlueShip in simulation.ships:
		ship.global_position.z = simulation._origin_z - 800.0
	await _advance(2)
	_send_key(KEY_0, true)
	_send_key(KEY_0, false)
	await _advance(2)
	_check(simulation.manual_difficulty == 0 and simulation.difficulty_level == 2 and field.difficulty_override == 0, "0 ne revient pas au niveau AUTO correspondant à 800 m.")
	var physical: InputEventKey = InputEventKey.new()
	physical.device = InputEvent.DEVICE_ID_KEYBOARD
	physical.physical_keycode = KEY_3
	_check(physical.is_action("difficulty_hard"), "La rangée numérique physique ne fonctionne pas en AZERTY.")
	physical.pressed = true
	physical.echo = true
	Input.parse_input_event(physical)
	await _advance(2)
	_check(simulation.manual_difficulty == 0, "Une répétition clavier change le mode de difficulté.")
	_check(simulation.statistics.text == "Vaisseaux détruits : 0", "Changer la difficulté modifie le compteur de destructions.")
	print("Clavier difficulté : 1/2/3 MANUEL, nouveaux patterns, obstacles conservés, 0 AUTO à 800 m et binding physique validés.")
	await _dispose(simulation)


func _test_forced_hard_field() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	simulation.manual_difficulty = 3
	root.add_child(simulation)
	var reaction_ticks: int = 0
	var minimum_spacing: float = INF
	for configuration: Node3D in simulation.asteroid_container.configurations:
		_check(int(configuration.get_meta("difficulty")) == 3, "Le niveau forcé initial n'est pas utilisé pour le premier champ.")
	for frame: int in range(5400):
		await physics_frame
		_check(simulation.difficulty_level == 3 and simulation.manual_difficulty == 3, "La difficulté forcée n'est pas réellement utilisée.")
		for ship: BlueShip in simulation.ships:
			if ship.mobile_threat_count > 0:
				reaction_ticks += 1
			_check(ship.velocity.z < 0.0, "Un chasseur manuel est bloqué.")
		for drone: PatrolDrone in simulation.drones:
			_check(drone.velocity.z < 0.0 and drone.global_position.is_finite(), "Un drone manuel est bloqué ou invalide.")
		if frame % 30 == 0:
			_check(simulation.asteroid_container.active_asteroid_count <= 72 and simulation.drones.size() <= 3, "Le scénario manuel dépasse les budgets.")
			minimum_spacing = minf(minimum_spacing, simulation.average_spacing)
	await process_frame
	_check(simulation.living_agent_count > 0 and simulation.living_agent_count + simulation.death_count == 10, "Le scénario manuel ne reste pas actif avec des compteurs corrects.")
	_check(simulation.asteroid_container.generated_configuration_count > 20 and simulation.asteroid_container.removed_configuration_count > 0, "Le champ difficile ne se renouvelle pas.")
	print("M5 MANUEL 3, 90 s : distance=%.2f m, vivants=%d, morts=%d, drones actifs=%d, drones détruits=%d, créés=%d, ticks-agent anticipation mobile=%d, obstacles max=%d, espacement final=%.2f m, minimum moyen=%.2f m, dispersion finale=%.2f m" % [simulation.distance_travelled, simulation.living_agent_count, simulation.death_count, simulation.drones.size(), simulation.drone_death_count, simulation.drone_spawn_count, reaction_ticks, simulation.asteroid_container.maximum_active_observed, simulation.average_spacing, minimum_spacing, simulation.dispersion])
	await _dispose(simulation)


func _test_flock_recovery() -> void:
	var simulation: SpaceSimulation = _empty_field(10)
	var positions: Array[Vector3] = [
		Vector3(-10, -4, -4), Vector3(10, 4, 4), Vector3(-6, 6, 5), Vector3(6, -6, -5),
		Vector3(-10, 5, -8), Vector3(10, -5, 8), Vector3(0, 0, -10), Vector3(0, 0, 10),
		Vector3(-49, 0, 0), Vector3(49, 0, 0)
	]
	for index: int in range(positions.size()):
		simulation.ships[index].position = positions[index]
	simulation._measure_group(simulation._fleet_center())
	var initial_dispersion: float = simulation.dispersion
	var regrouping_observed: bool = false
	var critical_samples: int = 0
	var sample_count: int = 0
	var minimum_distance: float = INF
	for frame: int in range(1800):
		await physics_frame
		for ship: BlueShip in simulation.ships:
			regrouping_observed = regrouping_observed or ship.behavior_state == BlueShip.BehaviorState.REGROUPING
			if frame % 12 == 0:
				var nearest: float = INF
				for other: BlueShip in simulation.ships:
					if other != ship:
						nearest = minf(nearest, ship.global_position.distance_to(other.global_position))
				minimum_distance = minf(minimum_distance, nearest)
				sample_count += 1
				if nearest < ship.critical_separation_distance:
					critical_samples += 1
	simulation._measure_group(simulation._fleet_center())
	var critical_fraction: float = float(critical_samples) / float(maxi(sample_count, 1))
	_check(regrouping_observed, "L'état REGROUPEMENT n'a pas été observé.")
	_check(simulation.dispersion < initial_dispersion * 0.8, "La dispersion ne diminue pas après une séparation visible localement.")
	_check(critical_fraction < 0.1 and simulation.average_spacing >= 8.0, "Le regroupement compacte excessivement le banc.")
	_check(simulation.isolated_agent_count == 0 and simulation.living_agent_count == 10, "Un chasseur reste isolé après le regroupement sans obstacles.")
	print("Regroupement, 30 s : dispersion %.2f -> %.2f m, espacement=%.2f m, minimum=%.2f m, observations critiques=%.2f %%, isolés=%d" % [initial_dispersion, simulation.dispersion, simulation.average_spacing, minimum_distance, critical_fraction * 100.0, simulation.isolated_agent_count])
	await _dispose(simulation)


func _test_recovery_perception_limit() -> void:
	var simulation: SpaceSimulation = _empty_field(2)
	var ship: BlueShip = simulation.ships[0]
	var other: BlueShip = simulation.ships[1]
	ship.position = Vector3.ZERO
	other.position = Vector3(70.0, 0.0, 0.0)
	ship._update_neighbor_rules()
	_check(ship.neighbor_count == 0 and ship._recovery == Vector3.ZERO, "Un voisin au-delà de recovery_radius attire l'agent.")
	other.position = Vector3(42.0, 0.0, 0.0)
	ship._update_neighbor_rules()
	_check(ship.neighbor_count == 0 and ship._recovery.x > 0.0, "Un voisin visible entre 32 et 50 m n'aide pas au regroupement.")
	other.position = Vector3(15.0, 0.0, 0.0)
	ship._update_neighbor_rules()
	_check(ship.neighbor_count == 1 and ship._recovery == Vector3.ZERO, "La récupération attire trop un voisin déjà proche.")
	print("Récupération locale : attraction à 42 m, aucune information à 70 m, espace personnel conservé.")
	await _dispose(simulation)


func _test_removed_obstacle_memory() -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3.ZERO
	ship.set_physics_process(false)
	var drone: PatrolDrone = _fixture_drone(simulation, Vector3.ZERO)
	drone.set_physics_process(false)
	var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	asteroid.position = Vector3(0, 0, -20)
	simulation.asteroid_container.add_child(asteroid)
	ship._obstacle_avoidance()
	drone._obstacle_avoidance()
	_check(ship._avoid_directions.has(asteroid) and ship._threats.has(asteroid), "La menace n'a pas été mémorisée pour le test de suppression.")
	_check(drone._obstacle_directions.has(asteroid), "Le drone ne mémorise pas l'obstacle utilisé pour le test de suppression.")
	asteroid.queue_free()
	await _advance(2)
	ship._find_threats()
	_check(ship._avoid_directions.is_empty() and ship._threats.is_empty(), "Une référence à un obstacle supprimé est conservée.")
	_check(drone._obstacle_directions.is_empty(), "Le drone conserve une référence à un astéroïde supprimé.")
	print("Suppression : mémoires BlueShip et PatrolDrone nettoyées sans référence invalide.")
	await _dispose(simulation)


func _stream_signature(seed_value: int) -> Array[String]:
	var simulation: SpaceSimulation = _empty_field(2, seed_value)
	var field: ObstacleField = simulation.asteroid_container
	for ship: BlueShip in simulation.ships:
		ship.set_physics_process(false)
	field.initialize_field(seed_value, Vector3(120, -70, 0), -4.0)
	var signature: Array[String] = []
	for step: int in range(61):
		var center: Vector3 = Vector3(120.0 + float(step) * 0.8, -70.0 + float(step % 5), -float(step) * 100.0)
		simulation.ships[0].position = center + Vector3(-4, 0, -4)
		simulation.ships[1].position = center + Vector3(4, 0, 4)
		var first_new_index: int = field.generated_configuration_count
		field.advance(center, center.z - 4.0, center.z + 4.0)
		for configuration: Node3D in field.configurations:
			_check(is_instance_valid(configuration) and not configuration.is_queued_for_deletion(), "Le streaming conserve une configuration supprimée.")
			if int(configuration.get_meta("generation_index")) < first_new_index:
				continue
			_check(absf(configuration.global_position.x - center.x) <= field.horizontal_spread * 0.45 + 0.01, "Les obstacles ne suivent pas la dérive X du groupe.")
			_check(absf(configuration.global_position.y - center.y) <= field.vertical_spread * 0.45 + 0.01, "Les obstacles ne suivent pas la dérive Y du groupe.")
			signature.append("%d/%d/%s" % [int(configuration.get_meta("pattern")), int(configuration.get_meta("difficulty")), configuration.global_position])
			for child: Node in configuration.get_children():
				var asteroid: SpaceAsteroid = child as SpaceAsteroid
				signature.append("%s/%.6f/%s/%d" % [asteroid.global_position, asteroid.diameter, asteroid.rotation, asteroid.shape_seed])
		_check(field.active_asteroid_count <= field.max_active_asteroids, "Le streaming dépasse son budget d'obstacles.")
		await _advance(2)
		_check(get_nodes_in_group("asteroids").size() == field.active_asteroid_count, "Le comptage d'obstacles actifs diverge après nettoyage.")
	_check(field.patterns_generated.size() == 6, "Les six patterns ne sont pas apparus dans le parcours artificiel.")
	_check(field.removed_configuration_count > 0 and field.maximum_active_observed <= field.max_active_asteroids, "Le champ ne se renouvelle pas de façon bornée.")
	print("Streaming artificiel : seed=%d, patterns=%d, configurations=%d, supprimées=%d, obstacles max=%d" % [seed_value, field.patterns_generated.size(), field.generated_configuration_count, field.removed_configuration_count, field.maximum_active_observed])
	await _dispose(simulation)
	return signature


func _test_streaming_and_difficulty() -> void:
	var first: Array[String] = await _stream_signature(20261012)
	var repeated: Array[String] = await _stream_signature(20261012)
	var changed: Array[String] = await _stream_signature(20261013)
	_check(first == repeated and first != changed, "La génération n'est pas reproductible avec la graine.")
	var simulation: SpaceSimulation = _empty_field(2)
	var field: ObstacleField = simulation.asteroid_container
	_check(field.difficulty_for_distance(0) == 1 and field.difficulty_for_distance(499) == 1, "Niveau facile incorrect.")
	_check(field.difficulty_for_distance(500) == 2 and field.difficulty_for_distance(1099) == 2, "Niveau intermédiaire incorrect.")
	_check(field.difficulty_for_distance(1100) == 3, "Niveau difficile incorrect.")
	_check(field.spacing_for_level(1) > field.spacing_for_level(2) and field.spacing_for_level(2) > field.spacing_for_level(3), "Les configurations ne se rapprochent pas avec la difficulté.")
	var previous_density: float = 0.0
	for level: int in range(1, 4):
		var choices: Array[int] = field.allowed_patterns(level)
		var total_bodies: int = 0
		for pattern: int in choices:
			total_bodies += field.pattern_offsets(pattern, 14.0).size()
		var density: float = float(total_bodies) / float(choices.size()) / field.spacing_for_level(level)
		_check(density > previous_density, "La densité moyenne des profils ne progresse pas.")
		previous_density = density
	_check(not field.allowed_patterns(1).has(ObstacleField.Pattern.LARGE_WITH_COMPANIONS) and field.allowed_patterns(3).has(ObstacleField.Pattern.LARGE_WITH_COMPANIONS), "Les patterns n'évoluent pas avec la difficulté.")
	for ship: BlueShip in simulation.ships:
		ship.set_physics_process(false)
	simulation._origin_z = 0.0
	for distance: float in [0.0, 600.0, 1200.0]:
		simulation.ships[0].position = Vector3(-4, 0, -distance)
		simulation.ships[1].position = Vector3(4, 0, -distance)
		await _advance(30)
		_check(simulation.difficulty_level == field.difficulty_for_distance(distance), "Le niveau Main ne suit pas la progression.")
		_check(is_equal_approx(simulation.distance_travelled, distance), "La distance interne ne suit pas la progression.")
		_check(is_equal_approx(simulation.average_spacing, 8.0) and is_equal_approx(simulation.dispersion, 4.0), "Les mesures internes du groupe ne sont plus calculées.")
	field.initialize_field(20261012, Vector3.ZERO, -4.0)
	field._spawn_configuration(ObstacleField.Pattern.SINGLE, 1, Vector3.ZERO, -20.0)
	var near_laggard: Node3D = field.configurations[0]
	field.advance(Vector3(0, 0, -500), -1000.0, 0.0)
	_check(not near_laggard.is_queued_for_deletion(), "Un obstacle proche du dernier agent est supprimé prématurément.")
	field.advance(Vector3(0, 0, -1000), -1004.0, -996.0)
	_check(near_laggard.is_queued_for_deletion(), "Un obstacle passé derrière tous les agents n'est pas supprimé.")
	await _advance(2)
	_check(not is_instance_valid(near_laggard), "La configuration dépassée reste en mémoire.")
	print("Difficulté : seuils 500/1100 m, densité croissante, patterns, métriques internes et nettoyage derrière tous les survivants validés.")
	await _dispose(simulation)


func _test_long_field() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	root.add_child(simulation)
	var field: ObstacleField = simulation.asteroid_container
	var maximum_nodes: int = get_node_count()
	var generation_at_180_seconds: int = 0
	var first_hard_window_start: int = 0
	var first_hard_window_usec: int = 0
	var last_window_start: int = 0
	var last_window_usec: int = 0
	var max_late_obstacles: int = 0
	for frame: int in range(18000):
		await physics_frame
		if frame == 10800:
			generation_at_180_seconds = field.generated_configuration_count
			first_hard_window_start = Time.get_ticks_usec()
		if frame == 12600:
			first_hard_window_usec = Time.get_ticks_usec() - first_hard_window_start
		if frame == 16200:
			last_window_start = Time.get_ticks_usec()
		if frame % 30 == 0:
			maximum_nodes = maxi(maximum_nodes, get_node_count())
			if frame >= 10800:
				max_late_obstacles = maxi(max_late_obstacles, field.active_asteroid_count)
			_check(field.active_asteroid_count <= field.max_active_asteroids, "Le champ croît sans limite dans le test long.")
			_check(simulation.living_agent_count + simulation.death_count == simulation.initial_agent_count, "Compteurs incohérents pendant le test long.")
			for ship: BlueShip in simulation.ships:
				_check(ship.velocity.z < 0.0 and ship.global_position.is_finite(), "Un survivant reste bloqué ou invalide dans le test long.")
				for obstacle: SpaceAsteroid in ship._threats:
					_check(is_instance_valid(obstacle) and not obstacle.is_queued_for_deletion(), "Une menace supprimée est utilisée dans le test long.")
	last_window_usec = Time.get_ticks_usec() - last_window_start
	await process_frame
	_check(simulation.difficulty_level == 3 and simulation.living_agent_count > 0, "Le test long n'atteint pas la difficulté 3 avec un comportement encore actif.")
	_check(field.generated_configuration_count > generation_at_180_seconds and field.removed_configuration_count > 0, "Le streaming s'arrête après trois minutes.")
	_check(field.maximum_active_observed <= field.max_active_asteroids and get_nodes_in_group("asteroids").size() == field.active_asteroid_count, "Des obstacles anciens s'accumulent dans le test long.")
	_check(maximum_nodes < 1400, "Le nombre de nœuds dépasse la borne du scénario normal.")
	print("M5 AUTO long, 300 s : distance=%.2f m, difficulté=%d, vivants=%d, morts=%d, obstacles max=%d, max après 180 s=%d, actifs fin=%d, configurations=%d / supprimées=%d, nœuds max=%d" % [simulation.distance_travelled, simulation.difficulty_level, simulation.living_agent_count, simulation.death_count, field.maximum_active_observed, max_late_obstacles, field.active_asteroid_count, field.generated_configuration_count, field.removed_configuration_count, maximum_nodes])
	print("Drones après 300 s : actifs=%d, détruits=%d, retirés=%d, créés total=%d" % [simulation.drones.size(), simulation.drone_death_count, simulation.drone_retired_count, simulation.drone_spawn_count])
	print("Coût moyen par tick headless en difficulté 3 : fenêtre 180-210 s=%.3f ms ; 270-300 s=%.3f ms (mesure CPU, pas FPS du rendu)." % [float(first_hard_window_usec) / 1800.0 / 1000.0, float(last_window_usec) / 1800.0 / 1000.0])
	await _dispose(simulation)


func _test_unobstructed_motion() -> void:
	var simulation: SpaceSimulation = _empty_field(10)
	var minimum: Array[Vector3] = []
	var maximum: Array[Vector3] = []
	var start_z: Array[float] = []
	var center: Vector3 = simulation._fleet_center()
	for ship: BlueShip in simulation.ships:
		minimum.append(ship.global_position - center)
		maximum.append(ship.global_position - center)
		start_z.append(ship.global_position.z)
	for _frame: int in range(960):
		await physics_frame
		center = simulation._fleet_center()
		for index: int in range(simulation.ships.size()):
			var ship: BlueShip = simulation.ships[index]
			var relative: Vector3 = ship.global_position - center
			minimum[index] = minimum[index].min(relative)
			maximum[index] = maximum[index].max(relative)
	for index: int in range(simulation.ships.size()):
		var excursion: Vector3 = maximum[index] - minimum[index]
		_check(excursion.x > 1.0 and excursion.y > 1.0 and excursion.z > 1.5, "Un chasseur manque de mouvement relatif en X/Y/Z : %s" % excursion)
		_check(simulation.ships[index].global_position.z < start_z[index] - 100.0, "Progression avant insuffisante.")
	_check(simulation.living_agent_count == 10 and simulation.death_count == 0, "Mort en l'absence de rochers.")
	print("Vol sans obstacles, 16 s : mouvement individuel en X, Y et Z validé pour les dix chasseurs.")
	await _dispose(simulation)


func _test_separation() -> void:
	var simulation: SpaceSimulation = _empty_field(2)
	for index: int in range(2):
		var ship: BlueShip = simulation.ships[index]
		ship.position = Vector3(-1.0 if index == 0 else 1.0, 0.0, 0.0)
		ship.wander_strength = 0.0
		ship.vertical_wander_strength = 0.0
		ship.longitudinal_wander_strength = 0.0
		ship._speed_factor = 1.0
		ship.velocity = Vector3.FORWARD * ship.forward_speed
	await _advance(180)
	var distance: float = simulation.ships[0].global_position.distance_to(simulation.ships[1].global_position)
	_check(distance > 7.0, "La séparation ne rétablit pas l'espace personnel après un rapprochement forcé.")
	print("Séparation : deux chasseurs initialement à 2 m s'écartent à %.2f m." % distance)
	await _dispose(simulation)


func _test_local_perception() -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3.ZERO
	ship.velocity = Vector3.FORWARD * ship.forward_speed
	ship.set_physics_process(false)
	var distant: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	distant.position = Vector3(0.0, 0.0, -80.0)
	simulation.asteroid_container.add_child(distant)
	var behind: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	behind.position = Vector3(0.0, 0.0, 12.0)
	simulation.asteroid_container.add_child(behind)
	ship._find_threats()
	_check(ship._threats.is_empty(), "Un astéroïde éloigné ou derrière le chasseur déclenche un évitement.")
	var close_obstacles: Array[SpaceAsteroid] = []
	for index: int in range(4):
		var obstacle: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
		obstacle.position = Vector3(0.0, 0.0, -18.0 - float(index) * 6.0)
		simulation.asteroid_container.add_child(obstacle)
		close_obstacles.append(obstacle)
	ship._find_threats()
	_check(ship._threats.size() == 3, "Les trois menaces les plus proches ne sont pas sélectionnées.")
	_check(ship._threats.has(close_obstacles[0]) and not ship._threats.has(close_obstacles[3]), "Priorité des menaces incorrecte.")
	_check(not ship._threats.has(distant) and not ship._threats.has(behind), "Perception locale incorrecte.")
	print("Perception : obstacles lointains/arrière ignorés, trois menaces proches maximum.")
	await _dispose(simulation)


func _test_multiple_obstacles() -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3.ZERO
	ship.velocity = Vector3.FORWARD * ship.forward_speed
	ship.wander_strength = 0.0
	ship.vertical_wander_strength = 0.0
	ship.longitudinal_wander_strength = 0.0
	ship._preferred_avoidance = Vector3.UP
	for side: float in [-4.0, 4.0]:
		var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
		asteroid.position = Vector3(side, 0.0, -27.0)
		asteroid.diameter = 6.0
		asteroid.size_category = SpaceAsteroid.SizeCategory.LARGE
		asteroid.shape_seed = 88
		asteroid.rotation_speed = 0.0
		simulation.asteroid_container.add_child(asteroid)
	var maximum_threats: int = 0
	var vertical_excursion: float = 0.0
	for _frame: int in range(360):
		await physics_frame
		if not is_instance_valid(ship):
			break
		maximum_threats = maxi(maximum_threats, ship._threats.size())
		vertical_excursion = maxf(vertical_excursion, absf(ship.global_position.y))
	_check(maximum_threats == 2, "Les deux obstacles proches n'ont pas été perçus ensemble.")
	_check(simulation.living_agent_count == 1 and vertical_excursion > 5.0, "Le chasseur échoue à contourner deux grands rochers côte à côte.")
	print("Deux rochers côte à côte : menaces=%d, excursion verticale=%.2f m, vivants=%d" % [maximum_threats, vertical_excursion, simulation.living_agent_count])
	await _dispose(simulation)


func _test_avoidance(direction: Vector3) -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3.ZERO
	ship.velocity = Vector3.FORWARD * ship.forward_speed
	ship.wander_strength = 0.0
	ship.vertical_wander_strength = 0.0
	ship.longitudinal_wander_strength = 0.0
	ship._preferred_avoidance = direction
	var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	asteroid.diameter = 6.0
	asteroid.size_category = SpaceAsteroid.SizeCategory.LARGE
	asteroid.shape_seed = 88
	asteroid.position = Vector3(0.0, 0.0, -20.0)
	simulation.asteroid_container.add_child(asteroid)
	var side_excursion: float = 0.0
	var anticipated: bool = false
	for _frame: int in range(360):
		await physics_frame
		if not is_instance_valid(ship) or not ship.alive:
			break
		side_excursion = maxf(side_excursion, ship.global_position.dot(direction))
		if ship._avoid_directions.has(asteroid):
			anticipated = true
			_check(ship._avoid_directions[asteroid].dot(direction) > 0.99, "La décision de contournement change pendant la manœuvre.")
		_check(ship.velocity.z < 0.0, "L'évitement a annulé la progression avant.")
	_check(simulation.living_agent_count == 1, "Échec du contournement dans la direction %s." % direction)
	_check(anticipated and side_excursion > 5.0, "Évitement anticipé insuffisant dans la direction %s." % direction)
	if is_instance_valid(ship):
		_check(ship.global_position.z < -35.0, "Le chasseur n'a pas dépassé le rocher.")
	print("Contournement %s : excursion=%.2f m, vivants=%d" % [direction, side_excursion, simulation.living_agent_count])
	await _dispose(simulation)


func _on_test_death(ship: BlueShip) -> void:
	_death_signals += 1
	_check(not ship.alive and not ship.is_in_group("blue_ships"), "L'agent mort continue son comportement.")
	_check(ship.collision_layer == 0 and ship.collision_mask == 0, "L'agent mort conserve ses collisions.")
	_check(ship.behavior_state == BlueShip.BehaviorState.DESTROYED, "État DETRUIT absent après collision.")
	_check(ship.get_parent().get_node_or_null("Explosion") != null, "Explosion absente au moment de la mort.")
	ship._die()


func _test_collision_and_statistics() -> void:
	_death_signals = 0
	var simulation: SpaceSimulation = _empty_field(1)
	var ship: BlueShip = simulation.ships[0]
	ship.wander_strength = 0.0
	ship.vertical_wander_strength = 0.0
	ship.longitudinal_wander_strength = 0.0
	ship.obstacle_detection_radius = 0.0
	ship.forward_speed = 35.0
	ship.died.connect(_on_test_death)
	var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	asteroid.position = ship.position + Vector3.FORWARD * 8.0
	asteroid.diameter = 6.0
	asteroid.size_category = SpaceAsteroid.SizeCategory.LARGE
	simulation.asteroid_container.add_child(asteroid)
	await _advance(90)
	_check(_death_signals == 1, "Le signal de mort doit être émis exactement une fois.")
	_check(simulation.initial_agent_count == 1 and simulation.living_agent_count == 0 and simulation.death_count == 1, "Compteurs de mort incorrects.")
	_check(simulation.ships.is_empty() and get_nodes_in_group("blue_ships").is_empty(), "Agent détruit encore utilisé.")
	_check(not is_instance_valid(ship), "Le chasseur mort n'est pas supprimé.")
	_check(simulation.statistics.text == "Vaisseaux détruits : 1", "HUD incorrect après destruction d'un BlueShip.")
	_check(simulation.get_node("HUD").find_children("*", "Label", true, false).size() == 1, "Un message supplémentaire apparaît après la dernière mort.")
	_check(simulation.ship_container.get_child_count() == 0, "L'explosion n'a pas été supprimée.")
	print("Stress à 35 m/s, perception désactivée : collision réelle, destruction unique, débris, compteurs et fin du groupe validés.")
	await _dispose(simulation)


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_mouse(button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_MOUSE
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(950.0, 500.0)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT and pressed else 0
	Input.parse_input_event(event)


func _test_camera_controls() -> void:
	var simulation: SpaceSimulation = _empty_field(3)
	var camera: SimulationCamera = simulation.camera
	var start_position: Vector3 = camera.global_position
	await _advance(120)
	_check(camera.global_position.z < start_position.z - 10.0, "La caméra ne suit pas la progression du groupe.")
	var target: Vector3 = simulation._fleet_center() + Vector3.FORWARD * 8.0
	_check((-camera.global_basis.z).dot((target - camera.global_position).normalized()) > 0.99, "La caméra suivi ne regarde pas le groupe.")
	for action: String in ["camera_toggle", "camera_recenter", "camera_forward", "camera_backward", "camera_left", "camera_right", "camera_up", "camera_down", "camera_orbit", "camera_zoom_in", "camera_zoom_out"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Input Action caméra absente : %s" % action)
	var azerty_event: InputEventKey = InputEventKey.new()
	azerty_event.device = InputEvent.DEVICE_ID_KEYBOARD
	azerty_event.keycode = KEY_Q
	_check(azerty_event.is_action("camera_left") and not azerty_event.is_action("camera_down"), "Q doit aller à gauche, sans conflit vertical en AZERTY.")
	azerty_event.keycode = KEY_Z
	_check(azerty_event.is_action("camera_forward"), "Z doit permettre le déplacement avant en AZERTY.")
	azerty_event.keycode = KEY_HOME
	_check(azerty_event.is_action("camera_recenter"), "Home doit permettre le recentrage.")
	var agent_positions: Array[Vector3] = []
	var agent_velocities: Array[Vector3] = []
	for ship: BlueShip in simulation.ships:
		ship.set_physics_process(false)
		agent_positions.append(ship.global_position)
		agent_velocities.append(ship.velocity)
	_send_key(KEY_F, true)
	_send_key(KEY_F, false)
	await _advance(2)
	_check(camera.mode == SimulationCamera.Mode.FREE, "F n'active pas la caméra libre.")
	_check(simulation.statistics.text == "Vaisseaux détruits : 0", "Changer la caméra modifie le compteur de destructions.")
	var pan_start: Vector3 = camera.global_position
	_send_key(KEY_RIGHT, true)
	await _advance(30)
	_send_key(KEY_RIGHT, false)
	await _advance(2)
	_check(camera.global_position.distance_to(pan_start) > 5.0, "Le pan clavier ne déplace pas la caméra.")
	pan_start = camera.global_position
	_send_key(KEY_PAGEUP, true)
	await _advance(15)
	_send_key(KEY_PAGEUP, false)
	await _advance(2)
	_check(camera.global_position.y > pan_start.y + 3.0, "Le pan vertical ne fonctionne pas.")
	var initial_basis: Basis = camera.global_basis
	_send_mouse(MOUSE_BUTTON_RIGHT, true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.screen_relative = Vector2(80.0, -25.0)
	motion.relative = motion.screen_relative
	motion.position = Vector2(950.0, 500.0)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	_send_mouse(MOUSE_BUTTON_RIGHT, false)
	await _advance(2)
	_check(not camera.global_basis.is_equal_approx(initial_basis), "Clic droit + souris ne produit pas d'orbite.")
	var initial_distance: float = camera._orbit_distance
	_send_mouse(MOUSE_BUTTON_WHEEL_UP, true)
	_send_mouse(MOUSE_BUTTON_WHEEL_UP, false)
	await _advance(2)
	_check(camera._orbit_distance < initial_distance, "La molette ne zoome pas.")
	_send_key(KEY_G, true)
	_send_key(KEY_G, false)
	await _advance(2)
	target = simulation._fleet_center() + Vector3.FORWARD * 8.0
	_check(camera._orbit_center.distance_to(target) < 0.01 and camera.mode == SimulationCamera.Mode.FREE, "G ne recentre pas la caméra libre sur le groupe actuel.")
	_send_key(KEY_F, true)
	_send_key(KEY_F, false)
	await _advance(2)
	_check(camera.mode == SimulationCamera.Mode.FOLLOW, "Le retour au suivi échoue.")
	for index: int in range(simulation.ships.size()):
		_check(simulation.ships[index].global_position.is_equal_approx(agent_positions[index]) and simulation.ships[index].velocity.is_equal_approx(agent_velocities[index]), "Les commandes caméra ont modifié un agent.")
	print("Caméra : suivi, F, pan clavier/vertical, orbite souris, zoom, G et HUD validés par événements d'entrée.")
	await _dispose(simulation)


func _camera_independence_path(free_camera: bool) -> Array[Vector3]:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	root.add_child(simulation)
	if free_camera:
		simulation.camera.toggle_mode()
		simulation.camera._orbit_center += Vector3(30.0, 15.0, 20.0)
		simulation.camera._yaw += 0.8
	for _frame: int in range(600):
		await physics_frame
	var states: Array[Vector3] = []
	for ship: BlueShip in simulation.ships:
		states.append(ship.global_position)
		states.append(ship.velocity)
	await _dispose(simulation)
	return states


func _test_camera_independence() -> void:
	var follow_states: Array[Vector3] = await _camera_independence_path(false)
	var free_states: Array[Vector3] = await _camera_independence_path(true)
	_check(follow_states.size() == free_states.size(), "La caméra change le nombre de survivants.")
	var maximum_difference: float = 0.0
	for index: int in range(mini(follow_states.size(), free_states.size())):
		maximum_difference = maxf(maximum_difference, follow_states[index].distance_to(free_states[index]))
	_check(maximum_difference < 0.001, "La caméra libre change les trajectoires ou vitesses des agents.")
	print("Indépendance caméra : même parcours de 10 s en suivi/libre, différence maximale=%.6f." % maximum_difference)


func _test_starfield_recycling() -> void:
	var simulation: SpaceSimulation = _empty_field(1)
	var decor: SpaceEnvironment = simulation.space_decor
	var anchor: Vector3 = Vector3(950.0, 450.0, -1500.0)
	decor.recycle_stars(anchor)
	var count: int = 0
	var valid_bounds: bool = true
	var valid_transforms: bool = true
	var rendering_active: bool = DisplayServer.get_name() != "headless"
	for layer: int in range(decor._star_layers.size()):
		var extent: Vector3 = SpaceEnvironment.LAYER_EXTENTS[layer]
		for index: int in range(decor._star_positions[layer].size()):
			var star_position: Vector3 = decor._star_positions[layer][index]
			var relative: Vector3 = star_position - anchor
			count += 1
			valid_bounds = valid_bounds and absf(relative.x) <= extent.x + 0.01 and absf(relative.y) <= extent.y + 0.01 and relative.z >= -extent.z - 0.01 and relative.z <= extent.z * 0.25 + 0.01
			if rendering_active:
				valid_transforms = valid_transforms and decor._star_layers[layer].multimesh.get_instance_transform(index).origin.distance_to(star_position) < 0.01
	_check(decor._star_layers.size() == 3 and count == decor.star_count, "Les trois couches d'étoiles sont incomplètes.")
	_check(valid_bounds and valid_transforms, "Le recyclage des étoiles après déplacement libre est incorrect.")
	print("Espace : trois couches, %d étoiles, recyclage latéral/arrière validé ; transforms graphiques %s." % [count, "vérifiés avec rendu" if rendering_active else "vérifiés séparément avec --capture"])
	await _dispose(simulation)


func _capture_preview() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	root.add_child(simulation)
	await _advance(180)
	await RenderingServer.frame_post_draw
	var directory_error: Error = DirAccess.make_dir_recursive_absolute("res://.godot/validation")
	_check(directory_error == OK, "Impossible de créer le dossier de capture.")
	var screenshot: Image = root.get_texture().get_image()
	_check(screenshot != null and not screenshot.is_empty(), "Capture vide : utiliser un lancement avec rendu.")
	if screenshot != null and not screenshot.is_empty():
		var save_error: Error = screenshot.save_png("res://.godot/validation/preview.png")
		_check(save_error == OK, "Impossible d'enregistrer la capture.")
		print("Capture : res://.godot/validation/preview.png")
	if OS.get_cmdline_user_args().has("--capture-drone") and not simulation.drones.is_empty():
		simulation.camera.toggle_mode()
		simulation.camera._orbit_center = simulation.drones[0].global_position
		simulation.camera._orbit_distance = 9.0
		simulation.camera._yaw = -0.6
		simulation.camera._pitch = 0.5
		await _advance(2)
		await RenderingServer.frame_post_draw
		var drone_screenshot: Image = root.get_texture().get_image()
		_check(drone_screenshot.save_png("res://.godot/validation/patrol_drone.png") == OK, "Capture drone impossible.")
		print("Capture drone : res://.godot/validation/patrol_drone.png")
	await _dispose(simulation)
	await _test_starfield_recycling()
	quit(0 if _failures == 0 else 1)
