extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const CAPITAL: PackedScene = preload("res://scenes/capital_ship.tscn")
const ROCK: PackedScene = preload("res://scenes/asteroid.tscn")
const LASER: PackedScene = preload("res://scenes/blue_laser.tscn")
var failures: int = 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture-design"):
		await _capture_design()
	elif OS.get_cmdline_user_args().has("--native"):
		await _native_run(60, true)
	elif OS.get_cmdline_user_args().has("--long-native"):
		await _native_run(180, false)
	else:
		await _test_states()
		await _test_patterns()
		await _test_flight_safety()
		await _test_heavy(false)
		await _test_heavy(true)
		await _test_damage_respawn()
		await _test_vulnerability()
		await _test_population()
		if not OS.get_cmdline_user_args().has("--unit-only"):
			await _simulation_run(90, false)
			await _simulation_run(60, true)
			await _simulation_run(180, false)
	var suffix: String = "native_long" if OS.get_cmdline_user_args().has("--long-native") else "native" if OS.get_cmdline_user_args().has("--native") else "unit" if OS.get_cmdline_user_args().has("--unit-only") else "design" if OS.get_cmdline_user_args().has("--capture-design") else "metrics"
	var file: FileAccess = FileAccess.open("res://.godot/m10_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("PASS M10 : Capital, états, cinq salves, esquive, dégâts, populations et budgets." if failures == 0 else "FAIL M10 : %d" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await physics_frame
	await process_frame


func _empty(count: int = 1) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.ship_count = count
	sim.streaming_enabled = false
	sim.drones_enabled = false
	sim.interceptors_enabled = false
	sim.capital_ships_enabled = false
	sim.simulation_speed_multiplier = 1
	root.add_child(sim)
	return sim


func _dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await _advance(2)
	for group: String in ["capital_ships", "artillery_projectiles", "hostile_projectiles", "blue_ships", "hostile_agents", "capital_explosions"]:
		_check(get_nodes_in_group(group).is_empty(), "Groupe non nettoyé : " + group)
	_check(Engine.time_scale == 1 and Engine.physics_ticks_per_second == 60, "Horloge non restaurée.")


func _capital(sim: SpaceSimulation) -> CapitalShip:
	var ship: CapitalShip = CAPITAL.instantiate() as CapitalShip
	ship.individual_seed = 20261012
	ship.position = Vector3(0, 0, -190)
	ship.projectile_container = sim.projectile_container
	sim.capital_container.add_child(ship)
	return ship


func _test_states() -> void:
	var sim: SpaceSimulation = _empty()
	var capital: CapitalShip = _capital(sim)
	await _advance(30 * 60)
	for state: int in [CapitalShip.State.ENTRY, CapitalShip.State.OBSERVE, CapitalShip.State.PREPARE, CapitalShip.State.FIRE, CapitalShip.State.COOLDOWN, CapitalShip.State.REPOSITION]:
		_check(capital.state_history.has(state), "État non traversé : " + CapitalShip.State.keys()[state])
	_check(capital.salvos_fired >= 2 and capital.observed_count == 1 and capital.group_distance > 120 and capital.group_distance < 250, "Cycle, perceptions ou distance invalide.")
	var rock: SpaceAsteroid = ROCK.instantiate() as SpaceAsteroid
	rock.diameter = 16
	rock.motion_type = SpaceAsteroid.MotionType.LINEAR
	rock.motion_velocity = Vector3.BACK * 20
	rock.motion_duration = 10
	rock.position = capital.global_position + Vector3(0, 0, 50)
	sim.asteroid_container.add_child(rock)
	capital._transition(CapitalShip.State.REPOSITION)
	await _advance(20)
	_check(capital.state == CapitalShip.State.AVOIDING, "Obstacle critique non anticipé.")
	rock.queue_free()
	await _advance(90)
	_check(capital.state != CapitalShip.State.AVOIDING and capital.state_history.has(CapitalShip.State.AVOIDING), "Évitement sans reprise.")
	var reference: Array[int] = []
	capital._random.seed = 1203
	capital._patterns.clear()
	for _index: int in range(15):
		reference.append(capital._choose_pattern())
	capital._random.seed = 1203
	capital._patterns.clear()
	for index: int in range(15):
		_check(reference[index] == capital._choose_pattern(), "Choix d'attaque non reproductible.")
	_check(reference.slice(0, 5).has(0) and reference.slice(0, 5).has(4), "Cycle sans cinq patterns.")
	print("FSM : ENTRY → OBSERVE → PREPARE → FIRE → COOLDOWN → REPOSITION ; AVOIDING/reprise et seed validés.")
	await _dispose(sim)


func _test_patterns() -> void:
	var sim: SpaceSimulation = _empty(3)
	sim.set_physics_process(false)
	for ship: BlueShip in sim.ships:
		ship.set_physics_process(false)
		ship.global_position = Vector3(200, 200, 200)
	var capital: CapitalShip = _capital(sim)
	capital.set_physics_process(false)
	capital.observed_center = Vector3.ZERO
	capital.observed_velocity = Vector3.FORWARD * 10.5
	capital.observed_dispersion = 24
	for pattern: int in range(5):
		var salvo: Array[Dictionary] = capital.build_salvo(pattern)
		_check(salvo.size() == [1, 5, 4, 6, 3][pattern], "Nombre de projectiles incorrect.")
		if pattern == CapitalShip.ArtilleryPattern.SPREAD:
			_check(Vector3(salvo[1].aim).distance_to(salvo[2].aim) > 20, "Éventail sans dispersion.")
		if pattern == CapitalShip.ArtilleryPattern.CROSS_FIRE:
			_check(Vector3(salvo[0].origin).distance_to(salvo[1].origin) > 40, "Cross sans deux lanceurs.")
		for spec: Dictionary in salvo:
			capital._launch(spec)
		var projectiles: Array[Node] = get_nodes_in_group("artillery_projectiles")
		for index: int in range(projectiles.size()):
			var node: Node = projectiles[index]
			var projectile: ArtilleryProjectile = node as ArtilleryProjectile
			_check(projectile.velocity.is_finite() and projectile.damage > 0 and projectile.avoidance_radius > 0, "Contrat projectile invalide.")
			if pattern == CapitalShip.ArtilleryPattern.ARC_SALVO:
				var middle: Vector3 = projectile.trajectory(projectile.arc_duration * 0.5)
				var chord: Vector3 = projectile._origin + projectile.flight_direction * projectile.projectile_speed * projectile.arc_duration * 0.5
				_check(middle.distance_to(chord) > 23 and projectile.trajectory(projectile.arc_duration).distance_to(Vector3(salvo[index].aim)) < 0.2, "Arc sans courbe ou sans arrivée dans la zone.")
			if pattern == CapitalShip.ArtilleryPattern.SEEKER_SALVO:
				_check(is_instance_valid(projectile.target), "Seeker sans cible initiale.")
				var before: Vector3 = projectile.flight_direction
				projectile.target.global_position = projectile.global_position + Vector3(100, 0, 0)
				projectile._physics_process(0.1)
				_check(rad_to_deg(before.angle_to(projectile.flight_direction)) <= 0.61, "Guidage supérieur à 6°/s.")
		await _advance(120)
		for node: Node in get_nodes_in_group("artillery_projectiles"):
			_check((node as ArtilleryProjectile).age >= 1.9 and (node as ArtilleryProjectile).velocity.is_finite(), "Vol trop court ou NaN.")
		for node: Node in projectiles:
			if is_instance_valid(node):
				node.queue_free()
		await _advance(2)
	# Une cible supprimée ne provoque pas de référence invalide.
	var seeker: ArtilleryProjectile = ArtilleryProjectile.new()
	seeker.kind = ArtilleryProjectile.Kind.SEEKER_SALVO
	seeker.target = sim.ships[0]
	seeker.position = Vector3(500, 0, 0)
	sim.projectile_container.add_child(seeker)
	sim.ships[0].queue_free()
	await _advance(20)
	_check(is_instance_valid(seeker) and seeker.target == null and seeker.velocity.is_finite(), "Seeker après suppression cible.")
	# Budget partagé : une salve entière est refusée avant le premier tir.
	capital.artillery_limit = 1
	capital.selected_pattern = CapitalShip.ArtilleryPattern.SPREAD
	capital._transition(CapitalShip.State.FIRE)
	capital._update_state(0.1)
	_check(capital.state == CapitalShip.State.COOLDOWN and capital._pending.is_empty(), "Salve massive dépasse le plafond.")
	print("Patterns : heavy 1, spread 5, arc 4, cross 6/two launchers, seeker 3/6°s ; courbes, références et plafond validés.")
	await _dispose(sim)


func _test_flight_safety() -> void:
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	var ship: BlueShip = sim.ships[0]
	ship.set_physics_process(false)
	ship.global_position = Vector3(400, 0, 0)
	var endpoints: Array[Vector3] = []
	for rate: int in [60, 120]:
		sim.set_simulation_speed(float(rate) / 60)
		var projectile: ArtilleryProjectile = ArtilleryProjectile.new()
		projectile.kind = ArtilleryProjectile.Kind.ARC_SALVO
		projectile.position = Vector3(100, 100, 0)
		projectile.arc_duration = 4
		sim.projectile_container.add_child(projectile)
		projectile.set_physics_process(false)
		for _frame: int in range(4 * rate):
			projectile._physics_process(1.0 / rate)
		endpoints.append(projectile.position)
		projectile.queue_free()
		await _advance(2)
	_check(endpoints[0].distance_to(endpoints[1]) < 0.001, "Arc dépend du pas / time_scale.")
	sim.set_simulation_speed(1)
	for kind: int in range(5):
		ship.global_position = Vector3.ZERO
		ship.health = 3
		var projectile: ArtilleryProjectile = ArtilleryProjectile.new()
		projectile.kind = kind as ArtilleryProjectile.Kind
		projectile.damage = 2 if kind == 0 else 1
		projectile.arc_amplitude = 0 # Même sweep physique pour les cinq objets.
		projectile.position = Vector3(0, 0, -10)
		sim.projectile_container.add_child(projectile)
		await _advance(60)
		_check(not is_instance_valid(projectile) and ship.health == (1 if kind == 0 else 2), "Collision / dégâts du pattern %d." % kind)
	ship.global_position = Vector3(400, 0, 0)
	await _advance(2) # Synchroniser la pose du corps avant une nouvelle requête physique.
	var expiring: ArtilleryProjectile = ArtilleryProjectile.new()
	expiring.lifetime = 0.3
	sim.projectile_container.add_child(expiring)
	await _advance(30)
	_check(not is_instance_valid(expiring), "Lifetime non nettoyée.")
	var rock: SpaceAsteroid = ROCK.instantiate() as SpaceAsteroid
	rock.position = Vector3(0, 0, 10)
	sim.asteroid_container.add_child(rock)
	var blocked: ArtilleryProjectile = ArtilleryProjectile.new()
	sim.projectile_container.add_child(blocked)
	await _advance(60)
	_check(not is_instance_valid(blocked) and is_instance_valid(rock), "Astéroïde n'absorbe pas l'artillerie.")
	rock.queue_free()
	await _advance(2)
	ship.health = 3
	ship.global_position = Vector3.ZERO
	await _advance(2)
	var seeker: ArtilleryProjectile = ArtilleryProjectile.new()
	seeker.kind = ArtilleryProjectile.Kind.SEEKER_SALVO
	seeker.target = ship
	seeker.position = Vector3(0, 0, -70)
	seeker.projectile_speed = 30
	sim.projectile_container.add_child(seeker)
	for _frame: int in range(240):
		ship.global_position += Vector3(9, 0, -10.5) / 60
		await physics_frame
	_check(ship.health == 3, "Guidage impossible à esquiver par déplacement latéral.")
	print("Vol : arcs à pas 60/120 Hz et time_scale 1/2 identiques ; collisions cinq types, absorption rocher, lifetime et seeker esquivable validés.")
	await _dispose(sim)


func _test_heavy(disable_perception: bool) -> void:
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	var ship: BlueShip = sim.ships[0]
	ship.fired.connect(func(_projectile: BlueLaser) -> void:
		_check(not ship.projectile_avoidance_active and ship.behavior_state != BlueShip.BehaviorState.AVOIDANCE, "BlueShip tire pendant l'esquive critique."))
	ship.global_position = Vector3.ZERO
	ship.velocity = Vector3.FORWARD * 10.5
	ship.wander_strength = 0
	ship.vertical_wander_strength = 0
	ship.longitudinal_wander_strength = 0
	if disable_perception:
		ship.set_physics_process(false)
	var capital: CapitalShip = _capital(sim)
	capital.set_physics_process(false)
	capital.global_position = Vector3(0, 0, -65)
	var heavy: ArtilleryProjectile = ArtilleryProjectile.new()
	heavy.position = Vector3(0, 0, -75)
	heavy.flight_direction = Vector3.BACK
	sim.projectile_container.add_child(heavy)
	await _advance(4 * 60)
	if disable_perception:
		_check(ship.health == 1 and not is_instance_valid(heavy), "Impact heavy ne retire pas 2 HP / projectile non supprimé.")
	else:
		_check(ship.alive and ship.health == 3 and ship.projectile_dodge_count > 0 and absf(ship.position.y) + absf(ship.position.x) > 4, "Heavy non esquivé.")
	print("HEAVY : " + ("impact réel -2 HP et suppression" if disable_perception else "détection, esquive et priorité sur le tir") + " validés.")
	await _dispose(sim)


func _test_damage_respawn() -> void:
	var sim: SpaceSimulation = _empty()
	sim.capital_ships_enabled = true
	sim.set_difficulty_mode(3)
	sim._maintain_capitals(sim._fleet_center(), 0)
	var capital: CapitalShip = sim.capitals[0]
	capital.set_physics_process(false)
	capital.global_position = Vector3(0, 0, -65)
	sim.ships[0].set_physics_process(false)
	sim.ships[0].global_position = Vector3.ZERO
	var laser: BlueLaser = LASER.instantiate() as BlueLaser
	laser.position = Vector3(0, 0, -20)
	sim.projectile_container.add_child(laser)
	await _advance(60)
	_check(capital.health == 23, "BlueLaser → Capital ne retire pas 1 HP.")
	capital.velocity = Vector3.ZERO
	var blue: BlueShip = sim.ships[0]
	_check(blue._find_combat_target() == capital, "Blindage arrière hors portée naturelle du BlueShip.")
	blue._update_combat(1)
	await _advance(60)
	_check(capital.health == 22 and blue.shots_fired == 1, "BlueShip ne peut pas attaquer naturellement le Capital vulnérable.")
	# Vol existant indépendant du lanceur.
	var heavy: ArtilleryProjectile = ArtilleryProjectile.new()
	heavy.position = Vector3(300, 0, -150)
	sim.projectile_container.add_child(heavy)
	capital.take_damage(100)
	capital.take_damage(100)
	_check(sim.capitals_destroyed == 1 and sim.enemies_destroyed == 1 and capital.state == CapitalShip.State.DESTROYED, "Double destruction/signal.")
	capital.set_physics_process(true)
	await _advance(4 * 60)
	_check(not is_instance_valid(capital) and is_instance_valid(heavy) and sim.capitals.is_empty(), "Séquence destruction/indépendance projectiles.")
	await _advance(19 * 60)
	_check(sim.capitals.is_empty(), "Respawn avant 25 s.")
	await _advance(3 * 60)
	_check(sim.capitals.size() == 1 and sim.capital_spawn_count == 2, "Respawn long non effectué.")
	print("Dégâts : laser -1/24 HP, destruction unique, moteurs éteints, explosions puis disparition 3,4 s, respawn 25 s validés.")
	await _dispose(sim)


func _test_population() -> void:
	var sim: SpaceSimulation = _empty(10)
	sim.capital_ships_enabled = true
	for level: int in [1, 2, 3]:
		sim.set_difficulty_mode(level)
		await _advance(2)
		_check(sim.capitals.size() == (1 if level == 3 else 0), "Population du niveau incorrecte.")
	sim.demo_controls.minus_buttons["Capital Ship"].pressed.emit()
	await _advance(2)
	_check(sim.capitals.is_empty() and sim.target_capital_count() == 0, "Panneau - Capital inopérant.")
	sim.demo_controls.plus_buttons["Capital Ship"].pressed.emit()
	await _advance(2)
	_check(sim.capitals.size() == 1 and sim.demo_controls.plus_buttons["Capital Ship"].disabled and sim.demo_controls._counts["Capital Ship"].text == "1/1", "Panneau + / maximum 1 incorrect.")
	sim.set_difficulty_mode(1)
	sim.reset_population_overrides()
	await _advance(2)
	_check(sim.capitals.is_empty() and sim.manual_capital_count_override == -1, "Reset ne restaure pas le niveau.")
	sim.apply_action_preset()
	await _advance(6 * Engine.physics_ticks_per_second)
	_check(sim.ships.size() == 15 and sim.target_drone_count() == 0 and sim.target_capital_count() == 1 and sim.capitals.size() == 1, "Spectacle /15 bleus et Capital incorrect.")
	print("Populations : 0/0/1 ; panneau 0–1, reset, spectacle 15 bleus/1 Capital validés.")
	await _dispose(sim)


func _test_vulnerability() -> void:
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	var blue: BlueShip = sim.ships[0]
	blue.global_position = Vector3.ZERO
	blue.velocity = Vector3.FORWARD * 10.5
	blue.wander_strength = 0
	blue.vertical_wander_strength = 0
	blue.longitudinal_wander_strength = 0
	blue.combat_enabled = false
	var capital: CapitalShip = _capital(sim)
	capital.salvos_fired = 3
	capital._transition(CapitalShip.State.REPOSITION)
	var previous: Vector3 = capital.position
	var max_step: float = 0
	for _frame: int in range(24 * 60):
		await physics_frame
		max_step = maxf(max_step, capital.position.distance_to(previous))
		previous = capital.position
	var distance: float = capital.global_position.distance_to(blue.global_position)
	_check(capital.vulnerable and distance >= 50 and distance <= 90 and max_step < 0.4, "Rapprochement vulnérable absent ou téléportation.")
	blue.combat_enabled = true
	await _advance(4 * 60)
	_check(capital.health < 24 and blue.alive, "Aucun tir bleu naturel durant la vulnérabilité.")
	print("Vulnérabilité : %.2f m après approche continue, pas max %.3f m, BlueShip tire sans poursuite." % [distance, max_step])
	await _dispose(sim)


func _metrics(sim: SpaceSimulation, name: String, nodes_max: int, maximum_dispersion: float, cpu: float) -> Dictionary:
	return {"test": name, "simulation_seconds": sim.elapsed_simulation_time, "blue_alive": sim.ships.size(), "blue_dead": sim.death_count, "blue_created": sim.ship_spawn_count, "green": sim.drones.size(), "red": sim.interceptors.size(), "capital": sim.capitals.size(), "capital_destroyed": sim.capitals_destroyed, "capital_spawns": sim.capital_spawn_count, "salvos": sim.capital_salvos, "artillery_hits": sim.artillery_hits, "artillery_obstacle_hits": sim.artillery_obstacle_hits, "dodges": sim.projectile_dodge_count, "artillery_max": sim.maximum_artillery_projectiles, "projectiles_max": sim.maximum_active_projectiles, "projectiles_final": sim.projectile_container.get_child_count(), "nodes_max": nodes_max, "nodes_final": get_node_count(), "dispersion_max": maximum_dispersion, "dispersion_final": sim.dispersion, "isolated_final": sim.isolated_agent_count, "cpu_ms_per_tick": cpu}


func _capture_design() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var sim: SpaceSimulation = _empty()
	sim.set_physics_process(false)
	sim.set_process(false)
	sim.ships[0].set_physics_process(false)
	var capital: CapitalShip = _capital(sim)
	capital.set_physics_process(false)
	capital.global_position = Vector3.ZERO
	sim.ships[0].global_position = Vector3(35, -4, 30)
	sim.demo_controls.panel.hide()
	sim.demo_controls.help_panel.hide()
	sim.camera.global_position = Vector3(80, 55, 115)
	sim.camera.look_at(Vector3.ZERO)
	capital.get_node("Visuals").show_charge(1, 1, true)
	await _advance(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/m10_capital_design.png")
	sim.demo_controls.panel.show()
	await _advance(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/m10_controls.png")
	await _dispose(sim)


func _simulation_run(seconds: int, spectacle: bool) -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.manual_difficulty = 3
	root.add_child(sim)
	if spectacle:
		sim.apply_action_preset()
	var rate: int = Engine.physics_ticks_per_second
	var nodes_max: int = get_node_count()
	var spread: float = 0
	var start: int = Time.get_ticks_usec()
	for frame: int in range(seconds * rate):
		await physics_frame
		if frame % 60 == 0:
			nodes_max = maxi(nodes_max, get_node_count())
			spread = maxf(spread, sim.dispersion)
			_check(sim.maximum_artillery_projectiles <= 50, "Budget artillerie dépassé.")
	var cpu: float = float(Time.get_ticks_usec() - start) / (seconds * rate) / 1000
	var metrics: Dictionary = _metrics(sim, "headless_spectacle" if spectacle else "headless_%ds" % seconds, nodes_max, spread, cpu)
	results.append(metrics)
	_check(sim.capital_salvos.reduce(func(total: int, value: int) -> int: return total + value, 0) >= 1, "Scénario sans artillerie.")
	_check(sim.projectile_container.get_child_count() < 100 and nodes_max < 2500, "Croissance non bornée.")
	print(JSON.stringify(metrics))
	await _dispose(sim)


func _native_run(seconds: int, spectacle: bool) -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_position(Vector2i(180, 140))
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	sim.manual_difficulty = 3
	root.add_child(sim)
	if spectacle:
		sim.apply_action_preset()
	else:
		sim.camera.set_mode(SimulationCamera.Mode.CINEMATIC)
	sim.demo_controls.panel.hide()
	sim.demo_controls.help_panel.hide()
	var start: int = Time.get_ticks_usec()
	var last: int = start
	var sample_frames: int = 0
	var fps_sum: float = 0
	var fps_count: int = 0
	var fps_min: float = INF
	var frames: int = 0
	var nodes_max: int = get_node_count()
	var spread: float = 0
	var next_capture: int = 20
	var next_report: int = 30
	while float(Time.get_ticks_usec() - start) / 1000000 < seconds:
		await process_frame
		frames += 1
		sample_frames += 1
		var now: int = Time.get_ticks_usec()
		var elapsed: float = float(now - start) / 1000000
		if now - last >= 1000000:
			var fps: float = sample_frames * 1000000.0 / (now - last)
			fps_sum += fps
			fps_count += 1
			fps_min = minf(fps_min, fps)
			last = now
			sample_frames = 0
			nodes_max = maxi(nodes_max, get_node_count())
			spread = maxf(spread, sim.dispersion)
		if spectacle and elapsed >= next_capture:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/validation/m10_spectacle_%ds.png" % next_capture)
			next_capture += 20
		if elapsed >= next_report:
			print("NATIVE %ds : Capital %d, salves %s, artillerie %d, nodes %d" % [next_report, sim.capitals.size(), sim.capital_salvos, get_nodes_in_group("artillery_projectiles").size(), get_node_count()])
			next_report += 30
	var metrics: Dictionary = _metrics(sim, "native_spectacle" if spectacle else "native_long", nodes_max, spread, 0)
	metrics["real_seconds"] = float(Time.get_ticks_usec() - start) / 1000000
	metrics["fps_mean"] = frames / float(metrics.real_seconds)
	metrics["fps_sample_mean"] = fps_sum / maxf(fps_count, 1)
	metrics["fps_min_1s"] = fps_min
	results.append(metrics)
	_check(sim.maximum_artillery_projectiles <= 50 and nodes_max < 2500, "Budget native dépassé.")
	_check(metrics.fps_mean > 60, "FPS moyen 1080p inférieur à 60.")
	print(JSON.stringify(metrics))
	await _dispose(sim)
