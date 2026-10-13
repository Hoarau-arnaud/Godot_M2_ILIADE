extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const ROCK: PackedScene = preload("res://scenes/asteroid.tscn")
const BLUE_LASER: PackedScene = preload("res://scenes/blue_laser.tscn")
const ENEMY_LASER: PackedScene = preload("res://scenes/enemy_laser.tscn")

var _failures: int = 0
var _runtime_births: int = 0
var _metrics: Array[Dictionary] = []


func _initialize() -> void:
	# Le pilote headless démarre à 64×64 : aligner les coordonnées d'entrée sur la vue de jeu.
	root.size = Vector2i(1280, 720)
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture-demo"):
		await _capture()
	else:
		await _test_stars_and_toggle()
		await _test_speed_and_camera()
		if OS.get_cmdline_user_args().has("--ui-only"):
			quit(0 if _failures == 0 else 1)
			return
		await _test_blue_population()
		await _test_enemy_overrides()
		await _test_spacing()
		var calm: Dictionary = await _movement_probe(0.5)
		var lively: Dictionary = await _movement_probe(2.0)
		_check(float(lively["side_speed"]) > float(calm["side_speed"]) * 1.15, "Le mouvement 2,0 n'augmente pas la mobilité X/Y.")
		print("Mouvement comparé : " + JSON.stringify({"0.5": calm, "2.0": lively}))
		if not OS.get_cmdline_user_args().has("--unit-only"):
			await _test_run(false)
			await _test_run(true)
			var output: FileAccess = FileAccess.open("res://.godot/m7_metrics.json", FileAccess.WRITE)
			output.store_string(JSON.stringify(_metrics, "\t"))
	print("PASS : étoiles, contrôles runtime, populations, rythme et caméra M7." if _failures == 0 else "FAIL : %d validations M7." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await physics_frame
	await process_frame


func _dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await _advance(2)
	_check(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60, "Réglages Engine non restaurés à la fermeture.")
	for group: String in ["blue_ships", "patrol_drones", "interceptors", "hostile_agents", "blue_lasers", "hostile_projectiles", "asteroids"]:
		_check(get_nodes_in_group(group).is_empty(), "Objet non nettoyé après test M7 : %s." % group)


func _empty(count: int = 10) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.5)
	sim.simulation_speed_multiplier = 1.0
	sim.ship_count = count
	sim.streaming_enabled = false
	sim.drones_enabled = false
	sim.interceptors_enabled = false
	root.add_child(sim)
	return sim


func _key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)


func _mouse(button: MouseButton, pressed: bool, pos: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_MOUSE
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT and pressed else 0
	root.push_input(event, true)


func _motion(pos: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.relative = Vector2(80, -25)
	motion.screen_relative = motion.relative
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion, true)


func _test_stars_and_toggle() -> void:
	var sim: SpaceSimulation = _empty()
	var ui: DemoControls = sim.demo_controls
	for level: int in range(1, 4):
		_key(KEY_1 + level - 1 as Key)
		await _advance(2)
		_check(sim.difficulty_level == level and ui.stars_text() == ["★☆☆", "★★☆", "★★★"][level - 1], "Étoiles incorrectes au niveau %d." % level)
	_check(ui.panel.visible, "Panneau caché au lancement.")
	_key(KEY_TAB)
	await _advance(2)
	_check(not ui.panel.visible and ui.stars.visible and sim.statistics.is_visible_in_tree(), "TAB masque le HUD principal ou laisse le panneau visible.")
	_check(ui.stars_text() == "★★★" and sim.statistics.text == "Vaisseaux bleus détruits : 0", "HUD masqué incorrect.")
	_key(KEY_TAB)
	await _advance(2)
	_check(ui.panel.visible, "TAB ne réaffiche pas le panneau.")
	# AUTO progresse réellement, avec seuils raccourcis uniquement dans la fixture.
	sim.asteroid_container.intermediate_distance = 10.0
	sim.asteroid_container.hard_distance = 20.0
	_key(KEY_0)
	await _advance(65)
	_check(sim.manual_difficulty == 0 and sim.difficulty_level == 2 and ui.stars_text() == "★★☆", "AUTO ne met pas à jour les étoiles au seuil intermédiaire.")
	await _advance(65)
	_check(sim.difficulty_level == 3 and ui.stars_text() == "★★★", "AUTO ne met pas à jour les étoiles au seuil difficile.")
	print("HUD : 1/2/3, AUTO naturel et TAB validés ; étoiles indépendantes du panneau.")
	await _dispose(sim)


func _test_speed_and_camera() -> void:
	var sim: SpaceSimulation = _empty()
	var ui: DemoControls = sim.demo_controls
	var camera: SimulationCamera = sim.camera
	_key(KEY_F)
	await _advance(2)
	_check(camera.mode == SimulationCamera.Mode.FREE, "Caméra libre indisponible.")
	sim.set_process(false)
	var pan_distances: Array[float] = []
	for speed: float in [0.5, 1.0, 1.5, 2.0, 2.5]:
		ui.speed_slider.value = speed
		_check(is_equal_approx(Engine.time_scale, speed) and Engine.physics_ticks_per_second >= 60 and Engine.physics_ticks_per_second % 60 == 0, "Slider vitesse ou fréquence physique incorrects.")
		_check(Engine.time_scale / Engine.physics_ticks_per_second <= 1.0 / 60.0 + 0.00001, "Pas physique trop grand avec time_scale.")
		var blue: BlueLaser = BLUE_LASER.instantiate() as BlueLaser
		FlightTuning.legacy_actor(blue)
		var red: EnemyLaser = ENEMY_LASER.instantiate() as EnemyLaser
		FlightTuning.legacy_actor(red)
		blue.position = Vector3(200, 200, -300)
		red.position = Vector3(-200, 200, -300)
		sim.projectile_container.add_child(blue)
		sim.projectile_container.add_child(red)
		var start: Vector3 = sim.ships[0].position
		await _advance(12)
		_check(sim.ships[0].position.z < start.z and blue.position.z < -300 and red.position.z < -300, "Agents ou projectiles arrêtés par le multiplicateur.")
		camera._orbit_center = Vector3.ZERO
		Input.action_press("camera_right")
		for _step: int in range(24):
			camera.observe_group(Vector3.ZERO, 0, speed / 60.0)
		Input.action_release("camera_right")
		pan_distances.append(camera._orbit_center.length())
		_check(absf(pan_distances.back() - 9.6) < 0.01, "La vitesse de pan dépend de time_scale.")
		blue.queue_free()
		red.queue_free()
	sim.set_simulation_speed(1.0)
	await _advance(2)
	var panel_position: Vector2 = ui.speed_slider.get_global_rect().get_center()
	var yaw: float = camera._yaw
	var zoom: float = camera._orbit_distance
	_mouse(MOUSE_BUTTON_RIGHT, true, panel_position)
	_motion(panel_position)
	_mouse(MOUSE_BUTTON_RIGHT, false, panel_position)
	_mouse(MOUSE_BUTTON_WHEEL_UP, true, panel_position)
	_mouse(MOUSE_BUTTON_WHEEL_UP, false, panel_position)
	await _advance(2)
	_check(is_equal_approx(camera._yaw, yaw) and is_equal_approx(camera._orbit_distance, zoom) and not camera._dragging, "Un événement UI déclenche l'orbite ou le zoom.")
	# Le même geste reste opérationnel hors du panneau.
	var space_position: Vector2 = Vector2(350, 500)
	_mouse(MOUSE_BUTTON_RIGHT, true, space_position)
	_motion(space_position)
	_mouse(MOUSE_BUTTON_RIGHT, false, panel_position)
	await _advance(2)
	_check(not is_equal_approx(camera._yaw, yaw) and not camera._dragging, "L'orbite libre ou sa release au-dessus de l'UI échoue.")
	_key(KEY_HOME)
	await _advance(2)
	_check(camera.mode == SimulationCamera.Mode.FREE, "Home change le mode caméra.")
	print("Vitesse 0,5/1/1,5/2/2,5 : agents/tirs actifs, pan constant 9,6 m, UI sans orbite/zoom parasite.")
	await _dispose(sim)


func _on_runtime_birth(node: Node, sim: SpaceSimulation) -> void:
	var ship: BlueShip = node as BlueShip
	if ship == null:
		return
	_runtime_births += 1
	_check(ship.is_in_group("blue_ships") and ship.individual_seed != 0 and ship.combat_enabled and ship.fired.is_connected(sim._on_ship_fired), "BlueShip ajouté sans groupe, seed ou combat.")
	_check(ship.demo_movement_multiplier == sim.movement_multiplier and ship.demo_spacing_multiplier == sim.spacing_multiplier, "Nouveau chasseur sans les réglages de démonstration courants.")
	for other: BlueShip in sim.ships:
		_check(ship.global_position.distance_to(other.global_position) >= sim.initial_ship_spacing, "Spawn bleu superposé à un autre BlueShip.")
	for rock: Node in get_nodes_in_group("asteroids"):
		var asteroid: SpaceAsteroid = rock as SpaceAsteroid
		_check(ship.global_position.distance_to(asteroid.global_position) > asteroid.avoidance_radius + BlueShip.SHIP_CLEARANCE, "Spawn bleu dans un rocher.")


func _test_blue_population() -> void:
	var sim: SpaceSimulation = _empty()
	var rock: SpaceAsteroid = ROCK.instantiate() as SpaceAsteroid
	FlightTuning.legacy_actor(rock)
	rock.position = sim._fleet_center() + Vector3(0, 0, 18)
	rock.diameter = 7
	rock.rotation_speed = 0
	sim.asteroid_container.add_child(rock)
	_runtime_births = 0
	sim.ship_container.child_entered_tree.connect(_on_runtime_birth.bind(sim))
	for ship: BlueShip in sim.ships:
		ship.set_physics_process(false)
	sim.demo_controls.movement_slider.value = 1.5
	sim.demo_controls.spacing_slider.value = 1.2
	for _press: int in range(5):
		sim.demo_controls.plus_buttons["BlueShip"].pressed.emit()
	await _advance(3)
	_check(sim.ships.size() < 15 and sim.target_ship_count == 15, "Ajout bleu non progressif.")
	await _advance(150)
	_check(sim.ships.size() == 15 and _runtime_births == 5 and sim.death_count == 0, "10→15 ne crée pas cinq BlueShip sans mort.")
	var active_new_ship: BlueShip = sim.ships.back()
	_check(active_new_ship.neighbor_count > 0, "Un nouveau BlueShip ne rejoint pas le flocking local.")
	sim.set_ship_count(8)
	await _advance(2)
	_check(sim.ships.size() == 8 and get_nodes_in_group("blue_ships").size() == 8 and sim.ship_retired_count == 7 and sim.death_count == 0, "15→8 compte un retrait comme une mort.")
	_check(sim.ship_container.find_children("Explosion*", "Node3D", false, false).is_empty(), "Retrait bleu avec explosion.")
	sim.ships[0].take_damage(3)
	await _advance(90)
	_check(sim.ships.size() == 7 and sim.target_ship_count == 7 and sim.death_count == 1 and sim.ship_spawn_count == 15, "Un décès bleu est remplacé automatiquement ou mal compté.")
	_check(sim.living_agent_count + sim.death_count + sim.ship_retired_count == sim.ship_spawn_count, "Bilan naissance/retrait/mort incohérent.")
	sim.set_ship_count(100)
	_check(sim.target_ship_count == 20, "Borne haute BlueShip incorrecte.")
	sim.set_ship_count(-10)
	_check(sim.target_ship_count == 5 and sim.death_count == 1, "Borne basse ou compteur de morts modifié par le panneau.")
	print("BlueShip : 10→15→8, spawn sûr/progressif, flocking/combat, retrait sans explosion, pertes non remplacées.")
	await _dispose(sim)


func _test_enemy_overrides() -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.5)
	sim.simulation_speed_multiplier = 1.0
	sim.manual_difficulty = 3
	sim.streaming_enabled = false
	root.add_child(sim)
	for ship: BlueShip in sim.ships:
		ship.set_physics_process(false)
	sim.set_drone_count_override(6)
	sim.set_interceptor_count_override(5)
	await _advance(3)
	_check(sim.drones.size() < 6 and sim.interceptors.size() < 5, "Ennemis ajoutés tous dans la même frame.")
	await _advance(120)
	_check(sim.drones.size() == 6 and sim.interceptors.size() == 5, "Overrides 6/5 non atteints.")
	sim.set_difficulty_mode(1)
	await _advance(2)
	_check(sim.target_drone_count() == 6 and sim.target_interceptor_count() == 5 and sim.demo_controls.stars_text() == "★☆☆", "Changement de difficulté efface les overrides ou les étoiles reflètent la population.")
	sim.set_difficulty_mode(3)
	sim.ships[0].take_damage(3)
	sim.distance_travelled = 321.0
	var field_id: int = sim.asteroid_container.get_instance_id()
	sim.demo_controls.reset_button.pressed.emit()
	await _advance(2)
	_check(sim.manual_drone_count_override == -1 and sim.manual_interceptor_count_override == -1 and sim.drones.size() == 3 and sim.interceptors.size() == 2, "Reset ne restaure pas les populations du niveau.")
	_check(sim.death_count == 1 and sim.distance_travelled >= 321 and sim.asteroid_container.get_instance_id() == field_id and sim.enemies_destroyed == 0, "Reset réinitialise morts, distance, environnement ou score.")
	sim.set_drone_count_override(99)
	sim.set_interceptor_count_override(-9)
	_check(sim.target_drone_count() == 8 and sim.target_interceptor_count() == 0, "Bornes des overrides incorrectes.")
	print("Overrides : verts 3→6, rouges 2→5, progressivité, persistance et reset sans réinitialisation/score validés.")
	await _dispose(sim)


func _test_spacing() -> void:
	var sim: SpaceSimulation = _empty(2)
	var ship: BlueShip = sim.ships[0]
	var weights: Vector2 = Vector2(ship.separation_weight, ship.cohesion_weight)
	for value: float in [0.8, 1.4]:
		sim.demo_controls.spacing_slider.value = value
		await _advance(90)
		sim.ships[0].position = Vector3.ZERO
		sim.ships[1].position = Vector3(8, 0, 0)
		ship._update_neighbor_rules()
		_check(ship.critical_separation_active == (value > 1.0), "Espacement sans effet sur le seuil critique.")
		_check(Vector2(ship.separation_weight, ship.cohesion_weight) == weights and ship.collision_mask == 6, "Espacement modifie les forces ou les collisions.")
	sim.set_movement_multiplier(9)
	sim.set_spacing_multiplier(-1)
	sim.set_simulation_speed(9)
	_check(sim.movement_multiplier == 2.0 and sim.spacing_multiplier == 0.8 and sim.simulation_speed_multiplier == 2.5, "Bornes des multiplicateurs incorrectes.")
	print("Espacement : effet observable à 0,8/1,4, transition interpolée, forces/collisions conservées.")
	await _dispose(sim)


func _movement_probe(value: float) -> Dictionary:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.5)
	sim.simulation_speed_multiplier = 1.0
	sim.manual_difficulty = 3
	root.add_child(sim)
	sim.demo_controls.movement_slider.value = value
	var side_sum: float = 0
	var samples: int = 0
	for _frame: int in range(1800):
		await physics_frame
		for ship: BlueShip in sim.ships:
			side_sum += Vector2(ship.velocity.x, ship.velocity.y).length()
			samples += 1
			_check(ship.global_position.is_finite() and ship.velocity.z < 0, "Mouvement extrême instable.")
	_check(sim.living_agent_count >= 6, "Mouvement seul provoque des collisions massives en 30 s.")
	var result: Dictionary = {"side_speed": side_sum / maxi(samples, 1), "alive": sim.living_agent_count, "deaths": sim.death_count}
	await _dispose(sim)
	return result


func _test_run(intense: bool) -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.5)
	sim.manual_difficulty = 3
	root.add_child(sim)
	var seconds: int = 60 if intense else 90
	if intense:
		sim.demo_controls.speed_slider.value = 1.8
		sim.set_ship_count(15)
		sim.set_drone_count_override(6)
		sim.set_interceptor_count_override(5)
		sim.demo_controls.movement_slider.value = 1.5
		# Inclure l'arrivée progressive dans les 60 secondes de démonstration.
	var rate: int = Engine.physics_ticks_per_second
	var frames: int = seconds * rate
	var node_max: int = get_node_count()
	var max_dispersion: float = 0
	var spacing_sum: float = 0
	var spacing_samples: int = 0
	var minimum_pair: float = INF
	var wall_start: int = Time.get_ticks_usec()
	var first_window_start: int = wall_start
	var first_window_usec: int = 0
	var last_window_start: int = 0
	for frame: int in range(frames):
		await physics_frame
		if frame == rate * 10:
			first_window_usec = Time.get_ticks_usec() - first_window_start
		if frame == (seconds - 10) * rate:
			last_window_start = Time.get_ticks_usec()
		if frame % 12 != 0:
			continue
		var center: Vector3 = sim._fleet_center()
		for ship: BlueShip in sim.ships:
			_check(ship.velocity.z < 0 and ship.global_position.is_finite(), "Vol M7 instable.")
			max_dispersion = maxf(max_dispersion, ship.position.distance_to(center))
			var nearest: float = INF
			for other: BlueShip in sim.ships:
				if other != ship:
					nearest = minf(nearest, ship.position.distance_to(other.position))
			minimum_pair = minf(minimum_pair, nearest)
			if frame > rate and nearest != INF:
				spacing_sum += nearest
				spacing_samples += 1
		node_max = maxi(node_max, get_node_count())
		_check(sim.living_agent_count + sim.death_count + sim.ship_retired_count == sim.ship_spawn_count, "Bilan des BlueShip incohérent.")
		_check(sim.drones.size() <= sim.target_drone_count() and sim.interceptors.size() <= sim.target_interceptor_count() and sim.asteroid_container.active_asteroid_count <= 72, "Population ou streaming hors budget.")
		_check(sim.projectile_container.get_child_count() <= 160 and node_max < 2500, "Accumulation de projectiles ou nœuds.")
		_check(sim.statistics.text == "Vaisseaux bleus détruits : %d" % sim.death_count and sim.demo_controls.stars_text() == "★★★", "HUD principal incorrect pendant démonstration.")
	await process_frame
	var wall_usec: int = Time.get_ticks_usec() - wall_start
	var last_window_usec: int = Time.get_ticks_usec() - last_window_start
	_check(sim.living_agent_count > 0 and sim.blue_shots_fired > 0 and sim.enemy_shots_fired > 0 and sim.projectile_dodge_count > 0, "Parcours M7 sans survivants ou sans combat/esquive.")
	_check(sim.ship_spawn_count == (15 if intense else 10), "Ajouts bleus non atteints ou pertes remplacées.")
	var metrics: Dictionary = {
		"scenario": "INTENSE" if intense else "DEFAUT DIFFICILE", "demo_seconds": seconds,
		"simulation_seconds": seconds * sim.simulation_speed_multiplier, "speed": sim.simulation_speed_multiplier,
		"movement": sim.movement_multiplier, "spacing": sim.spacing_multiplier, "physics_rate": rate,
		"seed": sim.simulation_seed, "blue_alive": sim.living_agent_count, "blue_deaths": sim.death_count,
		"blue_generated": sim.ship_spawn_count, "blue_retired": sim.ship_retired_count,
		"green_active": sim.drones.size(), "red_active": sim.interceptors.size(),
		"green_target": sim.target_drone_count(), "red_target": sim.target_interceptor_count(),
		"green_kills": sim.drones_destroyed, "red_kills": sim.interceptors_destroyed,
		"green_generated": sim.drone_spawn_count, "red_generated": sim.interceptor_spawn_count,
		"blue_shots": sim.blue_shots_fired, "blue_hits": sim.hostile_hits,
		"red_shots": sim.enemy_shots_fired, "red_hits": sim.blue_ship_hits,
		"dodges": sim.projectile_dodge_count, "dodge_agent_ticks": sim.projectile_dodge_ticks,
		"distance_m": sim.distance_travelled, "spacing_mean_m": spacing_sum / maxi(spacing_samples, 1),
		"minimum_pair_m": minimum_pair, "dispersion_max_m": max_dispersion, "dispersion_final_m": sim.dispersion,
		"asteroids_max": sim.asteroid_container.maximum_active_observed, "projectiles_max": sim.maximum_active_projectiles,
		"nodes_max": node_max, "cpu_mean_ms_per_tick": float(wall_usec) / frames / 1000.0,
		"cpu_first10_ms_per_tick": float(first_window_usec) / (rate * 10) / 1000.0,
		"cpu_last10_ms_per_tick": float(last_window_usec) / (rate * 10) / 1000.0,
		"wall_seconds": wall_usec / 1000000.0
	}
	_metrics.append(metrics)
	print("M7 METRICS " + JSON.stringify(metrics))
	await _dispose(sim)


func _capture() -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.5)
	sim.manual_difficulty = 3
	var suffix: String = "1_5"
	if OS.get_cmdline_user_args().has("--speed-135"):
		sim.simulation_speed_multiplier = 1.35
		suffix = "1_35"
	root.add_child(sim)
	await _advance(12 * Engine.physics_ticks_per_second)
	print("PACING " + JSON.stringify({"speed": sim.simulation_speed_multiplier, "demo_seconds": 12, "distance_m": sim.distance_travelled}))
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/validation")
	_check(root.get_texture().get_image().save_png("res://.godot/validation/m7_demo_" + suffix + ".png") == OK, "Capture panneau impossible.")
	sim.demo_controls.toggle_panel()
	await _advance(3)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://.godot/validation/m7_hidden_" + suffix + ".png") == OK, "Capture HUD masqué impossible.")
	sim.demo_controls.toggle_panel()
	root.size = Vector2i(800, 450)
	await _advance(3)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://.godot/validation/m7_small_" + suffix + ".png") == OK, "Capture petite fenêtre impossible.")
	await _dispose(sim)
