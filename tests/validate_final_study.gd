extends "res://tests/validate_arcade_hazards.gd"

const OBSERVER: Script = preload("res://tests/study_observer.gd")

func damage_flash() -> void:
	var sim: SpaceSimulation = modern(1)
	var blue: BlueShip = sim.ships[0]
	check(not blue._hit_flash.visible, "Flash actif sans impact")
	blue.take_damage(1)
	await frames(2)
	check(blue.alive and blue._hit_flash.visible and blue._hit_flash.light_energy > 0, "Flash d'impact supprimé")
	await frames(20)
	check(not blue._hit_flash.visible and is_zero_approx(blue._hit_flash.light_energy), "Lumière inactive conservée après le flash")
	records.append({"test": "damage_flash", "visible_on_damage": true, "hidden_when_idle": true})
	await dispose(sim)

func key(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code as Key
	event.pressed = true
	Input.parse_input_event(event)

func controls() -> void:
	var sim: SpaceSimulation = modern()
	sim.demonstration.start()
	await frames(3)
	sim.presentation.guided_phase(4)
	await frames(3)
	check(sim.demonstration.phase_index == 4 and sim.capitals.size() == 3 and sim.ships.size() == 15, "F5 n'initialise pas la phase Capital")
	while sim.demonstration.phase_elapsed < 2.5:
		await process_frame
	check(not get_nodes_in_group("artillery_projectiles").is_empty(), "Pause sans projectiles à vérifier")
	key(KEY_P)
	await frames(2)
	check(paused and sim.demo_controls.pause_label.visible, "P ne suspend pas la simulation")
	var positions: Dictionary = {}
	for group: String in ["blue_ships", "hostile_agents", "artillery_projectiles", "combat_hazards"]:
		for node: Node3D in get_nodes_in_group(group):
			positions[node] = node.global_transform
	var timer: float = sim.demonstration.phase_elapsed
	var camera_pose: Transform3D = sim.camera.global_transform
	await frames(40)
	for node: Node3D in positions:
		check(node.global_transform.is_equal_approx(positions[node]), "Entité mobile pendant PAUSE")
	check(is_equal_approx(timer, sim.demonstration.phase_elapsed) and sim.camera.global_transform.is_equal_approx(camera_pose), "Timer / caméra mobile pendant PAUSE")
	if OS.get_cmdline_user_args().has("--ui-native"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m16_pause.png")
	key(KEY_P)
	await frames(5)
	check(not paused and not sim.demo_controls.pause_label.visible and sim.demonstration.phase_elapsed > timer, "Reprise incorrecte")
	var old_deaths: int = sim.death_count
	sim.presentation.guided_phase(2)
	await frames(3)
	check(sim.demonstration.phase_index == 2 and sim.drones.size() == 4 and sim.capitals.is_empty(), "F3 / nettoyage Capital incorrect")
	check(get_nodes_in_group("artillery_projectiles").is_empty() and get_nodes_in_group("combat_hazards").is_empty(), "Résidus après saut")
	check(sim.death_count == old_deaths, "Nettoyage compté comme mort")
	sim.presentation.guided_phase(5)
	await frames(3)
	check(sim.ships.size() == 15 and sim.drones.size() == 4 and sim.interceptors.size() == 4 and sim.capitals.size() == 3, "F6 populations incorrectes")
	check(sim.camera.mode == SimulationCamera.Mode.CINEMATIC and sim.asteroid_container.storm_enabled, "F6 caméra / environnement incorrect")
	var blue: BlueShip = sim.ships[0]
	blue.take_damage(20)
	await frames(2)
	check(sim.death_count == old_deaths + 1, "Mort réelle non comptée")
	sim.demonstration.restart()
	await frames(3)
	check(sim.death_count == 0 and sim.demonstration.phase_index == 0 and sim.simulation_seed == sim.demonstration.demonstration_seed, "Replay ne restaure pas phase/seed/pertes")
	for index: int in range(6):
		sim.presentation.guided_phase(index)
		await frames(2)
		check(sim.demonstration.phase_index == index and sim.demonstration.phase_elapsed < 0.1, "Bouton phase / timer incorrect")
	key(KEY_PAUSE)
	await frames(2)
	sim.presentation.guided_phase(1)
	await frames(2)
	check(paused and sim.demonstration.phase_index == 1, "Saut pendant pause incorrect")
	check(sim.camera.global_position.length() < 100, "Caméra loin de la nouvelle scène après saut")
	sim.demonstration.stop()
	check(not paused and not sim.demonstration.is_guided(), "Retour FREE reste suspendu")
	check(not sim.demonstration.jump_to_phase(6), "Index de phase invalide accepté")
	records.append({"test": "presentation_controls", "pause": true, "jump_buttons": 6, "replay": true, "free_restored": true})
	await dispose(sim)

func study_sim(seed_value: int, parameters: Dictionary) -> SpaceSimulation:
	var sim: SpaceSimulation = modern(0)
	sim.demonstration.demonstration_seed = seed_value
	sim.demonstration.jump_to_phase(5)
	sim.set_spacing_multiplier(parameters.get("spacing", 1.0))
	sim.set_movement_multiplier(parameters.get("movement", 1.0))
	sim.set_rock_density(parameters.get("density", 1.0))
	var field: ObstacleField = sim.asteroid_container
	# Recréer uniquement le lot physique contrôlé, avant le premier tick.
	field._storm_container.free()
	field._storm_visuals.free()
	field.active_asteroid_count = 0
	field.active_mobile_count = 0
	field.maximum_active_observed = 0
	field.maximum_mobile_observed = 0
	field.storm_target = clampi(roundi(32 * sim.rock_density), 1, 62)
	field.initialize_field(seed_value + 5 * 1091, sim._fleet_center(), sim._fleet_z_bounds().x)
	field.advance(sim._fleet_center(), sim._fleet_z_bounds().x, sim._fleet_z_bounds().y)
	check(get_nodes_in_group("asteroids").size() == field.storm_target, "Lot contrôlé de rochers incorrect")
	var interceptors_requested: int = int(parameters.get("interceptors", 4))
	sim.manual_interceptor_count_override = interceptors_requested
	while sim.interceptors.size() > interceptors_requested:
		sim._retire_interceptor(sim.interceptors.back())
	while sim.interceptors.size() < interceptors_requested:
		sim.demonstration._spawn_interceptor(sim._fleet_center(), sim.interceptors.size())
	sim.set_fire_intensity(parameters.get("fire", 1.0))
	return sim

func study_case(seed_value: int, parameters: Dictionary) -> Dictionary:
	var sim: SpaceSimulation = study_sim(seed_value, parameters)
	# Pour l'étude, les attaques suivent le même pas physique que les agents.
	# Le séquenceur de présentation normal reste piloté par le rendu.
	sim.demonstration.set_process(false)
	# Stabiliser l'horloge 2×/120 Hz avant le premier tick de chaque essai.
	# Un appel depuis call_deferred ou physics_frame doit partir du même bord.
	sim.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	var observer: Node = OBSERVER.new()
	observer.simulation = sim
	observer.drive_study_clock = true
	observer.stop_simulated_seconds = 60
	sim.add_child(observer)
	sim.process_mode = Node.PROCESS_MODE_INHERIT
	while not paused:
		await process_frame
	var result: Dictionary = observer.result()
	result.seed = seed_value
	result.parameters = parameters
	result.simulated_seconds = sim.elapsed_simulation_time
	result.real_equivalent_seconds = sim.demonstration.phase_elapsed
	result.gate_passages = sim.demonstration.gate_passages
	result.gate_bypasses = sim.demonstration.gate_bypasses
	check(result.projectiles_max <= 40 and result.asteroids_max <= 64, "Étude dépasse les budgets M15")
	sim.set_presentation_paused(false)
	await dispose(sim)
	return result

func study() -> void:
	var results: Dictionary = {"protocol": {"godot": Engine.get_version_info().string, "seed": 20261012, "duration_simulated_seconds": 60, "physics_hz": 120, "pace": 2, "nominal": {"spacing": 1, "movement": 1, "density": 1, "fire": 1, "interceptors": 4}, "nominal_storm_target": 32, "density_ceiling": 62, "description": "Finale contrôlée, un paramètre à la fois ; 15 Blue / 4 Patrol / 4 Interceptor / 3 Capital."}, "parameters": [], "seeds": []}
	results.protocol.sequence_clock = "physics delta, independent of render"
	results.protocol.startup_frozen_frames = 2
	var ranges: Dictionary = {"spacing": [0.8, 1.0, 1.2, 1.4], "movement": [0.7, 1.0, 1.3, 1.6], "density": [0.7, 1.0, 1.5, 2.0], "fire": [0.7, 1.0, 1.5, 2.0], "interceptors": [0, 2, 4, 6]}
	for parameter: String in ranges:
		for value: float in ranges[parameter]:
			var sample: Dictionary = await study_case(20261012, {parameter: value})
			sample.parameter = parameter
			sample.value = value
			results.parameters.append(sample)
			print("M16 STUDY " + parameter + "=" + str(value) + " " + JSON.stringify(sample))
	for seed_value: int in [20261012, 20261013, 20261014, 20261015, 20261016]:
		var sample: Dictionary = await study_case(seed_value, {})
		results.seeds.append(sample)
		print("M16 SEED " + JSON.stringify(sample))
	DirAccess.make_dir_recursive_absolute("res://docs/experiments")
	var file: FileAccess = FileAccess.open("res://docs/experiments/m16_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	records.append({"test": "study", "parameter_runs": 20, "seed_runs": 5})

func study_reproducibility() -> void:
	var cold: Dictionary = await study_case(20261012, {})
	var warm: Dictionary = await study_case(20261012, {})
	for field: String in ["spacing_mean", "dispersion_max", "dispersion_final", "deaths", "death_causes", "reinforcements", "boosts", "targeted", "impacts", "pursuits", "bursts", "transitions", "isolated_final", "simulated_seconds", "real_equivalent_seconds"]:
		check(cold.get(field) == warm.get(field), "Étude dépendante du premier bord d'horloge : " + field)
	records.append({"test": "study_reproducibility", "cold_and_warm_equal": true, "runs": 2})

func recovery() -> void:
	var sim: SpaceSimulation = modern()
	for index: int in range(sim.ships.size()):
		var blue: BlueShip = sim.ships[index]
		blue.position = Vector3((index % 5 - 2) * 12, (index / 5 - 1) * 12, 0)
		blue.wander_strength = 0
		blue.vertical_wander_strength = 0
		blue.longitudinal_wander_strength = 0
		blue._speed_factor = 1
		sim.configure_guided_blue(blue)
		blue.adaptive_threat_response = true
	sim._measure_group(sim._fleet_center())
	var before: float = sim.dispersion
	var gate: MovingLaserGate = MovingLaserGate.new()
	gate.position = Vector3(0, 0, -220)
	sim.projectile_container.add_child(gate)
	var maximum: float = before
	await frames(1)
	for frame: int in range(330):
		await process_frame
		sim._measure_group(sim._fleet_center())
		maximum = maxf(maximum, sim.dispersion)
	await frames(900)
	sim._measure_group(sim._fleet_center())
	check(sim.death_count == 0 and sim.dispersion < maximum, "Pas de récupération locale après Gate")
	records.append({"test": "emergence_recovery", "before": before, "maximum": maximum, "after_15_sim_seconds": sim.dispersion, "deaths": sim.death_count, "isolated_final": sim.isolated_agent_count})
	await dispose(sim)

func demonstration_m16(native: bool) -> void:
	var capture: bool = OS.get_cmdline_user_args().has("--capture")
	var finale_only: bool = OS.get_cmdline_user_args().has("--finale")
	if native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.auto_start_presentation_demo = false
	sim.threat_choreography_enabled = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pace="):
			sim.guided_simulation_speed = argument.trim_prefix("--pace=").to_float()
	root.add_child(sim)
	sim.demonstration.start()
	await frames(3)
	var observer: Node = OBSERVER.new()
	observer.simulation = sim
	sim.add_child(observer)
	if finale_only:
		sim.demonstration._begin_phase(5, Vector3.ZERO)
	# Écarter uniquement la création initiale ; toutes les phases restent mesurées.
	if native:
		while sim.demonstration.phase_elapsed < 2:
			await process_frame
	var started: int = Time.get_ticks_usec()
	var last: int = started
	var count: int = 0
	var bucket: int = 0
	var minimum: float = INF
	var windows: Array[Dictionary] = []
	var captured: Dictionary[int, bool] = {}
	var final_finished: bool = false
	while not sim.demonstration.game_over:
		await process_frame
		count += 1
		bucket += 1
		var now: int = Time.get_ticks_usec()
		if now - last >= 1000000:
			var fps: float = bucket * 1000000.0 / (now - last)
			minimum = minf(minimum, fps)
			windows.append({"phase": sim.demonstration.phase_index + 1, "elapsed": sim.demonstration.phase_elapsed, "fps": fps})
			last = now
			bucket = 0
		var phase: int = sim.demonstration.phase_index
		if native and capture and phase in [0, 2, 5] and sim.demonstration.phase_elapsed >= (14.5 if phase == 0 else 12) and not captured.has(phase):
			captured[phase] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m16_phase_%d.png" % (phase + 1))
		if native and capture and phase == 4:
			for moment: int in [16]:
				var capture_key: int = 100 + moment
				if sim.demonstration.phase_elapsed >= moment and not captured.has(capture_key):
					captured[capture_key] = true
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.godot/validation/m16_capital_%d.png" % moment)
		if phase == 5 and sim.demonstration.phase_elapsed >= 60:
			check(sim.demonstration.is_guided() and sim.difficulty_level == 3, "Finale revient automatiquement en FREE")
			sim.demonstration._finish_phase()
			final_finished = true
			break
	var duration: float = float(Time.get_ticks_usec() - started) / 1000000
	var phases: Array[Dictionary] = sim.demonstration.phase_results.duplicate(true)
	if not finale_only:
		check(phases.size() == 6, "Démo s'arrête avant l'assaut final")
		for phase: Dictionary in phases:
			check(phase.projectiles_max <= 40 and phase.asteroids_max <= 64 and phase.nodes_max < 5000, "Budget physique M16 dépassé")
			check(phase.large_gates_max <= 1 and phase.colossals_active_max <= 1, "Plusieurs grandes grilles / Colossal simultanés")
		if phases.size() >= 5:
			check(phases[2].green_shots > 0 and phases[3].enemy_shots >= 20 and phases[3].boosts > 0, "Phases 3/4 sans attaque ciblée / boost")
			check(phases[4].targeted >= (phases[4].targeted + phases[4].suppression) * 0.65 and phases[4].boosts > 0, "Phase 5 ratio ciblé / boost insuffisant")
			for family: String in ["Heavy", "Seeker", "Bomb", "Laser", "Swarm"]:
				check(phases[4].weapon_families.has(family) and int(phases[4].weapon_families[family].shots) > 0 and int(phases[4].weapon_families[family].reactions) > 0, "Phase 5 sans action/réaction : " + family)
			# Arc reste balistique : sa réaction est testée dans la fixture ciblée.
			check(phases[4].weapon_families.has("Arc") and int(phases[4].weapon_families.Arc.shots) > 0, "Signature Arc absente phase 5")
	if not finale_only:
		check(phases[0].colossals == 1 and phases[1].colossals == 1, "Colossal absent phase 1/2")
		check(phases[0].megas > 0 and phases[1].megas > 0, "Mega absent phase 1/2")
		for motion: int in [SpaceAsteroid.MotionType.DIAGONAL, SpaceAsteroid.MotionType.VERTICAL_SWEEP, SpaceAsteroid.MotionType.CIRCULAR, SpaceAsteroid.MotionType.ARC]:
			check(int(phases[1].motion_types.get(motion, 0)) > 0, "Trajectoire dynamique absente phase 2")
		check(phases[4].moving_gates >= 1 and phases[4].rotating_gates >= 1 and phases[4].gate_passages > 0, "Grilles sans traversée phase 5")
	var final: Dictionary = phases.back()
	check(final.blue_alive >= 13 and not sim.demonstration.game_over, "Population finale non maintenue")
	check(final.green == 4 and final.red == 4 and final.capital == 3, "Population hostile finale M16 non maintenue")
	check(final.phase == 6 and final.real_seconds >= 5, "Extinction trop rapide en finale")
	check(final.targeted > 0 and final.boosts > 0 and final.critical_threats > 0 and final.lateral_excursion > 20, "Finale sans menaces / esquives visibles")
	check(final.projectiles_max <= 40 and final.asteroids_max <= 64, "Plafond finale dépassé")
	var record: Dictionary = {"test": "native_1080p" if native else "headless_complete", "pace": sim.guided_simulation_speed, "physics_hz": Engine.physics_ticks_per_second, "wall_seconds": duration, "fps_mean": count / duration, "fps_min_1s": minimum, "fps_windows": windows, "finale_60_seconds": final_finished, "game_over": sim.demonstration.game_over, "phases": phases, "metrics": sim.threat_metrics(), "capture_included": capture, "render_pixels": root.get_texture().get_size() if native else Vector2.ZERO}
	if native and not capture:
		check(minimum > 60, "FPS 1080p sous 60")
	record.window_pixels = DisplayServer.window_get_size() if native else Vector2i.ZERO
	record.msaa_3d = root.msaa_3d
	record.warmup_seconds = 2 if native else 0
	record.telemetry = observer.phases.duplicate(true)
	record.death_causes = sim.death_causes.duplicate()
	records.append(record)
	print("M16 RUN " + JSON.stringify(record))
	sim.demonstration.stop()
	await dispose(sim)

func ui_resolutions() -> void:
	var sim: SpaceSimulation = modern()
	sim.demonstration.start()
	await frames(5)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for pixels: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(pixels)
		root.content_scale_size = pixels
		await frames(15)
		sim.demo_controls.panel.show()
		sim.demo_controls.help_panel.show()
		await frames(3)
		check(sim.demo_controls.panel.get_global_rect().end.y <= pixels.y and sim.demo_controls.panel.get_global_rect().position.x >= 0, "Panneau hors fenêtre")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m16_ui_%dx%d.png" % [pixels.x, pixels.y])
		records.append({"test": "resolution", "pixels": root.get_texture().get_size(), "requested": pixels, "panel_bounds": sim.demo_controls.panel.get_global_rect()})
	for mode: int in [DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]:
		DisplayServer.window_set_mode(mode)
		root.content_scale_size = Vector2i(1920, 1080)
		await frames(15)
		check(DisplayServer.window_get_mode() == mode, "Mode maximisé / fullscreen incorrect")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m16_ui_%s.png" % ("maximized" if mode == DisplayServer.WINDOW_MODE_MAXIMIZED else "fullscreen"))
		records.append({"test": "window_mode", "mode": mode, "window_size": DisplayServer.window_get_size(), "render_pixels": root.get_texture().get_size()})
	await dispose(sim)


func _run() -> void:
	if OS.get_cmdline_user_args().has("--native"):
		await demonstration_m16(true)
	elif OS.get_cmdline_user_args().has("--ui-native"):
		await controls()
		await ui_resolutions()
	elif OS.get_cmdline_user_args().has("--study"):
		await study()
	else:
		await study_reproducibility()
		await damage_flash()
		await controls()
		await recovery()
	var output: String = "native" if OS.get_cmdline_user_args().has("--native") else "ui" if OS.get_cmdline_user_args().has("--ui-native") else "study_summary" if OS.get_cmdline_user_args().has("--study") else "controls"
	var file: FileAccess = FileAccess.open("res://.godot/m16_" + output + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS M16 : contrôles, étude et validation finale." if failures == 0 else "FAIL M16 : validation finale.")
	quit(0 if failures == 0 else 1)
