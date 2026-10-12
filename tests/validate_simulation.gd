extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ASTEROID_SCENE: PackedScene = preload("res://scenes/asteroid.tscn")

var _failures: int = 0
var _death_signals: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture_preview()
		return
	await _test_default_field()
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
	if _failures == 0:
		print("PASS : toutes les validations du milestone 2.")
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


func _empty_field(count: int) -> SpaceSimulation:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	simulation.ship_count = count
	simulation.asteroid_rows = 0
	root.add_child(simulation)
	return simulation


func _test_default_field() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	root.add_child(simulation)
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main.tscn", "Scène principale incorrecte.")
	_check(simulation.initial_agent_count == 10 and simulation.living_agent_count == 10, "Le lancement ne crée pas dix chasseurs.")
	_check(get_nodes_in_group("blue_ships").size() == 10, "Groupe blue_ships incorrect.")
	_check(get_nodes_in_group("asteroids").size() == 48, "Le champ doit contenir 48 rochers.")
	var categories: Array[bool] = [false, false, false]
	var first_asteroid: SpaceAsteroid = get_nodes_in_group("asteroids")[0] as SpaceAsteroid
	var initial_rotation: Quaternion = first_asteroid.quaternion
	var initial_asteroid_position: Vector3 = first_asteroid.position
	for node: Node in get_nodes_in_group("asteroids"):
		var asteroid: SpaceAsteroid = node as SpaceAsteroid
		_check(asteroid.collision_layer == 2 and asteroid.collision_mask == 0, "Couches du rocher incorrectes.")
		_check(asteroid.avoidance_radius > 0.0 and asteroid.scale == Vector3.ONE, "Géométrie du rocher incorrecte.")
		categories[int(asteroid.size_category)] = true
	_check(categories[0] and categories[1] and categories[2], "Une catégorie d'astéroïde manque.")
	for ship: BlueShip in simulation.ships:
		_check(ship.collision_layer == 1 and ship.collision_mask == 2, "Couches du chasseur incorrectes.")
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
	for frame: int in range(5400):
		await physics_frame
		var avoiding: int = 0
		var center: Vector3 = simulation._fleet_center()
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
			if frame > 60 and frame % 12 == 0:
				nearest_total += nearest
				nearest_samples += 1
		max_avoiding = maxi(max_avoiding, avoiding)
	await process_frame
	_check(max_avoiding > 0, "Aucun rocher du champ n'a été anticipé.")
	_check(simulation.living_agent_count + simulation.death_count == 10, "Statistiques incohérentes après le parcours.")
	_check(simulation.living_agent_count == simulation.initial_agent_count and simulation.death_count == 0, "Le parcours normal de 90 secondes doit conserver tous les chasseurs.")
	var average_nearest: float = nearest_total / float(maxi(nearest_samples, 1))
	_check(minimum_pair_distance > 5.5, "Deux chasseurs sont trop proches durant le parcours normal.")
	_check(average_nearest >= 7.0 and average_nearest <= 12.5, "L'espace personnel moyen n'est pas confortable.")
	_check(simulation.ships.size() == get_nodes_in_group("blue_ships").size(), "Références mortes dans Main.")
	_check(max_spread < 40.0, "Le groupe par défaut s'est trop dispersé.")
	_check(simulation.camera.global_position.is_finite(), "Caméra non finie.")
	_check(absf(first_asteroid.quaternion.dot(initial_rotation)) < 0.9999, "Les astéroïdes ne tournent pas.")
	_check(first_asteroid.position.is_equal_approx(initial_asteroid_position), "La rotation introduit une translation du rocher.")
	print("Champ par défaut, 90 s : vivants=%d, morts=%d, rayon maximal=%.2f m, évitements simultanés=%d, distance minimale=%.2f m, voisin le plus proche en moyenne=%.2f m" % [simulation.living_agent_count, simulation.death_count, max_spread, max_avoiding, minimum_pair_distance, average_nearest])
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
	_check(ship.get_parent().get_node_or_null("Explosion") != null, "Explosion absente au moment de la mort.")
	ship._die()


func _test_collision_and_statistics() -> void:
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
	_check(simulation.statistics.text == "Vaisseaux vivants : 0\nMorts : 1", "HUD incorrect après collision.")
	_check(simulation.end_message.visible, "Message de destruction totale absent.")
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
	_check(simulation.camera_mode_label.text == "Mode caméra : Libre", "Mode caméra libre absent du HUD.")
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
	_check(camera.mode == SimulationCamera.Mode.FOLLOW and simulation.camera_mode_label.text == "Mode caméra : Suivi", "Le retour au suivi échoue.")
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
	await _dispose(simulation)
	await _test_starfield_recycling()
	quit(0 if _failures == 0 else 1)
