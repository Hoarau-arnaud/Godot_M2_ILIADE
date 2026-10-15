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
	check(sim.presentation.phase_index == 1 and sim.drones.size() == 15 and sim.demo_controls.phase_label.text == "PHASE 2 — PATROUILLE AUTONOME", "ESPACE skip")
	check(sim.death_count == death_before and get_nodes_in_group("asteroids").is_empty(), "Skip résidus / fausses morts")
	presentation_key(KEY_SPACE)
	await frames(3)
	check(sim.presentation.phase_index == 2 and sim.interceptors.size() == 15 and not is_instance_valid(sim.demonstration._markers), "Skip Interceptor / marqueurs")
	for hostile: Interceptor in sim.interceptors.slice(0, 3):
		hostile.take_damage(20)
	await frames(3)
	check(sim.interceptors.size() <= 12, "P3 délai de remplacement absent")
	var replacement_until: float = sim.presentation.phase_elapsed + 1.6
	while sim.presentation.phase_elapsed < replacement_until:
		await process_frame
	check(sim.presentation.total_respawns.interceptor >= 3, "P3 remplacements après délai")
	presentation_key(KEY_SPACE)
	await frames(30)
	check(sim.capitals.size() == 6, "Six Capital en présentation")
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
	check(sim.presentation.phase_index == 4 and sim.drones.size() == 15 and sim.interceptors.size() == 15 and sim.capitals.size() == 6, "Population finale")
	presentation_key(KEY_SPACE)
	await frames(3)
	check(not paused and sim.presentation.state == PresentationDemonstration.State.FINAL_SANDBOX and sim.demo_controls.battle_panel.visible, "Skip sandbox")
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
	sim.presentation.guided_phase(4)
	await frames(3)
	check(not paused and sim.demonstration.is_guided() and sim.demonstration.phase_index == 4 and sim.demonstration.phase_duration(4) == 42, "Helper Guided M16 interne")
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


func population_snapshot(sim: SpaceSimulation) -> Dictionary:
	var data: Dictionary = {"frames": 0, "seconds": 0.0, "fps_windows": [], "window_frames": 0, "window_started": Time.get_ticks_usec(), "patrol_min": sim.drones.size(), "patrol_max": sim.drones.size(), "interceptor_min": sim.interceptors.size(), "interceptor_max": sim.interceptors.size(), "capital_min": sim.capitals.size(), "capital_max": sim.capitals.size(), "capital_distance_min": INF, "capital_distance_max": 0.0, "pursued_targets": {}, "capital_attacks": {}, "spawn_offsets": [], "route_geometries": [], "individual_seeds": [], "marker_routes": sim.demonstration._marker_drones.size()}
	var center: Vector3 = sim._fleet_center()
	for actor: Node3D in sim.drones + sim.interceptors + sim.capitals:
		data.spawn_offsets.append(actor.global_position - center)
		data.individual_seeds.append(actor.individual_seed)
	for drone: PatrolDrone in sim.drones:
		data.route_geometries.append(drone.demonstration_route_offsets.duplicate())
	for index: int in range(sim.capitals.size()):
		var capital: CapitalShip = sim.capitals[index]
		var role: int = index
		capital.salvo_started.connect(func(pattern: int) -> void:
			if not data.capital_attacks.has(role):
				data.capital_attacks[role] = []
			data.capital_attacks[role].append(pattern)
		)
	return data


func population_sample(sim: SpaceSimulation, data: Dictionary, seconds: float) -> void:
	data.frames += 1
	data.seconds += seconds
	data.window_frames += 1
	for family: String in ["patrol", "interceptor", "capital"]:
		var count: int = sim.drones.size() if family == "patrol" else sim.interceptors.size() if family == "interceptor" else sim.capitals.size()
		data[family + "_min"] = mini(data[family + "_min"], count)
		data[family + "_max"] = maxi(data[family + "_max"], count)
	for hostile: Interceptor in sim.interceptors:
		if is_instance_valid(hostile.target):
			data.pursued_targets[hostile.target.individual_seed] = true
	for capital: CapitalShip in sim.capitals:
		var distance: float = capital.global_position.distance_to(sim._fleet_center())
		data.capital_distance_min = minf(data.capital_distance_min, distance)
		data.capital_distance_max = maxf(data.capital_distance_max, distance)
	var now: int = Time.get_ticks_usec()
	if now - int(data.window_started) >= 1000000:
		data.fps_windows.append(float(data.window_frames) * 1000000 / (now - int(data.window_started)))
		data.window_started = now
		data.window_frames = 0


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
	var populations: Array[Dictionary] = []
	var sampled_at: int = started
	var starting_window: Vector2i = DisplayServer.window_get_size() if native else Vector2i.ZERO
	while sim.presentation.state != PresentationDemonstration.State.FINAL_SANDBOX:
		await process_frame
		if sim.presentation.phase_index != logged_phase:
			logged_phase = sim.presentation.phase_index
			populations.append(population_snapshot(sim))
			print("M17 seed=%d phase=%d elapsed=%.3f" % [seed_value, logged_phase + 1, sim.presentation.elapsed_real])
		if sim.presentation.phase_index == 3:
			for node: Node in get_nodes_in_group("artillery_projectiles"):
				var family: String = str(node.get_meta("weapon_family", ""))
				if not arrivals.has(family) and sim.ships.any(func(blue: BlueShip) -> bool: return blue.global_position.distance_to((node as Node3D).global_position) < 65):
					arrivals[family] = sim.presentation.phase_elapsed
			if sim.demonstration.bomb_explosions > 0 and not arrivals.has("Bomb detonation"):
				arrivals["Bomb detonation"] = sim.presentation.phase_elapsed
		if sim.presentation.state == PresentationDemonstration.State.RUNNING:
			population_sample(sim, populations[logged_phase], float(Time.get_ticks_usec() - sampled_at) / 1000000)
		sampled_at = Time.get_ticks_usec()
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
	for data: Dictionary in populations:
		data.fps_mean = float(data.frames) / maxf(float(data.seconds), 0.000001)
		data.fps_min_1s = data.fps_windows.min() if not data.fps_windows.is_empty() else 0.0
		if int(data.capital_max) == 0:
			data.capital_distance_min = null
		data.erase("window_started")
		data.erase("window_frames")
	record.populations = populations
	var expected: Array[Array] = [[0, 0, 0], [15, 0, 0], [0, 15, 0], [0, 0, 6], [15, 15, 6]]
	for index: int in range(populations.size()):
		var data: Dictionary = populations[index]
		check([data.patrol_max, data.interceptor_max, data.capital_max] == expected[index], "Population P%d" % (index + 1))
		if index < phases.size():
			check(phases[index].projectiles_max <= (48 if index >= 3 else 35), "Budget global P%d" % (index + 1))
		if index == 1:
			check(data.patrol_min > 0 and data.route_geometries.size() == 15 and data.marker_routes >= 3 and data.marker_routes <= 5, "P2 routes / marqueurs / population active")
			var unique: Dictionary = {}
			for route: Array in data.route_geometries:
				unique[str(route)] = true
			check(unique.size() == 15, "P2 géométries identiques")
		if index == 2:
			check(data.interceptor_min > 0, "P3 population active après destruction")
			check(data.pursued_targets.size() >= 3, "P3 cibles non réparties")
		if index == 3:
			check(data.capital_max == 6 and data.capital_distance_max <= 750 and data.capital_attacks.size() >= 3, "P4 distances / six tireurs")
		if native and index in [1, 2, 3]:
			check(data.fps_min_1s > 60, "FPS phase %d sous 60" % (index + 1))
	check(phases.size() == 5 and sim.demo_controls.battle_panel.visible and not paused, "Cinq phases / sandbox actif")
	check(sim.presentation.automatic_duration >= 150 and sim.presentation.automatic_duration <= 157, "Durée programmée")
	check(not sim.demonstration.game_over, "Game Over en présentation")
	if phases.size() == 5:
		check(phases[0].megas >= 1 and phases[0].colossals == 1 and phases[0].first_events.get("obstacle", 100) < 3, "P1 dangers immédiats")
		check(phases[0].dispersion_end < phases[0].dispersion_peak and phases[0].blue_alive == 15, "P1 récupération / population")
		check(phases[1].first_events.get("pulse", 100) < 4 and phases[1].first_events.get("waypoint", 100) < 4 and phases[1].green_shots > 18, "P2 waypoints / pulses de quinze patrouilles")
		check(phases[2].first_events.get("pursuit", 100) < 2 and phases[2].first_events.get("burst", 100) < 4 and phases[2].boosts > 0 and phases[2].first_events.has("disengage"), "P3 poursuite / boost / désengagement")
		check(phases[3].first_events.get("flash", 100) < 1 and phases[3].first_events.get("heavy", 100) < 2, "P4 Heavy immédiat")
		check(phases[3].gate_crossings.has("Gate") and phases[3].gate_crossings.has("Grid"), "Gate / Grid ne traversent pas")
		check(phases[1].blue_shots > 0 and sim.hostile_hits > 0, "P2 combat Blue absent")
		check(phases[3].get("grid_launches", 0) >= 17 and phases[3].get("geometries", {}).size() >= 4, "P4 dix-huit grilles / géométries")
		check(phases[4].asteroids_max <= 80 and phases[4].projectiles_max <= 48 and phases[4].large_gates_max <= 4 and phases[4].colossals_active_max <= 1, "P5 budgets")
		for phase: Dictionary in phases:
			check(phase.duration >= 30 and phase.duration < 30.2, "Durée phase de trente secondes")

	if native:
		check(DisplayServer.window_get_size() == Vector2i(1920, 1080), "Fenêtre native redimensionnée pendant la mesure")
		check(root.get_texture().get_size() == Vector2(1920, 1080), "Rendu natif hors 1080p")
		check(wall_seconds >= 150 and wall_seconds <= 157, "Durée réelle native")
		check(minimum > 60, "FPS natif sous 60")
	records.append(record)
	await sandbox_run(sim, native, false)
	await sandbox_run(sim, native, true)
	sim.presentation.finish_battle()
	check(paused and sim.presentation.state == PresentationDemonstration.State.FINISHED, "Terminer sandbox")
	print("M17 RUN " + JSON.stringify(record))
	sim.presentation.leave()
	await dispose(sim)


func sandbox_run(sim: SpaceSimulation, native: bool, chaos: bool) -> void:
	var controller: PresentationDemonstration = sim.presentation
	var before_kills: int = sim.enemies_destroyed
	var before_deaths: int = sim.death_count
	var before_respawns: Dictionary = controller.total_respawns.duplicate()
	var before_grids: int = int(controller._sample.get("grid_launches", 0))
	if chaos:
		controller.reset_battle(true)
	else:
		controller.set_setting("fire", 1)
		controller.set_setting("fire", 3)
		controller.set_setting("width", 2)
		controller.set_setting("patrol", 20)
		check(controller.settings.fire == 3 and controller.settings.width == 2 and sim.manual_drone_count_override == 20, "Réglages runtime")
	check(sim.enemies_destroyed == before_kills and sim.death_count == before_deaths, "Réglages créent de faux kills")
	var sample: Dictionary = population_snapshot(sim)
	var start_clock: float = controller.sandbox_elapsed
	var started: int = Time.get_ticks_usec()
	var sampled_at: int = started
	var max_nodes: int = 0
	var max_projectiles: int = 0
	var profile: Array[Dictionary] = []
	var peak_frame: Dictionary = {"ms": 0.0}
	while controller.sandbox_elapsed - start_clock < 30:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var frame_ms: float = float(now - sampled_at) / 1000
		if frame_ms > float(peak_frame.ms):
			peak_frame = {"ms": frame_ms, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "rocks": get_nodes_in_group("asteroids").size(), "enemies": sim.drones.size() + sim.interceptors.size() + sim.capitals.size()}
		population_sample(sim, sample, float(now - sampled_at) / 1000000)
		if profile.size() < sample.fps_windows.size():
			profile.append(peak_frame.duplicate())
			peak_frame = {"ms": 0.0}
		sampled_at = now
		max_nodes = maxi(max_nodes, get_node_count())
		max_projectiles = maxi(max_projectiles, ArtilleryZone.dangerous_count(self))
		if now - started > 90000000:
			check(false, "Sandbox trop lent")
			break
	var wall: float = float(Time.get_ticks_usec() - started) / 1000000
	var minimum: float = sample.fps_windows.min() if not sample.fps_windows.is_empty() else 0.0
	var result: Dictionary = {"test": "chaos_30s" if chaos else "sandbox_runtime_30s", "settings": controller.settings.duplicate(), "fps_mean": float(sample.frames) / wall, "fps_min_1s": minimum, "native": native, "nodes_max": max_nodes, "projectiles_max": max_projectiles, "blue_deaths": sim.death_count - before_deaths, "enemy_kills": sim.enemies_destroyed - before_kills, "respawns": {}, "grid_launches": int(controller._sample.get("grid_launches", 0)) - before_grids, "populations": sample, "profile": profile}
	for family: String in controller.FAMILIES:
		result.respawns[family] = int(controller.total_respawns[family]) - int(before_respawns[family])
	check(max_projectiles <= 48 and max_nodes < 3200 and not sim.demonstration.game_over, "Sandbox budget / crash")
	if native:
		check(minimum > 60, "Sandbox / Chaos sous 60 FPS")
	records.append(result)
	print("BATTLE LAB " + JSON.stringify(result))
	var kept_deaths: int = sim.death_count
	var kept_kills: int = sim.enemies_destroyed
	controller.reset_battle()
	check(sim.death_count == kept_deaths and sim.enemies_destroyed == kept_kills and controller.settings == controller.DEFAULT_SETTINGS, "RESET du labo efface les compteurs")


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
	check(sim.demo_controls.battle_panel.visible and root.get_visible_rect().encloses(sim.demo_controls.battle_panel.get_global_rect()), "Panneau final hors écran")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/battle_sandbox.png")
	sim.presentation.finish_battle()
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
	if args.has("--profile-lab"):
		var sim: SpaceSimulation = modern()
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1920, 1080)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		sim.presentation.prepare()
		var warmup: int = Time.get_ticks_usec()
		while Time.get_ticks_usec() - warmup < 2000000:
			await process_frame
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		await frames(5)
		for _index: int in range(5):
			sim.presentation.start_or_next()
		sim.presentation.start_or_next()
		sim.presentation.toggle_pause()
		var assets_started: int = Time.get_ticks_usec()
		while Time.get_ticks_usec() - assets_started < 3000000:
			await process_frame
		sim.presentation.toggle_pause()
		await sandbox_run(sim, true, false)
		await sandbox_run(sim, true, true)
		sim.presentation.leave()
		await dispose(sim)
	elif args.has("--native"):
		await complete_presentation(seed_value, true)
	elif args.has("--capture"):
		await capture_presentation()
	elif args.has("--complete"):
		await complete_presentation(seed_value, false)
	else:
		await presentation_controls()
	var suffix: String = "profile_lab" if args.has("--profile-lab") else "native_%d" % seed_value if args.has("--native") else "capture" if args.has("--capture") else "complete_%d" % seed_value if args.has("--complete") else "controls"
	var file: FileAccess = FileAccess.open("res://.godot/interactive_battle_m17_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS M17 : présentation soutenance." if failures == 0 else "FAIL M17 : présentation soutenance.")
	quit(0 if failures == 0 else 1)
