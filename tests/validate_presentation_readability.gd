extends "res://tests/validate_final_battle_flow.gd"

var native_readability: bool = false
var screenshots: bool = false


func wait_phase(sim: SpaceSimulation, until: float) -> void:
	while sim.presentation.phase_elapsed < until:
		await process_frame


func capture_readability(file_name: String) -> void:
	if not screenshots:
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_size() == Vector2(1920, 1080), "Capture native 1080p")
	root.get_texture().get_image().save_png("res://.godot/validation/" + file_name + ".png")


func explosion_fixture() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	sim.presentation.start_or_next()
	sim.presentation._next_meteor_wave = INF
	sim.streaming_enabled = false
	for blue: BlueShip in sim.ships:
		blue.set_physics_process(false)
	var baseline: int = sim.death_count
	var explosion_ids: Dictionary = {}
	var death_ids: Array[int] = []
	for index: int in range(3):
		var blue: BlueShip = sim.ships[0]
		death_ids.append(blue.get_instance_id())
		blue.take_damage(20)
		blue.take_damage(20) # Le garde alive doit bloquer le second effet.
		for effect: Node3D in get_nodes_in_group("blue_death_explosions"):
			explosion_ids[effect.get_instance_id()] = true
		await frames(1)
	check(sim.death_count == baseline + 3 and explosion_ids.size() == 3, "Une vraie mort = une explosion et un compteur")
	var effects: Array[Node] = get_nodes_in_group("blue_death_explosions")
	for effect: Node in effects:
		check(effect.shard_count == 22 and effect.effect_duration == 1.2 and effect.effect_scale == 2.8, "Configuration explosion Blue")
		check(effect.has_node("WhiteFlash") and effect.has_node("OrangeFireball") and effect.has_node("ShockWave") and effect.has_node("WarmDeathLight"), "Quatre composantes et lumière")
	await wait_phase(sim, 0.12)
	await capture_readability("readability_blue_explosion")
	await wait_phase(sim, 0.95)
	check(get_nodes_in_group("blue_death_explosions").size() == 3, "Explosion visible >=0,9 seconde réelle")
	await wait_phase(sim, 1.4)
	check(get_nodes_in_group("blue_death_explosions").is_empty(), "Nettoyage explosion après 1,2 s")
	await wait_phase(sim, 2.8)
	check(sim.reinforcement_count == 3 and sim.ships.size() == 15 and sim.death_count == baseline + 3, "Renfort conserve les pertes")
	var admin: BlueShip = sim.ships[0]
	sim.ships.erase(admin)
	admin.retire()
	await frames(2)
	check(get_nodes_in_group("blue_death_explosions").is_empty() and sim.death_count == baseline + 3, "Retrait administratif sans explosion ni perte")
	# Un changement de phase puis F7 ne crée aucun effet.
	sim.presentation.start_or_next()
	sim.presentation.prepare()
	await frames(2)
	check(get_nodes_in_group("blue_death_explosions").is_empty(), "Reset / changement de phase sans explosion")
	records.append({"test": "blue_explosion", "deaths": 3, "explosions": explosion_ids.size(), "duration_real": 1.2, "shards": 22, "scale": 2.8, "reinforcements": 3, "admin_effects": 0})
	sim.presentation.leave()
	await dispose(sim)


func visual_scale_fixture() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	sim.presentation.jump_to_final()
	sim.presentation._events.clear()
	sim.presentation._grid_at = INF
	sim.streaming_enabled = false
	sim.combat_enabled = false
	for blue: BlueShip in sim.ships:
		blue.combat_enabled = false
	for family: String in ["patrol", "interceptor"]:
		var actor: PatrolDrone = sim.presentation._actors(family)[0]
		var root_scale: Vector3 = actor.scale
		var visual: Node3D = actor.get_node("Visuals") as Node3D
		check(visual.scale == Vector3.ONE * 1.5 and root_scale == Vector3.ONE, "Visuals seulement " + family)
		var shape: CollisionShape3D = actor.get_node("BodyCollision") as CollisionShape3D
		var shape_scale: Vector3 = shape.scale
		sim.presentation.pack_actor(actor, family)
		sim.presentation.pack_actor(actor, family)
		check(visual.scale == Vector3.ONE * 1.5 and shape.scale == shape_scale, "Scale idempotent et collision stable " + family)
		actor.take_damage(100)
	await wait_phase(sim, 1.8)
	for family: String in ["patrol", "interceptor"]:
		check(sim.presentation.total_respawns[family] >= 1, "Remplacement " + family)
		sim.presentation.set_setting(family, 25)
	await wait_phase(sim, 4.5)
	for family: String in ["patrol", "interceptor"]:
		check(sim.presentation._actors(family).size() == 25, "Slider 15 vers 25 " + family)
		for actor: Node3D in sim.presentation._actors(family):
			check((actor.get_node("Visuals") as Node3D).scale == Vector3.ONE * 1.5, "Scale après slider/respawn " + family)
	await capture_readability("readability_enemy_sizes")
	# Les pièces partagées reprennent exactement la pose et le matériau des moteurs animés.
	sim.presentation._light_visuals._process(0)
	var batched_parts: int = 0
	for entry: Dictionary in sim.presentation._light_visuals._entries:
		if not is_instance_valid(entry.actor) or entry.actor.is_queued_for_deletion():
			continue
		var batch: MultiMesh = sim.presentation._light_visuals._batches[entry.key]
		var found: bool = false
		for index: int in range(batch.visible_instance_count):
			if (sim.presentation._light_visuals.global_transform * batch.get_instance_transform(index)).is_equal_approx(entry.part.global_transform):
				found = true
		if native_readability: # Le RenderingServer dummy ne conserve pas les transforms GPU.
			check(found, "Moteur/surface lumineuse : pose exacte à 1,5x")
		batched_parts += 1
	check(batched_parts > 100 and sim.presentation._light_visuals._batches.size() <= 8, "Rendu groupé des moteurs et capteurs")
	var planet: MeshInstance3D = sim.space_decor._backdrop.get_node("NearbyPlanet") as MeshInstance3D
	var surface: ShaderMaterial = planet.material_override as ShaderMaterial
	check(bool(surface.get_shader_parameter("presentation_cached")) == native_readability, "Cache du décor réservé à la Présentation native")
	records.append({"test": "visual_scale", "before": 1.0, "after": 1.5, "root": 1.0, "populations": [25, 25], "respawn_idempotent": true})
	sim.presentation.leave()
	check(not bool(surface.get_shader_parameter("presentation_cached")), "Shader historique restauré en FREE")
	await dispose(sim)


func firing_scale_fixture() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	sim.presentation.jump_to_final()
	sim.presentation._events.clear()
	sim.presentation._grid_at = INF
	sim.streaming_enabled = false
	for blue: BlueShip in sim.ships:
		blue.set_physics_process(false)
		blue.velocity = Vector3.ZERO
		blue.global_position = Vector3(10000, 10000, 0)
	for family: String in PresentationDemonstration.FAMILIES:
		for actor: Node3D in sim.presentation._actors(family):
			actor.set_physics_process(false)
	var patrol: PatrolDrone = sim.drones[0]
	patrol.global_position = Vector3(5000, 0, 0)
	(patrol.get_node("Visuals") as Node3D).quaternion = Quaternion.IDENTITY
	patrol.patrol_firing_cone_degrees = 43
	patrol.predictive_targeting = true
	var blue: BlueShip = sim.ships[0]
	var before: int = patrol.patrol_shots_fired
	for final_battle: bool in [true, false]:
		patrol.presentation_battle = final_battle
		for angle: float in [50.0, 30.0]:
			blue.global_position = patrol.global_position + Vector3(sin(deg_to_rad(angle)), 0, -cos(deg_to_rad(angle))) * 30
			patrol._patrol_fire_timer = 0
			patrol._battle_fire_sample_at = -INF
			patrol._update_patrol_fire(0)
			check(patrol.patrol_shots_fired == before + (1 if angle == 30 else 0), "Scale 1,5 conserve le cône frontal Patrol en P2/P5")
		before += 1
	var hostile: Interceptor = sim.interceptors[0]
	hostile.global_position = Vector3(5000, 0, 100)
	hostile.target = blue
	hostile.combat_enabled = true
	hostile.readable_threats = false
	hostile._mission_state = Interceptor.InterceptorState.PURSUIT
	var visual: Node3D = hostile.get_node("Visuals") as Node3D
	visual.quaternion = Quaternion.IDENTITY
	var directions: Array[Vector3] = []
	hostile.fired.connect(func(shot: EnemyLaser) -> void: directions.append(shot.flight_direction))
	for visual_scale: float in [1.0, 1.5]:
		visual.scale = Vector3.ONE * visual_scale
		blue.global_position = hostile._muzzle.global_position + Vector3.FORWARD * 30
		hostile._fire_random.seed = 70147
		hostile._shot_timer = 0
		hostile._burst_remaining = 1
		hostile._update_fire(0)
	check(directions.size() == 2 and directions[0].is_equal_approx(directions[1]), "Scale 1,5 conserve la dispersion Interceptor")
	records.append({"test": "firing_scale", "patrol_cone": 43, "outside_50_rejected": true, "inside_30_fires": true, "interceptor_spread_unchanged": true})
	sim.presentation.leave()
	await dispose(sim)


func checkpoints_fixture() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	sim.presentation.start_or_next()
	sim.presentation.start_or_next()
	var probe: PatrolDrone = sim.drones[0]
	var checkpoint: int = probe.current_checkpoint_index
	probe.position = probe.waypoint + Vector3(100, 100, -100)
	probe._physics_process(0.001)
	check(probe.current_checkpoint_index == checkpoint, "Passage plan Z ne valide pas un checkpoint")
	probe.position = probe.waypoint
	probe._physics_process(0.001)
	check(probe.current_checkpoint_index == (checkpoint + 1) % 4, "Proximité spatiale valide le checkpoint suivant")
	sim.presentation.leave()
	await dispose(sim)


func meteor_geometry_fixture() -> void:
	var first_samples: Array[Dictionary] = []
	for repetition: int in range(2):
		var sim: SpaceSimulation = modern(1)
		var field: ObstacleField = sim.asteroid_container
		field.initialize_field(20261012, Vector3.ZERO, 0)
		field.spawn_presentation_meteor_wave(Vector3.ZERO, Vector3(0, 0, -20), 20261012, 1.0, 0)
		if repetition == 0:
			first_samples.assign(field.meteor_samples.duplicate(true))
		else:
			check(field.meteor_samples == first_samples, "Vague déterministe, mêmes seeds/formes/positions/vitesses")
		for rock: SpaceAsteroid in get_nodes_in_group("asteroids"):
			var origin: Vector3 = rock.global_position
			var flight: Vector3 = rock.motion_velocity
			check(origin.length() >= 70 and origin.length() <= 130, "Distance initiale 70–130 m")
			check(origin.distance_to(sim.ships[0].global_position) > rock.diameter * 0.65 + 25, "Aucun spawn sur Blue")
			# Déplacer le centre ne change jamais la trajectoire ; même après l'ancienne période.
			sim.ships[0].global_position += Vector3(200, 100, -100)
			rock._physics_process(81)
			check(rock.velocity.is_equal_approx(flight) and rock.global_position.distance_to(origin + flight * 81) < 0.02, "Trajectoire fixe sans homing ni ping-pong")
		await dispose(sim)
	records.append({"test": "meteor_geometry", "deterministic": true, "ballistic": true, "no_reverse_at_80s": true, "spawn_clearance": true})


func measured_checkpoints() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	sim.presentation.start_or_next()
	sim.presentation.start_or_next()
	var actors: Dictionary = {}
	var initial: Array[int] = []
	for patrol: PatrolDrone in sim.drones:
		initial.append(patrol.get_instance_id())
	var capture_done: bool = false
	while sim.presentation.phase_index == 1 and sim.presentation.state == PresentationDemonstration.State.RUNNING:
		await process_frame
		for patrol: PatrolDrone in sim.drones:
			actors[patrol.get_instance_id()] = {"slot": patrol.get_meta("presentation_slot"), "trace": patrol.checkpoint_trace.duplicate(true), "reached": patrol.checkpoint_reached.duplicate(), "loops": patrol.routes_completed}
			check(patrol.demonstration_route_offsets.size() == 4 and patrol.route_waypoints.size() == 4, "Exactement quatre checkpoints")
			check(patrol.waypoint.is_equal_approx(patrol.route_waypoints[patrol.current_checkpoint_index]), "Waypoint réellement poursuivi")
		for index: int in range(sim.demonstration._marker_drones.size()):
			var patrol: PatrolDrone = sim.demonstration._marker_drones[index]
			if not is_instance_valid(patrol) or not patrol.alive:
				continue
			for point: int in range(4):
				var marker_distance: float = sim.demonstration._marker_nodes[index * 4 + point].global_position.distance_to(patrol.route_waypoints[point])
				check(marker_distance < 0.001, "Marker = vraie position du checkpoint")
		if not capture_done and sim.presentation.phase_elapsed >= 6:
			capture_done = true
			await capture_readability("readability_patrol_checkpoints")
	var multiple: int = 0
	var loops: int = 0
	var traces: Array[Dictionary] = []
	for id: int in initial:
		var entry: Dictionary = actors[id]
		if entry.trace.size() >= 2:
			multiple += 1
		if int(entry.loops) >= 1:
			loops += 1
	for entry: Dictionary in actors.values():
		var letters: Array[String] = []
		check(int(entry.loops) == maxi(0, (entry.trace.size() - 1) / 4), "Boucle complète = retour au premier checkpoint atteint")
		var previous: int = -1
		for visit: Dictionary in entry.trace:
			check(float(visit.distance) <= 5.0001 and Vector3(visit.position).distance_to(visit.waypoint) <= 5.0001, "Vraie distance checkpoint <=5m")
			if previous >= 0:
				check(int(visit.checkpoint) == (previous + 1) % 4, "Ordre A B C D strict")
			previous = int(visit.checkpoint)
			letters.append(["A", "B", "C", "D"][previous])
		traces.append({"slot": entry.slot, "reached": entry.reached, "loops": entry.loops, "trace": " → ".join(letters)})
	check(multiple == 15, "15/15 cohortes initiales atteignent plusieurs checkpoints : %d" % multiple)
	check(loops >= 10, ">=10/15 boucles complètes : %d" % loops)
	records.append({"test": "patrol_30s", "initial_multiple": multiple, "initial_loops": loops, "traces": traces, "marker_slots": [0, 7, 14], "markers": 12, "reach_distance": 5})
	sim.presentation.leave()
	await dispose(sim)


func measured_meteors() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	if native_readability:
		await frames(120) # Préchauffage derrière READY, hors mesure.
	sim.presentation.start_or_next()
	var start: int = Time.get_ticks_usec()
	var window_start: int = start
	var count: int = 0
	var window_count: int = 0
	var fps_windows: Array[float] = []
	var dispersion_max: float = 0
	var dispersion_final: float = 0
	var nodes_max: int = 0
	var visible_max: int = 0
	var snapshots: Dictionary = {}
	var field: ObstacleField = sim.asteroid_container
	while sim.presentation.phase_index == 0 and sim.presentation.state == PresentationDemonstration.State.RUNNING:
		await process_frame
		count += 1
		window_count += 1
		var now: int = Time.get_ticks_usec()
		if now - window_start >= 1000000:
			fps_windows.append(float(window_count) * 1000000 / (now - window_start))
			window_count = 0
			window_start = now
		dispersion_max = maxf(dispersion_max, sim.dispersion)
		dispersion_final = sim.dispersion
		nodes_max = maxi(nodes_max, get_node_count())
		var visible: int = 0
		for rock: SpaceAsteroid in get_nodes_in_group("asteroids"):
			check(rock.presentation_meteor and rock.diameter <= 18 and rock.velocity.is_equal_approx(rock.motion_velocity), "P1 balistique / limite de taille / vitesse fixe")
			if sim.camera.is_position_in_frustum(rock.global_position) and rock.global_position.distance_to(sim._fleet_center()) < 100:
				visible += 1
		visible_max = maxi(visible_max, visible)
		for time: int in [6, 18, 28]:
			if sim.presentation.phase_elapsed >= time and not snapshots.has(time):
				snapshots[time] = true
				await capture_readability("readability_meteors_%02d" % time)
	var report: Dictionary = field.meteor_report()
	report.test = "meteors_30s"
	report.waves = sim.presentation.meteor_wave_index
	report.wave_times = sim.presentation.meteor_wave_times.duplicate()
	var interval_sum: float = 0
	for index: int in range(1, report.wave_times.size()):
		interval_sum += float(report.wave_times[index]) - float(report.wave_times[index - 1])
	report.wave_interval_mean = interval_sum / maxi(1, report.wave_times.size() - 1)
	report.blue_deaths = sim.death_count
	report.boosts = sim.evasive_boost_count
	report.meteor_avoidance_reactions = int(sim.weapon_metrics.get("Meteor", {}).get("reactions", 0))
	report.dispersion_max = dispersion_max
	report.dispersion_final = dispersion_final
	report.fps_mean = float(count) * 1000000 / (Time.get_ticks_usec() - start)
	report.fps_min_1s = fps_windows.min() if not fps_windows.is_empty() else 0
	report.nodes_max = nodes_max
	report.visible_near_max = visible_max
	report.samples = field.meteor_samples.duplicate(true)
	report.window_pixels = DisplayServer.window_get_size() if native_readability else Vector2i.ZERO
	report.render_pixels = root.get_texture().get_size() if native_readability else Vector2i.ZERO
	check(int(report.meteor_spawned) >= 60 and int(report.meteor_spawned) <= 100, "60–100 météores : %d" % report.meteor_spawned)
	check(field.mega_generated == 0 and field.colossal_generated == 0, "Aucun Mega/Colossal en P1")
	check(report.meteor_collisions == report.blue_deaths and report.blue_deaths <= 5, "P1 pertes mesurées 0–5 : %d" % report.blue_deaths)
	check(report.meteor_avoidance_reactions > 0 and report.boosts > 0, "Réactions et boosts réels P1")
	check(visible_max >= 5, ">=5 météores simultanés dans la caméra : %d" % visible_max)
	check(dispersion_final < dispersion_max, "Début de regroupement après barrage")
	if native_readability:
		check(report.fps_min_1s > 60, "P1 FPS min >60")
	records.append(report)
	sim.presentation.leave()
	await dispose(sim)


func chaos_explosions() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	if native_readability:
		await frames(120)
	sim.presentation.jump_to_final()
	if native_readability:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# P5 standard puis CHAOS, sans mort injectée dans la mesure.
	var standard: Dictionary = await battle_measure(sim, 30, "readability_P5", native_readability)
	if sim.presentation.state != PresentationDemonstration.State.FINAL_SANDBOX:
		sim.presentation.start_or_next()
	sim.presentation.reset_battle(true)
	var before: int = sim.death_count
	var start: float = sim.presentation.phase_elapsed
	var ids: Dictionary = {}
	var existing_effects: Dictionary = {}
	for effect: Node in get_nodes_in_group("blue_death_explosions"):
		existing_effects[effect.get_instance_id()] = true
	var simultaneous: int = 0
	var fps_windows: Array[float] = []
	var clock_start: int = Time.get_ticks_usec()
	var window_start: int = clock_start
	var frame_count: int = 0
	var window_count: int = 0
	var nodes_max: int = 0
	var profile_windows: Array[Dictionary] = []
	var profile_sum: Vector3 = Vector3.ZERO
	while sim.presentation.phase_elapsed - start < 30:
		await process_frame
		frame_count += 1
		window_count += 1
		var now: int = Time.get_ticks_usec()
		if now - window_start >= 1000000:
			fps_windows.append(float(window_count) * 1000000 / (now - window_start))
			profile_windows.append({"time": sim.presentation.phase_elapsed - start, "fps": fps_windows.back(), "process_ms": profile_sum.x / window_count, "physics_ms": profile_sum.y / window_count, "draw_calls": profile_sum.z / window_count, "render_cpu": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()), "render_gpu": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())})
			profile_sum = Vector3.ZERO
			window_start = now
			window_count = 0
		profile_sum += Vector3(Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var effects: Array[Node] = get_nodes_in_group("blue_death_explosions")
		simultaneous = maxi(simultaneous, effects.size())
		for effect: Node in effects:
			if not existing_effects.has(effect.get_instance_id()):
				ids[effect.get_instance_id()] = true
		nodes_max = maxi(nodes_max, get_node_count())
	var report: Dictionary = {"test": "CHAOS_explosions", "deaths": sim.death_count - before, "explosions": ids.size(), "simultaneous_max": simultaneous, "fps_mean": float(frame_count) * 1000000 / (Time.get_ticks_usec() - clock_start), "fps_min_1s": fps_windows.min() if not fps_windows.is_empty() else 0, "nodes_max": nodes_max}
	report.profile_windows = profile_windows
	check(report.deaths == report.explosions, "CHAOS une explosion par mort")
	if native_readability:
		check(standard.fps_min_1s > 60 and report.fps_min_1s > 60, "P5 et CHAOS >60 FPS min")
	records.append(report)
	sim.presentation.reset_battle()
	check(sim.presentation.settings == PresentationDemonstration.DEFAULT_SETTINGS, "RESET après CHAOS")
	sim.presentation.leave()
	await dispose(sim)


func _run() -> void:
	native_readability = OS.get_cmdline_user_args().has("--native")
	screenshots = native_readability
	if native_readability:
		DirAccess.make_dir_recursive_absolute("res://.godot/validation")
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1920, 1080)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	if OS.get_cmdline_user_args().has("--unit"):
		await explosion_fixture()
		await visual_scale_fixture()
		await firing_scale_fixture()
		await checkpoints_fixture()
		await meteor_geometry_fixture()
	elif OS.get_cmdline_user_args().has("--p1"):
		await measured_meteors()
	elif OS.get_cmdline_user_args().has("--p2"):
		await measured_checkpoints()
	elif OS.get_cmdline_user_args().has("--chaos"):
		await chaos_explosions()
	else:
		await explosion_fixture()
		await visual_scale_fixture()
		await firing_scale_fixture()
		await checkpoints_fixture()
		await meteor_geometry_fixture()
		await measured_meteors()
		await measured_checkpoints()
		await chaos_explosions()
	var file: FileAccess = FileAccess.open("res://.godot/readability_" + ("native" if native_readability else "headless") + ("_unit" if OS.get_cmdline_user_args().has("--unit") else "_p1" if OS.get_cmdline_user_args().has("--p1") else "_p2" if OS.get_cmdline_user_args().has("--p2") else "_chaos" if OS.get_cmdline_user_args().has("--chaos") else "_complete") + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS READABILITY" if failures == 0 else "FAIL READABILITY")
	quit(0 if failures == 0 else 1)
