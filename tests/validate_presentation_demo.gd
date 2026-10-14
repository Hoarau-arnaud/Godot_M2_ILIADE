extends "res://tests/validate_arcade_hazards.gd"

const PRESENTATION_OBSERVER: Script = preload("res://tests/study_observer.gd")

func presentation_key(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code as Key
	event.pressed = true
	Input.parse_input_event(event)


func presentation_controls() -> void:
	var sim: SpaceSimulation = modern()
	var free_ids: Array[int] = []
	for blue: BlueShip in sim.ships:
		free_ids.append(blue.get_instance_id())
	presentation_key(KEY_F7)
	await frames(3)
	check(sim.presentation.state == PresentationDemonstration.State.READY and paused, "F7 / READY")
	check(sim.demonstration.mode == GuidedDemonstration.DemoMode.PRESENTATION and not sim.demonstration.is_guided(), "Troisième mode absent")
	check(sim.demo_controls.presentation_panel.visible and sim.demo_controls.presentation_start.visible, "Écran READY absent")
	var ready_pose: Transform3D = sim.ships[0].global_transform
	await frames(20)
	check(sim.ships[0].global_transform.is_equal_approx(ready_pose) and sim.presentation.elapsed_real == 0, "READY avance")
	presentation_key(KEY_SPACE)
	await frames(5)
	check(not paused and sim.presentation.state == PresentationDemonstration.State.RUNNING, "ESPACE start")
	var death_before: int = sim.death_count
	presentation_key(KEY_SPACE)
	await frames(3)
	check(sim.presentation.phase_index == 1 and sim.drones.size() == 3 and sim.demo_controls.phase_label.text == "PHASE 2 — PATROUILLE AUTONOME", "ESPACE skip")
	check(sim.death_count == death_before and get_nodes_in_group("asteroids").is_empty(), "Skip résidus / fausses morts")
	presentation_key(KEY_SPACE)
	await frames(3)
	check(sim.presentation.phase_index == 2 and sim.interceptors.size() == 3 and not is_instance_valid(sim.demonstration._markers), "Skip Interceptor / marqueurs")
	presentation_key(KEY_SPACE)
	await frames(30)
	check(not get_nodes_in_group("artillery_projectiles").is_empty(), "Pause sans projectiles")
	while sim.presentation.phase_elapsed < 15.0:
		await process_frame
	presentation_key(KEY_P)
	await frames(2)
	var poses: Dictionary = {}
	for group: String in ["blue_ships", "hostile_agents", "artillery_projectiles", "combat_hazards"]:
		for node: Node3D in get_nodes_in_group(group):
			poses[node] = node.global_transform
	var camera_pose: Transform3D = sim.camera.global_transform
	var timer: float = sim.presentation.phase_elapsed
	await frames(35)
	for node: Node3D in poses:
		check(node.global_transform.is_equal_approx(poses[node]), "Agent / projectile mobile en pause")
	check(sim.camera.global_transform.is_equal_approx(camera_pose) and sim.presentation.phase_elapsed == timer and sim.demo_controls.pause_label.visible, "Caméra / timer pause")
	presentation_key(KEY_P)
	await frames(4)
	check(not paused and sim.presentation.phase_elapsed > timer, "Reprise")
	presentation_key(KEY_SPACE)
	await frames(3)
	check(sim.presentation.phase_index == 4 and sim.drones.size() == 4 and sim.interceptors.size() == 4 and sim.capitals.size() == 3, "Population finale")
	presentation_key(KEY_SPACE)
	await frames(3)
	check(paused and sim.presentation.state == PresentationDemonstration.State.FINISHED and sim.demo_controls.presentation_replay.visible, "Skip FIN")
	sim.demo_controls.presentation_replay.pressed.emit()
	await frames(3)
	check(sim.presentation.state == PresentationDemonstration.State.READY and sim.death_count == 0, "REJOUER FIN")
	presentation_key(KEY_SPACE)
	await frames(3)
	sim.stop_on_squadron_extinction = true
	for blue: BlueShip in sim.ships.duplicate():
		blue.take_damage(20)
	await frames(2)
	check(not sim.demonstration.game_over and sim.presentation.state == PresentationDemonstration.State.RUNNING, "Game Over lors d'une extinction en PRESENTATION")
	while sim.presentation.phase_elapsed < 3.0:
		await process_frame
	check(sim.ships.size() == 15 and sim.reinforcement_count == 15, "Extinction sans renforts")
	sim.ships[0].take_damage(20)
	await frames(2)
	presentation_key(KEY_R)
	await frames(3)
	check(paused and sim.presentation.state == PresentationDemonstration.State.READY and sim.death_count == 0, "R restart READY")
	presentation_key(KEY_F5)
	await frames(3)
	check(not paused and sim.demonstration.is_guided() and sim.demonstration.phase_index == 4 and sim.demonstration.phase_duration(4) == 42, "F1–F6 Guided M16")
	presentation_key(KEY_F7)
	await frames(3)
	presentation_key(KEY_D)
	await frames(3)
	check(not paused and not sim.presentation.active() and sim.demonstration.mode == GuidedDemonstration.DemoMode.FREE, "D FREE")
	for id: int in free_ids:
		check(sim.ships.any(func(blue: BlueShip) -> bool: return blue.get_instance_id() == id), "FREE identité non restaurée")
	sim.demo_controls.presentation_button.pressed.emit()
	await frames(3)
	presentation_key(KEY_ESCAPE)
	await frames(3)
	check(not paused and not sim.presentation.active(), "Bouton F7 / Échap")
	records.append({"test": "controls", "ready": true, "skip": true, "pause_actors_projectiles_camera_timer": true, "restart": true, "free": true, "guided": true, "no_game_over_after_extinction": true})
	await dispose(sim)


func complete_presentation(seed_value: int, native: bool) -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.presentation_seed = seed_value
	var observer: Node = PRESENTATION_OBSERVER.new()
	observer.simulation = sim
	sim.add_child(observer)
	if native:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		# Fenêtre dédiée au benchmark : empêcher un resize interactif de bloquer le rendu.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		root.content_scale_size = Vector2i(1920, 1080)
	sim.presentation.prepare()
	# Compilation / shaders avant la mesure, sans avancer la démo.
	var warmup: int = Time.get_ticks_usec()
	while native and Time.get_ticks_usec() - warmup < 2000000:
		await process_frame
	if native:
		# Les changements de décoration de fenêtre peuvent modifier sa zone cliente.
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		await frames(3)
	sim.presentation.start_or_next()
	var started: int = Time.get_ticks_usec()
	var window_started: int = started
	var counted: int = 0
	var window_count: int = 0
	var fps_windows: Array[float] = []
	var logged_phase: int = -1
	var arrivals: Dictionary = {}
	var starting_window: Vector2i = DisplayServer.window_get_size() if native else Vector2i.ZERO
	while sim.presentation.state != PresentationDemonstration.State.FINISHED:
		await process_frame
		if sim.presentation.phase_index != logged_phase:
			logged_phase = sim.presentation.phase_index
			print("M17 seed=%d phase=%d elapsed=%.3f" % [seed_value, logged_phase + 1, sim.presentation.elapsed_real])
		if sim.presentation.phase_index == 3:
			for node: Node in get_nodes_in_group("artillery_projectiles"):
				var family: String = str(node.get_meta("weapon_family", ""))
				if not arrivals.has(family) and sim.ships.any(func(blue: BlueShip) -> bool: return blue.global_position.distance_to((node as Node3D).global_position) < 65):
					arrivals[family] = sim.presentation.phase_elapsed
			if sim.demonstration.bomb_explosions > 0 and not arrivals.has("Bomb detonation"):
				arrivals["Bomb detonation"] = sim.presentation.phase_elapsed
		counted += 1
		window_count += 1
		var now: int = Time.get_ticks_usec()
		if now - window_started >= 1000000:
			fps_windows.append(float(window_count) * 1000000 / (now - window_started))
			window_started = now
			window_count = 0
		if now - started > 300000000:
			check(false, "Présentation ne termine pas avant 5 minutes")
			break
	var wall_seconds: float = float(Time.get_ticks_usec() - started) / 1000000
	var phases: Array[Dictionary] = sim.presentation.records.duplicate(true)
	var minimum: float = fps_windows.min() if not fps_windows.is_empty() else 0.0
	var record: Dictionary = {"test": "native_1080p" if native else "headless_complete", "seed": seed_value, "wall_seconds": wall_seconds, "presentation_seconds": sim.presentation.elapsed_real, "fps_mean": counted / wall_seconds, "fps_min_1s": minimum, "fps_windows": fps_windows, "deaths": sim.death_count, "reinforcements": sim.reinforcement_count, "reinforcement_delays": sim.reinforcement_spawns.duplicate(), "boosts": sim.evasive_boost_count, "blue_alive": sim.ships.size(), "phases": phases, "actors": observer.phases.duplicate(true), "game_over": sim.demonstration.game_over, "render_pixels": root.get_texture().get_size() if native else Vector2.ZERO}
	record.window_pixels_start = starting_window
	record.window_pixels_end = DisplayServer.window_get_size() if native else Vector2i.ZERO
	record.msaa_3d = root.msaa_3d
	record.artillery_arrival_seconds = arrivals
	check(phases.size() == 5 and sim.demo_controls.presentation_panel.visible and paused, "Cinq phases / FIN figée")
	check(sim.presentation.elapsed_real >= 230 and sim.presentation.elapsed_real <= 245, "Durée programmée")
	check(not sim.demonstration.game_over, "Game Over en présentation")
	if phases.size() == 5:
		check(phases[0].megas >= 1 and phases[0].colossals == 1 and phases[0].first_events.get("obstacle", 100) < 3, "P1 dangers immédiats")
		check(phases[0].dispersion_end < phases[0].dispersion_peak and phases[0].blue_alive == 15, "P1 récupération / population")
		check(phases[1].first_events.get("pulse", 100) < 4 and phases[1].first_events.get("waypoint", 100) < 4 and phases[1].green_shots >= 10 and phases[1].green_shots <= 18, "P2 waypoints / 10–18 pulses utiles")
		check(phases[2].first_events.get("pursuit", 100) < 2 and phases[2].first_events.get("burst", 100) < 4 and phases[2].boosts > 0 and phases[2].first_events.has("disengage"), "P3 poursuite / boost / désengagement")
		check(phases[3].first_events.get("flash", 100) < 1 and phases[3].first_events.get("heavy", 100) < 2, "P4 Heavy immédiat")
		check(phases[3].gate_crossings.has("Gate") and phases[3].gate_crossings.has("Grid"), "Gate / Grid ne traversent pas")
		for family: String in ["Heavy", "Seeker", "Swarm", "Arc", "Bomb detonation"]:
			check(arrivals.has(family) and float(arrivals[family]) < {"Heavy": 7, "Seeker": 14, "Swarm": 52, "Arc": 55, "Bomb detonation": 32}[family], "P4 arrivée hors fenêtre : " + family)
		check(float(phases[3].gate_crossings.get("Gate", {}).get("first_time", 100)) < 25 and float(phases[3].gate_crossings.get("Grid", {}).get("first_time", 100)) < 44, "P4 traversées hors fenêtre")
		check(phases[3].bombs > 0 and phases[3].artillery_arrivals >= 12, "P4 attaques non arrivées")
		check(phases[4].asteroids_max <= 50 and phases[4].projectiles_max <= 35 and phases[4].large_gates_max <= 1 and phases[4].colossals_active_max <= 1, "P5 budgets")
	if native:
		check(DisplayServer.window_get_size() == Vector2i(1920, 1080), "Fenêtre native redimensionnée pendant la mesure")
		check(root.get_texture().get_size() == Vector2(1920, 1080), "Rendu natif hors 1080p")
		check(wall_seconds >= 230 and wall_seconds <= 245, "Durée réelle native")
		check(minimum > 60, "FPS natif sous 60")
	records.append(record)
	print("M17 RUN " + JSON.stringify(record))
	sim.presentation.leave()
	await dispose(sim)


func capture_presentation() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	for mode: int in [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]:
		for pixels: Vector2i in ([Vector2i(1280, 720), Vector2i(1920, 1080)] if mode == DisplayServer.WINDOW_MODE_WINDOWED else [Vector2i(1920, 1080)]):
			DisplayServer.window_set_mode(mode)
			if mode == DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_size(pixels)
			root.content_scale_size = pixels
			await frames(20)
			check(DisplayServer.window_get_mode() == mode, "Mode fenêtre / maximisé / fullscreen incorrect")
			for screen: int in [PresentationDemonstration.State.READY, PresentationDemonstration.State.FINISHED]:
				sim.demo_controls.show_presentation(screen)
				await frames(3)
				var bounds: Rect2 = sim.demo_controls.presentation_title.get_global_rect()
				check(root.get_visible_rect().encloses(bounds), "Titre READY / FIN hors écran")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/validation/presentation_ui_%d_%dx%d_%d.png" % [mode, pixels.x, pixels.y, screen])
			sim.demo_controls.show_presentation(PresentationDemonstration.State.RUNNING)
			sim.demo_controls.set_phase(3, PresentationDemonstration.TITLES[3], 3.0)
			await frames(20)
			check(root.get_visible_rect().encloses(sim.demo_controls.phase_panel.get_global_rect()), "Titre phase hors écran")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/presentation_ui_title_%d_%dx%d.png" % [mode, pixels.x, pixels.y])
			records.append({"test": "ui_context", "mode": mode, "window_size": DisplayServer.window_get_size(), "render_pixels": root.get_texture().get_size(), "ready_end_phase_title": true})
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(1920, 1080)
	sim.demo_controls.show_presentation(PresentationDemonstration.State.READY)
	sim.presentation.start_or_next()
	for index: int in range(5):
		while sim.presentation.phase_elapsed < (19.0 if index == 3 else 0.7 if index == 2 else 1.2):
			await process_frame
		if index == 2:
			while sim.presentation.phase_elapsed < 10 and not sim.ships.any(func(blue: BlueShip) -> bool: return blue.evasive_boost_remaining > 0 and blue._aura_blend > 0.6):
				await process_frame
			check(sim.ships.any(func(blue: BlueShip) -> bool: return blue.evasive_boost_remaining > 0 and blue._aura_blend > 0.6), "Aura absente de la capture Interceptor")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/presentation_phase%d.png" % (index + 1))
		check(root.get_visible_rect().encloses(sim.demo_controls.phase_panel.get_global_rect()), "Titre phase hors écran")
		sim.presentation.start_or_next()
	records.append({"test": "ui", "720p_1080p_maximized_fullscreen": true, "ready_end": true, "captures": 5})
	sim.presentation.leave()
	await dispose(sim)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/validation")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_value: int = 20261012
	for arg: String in args:
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
	if args.has("--native"):
		await complete_presentation(seed_value, true)
	elif args.has("--capture"):
		await capture_presentation()
	elif args.has("--complete"):
		await complete_presentation(seed_value, false)
	else:
		await presentation_controls()
	var suffix: String = "native_%d" % seed_value if args.has("--native") else "capture" if args.has("--capture") else "complete_%d" % seed_value if args.has("--complete") else "controls"
	var file: FileAccess = FileAccess.open("res://.godot/m17_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS M17 : présentation soutenance." if failures == 0 else "FAIL M17 : présentation soutenance.")
	quit(0 if failures == 0 else 1)
