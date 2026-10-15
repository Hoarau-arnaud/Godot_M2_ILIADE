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


func empty(count: int = 1) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.m13_fixture(sim)
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


func dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await frames(4)
	for group: String in GuidedDemonstration.GAME_GROUPS:
		check(get_nodes_in_group(group).is_empty(), "Fuite M13 : " + group)
	check(Engine.time_scale == 1 and Engine.physics_ticks_per_second == 60, "Horloge non restaurée")


func straight(ship: BlueShip, perception: bool) -> void:
	ship.position = Vector3.ZERO
	ship.velocity = Vector3(0, 0, -16)
	ship._speed_factor = 1
	ship.wander_strength = 0
	ship.vertical_wander_strength = 0
	ship.longitudinal_wander_strength = 0
	ship.separation_weight = 0
	ship.cohesion_weight = 0
	ship.alignment_weight = 0
	ship.recovery_weight = 0
	ship.obstacle_detection_radius = 0
	ship.mobile_detection_radius = 0
	ship.hostile_projectile_detection_radius = 80 if perception else 0
	ship.evasive_boost_enabled = perception
	ship.combat_enabled = false


func initial_threat(projectile: Node3D, point: Vector3, speed: Vector3) -> bool:
	var offset: Vector3 = projectile.global_position - point
	var relative: Vector3 = Vector3(projectile.get("velocity")) - speed
	var prediction: Vector2 = MobileAvoidance.approach(offset, relative, 20)
	return offset.dot(relative) < 0 and prediction.x > 0 and prediction.y < float(projectile.get("avoidance_radius"))


func _run() -> void:
	var native: bool = OS.get_cmdline_user_args().has("--native")
	if not native:
		await targeting_comparison()
		await forced_boost()
		await missile_safety()
		await asteroid_boost()
		await interceptor_aim()
		await patrol_aim()
		await capital_accuracy()
		await lifecycle()
	if not OS.get_cmdline_user_args().has("--unit-only"):
		await demonstration_run(native)
	var suffix: String = "native" if native else "unit" if OS.get_cmdline_user_args().has("--unit-only") else "metrics"
	var file: FileAccess = FileAccess.open("res://.godot/m13_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS M13 : ciblage, boosts, cycle guidé, survie et budgets." if failures == 0 else "FAIL M13 : %d" % failures)
	quit(0 if failures == 0 else 1)


func targeting_comparison() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	var results: Array[Dictionary] = []
	for perception: bool in [false, true]:
		random.seed = 131003
		var threatened: int = 0
		var hits: int = 0
		var survivors: int = 0
		var boosts: int = 0
		var lateral: float = 0
		for _shot: int in range(20):
			var sim: SpaceSimulation = empty()
			var ship: BlueShip = sim.ships[0]
			straight(ship, perception)
			var shot: ArtilleryProjectile = ArtilleryProjectile.new()
			shot.kind = ArtilleryProjectile.Kind.RAPID_BARRAGE
			shot.projectile_speed = 88
			shot.damage = 3
			shot.avoidance_radius = 4
			shot.targeted = true
			shot.lifetime = 1.8
			shot.position = Vector3(0, 0, -68)
			var error: Vector3 = Vector3(random.randf_range(-1.8, 1.8), random.randf_range(-1.8, 1.8), 0)
			shot.flight_direction = (CombatPrediction.aim(shot.position, ship.position, ship.velocity, 88) + error - shot.position).normalized()
			sim.projectile_container.add_child(shot)
			sim._on_artillery_fired(shot)
			if initial_threat(shot, ship.position, ship.velocity):
				threatened += 1
			await frames(105)
			hits += sim.combat_impacts
			boosts += sim.evasive_boost_count
			if not sim.ships.is_empty():
				survivors += 1
				lateral = maxf(lateral, Vector2(ship.position.x, ship.position.y).length())
			await dispose(sim)
		results.append({"perception": perception, "shots": 20, "initially_threatening": threatened, "hits": hits, "survivors": survivors, "boosts": boosts, "lateral_m": lateral})
	check(results[0].initially_threatening >= 14, "Visée statique moins de 70 % menaçante")
	check(results[1].survivors > results[0].survivors and results[1].lateral_m > 3 and results[1].boosts > 0, "L'esquive n'améliore pas la survie / déplacement XY")
	records.append({"test": "targeting_comparison", "samples": results})


func forced_boost() -> void:
	var sim: SpaceSimulation = empty()
	var ship: BlueShip = sim.ships[0]
	straight(ship, true)
	var shot: ArtilleryProjectile = ArtilleryProjectile.new()
	shot.kind = ArtilleryProjectile.Kind.SEEKER_SALVO
	shot.projectile_speed = 65
	shot.turn_rate_degrees = 12
	shot.damage = 1
	shot.target = ship
	shot.position = Vector3(0, 0, -58)
	shot.flight_direction = (CombatPrediction.aim(shot.position, ship.position, ship.velocity, 65) - shot.position).normalized()
	sim.projectile_container.add_child(shot)
	await frames(2)
	check(ship.evasive_boost_remaining > 0 and ship.behavior_state == BlueShip.BehaviorState.EVASIVE_BOOST, "Missile convergent sans boost")
	var gun_target: PatrolDrone = SpaceSimulation.DRONE_SCENE.instantiate() as PatrolDrone
	gun_target.position = ship.position + Vector3(0, 0, -20)
	sim.drone_container.add_child(gun_target)
	gun_target.set_physics_process(false)
	ship.combat_enabled = true
	ship._fire_timer = 0
	ship._visuals.basis = Basis.IDENTITY
	ship.projectile_avoidance_active = false
	ship._update_combat(0)
	check(ship.combat_target == gun_target and ship.shots_fired == 0, "Le boost n'interdit pas un tir autrement admissible")
	var direction: Vector3 = ship.boost_direction
	var active_time: float = 0
	var exhaust_max: float = 0
	var no_fire: bool = true
	var cooldown: float = 0
	while ship.evasive_boost_remaining > 0:
		await process_frame
		active_time += ship.get_process_delta_time()
		exhaust_max = maxf(exhaust_max, ship._right_exhaust.scale.y)
		check(ship.boost_direction.is_equal_approx(direction), "Boost change de direction pendant sa durée")
		no_fire = no_fire and ship.shots_fired == 0
		cooldown = ship.boost_cooldown_remaining
	check(active_time >= 0.55 and active_time <= 0.72, "Durée boost hors fenêtre")
	check(exhaust_max > 2.5 and ship._boost_material.emission_energy_multiplier > 1.5, "Animation boost invisible")
	check(no_fire and ship.boost_cooldown_remaining > 1.0, "Tir / cooldown incorrect pendant boost")
	gun_target.position = ship.position + Vector3(0, 0, -20)
	ship._visuals.basis = Basis.IDENTITY
	ship._fire_timer = 0
	ship.projectile_avoidance_active = false
	ship.behavior_state = BlueShip.BehaviorState.NAVIGATION
	ship._update_combat(0)
	check(ship.shots_fired == 1, "Tir ne reprend pas après le boost")
	ship.combat_enabled = false
	check(absf(ship._visual_angles.x) <= deg_to_rad(8.01) and absf(ship._visual_angles.z) <= deg_to_rad(55.01), "Pitch/roll non bornés")
	var emergency: ArtilleryProjectile = ArtilleryProjectile.new()
	emergency.kind = ArtilleryProjectile.Kind.RAPID_BARRAGE
	emergency.projectile_speed = 88
	emergency.position = ship.position + Vector3(0, 0, -8)
	emergency.flight_direction = (CombatPrediction.aim(emergency.position, ship.position, ship.velocity, 88) - emergency.position).normalized()
	sim.projectile_container.add_child(emergency)
	ship._environment_sample_in = 0
	await frames(2)
	check(ship.evasive_boost_count == 2 and ship.evasive_boost_remaining > 0, "Menace mortelle différente ne peut interrompre le cooldown")
	records.append({"test": "boost", "active_sim_seconds": active_time, "xy_m": Vector2(ship.position.x, ship.position.y).length(), "exhaust_scale_max": exhaust_max, "cooldown_remaining": ship.boost_cooldown_remaining, "no_fire": no_fire, "fire_resumes": ship.shots_fired == 1, "lethal_cooldown_override": ship.evasive_boost_count == 2, "cooldown_during": cooldown})
	emergency.queue_free()
	if is_instance_valid(shot):
		shot.queue_free()
	await frames(130)
	check(ship.boost_cooldown_remaining <= 0, "Cooldown boost ne s'écoule pas")
	check(CombatPrediction.threat(Vector3(30, 0, -50), Vector3(0, 0, 100), 4, 4).is_empty(), "Tir passant à 30 m provoque une panique")
	await dispose(sim)


func interceptor_aim() -> void:
	var sim: SpaceSimulation = empty()
	var blue: BlueShip = sim.ships[0]
	blue.position = Vector3.ZERO
	blue.velocity = Vector3(6, 2, -16)
	blue.set_physics_process(false)
	var hostile: Interceptor = SpaceSimulation.INTERCEPTOR_SCENE.instantiate() as Interceptor
	hostile.position = Vector3(0, 0, 36)
	hostile.projectile_container = sim.projectile_container
	sim.interceptor_container.add_child(hostile)
	hostile.set_physics_process(false)
	hostile.target = blue
	hostile.interceptor_state = Interceptor.InterceptorState.PURSUIT
	hostile._visuals.look_at(blue.position + blue.velocity * 0.5)
	var max_error: float = 0
	var threatened: int = 0
	for _index: int in range(20):
		hostile._shot_timer = 0
		hostile._update_fire(0)
		var shots: Array[Node] = get_nodes_in_group("hostile_projectiles")
		if shots.is_empty():
			check(false, "Interceptor refuse le tir ciblé")
			break
		var shot: EnemyLaser = shots.back() as EnemyLaser
		var ideal: Vector3 = CombatPrediction.aim(shot.global_position, blue.global_position, blue.velocity, 85) - shot.global_position
		max_error = maxf(max_error, rad_to_deg(ideal.angle_to(shot.flight_direction)))
		if initial_threat(shot, blue.global_position, blue.velocity):
			threatened += 1
	check(hostile.shots_fired == 20 and threatened >= 18 and max_error <= 1.2, "Rafale Interceptor sans interception précise")
	records.append({"test": "interceptor", "shots": hostile.shots_fired, "initially_threatening": threatened, "max_angular_error_degrees": max_error, "target_preserved": hostile.target == blue})
	await dispose(sim)


func missile_safety() -> void:
	var sim: SpaceSimulation = empty(2)
	var blue: BlueShip = sim.ships[0]
	blue.position = Vector3(20, 0, 0)
	blue.velocity = Vector3.ZERO
	blue.set_physics_process(false)
	var neighbor: BlueShip = sim.ships[1]
	neighbor.position = Vector3(10, 0, 0)
	neighbor.velocity = Vector3.ZERO
	neighbor.set_physics_process(false)
	var missile: ArtilleryProjectile = ArtilleryProjectile.new()
	missile.kind = ArtilleryProjectile.Kind.SEEKER_SALVO
	missile.turn_rate_degrees = 12
	missile.projectile_speed = 65
	missile.target = blue
	missile.position = Vector3(0, 0, -120)
	missile.flight_direction = Vector3.BACK
	sim.projectile_container.add_child(missile)
	var direction: Vector3 = blue._choose_boost_direction({"relative_velocity": Vector3.BACK * 80, "preferred": Vector3.LEFT, "offset": Vector3.FORWARD * 30, "time": 0.4})
	check(direction.dot(Vector3.LEFT) < 0.5 and absf(direction.z) < 0.001, "Boost préfère une route occupée par un voisin")
	var initial: Vector3 = missile.flight_direction
	await frames(30)
	var turn: float = rad_to_deg(initial.angle_to(missile.flight_direction))
	check(turn > 1 and turn <= 6.5, "Missile sans correction / dépasse 12 degrés par seconde")
	blue.take_damage(3)
	await frames(3)
	check(is_instance_valid(missile) and missile.target == null, "Missile M13 garde une cible supprimée")
	records.append({"test": "missile_safety", "turn_half_second_degrees": turn, "turn_rate_max": 12, "dead_target_safe": true, "neighbor_space_avoided": true})
	await dispose(sim)


func patrol_aim() -> void:
	var sim: SpaceSimulation = empty()
	var blue: BlueShip = sim.ships[0]
	blue.position = Vector3(3, 0, -35)
	blue.velocity = Vector3(3, 1, -16)
	blue.set_physics_process(false)
	var drone: PatrolDrone = SpaceSimulation.DRONE_SCENE.instantiate() as PatrolDrone
	drone.demonstration_route = true
	drone.patrol_fire_enabled = true
	drone.patrol_projectile_container = sim.projectile_container
	sim.drone_container.add_child(drone)
	drone.set_physics_process(false)
	var waypoint: Vector3 = drone.waypoint
	drone._patrol_fire_timer = 0
	drone._update_patrol_fire(0)
	check(drone.patrol_shots_fired == 1 and drone.waypoint == waypoint and drone.route_index == 1, "Patrol ne garde pas sa route A–D")
	var shot: EnemyLaser = get_nodes_in_group("hostile_projectiles")[0] as EnemyLaser
	check(shot.patrol_pulse and shot.projectile_speed == 58 and initial_threat(shot, blue.position, blue.velocity), "Pulse sans visée prédictive")
	blue.position.z = 35
	drone._patrol_fire_timer = 0
	drone._update_patrol_fire(0)
	check(drone.patrol_shots_fired == 1, "Patrol tire sur cible derrière son cône")
	records.append({"test": "patrol", "forward_shot": true, "behind_rejected": true, "waypoint_unchanged": true, "cone_degrees": 32})
	await dispose(sim)


func asteroid_boost() -> void:
	var sim: SpaceSimulation = empty()
	var blue: BlueShip = sim.ships[0]
	straight(blue, true)
	blue.obstacle_detection_radius = 44
	var rock: SpaceAsteroid = preload("res://scenes/asteroid.tscn").instantiate() as SpaceAsteroid
	rock.diameter = 8
	rock.shape_seed = 1313
	rock.position = Vector3(0, 0, -18)
	sim.asteroid_container.add_child(rock)
	await frames(3)
	check(blue.evasive_boost_remaining > 0 and blue.evasive_boost_count == 1, "Gros rocher convergent sans boost")
	await frames(75)
	check(not sim.ships.is_empty(), "Le boost n'évite pas le rocher contrôlé")
	var lateral: float = Vector2(blue.position.x, blue.position.y).length() if is_instance_valid(blue) else 0
	check(lateral > 5, "Boost rocher sans manœuvre XY visible")
	records.append({"test": "asteroid_boost", "diameter": 8, "boost": true, "survived": not sim.ships.is_empty(), "xy_m": lateral})
	await dispose(sim)


func capital_accuracy() -> void:
	var sim: SpaceSimulation = empty(15)
	for index: int in range(15):
		var blue: BlueShip = sim.ships[index]
		blue.position = Vector3((index % 5 - 2) * 10, (index / 5 - 1) * 10, 0)
		blue.health = 1000
		blue.wander_strength = 0
		blue.vertical_wander_strength = 0
		blue.longitudinal_wander_strength = 0
	var capital: CapitalShip = SpaceSimulation.CAPITAL_SCENE.instantiate() as CapitalShip
	capital.position = Vector3(0, 0, -420)
	capital.projectile_container = sim.projectile_container
	sim.capital_container.add_child(capital)
	capital.set_physics_process(false)
	capital.fired.connect(sim._on_artillery_fired)
	var threatened: int = 0
	var targets: Dictionary[int, bool] = {}
	var patterns: Array[int] = [5, 9, 0, 2, 4, 1, 3, 6]
	var emitted: int = 0
	var pattern_cursor: int = 0
	var pending: Array[Dictionary] = []
	while emitted < 100:
		capital.observe_group()
		pending = capital.build_salvo(patterns[pattern_cursor % patterns.size()])
		pattern_cursor += 1
		for spec: Dictionary in pending:
			if emitted == 100:
				break
			capital._launch(spec)
			var shot: ArtilleryProjectile = get_nodes_in_group("artillery_projectiles").back() as ArtilleryProjectile
			if shot.targeted:
				targets[(spec.target as BlueShip).individual_seed] = true
				if initial_threat(shot, shot.initial_target_position, shot.initial_target_velocity):
					threatened += 1
			emitted += 1
	await frames(850)
	var metrics: Dictionary = sim.threat_metrics()
	check(emitted == 100 and metrics.targeted >= 65 and threatened >= metrics.targeted * 0.7 and targets.size() >= 10, "Capital cible mal / concentration sur un Blue")
	check(metrics.boosts > 0 and metrics.near_misses > 0, "Capital sans réactions locales / passages proches")
	records.append({"test": "capital_100", "physical_shots": emitted, "targeted": metrics.targeted, "suppression": metrics.suppression, "initially_threatening": threatened, "hits": sim.artillery_hits, "misses": 100 - sim.artillery_hits, "all_damage_events": sim.combat_impacts, "zone_damage_events": sim.combat_impacts - sim.artillery_hits, "obstacle_hits": sim.artillery_obstacle_hits, "boosts": metrics.boosts, "dodges": sim.projectile_dodge_count, "near_misses": metrics.near_misses, "distinct_targets": targets.size()})
	await dispose(sim)


func storm_signature(sim: SpaceSimulation) -> String:
	var values: Array = []
	for node: Node in get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		values.append([rock.shape_seed, rock.motion_center, rock.motion_velocity])
	return JSON.stringify(values)


func lifecycle() -> void:
	var default_sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.m13_fixture(default_sim)
	root.add_child(default_sim)
	await frames(2)
	check(default_sim.presentation.state == PresentationDemonstration.State.READY and not default_sim.demonstration.is_guided() and default_sim.demo_controls.presentation_panel.visible, "Play ne prépare pas READY")
	records.append({"test": "autostart", "guided": default_sim.demonstration.is_guided(), "presentation_ready": default_sim.presentation.state == PresentationDemonstration.State.READY, "label": default_sim.demo_controls.presentation_title.text})
	await dispose(default_sim)
	for phase: int in range(6):
		var sim: SpaceSimulation = empty()
		var original: BlueShip = sim.ships[0]
		sim.demonstration.start()
		var signature: String = storm_signature(sim)
		if phase > 0:
			sim.demonstration._begin_phase(phase, Vector3.ZERO)
		for blue: BlueShip in sim.ships:
			blue.health = 1
			blue.set_physics_process(false)
			var shot: EnemyLaser = preload("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
			shot.position = blue.position + Vector3(0, 0, -3)
			shot.flight_direction = Vector3.BACK
			sim.projectile_container.add_child(shot)
		await frames(15)
		check(sim.demonstration.game_over and sim.ships.is_empty() and sim.death_count == 15, "Game Over absent phase %d" % (phase + 1))
		check(sim.demo_controls.game_over_panel.visible and sim.demo_controls.replay_button.visible and not sim.demo_controls.replay_button.disabled, "Bouton Rejouer absent")
		var time_value: float = sim.demonstration.phase_elapsed
		var shots: int = sim.enemy_shots_fired
		var generated: int = sim.asteroid_container._storm_serial
		await frames(100)
		check(sim.demonstration.phase_index == phase and sim.demonstration.phase_elapsed == time_value and sim.enemy_shots_fired == shots and sim.asteroid_container._storm_serial == generated, "Combat progresse après extinction")
		sim.demo_controls.replay_button.pressed.emit()
		check(not sim.demonstration.game_over and not sim.demo_controls.game_over_panel.visible and sim.demonstration.phase_index == 0 and sim.ships.size() == 15 and sim.death_count == 0 and sim.camera.mode == SimulationCamera.Mode.CINEMATIC, "Replay invalide")
		check(storm_signature(sim) == signature and sim.evasive_boost_count == 0 and sim.near_miss_count == 0, "Replay non déterministe / compteurs pollués")
		sim.demonstration.stop()
		check(sim.ships.has(original) and original.alive, "FREE ne restaure pas l'agent original")
		records.append({"test": "game_over_replay", "phase": phase + 1, "deaths": 15, "stopped": true, "replay": true, "deterministic": true, "free_identity_restored": true})
		await dispose(sim)


func demonstration_run(native: bool) -> void:
	var capture: bool = OS.get_cmdline_user_args().has("--capture")
	var finale_only: bool = OS.get_cmdline_user_args().has("--finale")
	if native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.m13_fixture(sim)
	sim.auto_start_presentation_demo = false
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
		if native and capture and sim.demonstration.phase_elapsed >= 12 and not captured.has(phase):
			captured[phase] = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m13_phase_%d.png" % (phase + 1))
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
			check(phase.projectiles_max <= 90 and phase.asteroids_max <= 180 and phase.nodes_max < 5000, "Budget physique M13 dépassé")
		if phases.size() >= 5:
			check(phases[2].green_shots > 0 and phases[3].enemy_shots >= 20 and phases[3].boosts > 0, "Phases 3/4 sans attaque ciblée / boost")
			check(phases[4].targeted >= (phases[4].targeted + phases[4].suppression) * 0.65 and phases[4].boosts > 0, "Phase 5 ratio ciblé / boost insuffisant")
	var final: Dictionary = phases.back()
	check(final.phase == 6 and final.real_seconds >= 5, "Extinction trop rapide en finale")
	check(final.targeted > 0 and final.boosts > 0 and final.critical_threats > 0 and final.lateral_excursion > 20, "Finale sans menaces / esquives visibles")
	check(final.projectiles_max <= 60 and final.asteroids_max <= 150, "Plafond finale dépassé")
	var record: Dictionary = {"test": "native_1080p" if native else "headless_complete", "pace": sim.guided_simulation_speed, "physics_hz": Engine.physics_ticks_per_second, "wall_seconds": duration, "fps_mean": count / duration, "fps_min_1s": minimum, "fps_windows": windows, "finale_60_seconds": final_finished, "game_over": sim.demonstration.game_over, "phases": phases, "metrics": sim.threat_metrics(), "capture_included": capture, "render_pixels": root.get_texture().get_size() if native else Vector2.ZERO}
	if native and not capture:
		check(minimum > 60, "FPS 1080p sous 60")
	if native and capture:
		if not sim.demonstration.game_over:
			for blue: BlueShip in sim.ships.duplicate():
				blue.take_damage(100)
		await frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m13_game_over.png")
		sim.demo_controls.replay_button.pressed.emit()
		await frames(5)
		check(sim.ships.size() == 15 and not sim.demonstration.game_over, "Replay natif invalide")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/m13_replay.png")
	records.append(record)
	print("M13 RUN " + JSON.stringify(record))
	sim.demonstration.stop()
	await dispose(sim)
