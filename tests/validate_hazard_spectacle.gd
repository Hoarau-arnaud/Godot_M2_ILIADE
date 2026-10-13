extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var failures: int = 0
var records: Array[Dictionary] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
	await physics_frame


func dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await frames(4)
	for group: String in GuidedDemonstration.GAME_GROUPS:
		check(get_nodes_in_group(group).is_empty(), "Fuite de groupe " + group)
	check(Engine.time_scale == 1 and Engine.physics_ticks_per_second == 60, "Engine non restauré")


func empty() -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	sim.simulation_speed_multiplier = 1
	sim.streaming_enabled = false
	sim.drones_enabled = false
	sim.interceptors_enabled = false
	sim.capital_ships_enabled = false
	sim.combat_enabled = false
	root.add_child(sim)
	return sim


func _run() -> void:
	var native: bool = OS.get_cmdline_user_args().has("--native")
	if not native:
		await storm_and_controls()
		await free_parameters()
		await fast_meteor_collision()
		await grid_collision()
		await bomb_collision()
		await missiles()
	if not OS.get_cmdline_user_args().has("--unit-only"):
		if OS.get_cmdline_user_args().has("--finale"):
			await benchmark_finale()
		else:
			await complete(native)
	var file: FileAccess = FileAccess.open("res://.godot/m12_" + ("native" if native else "metrics") + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS M12 : tempête, télégraphie, collisions, missiles, flotte, six phases et FREE." if failures == 0 else "FAIL M12 : %d" % failures)
	quit(0 if failures == 0 else 1)


func storm_signature(sim: SpaceSimulation) -> String:
	var values: Array = []
	for node: Node in get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		values.append([rock.shape_seed, rock.diameter, rock.motion_type, rock.motion_velocity, rock.motion_center])
	return JSON.stringify(values)


func storm_and_controls() -> void:
	var sim: SpaceSimulation = empty()
	await frames(3)
	sim.demo_controls.density_slider.value = 2.1
	sim.demo_controls.intensity_slider.value = 2.3
	check(is_equal_approx(sim.rock_density, 2.1) and is_equal_approx(sim.asteroid_container.density_multiplier, 2.1) and is_equal_approx(sim.fire_intensity, 2.3), "Sliders non appliqués")
	check(sim.asteroid_container.spacing_for_level(3) / sim.rock_density < sim.asteroid_container.spacing_for_level(3), "Densité sans effet sur streaming")
	sim.demonstration.start()
	var signature: String = storm_signature(sim)
	check(sim.asteroid_container.active_asteroid_count == 180 and sim.asteroid_container.active_mobile_count == 180, "Tempête initiale incomplète")
	var minimum: float = INF
	var maximum: float = 0
	var sizes: Array[int] = [0, 0, 0, 0]
	var angles: Dictionary = {}
	for node: Node in get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		minimum = minf(minimum, rock.motion_velocity.length())
		maximum = maxf(maximum, rock.motion_velocity.length())
		sizes[0 if rock.diameter < 2 else 1 if rock.diameter < 5 else 2 if rock.diameter < 10 else 3] += 1
		angles[str(rock.motion_velocity.normalized())] = true
		check(rock.diameter >= 0.6 and rock.diameter <= 16 and rock.collision_layer == 2, "Taille/collision météore incorrecte")
		check(rock.avoidance_radius < rock.diameter and rock.avoidance_radius > rock.diameter * 0.2, "Points convexes partagés/déformés dans le cache")
		check((rock.trajectory_offset(2) - rock.trajectory_offset(0)).cross(rock.motion_velocity).length() < 0.02, "Météore non rectiligne")
		for ship: BlueShip in sim.ships:
			check(rock.global_position.distance_to(ship.global_position) > rock.avoidance_radius + 8, "Spawn sur un BlueShip")
	check(minimum >= 3.99 and maximum <= 45.01 and maximum > 28 and angles.size() > 160 and sizes[3] > 0, "Distribution tailles/vitesses/angles insuffisante")
	sim.demonstration.restart()
	check(storm_signature(sim) == signature, "Même seed : tempête différente")
	sim.demonstration.demonstration_seed += 1
	sim.demonstration.restart()
	check(storm_signature(sim) != signature, "Autre seed : même tempête")
	sim.demonstration.stop()
	check(is_equal_approx(sim.rock_density, 2.1) and is_equal_approx(sim.fire_intensity, 2.3) and sim.demo_controls.density_slider.editable, "FREE perd ses réglages")
	await frames(4)
	check(sim.demo_controls.panel.get_global_rect().end.y <= root.get_visible_rect().end.y - 10, "Panneau FREE dépasse 720p")
	records.append({"test": "storm_seed", "count": 180, "sizes": sizes, "speed_min": minimum, "speed_max": maximum, "unique_angles": angles.size(), "debris": 1360})
	print("M12 STORM " + JSON.stringify(records.back()))
	await dispose(sim)


func benchmark_finale() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	root.add_child(sim)
	await frames(5)
	sim.demonstration.start()
	await frames(5)
	sim.demonstration._begin_phase(5, sim._fleet_center())
	var start: int = Time.get_ticks_usec()
	var last: int = start
	var count: int = 0
	var bucket: int = 0
	var minimum: float = INF
	while sim.demonstration.is_guided():
		await process_frame
		count += 1
		bucket += 1
		var now: int = Time.get_ticks_usec()
		if now - last >= 1000000:
			var fps: float = bucket * 1000000.0 / (now - last)
			minimum = minf(minimum, fps)
			print("FINAL PERF " + JSON.stringify({"elapsed": sim.demonstration.phase_elapsed, "fps": fps, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
			last = now
			bucket = 0
	var seconds: float = float(Time.get_ticks_usec() - start) / 1000000
	var record: Dictionary = {"test": "finale_1080p", "fps_mean": count / seconds, "fps_min_1s": minimum, "phase": sim.demonstration.phase_results.back().duplicate(true)}
	records.append(record)
	print("FINALE RESULT " + JSON.stringify(record))
	check(minimum > 60, "Finale sous 60 FPS")
	await dispose(sim)


func grid_collision() -> void:
	var sim: SpaceSimulation = empty()
	sim.set_physics_process(false)
	for index: int in range(sim.ships.size()):
		sim.ships[index].set_physics_process(false)
		sim.ships[index].position = Vector3(200 + index * 10, 0, 0)
	var struck: BlueShip = sim.ships[0]
	var safe: BlueShip = sim.ships[1]
	struck.position = Vector3(22, 0, 0)
	safe.position = Vector3.ZERO
	var zone: ArtilleryZone = ArtilleryZone.new()
	zone.kind = ArtilleryZone.Kind.GRID
	zone.delay = 1.2
	zone.warning_time = 1
	zone.active_time = 0.65
	sim.projectile_container.add_child(zone)
	await frames(35)
	check(not zone.active and struck.health == 3 and zone._visuals[0].visible, "Warning grille inflige des dégâts / invisible")
	check(not zone.avoidance_force(struck.position, Vector3.ZERO).is_zero_approx() and zone.avoidance_force(safe.position, Vector3.ZERO).is_zero_approx(), "Perception / passage central grille")
	await frames(45)
	check(not is_instance_valid(struck) and safe.alive and safe.health == 3 and zone.damage_events == 1, "Collision grille non létale / passage fermé / dégâts répétés")
	await frames(40)
	check(not is_instance_valid(zone), "Grille non nettoyée")
	# Réaction autonome : même danger, le BlueShip conserve son processus SMA.
	var reacting: BlueShip = sim.ships[2]
	reacting.environment_perception_interval = 0.05
	reacting.position = Vector3(22, 0, 14)
	reacting.set_physics_process(true)
	zone = ArtilleryZone.new()
	zone.kind = ArtilleryZone.Kind.GRID
	zone.delay = 1.9
	zone.warning_time = 1.9
	sim.projectile_container.add_child(zone)
	await frames(90)
	check(reacting.projectile_dodge_count > 0 and absf(reacting.position.x - 22) > 2 and reacting.alive, "BlueShip ne réagit pas au warning grille")
	records.append({"test": "grid", "warning_no_damage": true, "direct_contact_hp": 3, "safe_gap": true, "reaction_x": reacting.position.x - 22})
	await dispose(sim)


func free_parameters() -> void:
	var sim: SpaceSimulation = empty()
	var counts: Array[int] = []
	for density: float in [0.5, 2.5]:
		var field: ObstacleField = ObstacleField.new()
		field.density_multiplier = density
		field.difficulty_override = 3
		sim.add_child(field)
		field.initialize_field(20261012, Vector3.ZERO, 0)
		field.advance(Vector3.ZERO, 0, 0)
		counts.append(field.generated_configuration_count)
		field.queue_free()
		await frames(2)
	check(counts[1] > counts[0], "Slider densité ne crée pas davantage de configurations")
	var capital: CapitalShip = SpaceSimulation.CAPITAL_SCENE.instantiate() as CapitalShip
	FlightTuning.legacy_actor(capital)
	sim.capital_container.add_child(capital)
	capital.set_physics_process(false)
	capital.fire_intensity = 0.5
	capital._transition(CapitalShip.State.COOLDOWN)
	var slow: float = capital.cooldown_duration
	capital.fire_intensity = 3
	capital._transition(CapitalShip.State.COOLDOWN)
	check(capital.cooldown_duration < slow / 2, "Intensité sans changement de cadence Capital")
	var specs: Array[Dictionary] = capital.build_salvo(CapitalShip.ArtilleryPattern.HEAVY_SHOT)
	capital.projectile_container = sim.projectile_container
	capital._launch(specs[0])
	check((get_nodes_in_group("artillery_projectiles")[0] as ArtilleryProjectile).damage == 2, "Intensité modifie les dégâts")
	records.append({"test": "free_parameters", "configurations_low_high": counts, "damage_unchanged": true})
	await dispose(sim)


func fast_meteor_collision() -> void:
	var sim: SpaceSimulation = empty()
	sim.set_physics_process(false)
	for ship: BlueShip in sim.ships:
		ship.position = Vector3(200, 200, 200)
		ship.set_physics_process(false)
	var ship: BlueShip = sim.ships[0]
	ship.position = Vector3.ZERO
	ship.wander_strength = 0
	ship.vertical_wander_strength = 0
	ship.longitudinal_wander_strength = 0
	ship.obstacle_detection_radius = 0
	ship.mobile_detection_radius = 0
	ship.velocity = Vector3.FORWARD * ship.forward_speed * ship._speed_factor
	ship.set_physics_process(true)
	var rock: SpaceAsteroid = ObstacleField.ASTEROID_SCENE.instantiate() as SpaceAsteroid
	FlightTuning.legacy_actor(rock)
	rock.motion_type = SpaceAsteroid.MotionType.LINEAR
	rock.motion_velocity = Vector3(45, 0, 0)
	rock.motion_duration = 20
	rock.diameter = 1.8
	rock.size_category = SpaceAsteroid.SizeCategory.SMALL
	rock.single_convex_envelope = true
	rock.position = Vector3(-22.5, 0, ship.velocity.z * 0.5) - rock.trajectory_offset(0)
	sim.asteroid_container.add_child(rock)
	await frames(60)
	check(sim.death_count == 1 and not is_instance_valid(ship) and is_instance_valid(rock), "Petit météore 45 m/s traverse la collision BlueShip")
	records.append({"test": "meteor_stress", "speed": 45, "diameter": 1.8, "real_collision": sim.death_count == 1})
	await dispose(sim)


func bomb_collision() -> void:
	var sim: SpaceSimulation = empty()
	sim.set_physics_process(false)
	for index: int in range(sim.ships.size()):
		sim.ships[index].set_physics_process(false)
		sim.ships[index].position = Vector3(200 + index * 12, 0, 0)
	var victims: Array[BlueShip] = [sim.ships[0], sim.ships[1], sim.ships[2], sim.ships[3]]
	for index: int in range(4):
		victims[index].position = Vector3([0, 8, 12, 18][index], 0, 0)
	var zone: ArtilleryZone = ArtilleryZone.new()
	zone.delay = 0.5
	zone.warning_time = 0.5
	sim.projectile_container.add_child(zone)
	await frames(15)
	check(not zone.active and victims[0].health == 3 and zone.visible, "Warning bombe incorrect")
	check(not zone.avoidance_force(victims[0].position, Vector3.ZERO).is_zero_approx(), "Warning bombe absent de perception")
	await frames(20)
	check(not is_instance_valid(victims[0]) and victims[1].health == 1 and victims[2].health == 2 and victims[3].health == 3 and zone.damage_events == 3, "Rayon / gradient dégâts bombe incorrect")
	check(zone._shards.visible and zone._sphere.scale.x > 0, "Explosion visuelle absente")
	await frames(85)
	check(not is_instance_valid(zone), "Bombe non nettoyée")
	records.append({"test": "bomb", "radius": 13, "damage_center_mid_edge_out": [3, 2, 1, 0], "cleanup": true})
	await dispose(sim)


func missiles() -> void:
	var sim: SpaceSimulation = empty()
	sim.set_physics_process(false)
	for ship: BlueShip in sim.ships:
		ship.set_physics_process(false)
	var capital: CapitalShip = SpaceSimulation.CAPITAL_SCENE.instantiate() as CapitalShip
	FlightTuning.legacy_actor(capital)
	capital.spectacle_enabled = true
	capital.projectile_container = sim.projectile_container
	capital.position = Vector3(0, 0, -480)
	sim.capital_container.add_child(capital)
	capital.set_physics_process(false)
	capital.observed_center = Vector3.ZERO
	capital.observed_velocity = Vector3(0, 0, -10)
	var specs: Array[Dictionary] = capital.build_salvo(CapitalShip.ArtilleryPattern.MISSILE_SWARM)
	check(specs.size() == 18, "Essaim sans 12–24 missiles")
	var bombs: Array[Dictionary] = capital.build_salvo(CapitalShip.ArtilleryPattern.BOMB_CLUSTER)
	check(absf(Vector3(bombs[1].aim).z + 140) < 8, "Bombe sans centre prédit")
	var frozen_aim: Vector3 = bombs[1].aim
	capital.observed_center += Vector3(100, 100, 0)
	check(Vector3(bombs[1].aim) == frozen_aim, "Cible bombe poursuit le groupe")
	for spec: Dictionary in specs:
		capital._launch(spec)
	var rocket: ArtilleryProjectile = get_nodes_in_group("artillery_projectiles")[0] as ArtilleryProjectile
	rocket.target = sim.ships[0]
	var old: Vector3 = rocket.flight_direction
	await frames(30)
	check(rad_to_deg(old.angle_to(rocket.flight_direction)) <= 3.5 and rocket.get_node("Visual").get_child_count() >= 7, "Guidage missile illimité / visuel absent")
	rocket.target.take_damage(3)
	await frames(30)
	check(is_instance_valid(rocket) and rocket.target == null, "Missile garde référence cible morte")
	records.append({"test": "missiles", "salvo": 18, "turn_degrees_per_sim_second": 6, "dead_target_safe": true, "frozen_bomb_target": true})
	await dispose(sim)


func complete(native: bool) -> void:
	var capture: bool = OS.get_cmdline_user_args().has("--capture")
	if native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	root.add_child(sim)
	await frames(5)
	var original: BlueShip = sim.ships[0]
	var baseline: int = get_node_count()
	sim.demonstration.start()
	var started: int = Time.get_ticks_usec()
	var last: int = started
	var count: int = 0
	var bucket: int = 0
	var minimum: float = INF
	var captured: Dictionary = {}
	var fps_windows: Array[Dictionary] = []
	var fleet_visible: Dictionary[int, bool] = {}
	var fleet_flashes: Dictionary[int, bool] = {}
	var fleet_previous: Dictionary[int, Vector3] = {}
	var fleet_step_max: float = 0
	var fleet_distance_min: float = INF
	var fleet_distance_max: float = 0
	while sim.demonstration.is_guided():
		await process_frame
		count += 1
		bucket += 1
		var now: int = Time.get_ticks_usec()
		if now - last >= 1000000:
			var fps: float = bucket * 1000000.0 / (now - last)
			minimum = minf(minimum, fps)
			fps_windows.append({"phase": sim.demonstration.phase_index + 1, "elapsed": sim.demonstration.phase_elapsed, "fps": fps})
			if native and fps < 65:
				print("M12 SLOW " + JSON.stringify(fps_windows.back()))
			last = now
			bucket = 0
		if sim.demonstration.phase_index == 4:
			for capital: CapitalShip in sim.capitals:
				var id: int = capital.get_instance_id()
				if capital._flash_time > 0:
					fleet_flashes[id] = true
				var distance: float = capital.global_position.distance_to(sim._fleet_center())
				fleet_distance_min = minf(fleet_distance_min, distance)
				fleet_distance_max = maxf(fleet_distance_max, distance)
				if fleet_previous.has(id):
					fleet_step_max = maxf(fleet_step_max, capital.global_position.distance_to(fleet_previous[id]))
				fleet_previous[id] = capital.global_position
				if not sim.camera.is_position_behind(capital.global_position) and Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(sim.camera.unproject_position(capital.global_position)):
					fleet_visible[id] = true
		var phase: int = sim.demonstration.phase_index
		if native and capture and phase >= 0 and sim.demonstration.phase_elapsed >= (11 if phase < 4 else 17) and not captured.has(phase):
			captured[phase] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m12_phase_%d.png" % (phase + 1))
	var duration: float = float(Time.get_ticks_usec() - started) / 1000000
	var phases: Array[Dictionary] = sim.demonstration.phase_results
	check(phases.size() == 6 and sim.demonstration.last_duration >= 129.8 and sim.demonstration.last_duration < 132, "Démo sans six phases / durée 130 s")
	for phase: Dictionary in phases:
		check(phase.blue_alive + phase.blue_deaths == 15 and phase.blue_alive >= 5, "Extinction / reset compté comme décès")
		check(phase.projectiles_max <= 90 and phase.asteroids_max <= 180 and phase.nodes_max < 5000, "Budget M12 dépassé")
	check(phases[0].asteroids_max == 180 and phases[0].mobile_max == 180 and phases[0].green == 0 and phases[0].red == 0 and phases[0].capital == 0 and phases[0].lateral_excursion > 20, "Phase 1 sans tempête / translations")
	check(phases[1].asteroids_max == 84, "Phase 2 sans 60–100 physiques")
	for motion: int in [2, 3, 4, 5]:
		check(phases[1].motion_types.get(motion, 0) >= 8, "Famille complexe absente")
	check(phases[2].green >= 4 and phases[2].routes >= 4 and phases[2].green_shots >= 10, "Phase 3 sans patrouilles/tirs")
	check(phases[3].red >= 4 and phases[3].enemy_shots >= 100, "Phase 4 rafales insuffisantes")
	check(phases[4].capital == 5 and fleet_distance_min >= 350 and fleet_distance_max <= 650 and fleet_visible.size() == 5 and fleet_flashes.size() == 5 and fleet_step_max < 3, "Flotte distance/visibilité/flashes/continuité")
	check(phases[4].bombs > 0 and phases[4].grids > 0 and phases[4].curtains > 0 and phases[4].missiles >= 12 and phases[4].salvos[5] > 0, "Phase 5 arsenal non exercé")
	check(phases[4].artillery_arrivals > 20 and phases[5].artillery_arrivals > 10, "Tirs lointains n'arrivent pas près des BlueShip")
	check(phases[5].asteroids_max == 150 and phases[5].projectiles_max <= 60, "Budget calibré finale dépassé")
	check(phases[5].capital == 4 and phases[5].bombs > 0 and phases[5].grids > 0 and phases[5].missiles >= 12 and phases[5].dodges > 10 and phases[5].regroup_episodes >= 2, "Finale sans dangers et récupération SMA")
	check(sim.ships.has(original) and not sim.demonstration.is_guided() and not sim.asteroid_container.storm_enabled, "FREE non restauré")
	await frames(4)
	check(get_node_count() <= baseline + 35, "Nœuds conservés après GUIDED")
	var record: Dictionary = {"test": "native_1080p" if native else "headless_complete", "wall_seconds": duration, "sequence_seconds": sim.demonstration.last_duration, "fps_mean": count / duration, "fps_min_1s": minimum, "fleet_visible": fleet_visible.size(), "fleet_distance_min": fleet_distance_min, "fleet_distance_max": fleet_distance_max, "fleet_step_max": fleet_step_max, "nodes_before": baseline, "nodes_after": get_node_count(), "free_restored": sim.ships.has(original), "phases": phases.duplicate(true)}
	record.fps_windows = fps_windows
	record.fleet_flashes = fleet_flashes.size()
	record.capture_included = capture
	record.render_pixels = root.get_texture().get_size() if native else Vector2.ZERO
	record.window_pixels = DisplayServer.window_get_size() if native else Vector2i.ZERO
	if native:
		check(root.get_texture().get_size() == Vector2(1920, 1080), "Rendu non 1080p")
		if not capture:
			check(minimum > 60, "Performance 1080p inférieure à 60 FPS")
		else:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m12_free_panel.png")
	records.append(record)
	for phase: Dictionary in phases:
		print("M12 PHASE " + JSON.stringify(phase))
	print("M12 COMPLETE " + JSON.stringify(record))
	await dispose(sim)
