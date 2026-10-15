extends "res://tests/validate_targeted_evasion.gd"

func modern(count: int = 15) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.m14_fixture(sim)
	sim.auto_start_presentation_demo = false
	sim.ship_count = count
	sim.simulation_speed_multiplier = 1
	sim.streaming_enabled = false
	sim.drones_enabled = false
	sim.interceptors_enabled = false
	sim.capital_ships_enabled = false
	sim.combat_enabled = false
	root.add_child(sim)
	return sim


func quiet_guided() -> SpaceSimulation:
	var sim: SpaceSimulation = modern()
	sim.demonstration.start()
	sim.demonstration._begin_phase(4, Vector3.ZERO)
	sim.demonstration.spectacle_capital_duration = 1000
	sim.demonstration._next_attack = 1000
	for capital: CapitalShip in sim.capitals:
		capital.combat_enabled = false
	return sim


func kill_by_laser(sim: SpaceSimulation, blues: Array[BlueShip]) -> void:
	for blue: BlueShip in blues:
		blue.health = 1
		blue.set_physics_process(false)
		var shot: EnemyLaser = preload("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
		shot.position = blue.position + Vector3(0, 0, -3)
		shot.flight_direction = Vector3.BACK
		sim.projectile_container.add_child(shot)


func lifecycle_m14() -> void:
	var sim: SpaceSimulation = quiet_guided()
	var survivor: BlueShip = sim.ships[3]
	kill_by_laser(sim, [sim.ships[0], sim.ships[1], sim.ships[2]])
	await frames(8)
	check(sim.death_count == 3 and sim.ships.size() == 12 and get_nodes_in_group("explosions").size() >= 3, "Trois vraies destructions / explosions absentes")
	await frames(35)
	check(sim.reinforcement_count == 0, "Renfort avant 0,8 seconde réelle")
	await frames(140)
	check(sim.ships.has(survivor), "Renfort recrée les survivants")
	check(sim.ships.size() == 15 and sim.reinforcement_count == 3 and sim.death_count == 3, "Renforts / pertes cumulées incohérents")
	check(sim.statistics.text == "Vaisseaux bleus détruits : 3", "HUD cumulatif ambigu")
	for spawn: Dictionary in sim.reinforcement_spawns:
		var offset: Vector3 = Vector3(spawn.position) - Vector3(spawn.center)
		check(offset.z >= 30 and offset.z <= 50 and spawn.safe, "Spawn renfort dangereux / distance invalide")
	var reinforcement: BlueShip = sim.ships.back()
	check(reinforcement.alive and reinforcement._time > 0 and reinforcement.velocity.z < 0, "Renfort sans vol SMA")
	var before_distance: float = reinforcement.global_position.distance_to(sim._fleet_center())
	await frames(200)
	var after_distance: float = reinforcement.global_position.distance_to(sim._fleet_center())
	check(after_distance < before_distance or reinforcement.neighbor_count > 0, "Renfort ne rejoint pas les voisins")
	records.append({"test": "three_real_deaths", "deaths": sim.death_count, "active": sim.ships.size(), "reinforcements": sim.reinforcement_count, "spawn_records": sim.reinforcement_spawns.duplicate(true), "joining_before": before_distance, "joining_after": after_distance, "neighbors": reinforcement.neighbor_count})
	var death_before: int = sim.death_count
	for index: int in range(3):
		var blue: BlueShip = sim.ships.back()
		sim.ships.erase(blue)
		blue.retire()
		sim.ship_retired_count += 1
	for index: int in range(3):
		sim._add_ship(Vector3(45 + index * 12, 25, sim._fleet_center().z + 40))
	check(sim.death_count == death_before and sim.ships.size() == 15, "Retrait administratif compté comme mort")
	records.append({"test": "administrative_retirement", "deaths_before": death_before, "deaths_after": sim.death_count, "active": sim.ships.size()})
	var capital: CapitalShip = sim.capitals[0]
	capital.vulnerable = true
	capital.take_damage(1000)
	check(sim.death_count == death_before and sim.capitals_destroyed == 1, "Mort ennemie comptée comme perte BlueShip")
	var identity: BlueShip = sim.ships[0]
	sim.demonstration._begin_phase(3, sim._fleet_center())
	check(sim.ships.has(identity) and sim.death_count == death_before, "Transition recrée les survivants / efface les pertes")
	sim.demonstration.restart()
	check(sim.death_count == 0 and sim.reinforcement_count == 0 and sim.ships.size() == 15 and sim.demonstration.phase_index == 0, "Replay M14 incohérent")
	await dispose(sim)
	sim = quiet_guided()
	kill_by_laser(sim, sim.ships.duplicate())
	await frames(10)
	check(sim.ships.is_empty() and sim.death_count == 15 and not sim.demonstration.game_over, "Extinction guidée arrête la vidéo")
	var phase_time: float = sim.demonstration.phase_elapsed
	await frames(70)
	var intermediate: int = sim.ships.size()
	await frames(140)
	check(sim.ships.size() == 15 and sim.reinforcement_count == 15 and sim.death_count == 15 and sim.demonstration.phase_elapsed > phase_time, "Extinction non récupérée")
	check(intermediate > 0 and intermediate < 15, "Renforts simultanés non échelonnés")
	records.append({"test": "total_extinction", "intermediate_active": intermediate, "active": sim.ships.size(), "deaths": sim.death_count, "reinforcements": sim.reinforcement_count, "game_over": sim.demonstration.game_over, "continues": true})
	await dispose(sim)
	# Le profil M13 active explicitement le Game Over et désactive les renforts.
	await lifecycle()


func mega_fixture() -> void:
	var sim: SpaceSimulation = quiet_guided()
	for capital: CapitalShip in sim.capitals:
		capital.set_physics_process(false)
	var center: Vector3 = sim._fleet_center()
	var rock: SpaceAsteroid = ObstacleField.ASTEROID_SCENE.instantiate() as SpaceAsteroid
	rock.diameter = 40
	rock.size_category = SpaceAsteroid.SizeCategory.MEGA
	rock.shape_seed = 14440
	rock.threat_strength = 1.6
	rock.position = center + Vector3(12, 4, -130)
	rock.motion_type = SpaceAsteroid.MotionType.LINEAR
	rock.motion_velocity = Vector3(0, 0, 6)
	rock.motion_duration = 80
	rock.position -= rock.trajectory_offset(0)
	sim.asteroid_container.add_child(rock)
	var positions: Dictionary = {}
	var detected: Dictionary = {}
	var excursions: Dictionary = {}
	var maximum_dispersion: float = 0
	var maximum_center_xy: float = 0
	for blue: BlueShip in sim.ships:
		positions[blue.individual_seed] = blue.global_position
	for index: int in range(720):
		await process_frame
		for blue: BlueShip in sim.ships:
			if blue._threats.has(rock) and not detected.has(blue.individual_seed):
				detected[blue.individual_seed] = blue.global_position.distance_to(rock.global_position)
			var offset: Vector3 = blue.global_position - Vector3(positions[blue.individual_seed])
			excursions[blue.individual_seed] = maxf(float(excursions.get(blue.individual_seed, 0)), Vector2(offset.x, offset.y).length())
		maximum_dispersion = maxf(maximum_dispersion, sim.dispersion)
		var group_offset: Vector3 = sim._fleet_center() - center
		maximum_center_xy = maxf(maximum_center_xy, Vector2(group_offset.x, group_offset.y).length())
	var visible: int = 0
	for seed_value: int in excursions:
		if float(excursions[seed_value]) >= 10 and detected.has(seed_value):
			visible += 1
	check(detected.size() >= 8 and visible >= 8, "Mega sans anticipation / majorité de manœuvres")
	check(sim.death_count < 8, "Mega ne laisse pas de contournement à la majorité")
	check(sim.dispersion < maximum_dispersion, "Absence de récupération après le Mega")
	records.append({"test": "mega_40m", "diameter": rock.diameter, "radius": rock.avoidance_radius, "detection_effective": sim.ships[0].effective_obstacle_detection(rock), "detections": detected, "visible_maneuvers": visible, "individual_xy": excursions, "group_xy_max": maximum_center_xy, "boosts": sim.evasive_boost_count, "deaths": sim.death_count, "dispersion_max": maximum_dispersion, "dispersion_final": sim.dispersion})
	await dispose(sim)


func controlled_salvos() -> void:
	var sim: SpaceSimulation = modern()
	var capital: CapitalShip = SpaceSimulation.CAPITAL_SCENE.instantiate() as CapitalShip
	capital.readable_arsenal = true
	capital.choreographed = true
	capital.projectile_container = sim.projectile_container
	capital.position = Vector3(0, 0, -300)
	capital.fired.connect(sim._on_artillery_fired)
	sim.capital_container.add_child(capital)
	capital.set_physics_process(false)
	# Activer uniquement l'instrumentation M14, sans séquence guidée.
	sim.demonstration.mode = GuidedDemonstration.DemoMode.GUIDED
	sim.demonstration.set_process(false)
	var counts: Array[int] = [0, 0, 0, 0]
	var targets: Dictionary = {}
	var threatening: int = 0
	for index: int in range(10):
		capital.observe_group()
		for spec: Dictionary in capital.build_salvo(CapitalShip.ArtilleryPattern.RAPID_BARRAGE):
			capital._launch(spec)
			var projectile: ArtilleryProjectile = get_nodes_in_group("artillery_projectiles").back() as ArtilleryProjectile
			counts[projectile.threat_category] += 1
			if projectile.targeted:
				targets[projectile.target_seed] = true
				if initial_threat(projectile, projectile.initial_target_position, projectile.initial_target_velocity):
					threatening += 1
	check(counts == [80, 15, 5, 0] and threatening == 80 and targets.size() == 15, "100 tirs : catégories / interception / distribution invalides")
	var maximum: int = 0
	for value: int in sim.shots_targeted_per_ship.values():
		maximum = maxi(maximum, value)
	check(maximum <= 8, "Cible trop concentrée")
	records.append({"test": "controlled_100", "categories": counts, "initially_threatening": threatening, "distinct_targets": targets.size(), "shots_targeted_per_ship": sim.shots_targeted_per_ship.duplicate(), "maximum_per_ship": maximum})
	sim.demonstration.mode = GuidedDemonstration.DemoMode.FREE
	await dispose(sim)


func spawn_safety_fixture() -> void:
	var sim: SpaceSimulation = modern(1)
	var point: Vector3 = Vector3(100, 0, 40)
	var rock: SpaceAsteroid = ObstacleField.ASTEROID_SCENE.instantiate() as SpaceAsteroid
	rock.diameter = 40
	rock.size_category = SpaceAsteroid.SizeCategory.MEGA
	rock.position = point
	sim.asteroid_container.add_child(rock)
	check(not sim._runtime_ship_position_is_clear(point), "Spawn accepté dans un rocher")
	rock.remove_from_group("asteroids")
	rock.collision_layer = 0
	rock.queue_free()
	var missile: ArtilleryProjectile = ArtilleryProjectile.new()
	missile.position = point
	sim.projectile_container.add_child(missile)
	check(not sim._runtime_ship_position_is_clear(point), "Spawn accepté dans un missile")
	missile.remove_from_group("hostile_projectiles")
	missile.queue_free()
	var zone: ArtilleryZone = ArtilleryZone.new()
	zone.kind = ArtilleryZone.Kind.BOMB
	zone.position = point
	sim.projectile_container.add_child(zone)
	check(not sim._runtime_ship_position_is_clear(point), "Spawn accepté dans une zone")
	zone.remove_from_group("combat_hazards")
	zone.queue_free()
	var capital: CapitalShip = SpaceSimulation.CAPITAL_SCENE.instantiate() as CapitalShip
	capital.position = point
	sim.capital_container.add_child(capital)
	check(not sim._runtime_ship_position_is_clear(point + Vector3(20, 0, 0)), "Spawn accepté dans la grande coque hostile")
	capital.remove_from_group("hostile_agents")
	capital.queue_free()
	check(not sim._runtime_ship_position_is_clear(sim.ships[0].global_position), "Spawn accepté sur un BlueShip")
	check(sim._runtime_ship_position_is_clear(point), "Volume libre refusé")
	records.append({"test": "spawn_rejection", "rock": true, "missile": true, "zone": true, "capital_hull": true, "blue": true, "clear_volume": true})
	await dispose(sim)


func demonstration_m14(native: bool) -> void:
	var capture: bool = OS.get_cmdline_user_args().has("--capture")
	var finale_only: bool = OS.get_cmdline_user_args().has("--finale")
	if native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.m14_fixture(sim)
	sim.auto_start_presentation_demo = false
	sim.threat_choreography_enabled = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pace="):
			sim.guided_simulation_speed = argument.trim_prefix("--pace=").to_float()
	root.add_child(sim)
	sim.demonstration.start()
	await frames(3)
	if finale_only:
		sim.demonstration._begin_phase(5, Vector3.ZERO)
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
		if native and capture and sim.demonstration.phase_elapsed >= (4.8 if phase == 0 else 12) and not captured.has(phase):
			captured[phase] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m14_phase_%d.png" % (phase + 1))
		if native and capture and phase == 4:
			for moment: int in [4, 8, 14, 18, 23]:
				var capture_key: int = 100 + moment
				if sim.demonstration.phase_elapsed >= moment and not captured.has(capture_key):
					captured[capture_key] = true
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.godot/validation/m14_capital_%d.png" % moment)
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
			check(phase.projectiles_max <= 40 and phase.asteroids_max <= 64 and phase.nodes_max < 5000, "Budget physique M14 dépassé")
		if phases.size() >= 5:
			check(phases[2].green_shots > 0 and phases[3].enemy_shots >= 20 and phases[3].boosts > 0, "Phases 3/4 sans attaque ciblée / boost")
			check(phases[4].targeted >= (phases[4].targeted + phases[4].suppression) * 0.65 and phases[4].boosts > 0, "Phase 5 ratio ciblé / boost insuffisant")
			for family: String in ["Heavy", "Seeker", "Bomb", "Laser", "Swarm"]:
				check(phases[4].weapon_families.has(family) and int(phases[4].weapon_families[family].shots) > 0 and int(phases[4].weapon_families[family].reactions) > 0, "Phase 5 sans action/réaction : " + family)
	var final: Dictionary = phases.back()
	check(final.blue_alive >= 13 and not sim.demonstration.game_over, "Population finale non maintenue")
	check(final.phase == 6 and final.real_seconds >= 5, "Extinction trop rapide en finale")
	check(final.targeted > 0 and final.boosts > 0 and final.critical_threats > 0 and final.lateral_excursion > 20, "Finale sans menaces / esquives visibles")
	check(final.projectiles_max <= 40 and final.asteroids_max <= 64, "Plafond finale dépassé")
	var record: Dictionary = {"test": "native_1080p" if native else "headless_complete", "pace": sim.guided_simulation_speed, "physics_hz": Engine.physics_ticks_per_second, "wall_seconds": duration, "fps_mean": count / duration, "fps_min_1s": minimum, "fps_windows": windows, "finale_60_seconds": final_finished, "game_over": sim.demonstration.game_over, "phases": phases, "metrics": sim.threat_metrics(), "capture_included": capture, "render_pixels": root.get_texture().get_size() if native else Vector2.ZERO}
	if native and not capture:
		check(minimum > 60, "FPS 1080p sous 60")
	records.append(record)
	print("M14 RUN " + JSON.stringify(record))
	sim.demonstration.stop()
	await dispose(sim)


func _run() -> void:
	var native: bool = OS.get_cmdline_user_args().has("--native")
	if not native:
		await lifecycle_m14()
		await mega_fixture()
		await controlled_salvos()
		await spawn_safety_fixture()
	if not OS.get_cmdline_user_args().has("--unit-only"):
		await demonstration_m14(native)
	var file: FileAccess = FileAccess.open("res://.godot/m14_" + ("native" if native else "unit") + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS M14 : chorégraphie, Mega, renforts et pertes cumulées." if failures == 0 else "FAIL M14 : %d" % failures)
	quit(0 if failures == 0 else 1)
