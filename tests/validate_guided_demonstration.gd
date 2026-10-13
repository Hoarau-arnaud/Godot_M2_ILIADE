extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var failures: int = 0
var results: Array[Dictionary] = []
var _phase_ids: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--native-video"):
		await _native_video()
	elif OS.get_cmdline_user_args().has("--capture"):
		await _capture()
	else:
		await _test_controls_and_restore()
		await _test_layout_and_projectiles()
		if not OS.get_cmdline_user_args().has("--unit-only"):
			await _complete_run()
			await _test_repeatability()
	var suffix: String = "video" if OS.get_cmdline_user_args().has("--native-video") else "capture" if OS.get_cmdline_user_args().has("--capture") else "unit" if OS.get_cmdline_user_args().has("--unit-only") else "metrics"
	var file: FileAccess = FileAccess.open("res://.godot/m11_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("PASS M11 : FREE/GUIDED, six phases, restauration, projectiles et budgets." if failures == 0 else "FAIL M11 : %d" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await process_frame
	await physics_frame


func _dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await _advance(3)
	for group: String in GuidedDemonstration.GAME_GROUPS:
		_check(get_nodes_in_group(group).is_empty(), "Objet après suppression : " + group)
	_check(Engine.time_scale == 1 and Engine.physics_ticks_per_second == 60, "Engine non restauré.")


func _key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)


func _test_controls_and_restore() -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.manual_difficulty = 3
	root.add_child(sim)
	await _advance(4)
	sim.set_difficulty_mode(2)
	sim.set_simulation_speed(1.4)
	sim.set_movement_multiplier(0.8)
	sim.set_spacing_multiplier(1.1)
	sim.set_drone_count_override(1)
	sim.set_interceptor_count_override(2)
	sim.set_capital_count_override(0)
	sim.camera.set_mode(SimulationCamera.Mode.FREE)
	var original: BlueShip = sim.ships[0]
	await _advance(3)
	var pursuing: Interceptor = sim.interceptors[0]
	pursuing.global_position = original.global_position + Vector3(4, 4, 30)
	await _advance(3)
	_check(pursuing._mission_state == Interceptor.InterceptorState.PURSUIT and is_instance_valid(pursuing.target), "Fixture libre sans poursuite active.")
	var pursued: BlueShip = pursuing.target
	var camera_transform: Transform3D = sim.camera.global_transform
	var death_count: int = sim.death_count
	var spawn_count: int = sim.ship_spawn_count
	var random_state: int = sim._random.state
	var field_next: float = sim.asteroid_container._next_z
	_key(KEY_D)
	await _advance(1)
	_check(sim.demonstration.is_guided() and sim.camera.mode == SimulationCamera.Mode.CINEMATIC, "D ne démarre pas GUIDED/CINE.")
	_check(sim.demo_controls.phase_panel.visible and sim.demo_controls.phase_label.text.begins_with("PHASE 1"), "Label initial absent.")
	_check(not sim.demo_controls.speed_slider.editable and sim.demo_controls.action_button.disabled, "Contrôles forcés restent modifiables.")
	var frozen_position: Vector3 = original.position
	var frozen_time: float = original._time
	var frozen_pursuit_time: float = pursuing._pursuit_time
	await _advance(120)
	_check(original.position == frozen_position and original._time == frozen_time and not original.is_in_group("blue_ships"), "Simulation libre continue pendant GUIDED.")
	_check(pursuing.target == pursued and pursuing._mission_state == Interceptor.InterceptorState.PURSUIT and pursuing._pursuit_time == frozen_pursuit_time, "Pause libre perd la cible ou la mémoire de poursuite.")
	_check(sim.death_count == 0, "Reset de démonstration compté comme mort.")
	sim.demo_controls.restart_demo_button.pressed.emit()
	await _advance(3)
	_check(sim.demonstration.phase_index == 0 and sim.demonstration.phase_elapsed < 0.1 and sim.death_count == 0, "Restart ne reprend pas la phase 1.")
	_key(KEY_D)
	await _advance(1)
	_check(not sim.demonstration.is_guided() and sim.ships.has(original) and original.is_in_group("blue_ships"), "D ne restitue pas les mêmes agents.")
	_check(pursuing.target == pursued and pursuing._mission_state == Interceptor.InterceptorState.PURSUIT, "Reprise libre perd la poursuite précédente.")
	_check(original.position.distance_to(frozen_position) < 0.5, "La reprise libre téléporte le chasseur.")
	_check(sim.manual_difficulty == 2 and sim.simulation_speed_multiplier == 1.4 and sim.movement_multiplier == 0.8 and sim.spacing_multiplier == 1.1, "Réglages libres non restaurés.")
	_check(sim.manual_drone_count_override == 1 and sim.manual_interceptor_count_override == 2 and sim.manual_capital_count_override == 0, "Populations libres non restaurées.")
	_check(sim.death_count == death_count and sim.ship_spawn_count == spawn_count and sim._random.state == random_state and sim.asteroid_container._next_z == field_next, "Compteurs/RNG/streaming libre perdus.")
	_check(sim.camera.mode == SimulationCamera.Mode.FREE and sim.camera.global_transform.is_equal_approx(camera_transform) and not sim.demo_controls.phase_panel.visible, "Caméra/label non restaurés.")
	_check(sim.demo_controls.speed_slider.editable and not sim.demo_controls.panel.visible == false, "Panneau libre non repris.")
	sim.demo_controls.guided_button.pressed.emit()
	await _advance(2)
	sim.demo_controls.free_button.pressed.emit()
	await _advance(2)
	_check(not sim.demonstration.is_guided(), "Boutons FREE/GUIDED inopérants.")
	# Fermeture directe en GUIDED : le snapshot est libéré avec la scène.
	sim.demonstration.start()
	await _advance(2)
	await _dispose(sim)
	print("Contrôles : D, boutons, restart, pause des mêmes entités, réglages/caméra/RNG/compteurs et sortie directe validés.")


func _test_layout_and_projectiles() -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	await _advance(3)
	var blue: Node3D = load("res://scenes/blue_laser.tscn").instantiate() as Node3D
	_check((blue.get_node("Bolt").mesh as BoxMesh).size == Vector3(0.24, 0.24, 3.8), "BlueLaser non épaissi x2.")
	blue.free()
	var pulse: EnemyLaser = load("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
	pulse.patrol_pulse = true
	pulse.position = Vector3(400, 400, 0)
	pulse.projectile_speed = 26
	sim.projectile_container.add_child(pulse)
	_check(is_equal_approx((pulse.get_node("Bolt").mesh as BoxMesh).size.x, 0.48) and is_equal_approx((pulse.get_node("Spear").mesh as BoxMesh).size.x, 0.22), "Tirs rouges non épaissis x2.")
	_check((pulse.get_node("Pulse").material_override as StandardMaterial3D).albedo_color.g > 0.9 and is_equal_approx(pulse.get_node("Pulse").scale.x, 1.6) and pulse.damage == 1, "Pulse vert non lisible ou dégâts modifiés.")
	_check(sim.space_decor.get_node("DistantBackdrop/NearbyPlanet") != null and sim.space_decor.get_node("DistantBackdrop/OrbitalDebrisBand").multimesh.instance_count == 360, "Planète/anneau absents.")
	_check((sim.get_node("WorldEnvironment").environment as Environment).background_mode == Environment.BG_SKY, "Fond coloré absent.")
	_check(sim.space_decor.find_children("*", "CollisionObject3D", true, false).is_empty(), "Décor devenu collision/agent.")
	_check(sim.demo_controls.panel.get_global_rect().end.y <= root.get_visible_rect().end.y - 5, "Panneau M11 déborde la fenêtre.")
	sim.demonstration.start()
	await _advance(2)
	var linear_count: int = 0
	var angles: Dictionary = {}
	for node: Node in get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		if rock.motion_type == SpaceAsteroid.MotionType.LINEAR:
			linear_count += 1
			angles[str(rock.motion_velocity.normalized())] = true
			_check((rock.trajectory_offset(3) - rock.trajectory_offset(0)).cross(rock.motion_velocity).length() < 0.001, "Déplacement LINEAR non rectiligne.")
	_check(linear_count == 5 and angles.size() == 5 and get_nodes_in_group("hostile_agents").is_empty(), "Cinq angles rectilignes / isolation tunnel incorrects.")
	for ship: BlueShip in sim.ships:
		_check(ship.collision_layer == 1 and ship.collision_mask == 6, "Collisions bleues désactivées en démo.")
	for passage: Vector3 in sim.asteroid_container.configurations[0].get_meta("passages"):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(passage + Vector3.BACK * 4, passage + Vector3.FORWARD * 4, 2)
		_check(sim.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Passage du tunnel fermé physiquement.")
	sim.demonstration.stop()
	print("Présentation : lasers x2, pulse vert diamètre 1,28 m, artillerie conservée, planète/halo/360 débris sans collision, panneau dans le viewport.")
	await _dispose(sim)


func _validate_phases(phases: Array[Dictionary]) -> void:
	_check(phases.size() == 6, "Démo sans six phases.")
	if phases.size() != 6:
		return
	for index: int in range(6):
		var phase: Dictionary = phases[index]
		_check(phase.phase == index + 1 and phase.title == GuidedDemonstration.TITLES[index], "Ordre/titre de phase incorrect.")
		_check(phase.blue_alive + phase.blue_deaths == 15, "Reset mort ou population de phase incorrect.")
		_check(phase.nodes_max < 4000 and phase.projectiles_max < 100 and phase.asteroids_max <= 160, "Budget de démonstration dépassé.")
	_check(phases[0].green == 0 and phases[0].red == 0 and phases[0].capital == 0 and phases[0].asteroids_max >= 100, "Tunnel pas dense ou ennemis présents.")
	_check(phases[0].blue_alive >= 12 and phases[0].lateral_excursion >= 20, "Tunnel sans forte majorité de survivants / grandes translations.")
	for type: int in [2, 3, 4, 5]:
		_check(phases[1].motion_types.get(type, 0) >= 2, "Famille dynamique non montrée.")
	_check(phases[2].green >= 3 and phases[2].routes >= 3 and phases[2].waypoints >= 20 and phases[2].green_shots > 5 and phases[2].dodges > 0, "Patrol sans route complète, pulse ou réaction bleue.")
	_check(phases[3].pursuits >= 4 and phases[3].disengagements >= 4 and phases[3].enemy_shots > 10 and phases[3].green == 0 and phases[3].capital == 0, "Interceptor sans acquisition/rafale/désengagement.")
	_check(phases[4].salvos == [1, 1, 1, 1, 1] and phases[4].dodges > 0 and phases[4].capital == 1, "Capital sans cinq salves et esquive.")
	_check(phases[5].blue_alive >= 8 and phases[5].green >= 1 and phases[5].red >= 1 and phases[5].capital == 1 and phases[5].enemy_shots > 10 and phases[5].blue_shots > 0, "Finale illisible / extinction / tirs absents.")
	_check(phases[5].regroup_episodes >= 2, "Finale sans récupération locale des deux chasseurs écartés.")


func _complete_run() -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	await _advance(2)
	var original: BlueShip = sim.ships[0]
	var baseline_nodes: int = get_node_count()
	_phase_ids.clear()
	sim.demonstration.phase_changed.connect(func(index: int) -> void:
		_phase_ids.append(index)
		_check(sim.demo_controls.phase_label.text == "PHASE %d — %s" % [index + 1, GuidedDemonstration.TITLES[index]], "Label incorrect après transition."))
	sim.demonstration.start()
	var started: int = Time.get_ticks_usec()
	var physics_start: int = Engine.get_physics_frames()
	while sim.demonstration.is_guided():
		await process_frame
	var cost: float = float(Time.get_ticks_usec() - started) / maxf(Engine.get_physics_frames() - physics_start, 1) / 1000
	_validate_phases(sim.demonstration.phase_results)
	_check(_phase_ids == [0, 1, 2, 3, 4, 5] and sim.demonstration.last_duration >= 99.9 and sim.demonstration.last_duration < 101, "Durée/transitions automatiques incorrectes.")
	_check(sim.ships.has(original) and sim.streaming_enabled and not sim.demo_controls.phase_panel.visible, "Retour automatique FREE absent.")
	await _advance(4)
	_check(get_node_count() <= baseline_nodes + 30, "Nœuds conservés après retour FREE.")
	var record: Dictionary = {"test": "headless_complete", "duration": sim.demonstration.last_duration, "cost_ms_per_tick": cost, "phases": sim.demonstration.phase_results.duplicate(true), "nodes_before": baseline_nodes, "nodes_after": get_node_count(), "free_restored": sim.ships.has(original)}
	results.append(record)
	for phase: Dictionary in sim.demonstration.phase_results:
		print("M11 PHASE " + JSON.stringify(phase))
	print("M11 COMPLETE duration=%.3f s, headless=%.3f ms/tick, nodes %d → %d, mêmes agents FREE." % [record.duration, cost, baseline_nodes, get_node_count()])
	await _dispose(sim)


func _signature(sim: SpaceSimulation) -> String:
	var signature: Array = []
	for node: Node in get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		signature.append([rock.shape_seed, rock.diameter, rock.motion_type, rock.motion_velocity, rock.motion_center - sim.demonstration._phase_sample.origin])
	return JSON.stringify(signature)


func _test_repeatability() -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	sim.demonstration.start()
	var first: String = _signature(sim)
	await _advance(30)
	sim.demonstration.restart()
	_check(_signature(sim) == first, "Tunnel non reproductible au restart.")
	# Le choix pédagogique est mémorisé une fois par salve, même durant PREPARE.
	sim.demonstration._begin_phase(4, Vector3.ZERO)
	var capital: CapitalShip = sim.capitals[0]
	capital.salvo_started.connect(func(pattern: int) -> void: _phase_ids.append(pattern))
	_phase_ids.clear()
	while sim.demonstration.phase_index == 4:
		await process_frame
	_check(_phase_ids == [0, 1, 2, 3, 4], "Ordre réel Heavy/Spread/Arc/Cross/Seeker incorrect.")
	sim.demonstration.stop()
	await _advance(3)
	print("Reproductibilité : tunnel, reset sans mort et ordre FSM Heavy → Spread → Arc → Cross → Seeker validés.")
	await _dispose(sim)


func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	sim.demonstration.start()
	for index: int in range(6):
		if index > 0:
			sim.demonstration._begin_phase(index, sim._fleet_center())
		await _advance(240)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m11_phase_%d_qa.png" % (index + 1))
	sim.demonstration.stop()
	sim.demo_controls.panel.show()
	await _advance(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/m11_free_controls.png")
	await _dispose(sim)


func _native_video() -> void:
	DisplayServer.window_set_position(Vector2i(180, 140))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Test vidéo uniquement : rendu interne 1080p dans le plein écran de ce moniteur.
	# Le projet conserve son canvas_items natif et responsive.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	await _advance(5)
	_check(root.get_texture().get_size() == Vector2(1920, 1080) and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Vidéo pas en plein écran/rendu 1080p.")
	sim.demonstration.start()
	var started: int = Time.get_ticks_usec()
	var last: int = started
	var frames: int = 0
	var sample_frames: int = 0
	var fps_min: float = INF
	var captured: Dictionary = {}
	while sim.demonstration.is_guided():
		await process_frame
		frames += 1
		sample_frames += 1
		var now: int = Time.get_ticks_usec()
		if now - last >= 1000000:
			fps_min = minf(fps_min, sample_frames * 1000000.0 / (now - last))
			last = now
			sample_frames = 0
		var index: int = sim.demonstration.phase_index
		if index >= 0 and sim.demonstration.phase_elapsed >= 9 and not captured.has(index):
			captured[index] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m11_phase_%d_video.png" % (index + 1))
	var duration: float = float(Time.get_ticks_usec() - started) / 1000000
	_validate_phases(sim.demonstration.phase_results)
	var record: Dictionary = {"test": "native_1080p_fullscreen", "real_seconds": duration, "sequence_seconds": sim.demonstration.last_duration, "fps_mean": frames / duration, "fps_min_1s": fps_min, "render_pixels": root.get_texture().get_size(), "window_pixels": DisplayServer.window_get_size(), "phases": sim.demonstration.phase_results.duplicate(true), "free_restored": not sim.demonstration.is_guided()}
	results.append(record)
	_check(record.fps_mean > 60 and duration > 99 and duration < 110, "FPS/durée cible non atteints.")
	for phase: Dictionary in sim.demonstration.phase_results:
		print("M11 VIDEO PHASE " + JSON.stringify(phase))
	print("M11 VIDEO " + JSON.stringify(record))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _dispose(sim)
