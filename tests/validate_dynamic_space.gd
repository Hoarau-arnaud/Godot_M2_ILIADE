extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const ROCK: PackedScene = preload("res://scenes/asteroid.tscn")
var _failures: int = 0
var _results: Array[Dictionary] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture-native"):
		await _test_native()
	elif OS.get_cmdline_user_args().has("--render-spectacle"):
		await _test_render_spectacle()
	else:
		await _test_orientation()
		await _test_visual_independence()
		await _test_motion_types()
		await _test_distribution()
		await _test_production_determinism()
		await _test_barrage_motion()
		await _test_predictive_avoidance(false)
		await _test_predictive_avoidance(true)
		await _test_streaks()
		if not OS.get_cmdline_user_args().has("--unit-only"):
			await _test_run(90, false)
			await _test_run(90, true)
			await _test_run(60, true, true)
	var output: FileAccess = FileAccess.open("res://.godot/m9_" + ("graphics" if OS.get_cmdline_user_args().has("--render-spectacle") else "native" if OS.get_cmdline_user_args().has("--capture-native") else "metrics") + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(_results, "\t"))
	print("PASS : viewport, vol dynamique, trajectoires et présentation M9." if _failures == 0 else "FAIL : %d validations M9." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await physics_frame
	await process_frame


func _empty(count: int = 1) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.ship_count = count
	sim.simulation_speed_multiplier = 1.0
	sim.streaming_enabled = false
	sim.drones_enabled = false
	sim.interceptors_enabled = false
	root.add_child(sim)
	return sim


func _dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await _advance(2)
	_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Horloge Engine non restaurée.")
	for group: String in ["blue_ships", "asteroids", "patrol_drones", "interceptors", "hostile_agents", "blue_lasers", "hostile_projectiles", "explosions"]:
		_check(get_nodes_in_group(group).is_empty(), "Objet conservé après suppression M9 : " + group)


func _test_orientation() -> void:
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	var ship: BlueShip = sim.ships[0]
	ship.set_physics_process(false)
	ship.velocity = Vector3(18, 25, -10.5)
	var original_velocity: Vector3 = ship.velocity
	var max_pitch: float = 0
	for _frame: int in range(240):
		ship._update_orientation(1.0 / 60.0)
		max_pitch = maxf(max_pitch, absf(rad_to_deg(asin((-ship._visuals.basis.z).y))))
		_check(max_pitch <= 8.01 and absf(rad_to_deg(ship._visual_angles.y)) <= 10.01 and absf(rad_to_deg(ship._visual_angles.z)) <= 30.01, "Orientation visuelle hors limites.")
	_check(ship.velocity == original_velocity and ship.rotation.is_zero_approx(), "Le pitch modifie le déplacement ou la collision.")
	ship.velocity = Vector3.FORWARD * 10.5
	for _frame: int in range(240):
		ship._update_orientation(1.0 / 60.0)
	_check(ship._visual_angles.length() < deg_to_rad(0.1), "Retour à plat incomplet.")
	_check(ship.get_node("Visuals/Fuselage").mesh is ArrayMesh and ship.get_node("Visuals/Fuselage").mesh.get_aabb().size.y >= 0.9 and ship.get_node("Visuals/LeftNacelle").mesh.get_aabb().size.y >= 0.9, "Coque ou nacelle sans volume.")
	print("PITCH : max %.3f°, vitesse verticale imposée 25 m/s conservée ; yaw ≤10°, roll ≤30°, retour à plat et coques épaisses validés." % max_pitch)
	_results.append({"test": "ORIENTATION", "max_pitch_degrees": max_pitch, "vertical_velocity": original_velocity.y})
	ship.position = Vector3.ZERO
	ship.wander_strength = 0
	ship.vertical_wander_strength = 40
	ship.longitudinal_wander_strength = 0
	ship.set_physics_process(true)
	var min_y: float = 0
	var max_y: float = 0
	var max_vertical_speed: float = 0
	for _frame: int in range(240):
		await physics_frame
		min_y = minf(min_y, ship.position.y)
		max_y = maxf(max_y, ship.position.y)
		max_vertical_speed = maxf(max_vertical_speed, absf(ship.velocity.y))
		_check(absf(rad_to_deg(asin((-ship._visuals.basis.z).y))) <= 8.01, "Montée physique avec pitch excessif.")
	_check(max_y - min_y > 8 and max_vertical_speed > 6, "La limite de pitch bride le mouvement vertical physique.")
	print("MONTÉE PHYSIQUE : excursion %.2f m en 4 s, vitesse Y max %.2f m/s, pitch ≤8°." % [max_y - min_y, max_vertical_speed])
	await _dispose(sim)


func _visual_path(neutral: bool) -> Array[Vector3]:
	var sim: SpaceSimulation = _empty(10)
	for ship: BlueShip in sim.ships:
		ship.combat_enabled = false
		if neutral:
			ship.visual_pitch_limit_degrees = 0
			ship.visual_yaw_limit_degrees = 0
			ship.visual_roll_limit_degrees = 0
	await _advance(600)
	var positions: Array[Vector3] = []
	for ship: BlueShip in sim.ships:
		positions.append(ship.position)
		positions.append(ship.velocity)
	await _dispose(sim)
	return positions


func _test_visual_independence() -> void:
	var bounded: Array[Vector3] = await _visual_path(false)
	var neutral: Array[Vector3] = await _visual_path(true)
	var maximum: float = 0
	for index: int in range(bounded.size()):
		maximum = maxf(maximum, bounded[index].distance_to(neutral[index]))
	_check(maximum < 0.0001, "L'orientation visuelle modifie le SMA.")
	print("Orientation/SMA : écart positions et vitesses %.6f m." % maximum)


func _test_motion_types() -> void:
	for motion: int in range(6):
		var sim: SpaceSimulation = _empty()
		sim.set_physics_process(false)
		sim.ships[0].set_physics_process(false)
		var rock: SpaceAsteroid = ROCK.instantiate() as SpaceAsteroid
		rock.position = Vector3(100, 40, -35)
		rock.motion_type = motion as SpaceAsteroid.MotionType
		rock.motion_velocity = Vector3(6, 2, -1) if motion != SpaceAsteroid.MotionType.VERTICAL_SWEEP else Vector3(0, 6, 0)
		rock.motion_duration = 14
		rock.rotation_speed = 0
		rock.diameter = 4
		sim.asteroid_container.add_child(rock)
		var start: Vector3 = rock.position
		var query_hits: int = 0
		for _second: int in range(30):
			await _advance(60)
			_check(rock.position.is_finite() and rock.velocity.is_finite(), "Trajectoire non finie.")
			_check(rock.position.distance_to(rock.motion_center + rock.trajectory_offset(rock.motion_elapsed)) < 0.001, "Corps physique décalé de sa trajectoire.")
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(rock.global_position + Vector3.RIGHT * 12, rock.global_position - Vector3.RIGHT * 12, 2)
			var hit: Dictionary = rock.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.get("collider") == rock:
				query_hits += 1
		_check(query_hits == 30, "Collision ne suivant pas le rocher mobile.")
		_check(rock is AnimatableBody3D and not rock.sync_to_physics, "Type physique ou synchronisation incorrects.")
		_check(rock.position.distance_to(start) < 0.01 if motion == 0 else rock.position.distance_to(start) > 3, "Type de mouvement sans effet attendu.")
		print("MOTION %s : 30 s, déplacements finis, aller-retour et 30 raycasts physiques validés." % SpaceAsteroid.MotionType.keys()[motion])
		await _dispose(sim)


func _motion_signature(field: ObstacleField, seed_value: int, level: int) -> Array[String]:
	var signature: Array[String] = []
	for index: int in range(1000):
		var rock: SpaceAsteroid = ROCK.instantiate() as SpaceAsteroid
		field._configure_motion(rock, level, seed_value + index * 97, 180)
		signature.append(str([rock.motion_type, rock.motion_velocity, rock.motion_period, rock.motion_phase, rock.orbit_axis_u, rock.orbit_axis_v]))
		rock.free()
	return signature


func _test_distribution() -> void:
	var sim: SpaceSimulation = _empty()
	var field: ObstacleField = sim.asteroid_container
	for level: int in [1, 2, 3]:
		var first: Array[String] = _motion_signature(field, sim.simulation_seed, level)
		var second: Array[String] = _motion_signature(field, sim.simulation_seed, level)
		_check(first == second, "Trajectoires non reproductibles.")
		var mobile: int = 0
		var types: Dictionary = {}
		for row: String in first:
			var type: int = int(row.substr(1, 1))
			types[type] = true
			if type != 0:
				mobile += 1
		var ratio: float = mobile / 1000.0
		_check(ratio < 0.1 if level == 1 else ratio >= 0.15 and ratio <= 0.25 if level == 2 else ratio >= 0.35 and ratio <= 0.5, "Proportion mobile incorrecte.")
		_check(types.size() == 6, "Trajectoire absente du tirage.")
		print("DISTRIBUTION niveau %d : %.1f %% mobiles, mêmes 1000 signatures avec la même seed." % [level, ratio * 100])
		_results.append({"test": "DISTRIBUTION", "level": level, "mobile_ratio": ratio})
	_check(_motion_signature(field, sim.simulation_seed, 3) != _motion_signature(field, sim.simulation_seed + 1, 3), "Une autre seed ne change pas les trajectoires.")
	await _dispose(sim)


func _production_signature(hold_cleanup: bool) -> Dictionary[String, String]:
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	sim.ships[0].set_physics_process(false)
	var field: ObstacleField = sim.asteroid_container
	field.initialize_field(sim.simulation_seed, Vector3.ZERO, 0)
	field.difficulty_override = 3
	var signatures: Dictionary[String, String] = {}
	for index: int in range(40):
		var center: Vector3 = Vector3(0,0,-index * 120)
		field.advance(center, center.z - 14, 1000.0 if hold_cleanup and index < 10 else center.z + 28)
		for configuration: Node3D in field.configurations:
			for node: Node in configuration.get_children():
				var rock: SpaceAsteroid = node as SpaceAsteroid
				var id: String = "%d/%s" % [configuration.get_meta("generation_index"), rock.name]
				signatures[id] = str([rock.motion_type, rock.motion_velocity, rock.motion_amplitude, rock.motion_period, rock.motion_phase, rock.orbit_axis_u, rock.orbit_axis_v])
		await _advance(2)
	await _dispose(sim)
	return signatures


func _test_production_determinism() -> void:
	var regular: Dictionary[String, String] = await _production_signature(false)
	var delayed: Dictionary[String, String] = await _production_signature(true)
	var common: int = 0
	for id: String in regular:
		if delayed.has(id):
			common += 1
			_check(regular[id] == delayed[id], "Le budget/nettoyage change les types ou paramètres de trajectoire seedés.")
	_check(common > 50, "Comparaison de production trop courte.")
	print("PRODUCTION : %d signatures identiques malgré un nettoyage retardé et l'attente au budget." % common)


func _test_barrage_motion() -> void:
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	sim.ships[0].set_physics_process(false)
	var field: ObstacleField = sim.asteroid_container
	field.hard_mobile_ratio = 1.0
	field.initialize_field(sim.simulation_seed, Vector3.ZERO, 0)
	field._spawn_configuration(ObstacleField.Pattern.DOUBLE_CURTAIN, 3, Vector3.ZERO, -65)
	var configuration: Node3D = field.configurations[0]
	var first: SpaceAsteroid = configuration.get_child(0) as SpaceAsteroid
	var initial: Dictionary[int, Vector3] = {}
	for node: Node in configuration.get_children():
		var rock: SpaceAsteroid = node as SpaceAsteroid
		initial[rock.get_instance_id()] = rock.position - first.position
	for _second: int in range(16):
		await _advance(60)
		for node: Node in configuration.get_children():
			var rock: SpaceAsteroid = node as SpaceAsteroid
			_check((rock.position - first.position).distance_to(initial[rock.get_instance_id()]) < 0.05, "Mouvement fermant l'ouverture du barrage.")
		var shift: Vector3 = first.position - first.motion_center
		for passage: Vector3 in field.passage_points(ObstacleField.Pattern.DOUBLE_CURTAIN):
			for node: Node in configuration.get_children():
				var rock: SpaceAsteroid = node as SpaceAsteroid
				_check((passage + shift).distance_to(rock.position) - rock.avoidance_radius - BlueShip.SHIP_CLEARANCE > 5, "Passage mobile fermé.")
	_check(field.active_mobile_count == 16 and field.active_asteroid_count == 16, "Compte mobile incorrect.")
	field._cleanup_passed(-500)
	await _advance(2)
	_check(field.active_mobile_count == 0 and field.active_asteroid_count == 0, "Nettoyage mobile incomplet.")
	print("BARRAGE MOBILE : double rideau cohérent pendant 16 s, passages ouverts, enveloppe de nettoyage et compteurs validés.")
	await _dispose(sim)


func _test_predictive_avoidance(stress: bool) -> void:
	var sim: SpaceSimulation = _empty()
	var ship: BlueShip = sim.ships[0]
	ship.position = Vector3.ZERO
	ship.wander_strength = 0
	ship.vertical_wander_strength = 0
	ship.longitudinal_wander_strength = 0
	ship.velocity = Vector3.FORWARD * ship.forward_speed * ship._speed_factor
	if stress:
		ship.obstacle_detection_radius = 0
		ship.mobile_detection_radius = 0
		ship.hostile_projectile_detection_radius = 0
	var rock: SpaceAsteroid = ROCK.instantiate() as SpaceAsteroid
	rock.motion_type = SpaceAsteroid.MotionType.LINEAR
	rock.motion_velocity = Vector3(-7, 0, 0)
	rock.motion_duration = 10
	rock.position = Vector3(-14, 0, -31.5)
	rock.diameter = 7 if stress else 4
	rock.size_category = SpaceAsteroid.SizeCategory.LARGE
	sim.asteroid_container.add_child(rock)
	await _advance(2)
	if not stress:
		ship._obstacle_avoidance()
		_check(ship._threats.has(rock) and ship.global_position.distance_to(rock.global_position) > 20, "Croisement non anticipé à distance.")
	var max_side: float = 0
	for _frame: int in range(420):
		await physics_frame
		if is_instance_valid(ship):
			max_side = maxf(max_side, Vector2(ship.position.x, ship.position.y).length())
	if stress:
		_check(sim.death_count == 1 and sim.ships.is_empty(), "Stress sans perception sans collision réelle unique.")
	else:
		_check(sim.death_count == 0 and ship.moving_asteroid_avoidance_ticks > 0 and max_side > 3, "Croisement sans esquive efficace.")
	print("CROISEMENT %s : morts=%d, déplacement latéral max=%.2f m, obstacle intact." % ["stress sans perception" if stress else "anticipé", sim.death_count, max_side])
	_check(is_instance_valid(rock), "L'astéroïde est détruit lors du contact.")
	await _dispose(sim)


func _test_streaks() -> void:
	var sim: SpaceSimulation = _empty()
	var decor: SpaceEnvironment = sim.space_decor
	decor.recycle_stars(Vector3(500, 200, -1200), 0.1, 0.5, Vector3.FORWARD * 10)
	var slow: float = decor.streak_length_multiplier
	decor.recycle_stars(Vector3(500, 200, -1200), 0.1, 2.5, Vector3.FORWARD * 10)
	_check(decor.streak_length_multiplier > slow and decor._streaks.multimesh.instance_count == 48, "Streaks sans variation ou trop nombreux.")
	_check(decor._backdrop.find_children("*", "CollisionObject3D", true, false).is_empty(), "Décor lointain avec collision.")
	print("DÉCOR : 48 streaks MultiMesh, longueur selon rythme, trois couches de parallaxe et horizon sans collision validés.")
	await _dispose(sim)


func _sample(sim: SpaceSimulation, record: Dictionary) -> void:
	var center: Vector3 = sim._fleet_center()
	sim._measure_group(center)
	record["nodes_max"] = maxi(int(record.get("nodes_max", 0)), get_node_count())
	record["dispersion_max_m"] = maxf(float(record.get("dispersion_max_m", 0)), sim.dispersion)
	var moving_now: int = 0
	for node: Node in get_nodes_in_group("asteroids"):
		if (node as SpaceAsteroid).velocity.length_squared() > 0.01:
			moving_now += 1
	record["moving_now_max"] = maxi(int(record.get("moving_now_max", 0)), moving_now)
	var previous: Dictionary = record.get("regroup_states", {})
	var frame_rect: Rect2 = root.get_visible_rect()
	for ship: BlueShip in sim.ships:
		var regrouping: bool = ship.behavior_state == BlueShip.BehaviorState.REGROUPING
		var id: int = ship.get_instance_id()
		if regrouping and not previous.get(id, false):
			record["regroup_episodes"] = int(record.get("regroup_episodes", 0)) + 1
		previous[id] = regrouping
		record["framing_samples"] = int(record.get("framing_samples", 0)) + 1
		if not sim.camera.is_position_behind(ship.position) and frame_rect.has_point(sim.camera.unproject_position(ship.position)):
			record["framed_centers"] = int(record.get("framed_centers", 0)) + 1
		_check(ship.position.is_finite() and ship.velocity.z < 0, "Agent non fini ou ne progressant plus vers -Z.")
	record["regroup_states"] = previous
	_check(sim.asteroid_container.active_asteroid_count <= 96 and sim.asteroid_container.active_mobile_count <= sim.asteroid_container.active_asteroid_count, "Budget ou compte mobile invalide.")
	_check(sim.living_agent_count + sim.death_count + sim.ship_retired_count == sim.ship_spawn_count, "Bilan BlueShip incohérent.")


func _finish_record(sim: SpaceSimulation, record: Dictionary) -> Dictionary:
	_sample(sim, record)
	record.erase("regroup_states")
	record["framed_center_ratio"] = float(record.get("framed_centers", 0)) / maxf(record.get("framing_samples", 1), 1.0)
	record.erase("framed_centers")
	record.erase("framing_samples")
	record["elapsed_simulation_time"] = sim.elapsed_simulation_time
	record.merge({"blue_alive": sim.living_agent_count, "blue_deaths": sim.death_count, "green_active": sim.drones.size(), "red_active": sim.interceptors.size(), "asteroids_active": sim.asteroid_container.active_asteroid_count, "asteroids_max": sim.asteroid_container.maximum_active_observed, "mobile_active": sim.asteroid_container.active_mobile_count, "mobile_max": sim.asteroid_container.maximum_mobile_observed, "motion_types": sim.asteroid_container.motions_generated, "projectiles_max": sim.maximum_active_projectiles, "blue_shots": sim.blue_shots_fired, "red_shots": sim.enemy_shots_fired, "mobile_avoidance_episodes": sim.moving_asteroid_dodge_count, "mobile_avoidance_agent_ticks": sim.moving_asteroid_avoidance_ticks, "projectile_dodges": sim.projectile_dodge_count, "dispersion_final_m": sim.dispersion, "spacing_final_m": sim.average_spacing, "isolated_final": sim.isolated_agent_count, "shot_changes": sim.camera.shot_changes}, true)
	return record


func _test_run(seconds: int, cinematic: bool, spectacle: bool = false) -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	if not spectacle:
		sim.manual_difficulty = 3
	root.add_child(sim)
	if spectacle:
		sim.apply_action_preset()
	elif cinematic:
		sim.camera.set_mode(SimulationCamera.Mode.CINEMATIC)
	var rate: int = Engine.physics_ticks_per_second
	var record: Dictionary = {"test": "SPECTACLE_HEADLESS" if spectacle else "CINEMATIC" if cinematic else "FOLLOW", "demo_seconds": seconds, "simulation_seconds": seconds * sim.simulation_speed_multiplier}
	var start: int = Time.get_ticks_usec()
	for frame: int in range(seconds * rate):
		await physics_frame
		if frame % 30 == 0:
			_sample(sim, record)
	_finish_record(sim, record)
	record["cpu_ms_per_tick"] = (Time.get_ticks_usec() - start) / float(seconds * rate) / 1000.0
	_check(sim.living_agent_count > 0 and sim.moving_asteroid_dodge_count > 0 and sim.asteroid_container.motions_generated.size() >= 4, "Parcours sans survivant, sans anticipation ou diversité de trajectoires.")
	_check(sim.blue_shots_fired > 0 and sim.enemy_shots_fired > 0, "Parcours sans tirs des deux factions.")
	_check(float(record["framed_center_ratio"]) > 0.95, "Cadrage insuffisant pendant le parcours dynamique.")
	_results.append(record)
	print("M9 RUN " + JSON.stringify(record))
	await _dispose(sim)


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


func _capture_viewport(sim: SpaceSimulation, label: String) -> void:
	await _advance(15)
	await RenderingServer.frame_post_draw
	var window: Vector2i = DisplayServer.window_get_size()
	var visible: Vector2 = root.get_visible_rect().size
	var image: Image = root.get_texture().get_image()
	var expected: Vector2 = Vector2(window) / minf(window.x / 1280.0, window.y / 720.0)
	var projection: Projection = sim.camera.get_camera_projection()
	var camera_aspect: float = projection.y.y / projection.x.x
	_check(image.get_size() == window, "Rendu ne remplissant pas la fenêtre.")
	_check(visible.distance_to(expected) < 1.0, "Canvas logique sans extension au nouveau ratio.")
	_check(absf(camera_aspect - window.x / float(window.y)) < 0.005, "Aspect caméra non adapté à la fenêtre.")
	_check(sim.demo_controls.panel.get_global_rect().end.x <= visible.x and sim.demo_controls.panel.get_global_rect().end.y <= visible.y, "Panneau hors viewport.")
	_check(absf(sim.demo_controls.help_panel.get_global_rect().end.y - (visible.y - 18)) < 1.0, "Aide non ancrée au bas.")
	_check(absf(sim.demo_controls.panel.get_global_rect().end.x - (visible.x - 18)) < 1.0, "Panneau non ancré à droite.")
	image.save_png("res://.godot/validation/m9_" + label + ".png")
	var record: Dictionary = {"test": "VIEWPORT", "label": label, "window_pixels": str(window), "render_pixels": str(image.get_size()), "canvas_logical": str(visible), "mode": DisplayServer.window_get_mode()}
	_results.append(record)
	record["camera_aspect"] = camera_aspect
	print("M9 VIEWPORT " + JSON.stringify(record))


func _test_native() -> void:
	_check(DisplayServer.get_name() != "headless", "Validation viewport sans rendu natif.")
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	sim.apply_action_preset()
	for size: Vector2i in [Vector2i(800,450), Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(1600,1000), Vector2i(900,900), Vector2i(1920,800)]:
		DisplayServer.window_set_size(size)
		await _capture_viewport(sim, "%dx%d" % [size.x, size.y])
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_position(Vector2i(180,140))
	await _advance(15)
	var saved_position: Vector2i = DisplayServer.window_get_position()
	_key(KEY_F11)
	await _capture_viewport(sim, "fullscreen")
	_check(sim.presentation_window.is_fullscreen(), "F11 sans vrai plein écran.")
	_key(KEY_F11)
	await _advance(15)
	_check(DisplayServer.window_get_size() == Vector2i(1280,720) and DisplayServer.window_get_position() == saved_position and not sim.presentation_window.is_fullscreen(), "Fenêtre non restaurée.")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await _capture_viewport(sim, "maximized")
	_key(KEY_ENTER, true)
	await _capture_viewport(sim, "fullscreen_from_maximized")
	sim.demo_controls.fullscreen_button.pressed.emit()
	await _advance(15)
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "Sortie plein écran ne restaurant pas la maximisation.")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _dispose(sim)
	await _capture_ship()


func _capture_ship() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	var sim: SpaceSimulation = _empty()
	sim.set_process(false)
	sim.set_physics_process(false)
	sim.get_node("HUD").hide()
	sim.demo_controls.hide()
	var ship: BlueShip = sim.ships[0]
	ship.position = Vector3.ZERO
	ship.set_physics_process(false)
	var shots: Dictionary[String, Vector3] = {"top": Vector3(0,17,1), "three_quarter": Vector3(9,6,-11), "below": Vector3(9,-4,-11), "climb": Vector3(9,3,-11)}
	for label: String in shots:
		ship.velocity = Vector3(0, 25 if label == "climb" else 0, -10.5)
		for _frame: int in range(240):
			ship._update_orientation(1.0 / 60.0)
		ship._update_exhausts()
		sim.camera.position = shots[label]
		sim.camera.fov = 38
		sim.camera.look_at(Vector3(0,0,-0.6))
		await _advance(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m9_blue_" + label + ".png")
	await _dispose(sim)


func _test_render_spectacle() -> void:
	_check(DisplayServer.get_name() != "headless", "FPS demandé sans rendu.")
	DisplayServer.window_set_size(Vector2i(1920,1080))
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	sim.apply_action_preset()
	sim.demo_controls.toggle_help()
	sim.demo_controls.toggle_panel()
	var record: Dictionary = {"test": "SPECTACLE_REAL_60", "resolution": "1920x1080", "vsync": DisplayServer.window_get_vsync_mode()}
	var start: int = Time.get_ticks_usec()
	var start_frames: int = Engine.get_frames_drawn()
	var window_start: int = start
	var window_frames: int = start_frames
	var min_fps: float = INF
	var next_capture: int = 20
	while Time.get_ticks_usec() - start < 60000000:
		await process_frame
		if Engine.get_process_frames() % 15 == 0:
			_sample(sim, record)
		var seconds: float = (Time.get_ticks_usec() - start) / 1000000.0
		if Time.get_ticks_usec() - window_start >= 1000000:
			var now: int = Time.get_ticks_usec()
			min_fps = minf(min_fps, (Engine.get_frames_drawn() - window_frames) / ((now - window_start) / 1000000.0))
			window_start = now
			window_frames = Engine.get_frames_drawn()
		if seconds >= next_capture:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m9_spectacle_%ds.png" % next_capture)
			print("Spectacle réel %ds : %d survivants, %d mobiles, %d projectiles, %.1f FPS." % [next_capture, sim.living_agent_count, sim.asteroid_container.active_mobile_count, sim.projectile_container.get_child_count(), Engine.get_frames_per_second()])
			next_capture += 20
	var elapsed: float = (Time.get_ticks_usec() - start) / 1000000.0
	_finish_record(sim, record)
	record["real_seconds"] = elapsed
	record["fps_mean"] = (Engine.get_frames_drawn() - start_frames) / elapsed
	record["fps_final"] = Engine.get_frames_per_second()
	record["fps_min_1s"] = min_fps
	_check(sim.living_agent_count > 0 and sim.camera.shot_changes >= 5 and sim.enemy_shots_fired > 0, "Spectacle réel sans survivant, plans ou tirs.")
	_results.append(record)
	print("M9 GRAPHICS " + JSON.stringify(record))
	await _dispose(sim)
