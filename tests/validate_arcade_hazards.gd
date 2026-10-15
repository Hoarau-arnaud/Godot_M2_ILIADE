extends "res://tests/validate_threat_choreography.gd"

func modern(count: int = 15) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
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


func controlled_gate(rotation_value: float, grid_variant: int) -> void:
	var sim: SpaceSimulation = modern()
	var original: Dictionary = {}
	for index: int in range(sim.ships.size()):
		var blue: BlueShip = sim.ships[index]
		blue.position = Vector3((index % 5 - 2) * 12, (index / 5 - 1) * 12, 0)
		blue.adaptive_threat_response = true
		blue.wander_strength = 0
		blue.vertical_wander_strength = 0
		blue.longitudinal_wander_strength = 0
		blue._speed_factor = 1
		original[blue.individual_seed] = blue.position
	var gate: MovingLaserGate = MovingLaserGate.new()
	gate.variant = grid_variant as MovingLaserGate.Variant
	gate.angular_speed_degrees = rotation_value
	gate.initial_tilt_degrees = 20
	gate.position = Vector3(0, 0, -220)
	gate.active_time = 10
	sim.projectile_container.add_child(gate)
	var initial: Transform3D = gate.global_transform
	var opening_before: Vector3 = gate.safe_openings(0)[0]
	var distinct: Dictionary = {}
	var excursions: Dictionary = {}
	var maximum_changes: int = 0
	var dispersion_max: float = 0
	for index: int in range(330):
		await process_frame
		for blue: BlueShip in sim.ships:
			if blue._gate_memory.has(gate):
				distinct[int(blue._gate_memory[gate].index)] = true
			var offset: Vector3 = blue.position - Vector3(original[blue.individual_seed])
			excursions[blue.individual_seed] = maxf(float(excursions.get(blue.individual_seed, 0)), Vector2(offset.x, offset.y).length())
			maximum_changes = maxi(maximum_changes, blue.gate_opening_changes)
		dispersion_max = maxf(dispersion_max, sim.dispersion)
	var maneuvered: int = 0
	for value: float in excursions.values():
		if value > 5:
			maneuvered += 1
	var opening_after: Vector3 = gate.safe_openings(0)[0]
	check(gate.global_position.distance_to(initial.origin) > 150 and absf(rotation_value * gate.age) > 45, "Grille immobile / rotation absente")
	check(gate.safe_points.size() >= 7 and distinct.size() >= 2 and maneuvered >= 8, "Ouvertures / division locale absentes")
	check(gate.passage_count + gate.bypass_count >= 8 and gate.passage_count >= 4 and sim.ships.size() >= 8 and maximum_changes < 12, "Traversée trop létale / jitter excessif")
	check(opening_after.distance_to(opening_before + gate.velocity * gate.age) > 10, "Ouvertures ne tournent pas")
	var sample: Dictionary = {"test": "rotating_grid" if grid_variant == 1 else "moving_gate", "rotation_speed": rotation_value, "translation": gate.global_position.distance_to(initial.origin), "angle_degrees": rotation_value * gate.age, "safe_openings": gate.safe_points.size(), "selected_openings": distinct.size(), "maneuvered": maneuvered, "passages": gate.passage_count, "bypasses": gate.bypass_count, "survivors": sim.ships.size(), "deaths": sim.death_count, "choices": gate.opening_choices, "changes": gate.opening_changes, "max_changes_per_ship": maximum_changes, "xy": excursions, "dispersion_max": dispersion_max}
	await frames(540)
	sample.dispersion_after_recovery = sim.dispersion
	check(sim.dispersion < dispersion_max * 0.99, "Pas de récupération collective après la grille")
	records.append(sample)
	await dispose(sim)


func gate_contact() -> void:
	for inside_beam: bool in [true, false]:
		var sim: SpaceSimulation = modern(1)
		var blue: BlueShip = sim.ships[0]
		blue.position = Vector3(18 if inside_beam else 0, 0, 0)
		blue.set_physics_process(false)
		var gate: MovingLaserGate = MovingLaserGate.new()
		gate.position = Vector3(0, 0, -60)
		gate.initial_tilt_degrees = 0
		gate.angular_speed_degrees = 0
		sim.projectile_container.add_child(gate)
		await frames(150)
		check(sim.death_count == (1 if inside_beam else 0), "Collision barre/ouverture incohérente")
		records.append({"test": "beam_contact" if inside_beam else "safe_opening", "deaths": sim.death_count, "damage_events": gate.damage_events})
		await dispose(sim)


func colossal_fixture() -> void:
	var sim: SpaceSimulation = modern()
	for blue: BlueShip in sim.ships:
		blue.adaptive_threat_response = true
		sim.configure_guided_blue(blue)
	var rock: SpaceAsteroid = ObstacleField.ASTEROID_SCENE.instantiate() as SpaceAsteroid
	rock.diameter = 96
	rock.size_category = SpaceAsteroid.SizeCategory.COLOSSAL
	rock.shape_seed = 15960
	rock.single_convex_envelope = true
	rock.position = Vector3(18, 34, -240)
	rock.motion_type = SpaceAsteroid.MotionType.LINEAR
	rock.motion_velocity = Vector3(0, 0, 4)
	rock.motion_duration = 80
	rock.position -= rock.trajectory_offset(0)
	sim.asteroid_container.add_child(rock)
	var detected: Dictionary = {}
	var initial: Vector3 = sim._fleet_center()
	var group_xy: float = 0
	var maximum: float = 0
	for index: int in range(1200):
		await process_frame
		for blue: BlueShip in sim.ships:
			if blue._threats.has(rock) and not detected.has(blue.individual_seed):
				detected[blue.individual_seed] = blue.position.distance_to(rock.position)
		var offset: Vector3 = sim._fleet_center() - initial
		group_xy = maxf(group_xy, Vector2(offset.x, offset.y).length())
		maximum = maxf(maximum, sim.dispersion)
	check(detected.size() >= 8 and group_xy > 10 and sim.death_count < 8, "Colossal sans contournement possible")
	var collision_shapes: int = rock.find_children("*", "CollisionShape3D", true, false).size()
	check(collision_shapes == 1, "Colossal sans enveloppe de collision unique")
	records.append({"test": "colossal_96m", "radius": rock.avoidance_radius, "effective_detection": sim.ships[0].effective_obstacle_detection(rock), "detections": detected, "group_xy_max": group_xy, "deaths": sim.death_count, "dispersion_max": maximum, "dispersion_final": sim.dispersion, "lobes": rock.visuals.get_child_count(), "collision_shapes": collision_shapes})
	await dispose(sim)


func visuals_fixture() -> void:
	var sim: SpaceSimulation = modern(1)
	var blue: BlueShip = sim.ships[0]
	check(not blue._aura.visible, "Aura visible en vol normal")
	var colliders: int = blue.find_children("*", "CollisionShape3D", true, false).size()
	blue.evasive_boost_remaining = 0.8
	blue.boost_direction = Vector3.RIGHT
	await frames(20)
	var length_value: float = blue._right_exhaust.scale.y
	var emission_value: float = blue._boost_material.emission_energy_multiplier
	check(blue._aura.visible and blue._aura_material.albedo_color.a > 0.05 and length_value > 2 and emission_value > 4, "Boost doré / moteurs absent")
	await frames(130)
	check(not blue._aura.visible and blue.find_children("*", "CollisionShape3D", true, false).size() == colliders, "Aura persistante / collider ajouté")
	blue.reinforcement_glow_remaining = 1
	await frames(10)
	check(blue._aura.visible, "Aura renfort absente")
	await frames(150)
	check(not blue._aura.visible, "Aura renfort permanente")
	var weapons: Array[Dictionary] = []
	for kind: int in [0, 4, 2, 6, 5]:
		var shot: ArtilleryProjectile = ArtilleryProjectile.new()
		shot.arcade_signature = true
		shot.kind = kind as ArtilleryProjectile.Kind
		shot.position = Vector3(100 + kind * 30, 0, 0)
		shot.avoidance_radius = 16 if kind == 0 else 7 if kind == 4 else 8 if kind == 2 else 4
		sim.projectile_container.add_child(shot)
		shot.set_physics_process(false)
		var geometry: MeshInstance3D = shot.get_node("Visual/PackedWeaponSignature") as MeshInstance3D
		var dimensions: Vector3 = geometry.mesh.get_aabb().size
		check(dimensions.x > 0.8 and dimensions.y > 0.8 and dimensions.z > 2, "Missile encore plat")
		if kind in [0, 4, 2]:
			check(shot._shape is CapsuleShape3D, "Missile sans collider volumétrique")
		weapons.append({"kind": kind, "render_bounds_including_trail": dimensions, "collider": shot._shape.get_class(), "radius": shot._shape.get("radius"), "height": shot._shape.get("height"), "avoidance": shot.avoidance_radius})
	records.append({"test": "aura_and_weapons", "boost_exhaust_length": length_value, "boost_emission": emission_value, "visual_colliders_added": 0, "weapons": weapons, "decorative_nodes": sim.space_decor._arcade_layer.get_child_count()})
	await dispose(sim)


func missile_response() -> void:
	for kind: int in [0, 4]:
		var sim: SpaceSimulation = modern(1)
		var blue: BlueShip = sim.ships[0]
		straight(blue, true)
		blue.adaptive_threat_response = true
		var shot: ArtilleryProjectile = ArtilleryProjectile.new()
		shot.arcade_signature = true
		shot.kind = kind as ArtilleryProjectile.Kind
		shot.position = Vector3(0, 0, -100)
		shot.projectile_speed = 72 if kind == 0 else 65
		shot.flight_direction = Vector3.BACK
		shot.avoidance_radius = 16 if kind == 0 else 7
		shot.threat_strength = 1.6
		shot.damage = 3
		shot.target = blue if kind == 4 else null
		shot.turn_rate_degrees = 12
		sim.projectile_container.add_child(shot)
		var active_ticks: int = 0
		var distance_xy: float = 0
		for index: int in range(130):
			await process_frame
			if not is_instance_valid(blue):
				break
			if blue.evasive_boost_remaining > 0:
				active_ticks += 1
			distance_xy = maxf(distance_xy, Vector2(blue.position.x, blue.position.y).length())
		check(sim.death_count == 0 and sim.evasive_boost_count > 0 and active_ticks > 30 and distance_xy > 10, "Missile sans réaction prolongée / survie")
		records.append({"test": "heavy_evasion" if kind == 0 else "seeker_evasion", "active_boost_ticks": active_ticks, "xy": distance_xy, "deaths": sim.death_count, "boosts": sim.evasive_boost_count})
		await dispose(sim)


func arc_response() -> void:
	var sim: SpaceSimulation = modern(1)
	var blue: BlueShip = sim.ships[0]
	straight(blue, true)
	blue.adaptive_threat_response = true
	var shot: ArtilleryProjectile = ArtilleryProjectile.new()
	shot.arcade_signature = true
	shot.kind = ArtilleryProjectile.Kind.ARC_SALVO
	shot.position = Vector3(0, 0, -100)
	shot.projectile_speed = 62
	shot.flight_direction = Vector3.BACK
	shot.arc_duration = 100.0 / 78.0
	shot.avoidance_radius = 8
	shot.damage = 1
	sim.projectile_container.add_child(shot)
	var avoidance_ticks: int = 0
	var excursion: float = 0
	for frame: int in range(150):
		await process_frame
		if blue.projectile_avoidance_active:
			avoidance_ticks += 1
		excursion = maxf(excursion, Vector2(blue.position.x, blue.position.y).length())
	check(sim.death_count == 0 and avoidance_ticks > 10 and excursion > 5, "Arc ciblée sans réaction locale")
	records.append({"test": "arc_evasion", "avoidance_ticks": avoidance_ticks, "xy": excursion, "deaths": sim.death_count, "boosts": sim.evasive_boost_count})
	await dispose(sim)


func reinforcement_safety() -> void:
	var sim: SpaceSimulation = modern(0)
	var gate: MovingLaserGate = MovingLaserGate.new()
	gate.position = Vector3(100, 0, 40)
	gate.initial_tilt_degrees = 0
	gate.angular_speed_degrees = 0
	sim.projectile_container.add_child(gate)
	check(not sim._runtime_ship_position_is_clear(gate.global_position + Vector3(55, 0, 0)), "Renfort autorisé dans une barre extérieure")
	check(sim._runtime_ship_position_is_clear(gate.global_position), "Ouverture sûre refusée au renfort")
	check(not sim._runtime_ship_position_is_clear(gate.global_position + Vector3(55, 0, 30)), "Renfort autorisé devant une barre imminente")
	records.append({"test": "reinforcement_gate_safety", "outer_beam_rejected": true, "opening_clear": true, "incoming_beam_rejected": true})
	await dispose(sim)
	sim = modern()
	sim.demonstration.start()
	sim.demonstration._begin_phase(5, Vector3.ZERO)
	sim.demonstration._next_attack = 1000
	sim.demonstration._next_mega = 1000
	sim.demonstration._next_colossal = 1000
	sim.streaming_enabled = false
	for node: Node in get_nodes_in_group("asteroids"):
		node.free()
	for blue: BlueShip in sim.ships:
		blue.combat_enabled = false
	var lost: PatrolDrone = sim.drones[0]
	var seed_before: int = lost.individual_seed
	lost.take_damage(20)
	var lost_interceptor: Interceptor = sim.interceptors[0]
	var interceptor_seed: int = lost_interceptor.individual_seed
	lost_interceptor.take_damage(20)
	await frames(20)
	check(sim.drones.size() == 4 and sim.drone_death_count > 0, "Patrol non remplacé en finale M15")
	var seed_after: int = sim.drones.back().individual_seed
	check(seed_after != seed_before and sim.drones.back().patrol_fire_enabled, "Patrol remplacé sans nouvelle identité / tirs")
	check(sim.interceptors.size() == 4 and sim.interceptors.back().individual_seed != interceptor_seed, "Interceptor non remplacé en finale M15")
	records.append({"test": "finale_patrol_replacement", "active": sim.drones.size(), "old_seed": seed_before, "new_seed": seed_after})
	records.append({"test": "finale_interceptor_replacement", "active": sim.interceptors.size(), "old_seed": interceptor_seed, "new_seed": sim.interceptors.back().individual_seed})
	await dispose(sim)


func demonstration_m15(native: bool) -> void:
	var capture: bool = OS.get_cmdline_user_args().has("--capture")
	var finale_only: bool = OS.get_cmdline_user_args().has("--finale")
	if native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
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
		if native and capture and phase == 0 and sim.demonstration.phase_elapsed >= 14.5 and not captured.has(99):
			captured[99] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m15_colossal_phase_1.png")
		if native and capture and sim.demonstration.phase_elapsed >= (4.8 if phase == 0 else 12) and not captured.has(phase):
			captured[phase] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m15_phase_%d.png" % (phase + 1))
		if native and capture and phase == 4:
			for moment: int in [4, 8, 14, 16, 18, 23, 26, 29, 34, 37, 39, 40]:
				var capture_key: int = 100 + moment
				if sim.demonstration.phase_elapsed >= moment and not captured.has(capture_key):
					captured[capture_key] = true
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.godot/validation/m15_capital_%d.png" % moment)
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
			check(phase.projectiles_max <= 40 and phase.asteroids_max <= 64 and phase.nodes_max < 5000, "Budget physique M15 dépassé")
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
		check(phases[4].moving_gates >= 1 and phases[4].rotating_gates >= 1 and phases[4].gate_passages > 0, "Grilles sans traversée phase 5")
	var final: Dictionary = phases.back()
	check(final.blue_alive >= 13 and not sim.demonstration.game_over, "Population finale non maintenue")
	check(final.green == 4 and final.red == 4 and final.capital == 3, "Population hostile finale M15 non maintenue")
	check(final.phase == 6 and final.real_seconds >= 5, "Extinction trop rapide en finale")
	check(final.targeted > 0 and final.boosts > 0 and final.critical_threats > 0 and final.lateral_excursion > 20, "Finale sans menaces / esquives visibles")
	check(final.projectiles_max <= 40 and final.asteroids_max <= 64, "Plafond finale dépassé")
	var record: Dictionary = {"test": "native_1080p" if native else "headless_complete", "pace": sim.guided_simulation_speed, "physics_hz": Engine.physics_ticks_per_second, "wall_seconds": duration, "fps_mean": count / duration, "fps_min_1s": minimum, "fps_windows": windows, "finale_60_seconds": final_finished, "game_over": sim.demonstration.game_over, "phases": phases, "metrics": sim.threat_metrics(), "capture_included": capture, "render_pixels": root.get_texture().get_size() if native else Vector2.ZERO}
	if native and not capture:
		check(minimum > 60, "FPS 1080p sous 60")
	records.append(record)
	print("M15 RUN " + JSON.stringify(record))
	sim.demonstration.stop()
	await dispose(sim)




func _run() -> void:
	var native: bool = OS.get_cmdline_user_args().has("--native")
	if not native:
		await controlled_gate(15, 0)
		await controlled_gate(25, 1)
		await controlled_gate(-25, 1)
		await gate_contact()
		await colossal_fixture()
		await visuals_fixture()
		await missile_response()
		await arc_response()
		await reinforcement_safety()
	if not OS.get_cmdline_user_args().has("--unit-only"):
		await demonstration_m15(native)
	var file: FileAccess = FileAccess.open("res://.godot/m15_" + ("native" if native else "unit") + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS M15 : grilles mobiles, Colossal, volumes et aura." if failures == 0 else "FAIL M15 : %d" % failures)
	quit(0 if failures == 0 else 1)
