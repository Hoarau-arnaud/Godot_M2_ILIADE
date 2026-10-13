extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const ENEMY: PackedScene = preload("res://scenes/enemy_laser.tscn")
var _failures: int = 0
var _metrics: Array[Dictionary] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture-native"):
		await _native_capture()
	elif OS.get_cmdline_user_args().has("--capture-pace"):
		await _capture_pace()
	elif OS.get_cmdline_user_args().has("--capture-action"):
		await _capture_action()
	elif OS.get_cmdline_user_args().has("--render-benchmark"):
		await _render_benchmark()
	else:
		await _test_controls()
		await _test_ship_design()
		var first: Array[int] = await _camera_sequence()
		var second: Array[int] = await _camera_sequence()
		_check(first == second and first.size() >= 7, "Séquence de plans non déterministe ou trop courte.")
		await _test_camera_independence()
		await _test_projectile_variants()
		await _test_streaming()
		for pattern: int in range(ObstacleField.Pattern.ASTEROID_GATE, ObstacleField.Pattern.ASTEROID_CANYON + 1):
			await _test_barrage(pattern)
		await _test_barrage(ObstacleField.Pattern.DIVE, true)
		if not OS.get_cmdline_user_args().has("--unit-only"):
			await _test_run(false)
			await _test_run(true)
		var output: FileAccess = FileAccess.open("res://.godot/m8_metrics.json", FileAccess.WRITE)
		output.store_string(JSON.stringify(_metrics, "\t"))
	print("PASS : cinématique, barrages, design spatial et présentation M8." if _failures == 0 else "FAIL : %d validations M8." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await physics_frame
	await process_frame


func _empty(count: int = 10) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.capital_ships_enabled = false
	sim.ship_count = count
	sim.simulation_speed_multiplier = 1.0
	sim.streaming_enabled = false
	sim.drones_enabled = false
	sim.interceptors_enabled = false
	(sim.get_node("Asteroids") as ObstacleField).moving_asteroids_enabled = false
	(sim.get_node("Asteroids") as ObstacleField).irregular_barrages = false
	root.add_child(sim)
	return sim


func _dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await _advance(2)
	_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Engine non restauré après M8.")
	for group: String in ["blue_ships", "patrol_drones", "interceptors", "asteroids", "hostile_agents", "blue_lasers", "hostile_projectiles", "explosions"]:
		_check(get_nodes_in_group(group).is_empty(), "Objet M8 conservé après suppression : %s." % group)


func _key(code: Key, alt: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.keycode = code
	event.alt_pressed = alt
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)


func _test_controls() -> void:
	var sim: SpaceSimulation = _empty()
	var ui: DemoControls = sim.demo_controls
	_check(ui.help_panel.visible, "Aide non visible au lancement.")
	var c_event: InputEventKey = InputEventKey.new()
	c_event.device = InputEvent.DEVICE_ID_KEYBOARD
	c_event.keycode = KEY_C
	_check(c_event.is_action("camera_cinematic") and not c_event.is_action("camera_down"), "C est en conflit avec la descente caméra.")
	c_event.keycode = KEY_F11
	_check(c_event.is_action("presentation_fullscreen"), "F11 absent des Input Actions.")
	c_event.keycode = KEY_ENTER
	c_event.alt_pressed = true
	_check(c_event.is_action("presentation_fullscreen"), "Alt+Enter absent des Input Actions.")
	_key(KEY_C)
	await _advance(2)
	_check(sim.camera.mode == SimulationCamera.Mode.CINEMATIC and ui.cinematic_button.button_pressed, "C ne synchronise pas le mode/bouton cinématique.")
	_key(KEY_C)
	await _advance(2)
	_check(sim.camera.mode == SimulationCamera.Mode.FOLLOW and not ui.cinematic_button.button_pressed, "C ne revient pas en FOLLOW.")
	ui.cinematic_button.pressed.emit()
	_key(KEY_F)
	await _advance(2)
	_check(sim.camera.mode == SimulationCamera.Mode.FREE and not ui.cinematic_button.button_pressed, "F ne reprend pas une caméra libre depuis CINEMATIC.")
	_key(KEY_H)
	_key(KEY_TAB)
	await _advance(2)
	_check(not ui.help_panel.visible and not ui.panel.visible and ui.stars.visible, "H/TAB masquent les étoiles ou laissent l'aide visible.")
	var visible_labels: int = 0
	for node: Node in sim.find_children("*", "Label", true, false):
		if (node as Label).is_visible_in_tree():
			visible_labels += 1
	_check(visible_labels == 4, "Le HUD vidéo comporte autre chose que le compteur et les trois étoiles.")
	sim.ships[0].take_damage(3)
	sim.distance_travelled = 321
	ui.action_button.pressed.emit()
	await _advance(2)
	_check(sim.manual_difficulty == 3 and sim.simulation_speed_multiplier == 1.7 and sim.movement_multiplier == 1.3 and sim.target_drone_count() == 0, "Preset Action ou fixture sans drones incorrect.")
	_check(sim.manual_drone_count_override == 5 and sim.manual_interceptor_count_override == 4 and sim.camera.mode == SimulationCamera.Mode.CINEMATIC, "Preset Action incomplet.")
	ui.normal_button.pressed.emit()
	await _advance(2)
	_check(sim.movement_multiplier == 1.2 and sim.manual_drone_count_override == -1 and sim.manual_interceptor_count_override == -1 and sim.camera.mode == SimulationCamera.Mode.FOLLOW, "Preset Normal incomplet.")
	_check(sim.death_count == 1 and sim.distance_travelled >= 321 and sim.ships.size() >= 9 and sim.target_ship_count == 15, "Un preset réinitialise les morts, la distance ou les agents.")
	print("Commandes : C/F, H/TAB, F11/Alt+Enter et presets sans reset validés.")
	await _dispose(sim)


func _test_ship_design() -> void:
	var sim: SpaceSimulation = _empty(1)
	var ship: BlueShip = sim.ships[0]
	ship.set_physics_process(false)
	ship.velocity = Vector3(5, 0, -10)
	ship._update_orientation(10.0)
	_check(ship._visuals.basis.x.y < -0.1, "Déplacement droit sans aile droite abaissée.")
	ship.velocity = Vector3(-5, 0, -10)
	ship._update_orientation(10.0)
	_check(ship._visuals.basis.x.y > 0.1, "Déplacement gauche sans aile gauche abaissée.")
	ship.velocity = Vector3(0, 5, -10)
	ship._update_orientation(10.0)
	_check((-ship._visuals.basis.z).y > 0.04, "Montée sans nez relevé.")
	ship.velocity = Vector3(0, -5, -10)
	ship._update_orientation(10.0)
	_check((-ship._visuals.basis.z).y < -0.04, "Descente sans nez abaissé.")
	ship.velocity = Vector3.FORWARD * ship.forward_speed
	ship._update_exhausts()
	var low_thrust: float = ship._left_exhaust.scale.y
	ship.velocity *= 1.5
	ship._update_exhausts()
	_check(ship._left_exhaust.scale.y > low_thrust, "Flamme sans variation de vitesse.")
	_check((ship.get_node("HullCollision").shape as BoxShape3D).size == Vector3(0.78, 0.5, 3.15) and (ship.get_node("WingCollision").shape as BoxShape3D).size == Vector3(2.8, 0.16, 1.25), "Hitboxes M7 modifiées par le nouveau design.")
	_check(ship.rotation.is_zero_approx(), "Le banking tourne la racine de collision.")
	print("Design : banking dans le sens du déplacement, pitch, flammes et hitboxes stables validés.")
	await _dispose(sim)


func _camera_sequence() -> Array[int]:
	var sim: SpaceSimulation = _empty()
	sim.set_process(false)
	sim.set_physics_process(false)
	var camera: SimulationCamera = sim.camera
	camera.initialize_view(Vector3.ZERO, sim.simulation_seed)
	camera.set_mode(SimulationCamera.Mode.CINEMATIC)
	var positions: Array[Vector3] = [Vector3(-10, -6, -8), Vector3(10, 6, 8)]
	var max_step: float = 0
	for _frame: int in range(5400):
		var before: Vector3 = camera.position
		camera.observe_group(Vector3.ZERO, 20, 1.0 / 60.0, positions, 0.5)
		max_step = maxf(max_step, before.distance_to(camera.position))
		_check(camera.position.is_finite() and camera.fov >= 54 and camera.fov <= 70, "Position/FOV cinématique invalides.")
	_check(camera.shot_changes >= 7 and max_step < 1.5, "Plans absents ou transition de caméra trop brusque.")
	var history: Array[int] = camera.shot_history.duplicate()
	print("Plans 90 s contrôlés : " + str(history) + ", pas caméra max=%.3f m." % max_step)
	await _dispose(sim)
	return history


func _camera_path(cinematic: bool) -> Array[Vector3]:
	var sim: SpaceSimulation = _empty()
	if cinematic:
		sim.camera.set_mode(SimulationCamera.Mode.CINEMATIC)
	var result: Array[Vector3] = []
	await _advance(600)
	for ship: BlueShip in sim.ships:
		result.append(ship.position)
	await _dispose(sim)
	return result


func _test_camera_independence() -> void:
	var follow: Array[Vector3] = await _camera_path(false)
	var cinematic: Array[Vector3] = await _camera_path(true)
	var maximum: float = 0
	for index: int in range(follow.size()):
		maximum = maxf(maximum, follow[index].distance_to(cinematic[index]))
	_check(maximum < 0.0001, "La caméra cinématique modifie la trajectoire des agents.")
	print("Indépendance cinématique/SMA : écart maximal=%.6f m." % maximum)


func _test_projectile_variants() -> void:
	var sim: SpaceSimulation = _empty(1)
	for variant: EnemyLaser.VisualVariant in [EnemyLaser.VisualVariant.BOLT, EnemyLaser.VisualVariant.SPEAR, EnemyLaser.VisualVariant.PULSE]:
		var bolt: EnemyLaser = ENEMY.instantiate() as EnemyLaser
		bolt.visual_variant = variant
		bolt.position = Vector3(200, 200, 0)
		sim.projectile_container.add_child(bolt)
		var start: Vector3 = bolt.position
		await _advance(6)
		_check(bolt.position.z < start.z and bolt.projectile_speed == 45 and bolt.damage == 1 and bolt.lifetime == 3.5 and bolt.flight_direction == Vector3.FORWARD, "Une variante change la logique du projectile.")
		_check(bolt.get_node("Bolt").visible == (variant == EnemyLaser.VisualVariant.BOLT) and bolt.get_node("Spear").visible == (variant == EnemyLaser.VisualVariant.SPEAR) and bolt.get_node("Pulse").visible == (variant == EnemyLaser.VisualVariant.PULSE), "Variante visuelle incorrecte.")
		bolt.queue_free()
	print("Lasers : BOLT/SPEAR/PULSE distincts, logique 45 m/s, 1 dégât, 3,5 s conservée.")
	await _dispose(sim)


func _test_streaming() -> void:
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	for ship: BlueShip in sim.ships:
		ship.set_physics_process(false)
	var field: ObstacleField = sim.asteroid_container
	field.initialize_field(sim.simulation_seed, Vector3.ZERO, 0)
	field.difficulty_override = 3
	_check(field.allowed_patterns(1).size() == 2 and field.allowed_patterns(2).has(ObstacleField.Pattern.ASTEROID_GATE) and field.allowed_patterns(3).size() == 10, "Distribution des nouveaux patterns incorrecte.")
	for index: int in range(70):
		var center: Vector3 = Vector3(sin(index * 0.3) * 18, cos(index * 0.17) * 10, -index * 120)
		field.advance(center, center.z - 14, center.z + 28)
		_check(field.active_asteroid_count <= field.max_active_asteroids, "Un barrage dépasse le budget d'astéroïdes.")
		await _advance(2)
	for pattern: int in range(6, 12):
		_check(field.patterns_generated.has(pattern), "Un nouveau pattern n'apparaît jamais dans le streaming : %d." % pattern)
	_check(field.removed_configuration_count > 0, "Les barrages ne sont jamais nettoyés.")
	print("Streaming M8 : types=%d, configurations=%d/%d, astéroïdes max=%d." % [field.patterns_generated.size(), field.generated_configuration_count, field.removed_configuration_count, field.maximum_active_observed])
	await _dispose(sim)


func _test_barrage(pattern: int, inverted: bool = false) -> void:
	var sim: SpaceSimulation = _empty()
	var field: ObstacleField = sim.asteroid_container
	if inverted:
		field.generated_configuration_count = 1
	field._spawn_configuration(pattern, 3, Vector3.ZERO, -65)
	var configuration: Node3D = field.configurations.back()
	configuration.position = Vector3(0, 0, -65)
	for index: int in range(sim.ships.size()):
		sim.ships[index].position = Vector3((index - 4.5) * 4.4, -5 if index % 2 == 0 else 5, 0)
	var passages: Array[Vector3] = field.passage_points(pattern, inverted)
	var clearance_min: float = INF
	for point: Vector3 in passages:
		for node: Node in configuration.get_children():
			var asteroid: SpaceAsteroid = node as SpaceAsteroid
			clearance_min = minf(clearance_min, point.distance_to(asteroid.position) - asteroid.avoidance_radius - BlueShip.SHIP_CLEARANCE)
	_check(clearance_min > 5.0, "Un passage déclaré n'est pas suffisamment ouvert.")
	var avoidance_ticks: int = 0
	var max_dispersion: float = 0
	var directions: Dictionary[String, bool] = {}
	for frame: int in range(1800):
		await physics_frame
		for ship: BlueShip in sim.ships:
			if ship.behavior_state == BlueShip.BehaviorState.AVOIDANCE:
				avoidance_ticks += 1
			for direction: Vector3 in ship._avoid_directions.values():
				directions["%d/%d" % [signi(int(direction.x * 100)), signi(int(direction.y * 100))]] = true
		if frame % 30 == 0:
			sim._measure_group(sim._fleet_center())
			max_dispersion = maxf(max_dispersion, sim.dispersion)
	sim._measure_group(sim._fleet_center())
	_check(sim.living_agent_count >= 5 and avoidance_ticks > 0, "Barrage sans évitement visible ou extermination du groupe.")
	_check(sim.isolated_agent_count <= 2 and sim.average_spacing < 22, "Regroupement insuffisant après le barrage.")
	var metrics: Dictionary = {"test": "BARRAGE", "pattern": ObstacleField.Pattern.keys()[pattern], "inverted": inverted, "clearance_min_m": clearance_min, "alive": sim.living_agent_count, "deaths": sim.death_count, "avoidance_agent_ticks": avoidance_ticks, "directions": directions.size(), "dispersion_max_m": max_dispersion, "dispersion_final_m": sim.dispersion, "spacing_final_m": sim.average_spacing, "isolated_final": sim.isolated_agent_count}
	_metrics.append(metrics)
	print("M8 BARRAGE " + JSON.stringify(metrics))
	await _dispose(sim)


func _test_run(action: bool) -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.capital_ships_enabled = false
	(sim.get_node("Asteroids") as ObstacleField).moving_asteroids_enabled = false
	sim.manual_difficulty = 3
	(sim.get_node("Asteroids") as ObstacleField).irregular_barrages = false
	root.add_child(sim)
	var seconds: int = 60 if action else 90
	if action:
		sim.demo_controls.action_button.pressed.emit()
	else:
		sim.set_movement_multiplier(1.25)
		sim.camera.set_mode(SimulationCamera.Mode.CINEMATIC)
	var rate: int = Engine.physics_ticks_per_second
	var nodes_max: int = get_node_count()
	var max_dispersion: float = 0
	var frame_samples: int = 0
	var framed_ships: int = 0
	var total_ships: int = 0
	var cam_step_max: float = 0
	var camera_clearance_min: float = INF
	var previous_camera: Vector3 = sim.camera.position
	var previous_center: Vector3 = sim._fleet_center()
	var previous_process: int = -1
	var last_sample_process: int = -10
	var wall_start: int = Time.get_ticks_usec()
	for frame: int in range(seconds * rate):
		await physics_frame
		var process_index: int = Engine.get_process_frames()
		if process_index == previous_process:
			continue
		previous_process = process_index
		var center: Vector3 = sim._fleet_center()
		cam_step_max = maxf(cam_step_max, ((sim.camera.position - previous_camera) - (center - previous_center)).length())
		previous_camera = sim.camera.position
		previous_center = center
		if process_index - last_sample_process < 6:
			continue
		last_sample_process = process_index
		frame_samples += 1
		nodes_max = maxi(nodes_max, get_node_count())
		sim._measure_group(center)
		max_dispersion = maxf(max_dispersion, sim.dispersion)
		for node: Node in get_nodes_in_group("asteroids"):
			var asteroid: SpaceAsteroid = node as SpaceAsteroid
			camera_clearance_min = minf(camera_clearance_min, sim.camera.position.distance_to(asteroid.global_position) - asteroid.avoidance_radius)
		var rectangle: Rect2 = root.get_visible_rect().grow(8)
		for ship: BlueShip in sim.ships:
			total_ships += 1
			if not sim.camera.is_position_behind(ship.position) and rectangle.has_point(sim.camera.unproject_position(ship.position)):
				framed_ships += 1
			_check(ship.position.is_finite() and ship.velocity.z < 0, "Un agent ne progresse plus dans le parcours cinématique.")
		_check(sim.asteroid_container.active_asteroid_count <= 96 and nodes_max < 3000 and sim.projectile_container.get_child_count() <= 160, "Budget de scène M8 dépassé.")
		_check(sim.living_agent_count + sim.death_count + sim.ship_retired_count == sim.ship_spawn_count, "Métriques BlueShip incohérentes.")
	await process_frame
	var elapsed: int = Time.get_ticks_usec() - wall_start
	var framed_ratio: float = float(framed_ships) / maxi(total_ships, 1)
	_check(sim.camera.shot_changes >= 5 and sim.living_agent_count > 0 and framed_ratio > 0.95, "Cinématique sans plans, sans survivants ou cadrage insuffisant.")
	_check(cam_step_max < 3.0, "Saut de caméra dans le parcours cinématique.")
	_check(camera_clearance_min >= 0, "La caméra entre dans l'enveloppe d'un astéroïde.")
	_check(sim.blue_shots_fired > 0 and sim.enemy_shots_fired > 0 and sim.projectile_dodge_count > 0, "Parcours sans combat ou esquive.")
	var metrics: Dictionary = {"test": "ACTION" if action else "CINEMATIC", "demo_seconds": seconds, "simulation_seconds": seconds * sim.simulation_speed_multiplier, "speed": sim.simulation_speed_multiplier, "movement": sim.movement_multiplier, "blue_alive": sim.living_agent_count, "blue_deaths": sim.death_count, "green_active": sim.drones.size(), "red_active": sim.interceptors.size(), "green_kills": sim.drones_destroyed, "red_kills": sim.interceptors_destroyed, "blue_shots": sim.blue_shots_fired, "blue_hits": sim.hostile_hits, "red_shots": sim.enemy_shots_fired, "red_hits": sim.blue_ship_hits, "dodges": sim.projectile_dodge_count, "projectiles_max": sim.maximum_active_projectiles, "asteroids_max": sim.asteroid_container.maximum_active_observed, "nodes_max": nodes_max, "dispersion_max_m": max_dispersion, "dispersion_final_m": sim.dispersion, "spacing_final_m": sim.average_spacing, "shot_changes": sim.camera.shot_changes, "shot_history": sim.camera.shot_history, "framed_center_ratio": framed_ratio, "camera_relative_step_max_m": cam_step_max, "cpu_ms_per_tick": float(elapsed) / (seconds * rate) / 1000.0, "wall_seconds": elapsed / 1000000.0}
	_metrics.append(metrics)
	metrics["camera_clearance_min_m"] = camera_clearance_min
	print("M8 RUN " + JSON.stringify(metrics))
	await _dispose(sim)


func _native_capture() -> void:
	_check(DisplayServer.get_name() != "headless", "Les tests plein écran et captures nécessitent le rendu.")
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.capital_ships_enabled = false
	sim.manual_difficulty = 3
	(sim.get_node("Asteroids") as ObstacleField).irregular_barrages = false
	root.add_child(sim)
	sim.apply_action_preset()
	await _advance(360)
	DirAccess.make_dir_recursive_absolute("res://.godot/validation")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 450)]:
		DisplayServer.window_set_size(resolution)
		await _advance(12)
		_check(DisplayServer.window_get_size() == resolution, "Résolution de fenêtre incorrecte.")
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		_check(screenshot.get_size() == resolution, "Résolution de capture incorrecte.")
		_check(screenshot.save_png("res://.godot/validation/m8_" + str(resolution.x) + "x" + str(resolution.y) + ".png") == OK, "Capture impossible.")
		_check(sim.demo_controls.panel.get_global_rect().end.y <= root.get_visible_rect().size.y and sim.demo_controls.help_panel.get_global_rect().position.y >= 0, "Un panneau sort du viewport.")
	var window_size: Vector2i = DisplayServer.window_get_size()
	var window_position: Vector2i = DisplayServer.window_get_position()
	_key(KEY_F11)
	await _advance(12)
	_check(sim.presentation_window.is_fullscreen() and sim.demo_controls.fullscreen_button.button_pressed, "F11 ne passe pas en plein écran.")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/m8_fullscreen.png")
	_key(KEY_F11)
	await _advance(12)
	_check(not sim.presentation_window.is_fullscreen() and DisplayServer.window_get_size() == window_size and DisplayServer.window_get_position() == window_position, "Sortie plein écran sans restitution de taille/position.")
	_key(KEY_ENTER, true)
	await _advance(12)
	_check(sim.presentation_window.is_fullscreen(), "Alt+Enter ne passe pas en plein écran.")
	sim.demo_controls.fullscreen_button.pressed.emit()
	await _advance(12)
	_check(not sim.presentation_window.is_fullscreen(), "Bouton plein écran ne revient pas en fenêtre.")
	_key(KEY_H)
	_key(KEY_TAB)
	await _advance(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/m8_clean.png")
	print("NATIVE : 1280×720, 1920×1080, 800×450, F11/Alt+Enter/bouton et H/TAB validés.")
	await _dispose(sim)
	await _capture_ship()


func _capture_ship() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var sim: SpaceSimulation = _empty(1)
	sim.set_process(false)
	sim.set_physics_process(false)
	sim.get_node("HUD").hide()
	sim.demo_controls.hide()
	var ship: BlueShip = sim.ships[0]
	ship.position = Vector3.ZERO
	ship.set_physics_process(false)
	ship.velocity = Vector3.FORWARD * 13
	ship._update_exhausts()
	sim.camera.position = Vector3(8, 6, 10)
	sim.camera.fov = 38
	sim.camera.look_at(Vector3(0, 0, 0.2))
	await _advance(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/m8_blue_ship.png")
	sim.camera.position = Vector3(0, 14, 3)
	sim.camera.look_at(Vector3.ZERO)
	await _advance(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/m8_blue_ship_top.png")
	await _dispose(sim)


func _capture_pace() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for speed: float in [1.7, 1.8]:
		var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
		sim.capital_ships_enabled = false
		sim.manual_difficulty = 3
		sim.simulation_speed_multiplier = speed
		sim.movement_multiplier = 1.25
		(sim.get_node("Asteroids") as ObstacleField).irregular_barrages = false
		root.add_child(sim)
		sim.camera.set_mode(SimulationCamera.Mode.CINEMATIC)
		sim.demo_controls.toggle_help()
		sim.demo_controls.toggle_panel()
		var rate: int = Engine.physics_ticks_per_second
		for seconds: int in [4, 8, 12]:
			await _advance(4 * rate)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m8_pace_%d_%ds.png" % [roundi(speed * 10), seconds])
		_check(sim.living_agent_count > 0 and sim.camera.shot_changes > 0, "Comparaison de rythme sans survivants ou changement de plan.")
		print("PACE %.1fx : 12 s demo, %.1f s simulation, %d vivants, %d morts, %d tirs bleus / %d rouges, %d plans changés, dispersion %.2f m." % [speed, 12 * speed, sim.living_agent_count, sim.death_count, sim.blue_shots_fired, sim.enemy_shots_fired, sim.camera.shot_changes, sim.dispersion])
		await _dispose(sim)


func _capture_action() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.capital_ships_enabled = false
	sim.manual_difficulty = 3
	(sim.get_node("Asteroids") as ObstacleField).irregular_barrages = false
	root.add_child(sim)
	sim.apply_action_preset()
	sim.demo_controls.toggle_help()
	sim.demo_controls.toggle_panel()
	var rate: int = Engine.physics_ticks_per_second
	for seconds: int in [10, 20, 30, 40, 50, 60]:
		await _advance(10 * rate)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m8_action_%ds.png" % seconds)
		print("CAPTURE spectacle %ds : plan %s, %d BlueShip, %d projectiles actifs." % [seconds, SimulationCamera.Shot.keys()[sim.camera.cinematic_shot], sim.living_agent_count, sim.projectile_container.get_child_count()])
	_check(sim.camera.shot_changes >= 5 and sim.blue_shots_fired > 0 and sim.enemy_shots_fired > 0, "Capture spectacle sans plans ou combat.")
	await _dispose(sim)


func _render_benchmark() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.capital_ships_enabled = false
	sim.manual_difficulty = 3
	(sim.get_node("Asteroids") as ObstacleField).irregular_barrages = false
	root.add_child(sim)
	sim.apply_action_preset()
	sim.demo_controls.toggle_help()
	sim.demo_controls.toggle_panel()
	var started: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < 3000000:
		await process_frame
	var frames_start: int = Engine.get_frames_drawn()
	started = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < 12000000:
		await process_frame
	var real_seconds: float = (Time.get_ticks_usec() - started) / 1000000.0
	var metrics: Dictionary = {"test": "GRAPHICS", "resolution": str(DisplayServer.window_get_size()), "real_seconds": real_seconds, "fps_mean": (Engine.get_frames_drawn() - frames_start) / real_seconds, "fps_engine_final": Engine.get_frames_per_second(), "vsync_mode": DisplayServer.window_get_vsync_mode(), "blue_alive": sim.living_agent_count, "asteroids": sim.asteroid_container.active_asteroid_count}
	var output: FileAccess = FileAccess.open("res://.godot/m8_graphics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics, "\t"))
	print("M8 GRAPHICS " + JSON.stringify(metrics))
	await _dispose(sim)
