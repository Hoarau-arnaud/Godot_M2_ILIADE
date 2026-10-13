extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const RED: PackedScene = preload("res://scenes/interceptor.tscn")
const GREEN: PackedScene = preload("res://scenes/patrol_drone.tscn")
const ENEMY: PackedScene = preload("res://scenes/enemy_laser.tscn")
const ROCK: PackedScene = preload("res://scenes/asteroid.tscn")

var _failures: int = 0
var _deaths: int = 0
var _red_destroyed: int = 0
var _metrics: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture-m6"):
		await _capture()
	else:
		await _test_states()
		await _test_bursts()
		await _test_enemy_damage()
		await _test_dodge()
		await _test_blue_combat()
		await _test_populations()
		if not OS.get_cmdline_user_args().has("--unit-only"):
			await _test_run(0, 90)
			await _test_run(3, 90)
			await _test_run(3, 300)
			var output: FileAccess = FileAccess.open("res://.godot/m6_metrics.json", FileAccess.WRITE)
			output.store_string(JSON.stringify(_metrics, "\t"))
	print("PASS : intercepteur, tirs ennemis, santé, esquive et populations M6." if _failures == 0 else "FAIL : %d validations M6." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await physics_frame
	await process_frame


func _empty(count: int = 1) -> SpaceSimulation:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.0)
	sim.simulation_speed_multiplier = 1.0
	sim.ship_count = count
	sim.streaming_enabled = false
	sim.drones_enabled = false
	sim.interceptors_enabled = false
	root.add_child(sim)
	sim.set_physics_process(false)
	for index: int in range(count):
		var ship: BlueShip = sim.ships[index]
		ship.position = Vector3(index * 15.0, 0, 0)
		ship.velocity = Vector3.ZERO
		ship.set_physics_process(false)
	return sim


func _dispose(sim: SpaceSimulation) -> void:
	sim.queue_free()
	await _advance(2)
	for group: String in ["blue_ships", "patrol_drones", "interceptors", "hostile_agents", "asteroids", "blue_lasers", "hostile_projectiles"]:
		_check(get_nodes_in_group(group).is_empty(), "Objet non nettoyé : %s." % group)


func _red(sim: SpaceSimulation, pos: Vector3) -> Interceptor:
	var red: Interceptor = RED.instantiate() as Interceptor
	FlightTuning.legacy_actor(red)
	red.position = pos
	red.individual_seed = 7361
	red.projectile_container = sim.projectile_container
	red.died.connect(sim._on_interceptor_died)
	red.destroyed.connect(sim._on_hostile_destroyed)
	red.fired.connect(sim._on_enemy_fired)
	sim.interceptor_container.add_child(red)
	sim.interceptors.append(red)
	red.set_physics_process(false)
	red.velocity = Vector3.ZERO
	return red


func _green(sim: SpaceSimulation, pos: Vector3) -> PatrolDrone:
	var green: PatrolDrone = GREEN.instantiate() as PatrolDrone
	FlightTuning.legacy_actor(green)
	green.position = pos
	green.died.connect(sim._on_drone_died)
	green.destroyed.connect(sim._on_hostile_destroyed)
	sim.drone_container.add_child(green)
	sim.drones.append(green)
	green.set_physics_process(false)
	green.velocity = Vector3.ZERO
	return green


func _rock(sim: SpaceSimulation, pos: Vector3) -> SpaceAsteroid:
	var rock: SpaceAsteroid = ROCK.instantiate() as SpaceAsteroid
	FlightTuning.legacy_actor(rock)
	rock.position = pos
	rock.diameter = 5.0
	rock.shape_seed = 881
	rock.rotation_speed = 0.0
	sim.asteroid_container.add_child(rock)
	return rock


func _enemy(sim: SpaceSimulation, pos: Vector3, direction: Vector3) -> EnemyLaser:
	var bolt: EnemyLaser = ENEMY.instantiate() as EnemyLaser
	FlightTuning.legacy_actor(bolt)
	bolt.position = pos
	bolt.flight_direction = direction
	sim.projectile_container.add_child(bolt)
	sim._on_enemy_fired(bolt)
	return bolt


func _test_states() -> void:
	var sim: SpaceSimulation = _empty(2)
	var ship: BlueShip = sim.ships[0]
	ship.position.z = -40
	sim.ships[1].position = Vector3(20, 0, -55)
	var red: Interceptor = _red(sim, Vector3.ZERO)
	red.combat_enabled = false
	_check(red.interceptor_state == Interceptor.InterceptorState.PATROL, "État initial différent de PATROL.")
	red._physics_process(1.0 / 60.0)
	_check(red.target == ship and red.interceptor_state == Interceptor.InterceptorState.PURSUIT, "PATROL ne détecte pas le BlueShip vivant le plus proche.")
	# Avancer les horloges sans un déplacement physique artificiel de huit secondes.
	red._update_mission(red.max_pursuit_duration)
	_check(red._mission_state == Interceptor.InterceptorState.DISENGAGE and red.target == null, "Poursuite sans durée maximale.")
	red._update_mission(red.disengage_duration)
	_check(red._mission_state == Interceptor.InterceptorState.PATROL, "Désengagement sans retour PATROL.")
	red.position = Vector3.ZERO
	red.velocity = Vector3.FORWARD * red.forward_speed
	red._physics_process(1.0 / 60.0)
	var rock: SpaceAsteroid = _rock(sim, Vector3(0, 0, -20))
	await _advance(2)
	red._physics_process(1.0 / 60.0)
	_check(red.interceptor_state == Interceptor.InterceptorState.AVOIDING and red._mission_state == Interceptor.InterceptorState.PURSUIT, "Obstacle sans AVOIDING ou mission perdue.")
	rock.queue_free()
	await _advance(2)
	red._physics_process(1.0 / 60.0)
	_check(red.interceptor_state == Interceptor.InterceptorState.PURSUIT, "L'évitement ne reprend pas la poursuite.")
	ship.position.z = -300
	red._physics_process(1.0 / 60.0)
	_check(red.interceptor_state == Interceptor.InterceptorState.DISENGAGE, "Cible hors portée toujours poursuivie.")
	red._mission_state = Interceptor.InterceptorState.PURSUIT
	red.target = sim.ships[1]
	sim.ships[1].take_damage(3)
	await _advance(2)
	red._physics_process(1.0 / 60.0)
	_check(red.target == null and red.interceptor_state == Interceptor.InterceptorState.DISENGAGE, "Cible disparue toujours mémorisée.")
	red.take_damage(4)
	_check(red.interceptor_state == Interceptor.InterceptorState.DESTROYED and not red.alive and not red.is_in_group("interceptors"), "DESTROYED non terminal.")
	print("FSM : patrouille/poursuite/désengagement, durée 8 s, évitement/reprise, cible perdue et état final validés.")
	await _dispose(sim)


func _freeze_enemy(bolt: EnemyLaser) -> void:
	bolt.set_physics_process(false)


func _test_bursts() -> void:
	var sim: SpaceSimulation = _empty()
	var ship: BlueShip = sim.ships[0]
	ship.position.z = -30
	var red: Interceptor = _red(sim, Vector3.ZERO)
	red.fired.connect(_freeze_enemy)
	red._update_mission(0.0)
	red.interceptor_state = Interceptor.InterceptorState.PURSUIT
	red._shot_timer = 0.0
	var rock: SpaceAsteroid = _rock(sim, Vector3(0, 0, -15))
	await _advance(2)
	red._update_fire(0.0)
	_check(red.shots_fired == 0 and not red._has_clear_line_of_sight(), "Tir rouge à travers un rocher.")
	rock.position.x = 30
	await _advance(2)
	red._update_fire(0.0)
	red._update_fire(0.1)
	_check(red.shots_fired == 1, "Intervalle de rafale incorrect.")
	red._update_fire(0.1)
	red._update_fire(0.2)
	_check(red.shots_fired == 3 and red._burst_remaining == 0, "Rafale différente de trois tirs.")
	red._update_fire(1.5)
	_check(red.shots_fired == 3, "Pause de rafale trop courte.")
	red._update_fire(0.11)
	_check(red.shots_fired == 4, "Nouvelle rafale absente après cooldown.")
	var bolt: EnemyLaser = sim.projectile_container.get_child(0) as EnemyLaser
	var direction: Vector3 = bolt.flight_direction
	var start: Vector3 = bolt.global_position
	_check(start.is_equal_approx(red._muzzle.global_position) and direction.dot(-red._muzzle.global_basis.z.normalized()) > cos(deg_to_rad(red.firing_cone_angle)), "Bolt hors du nez/cône.")
	bolt._physics_process(0.1)
	_check(bolt.flight_direction == direction and bolt.global_position.is_equal_approx(start + direction * 4.5), "Bolt non rectiligne à 45 m/s.")
	var material: StandardMaterial3D = (bolt.get_node("Bolt") as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	_check(material.albedo_color.r > material.albedo_color.b and bolt.is_in_group("hostile_projectiles"), "Couleur ou groupe du bolt incorrect.")
	for state: Interceptor.InterceptorState in [Interceptor.InterceptorState.PATROL, Interceptor.InterceptorState.DISENGAGE, Interceptor.InterceptorState.AVOIDING]:
		red.interceptor_state = state
		red._update_fire(2.0)
	_check(red.shots_fired == 4, "Tir rouge en dehors de PURSUIT.")
	red.interceptor_state = Interceptor.InterceptorState.PURSUIT
	ship.position = Vector3(30, 0, 0)
	red._update_fire(2.0)
	_check(red.shots_fired == 4, "Tir rouge hors cône frontal.")
	print("Rafale : 0/0,2/0,4 s puis pause 1,6 s ; nez, cône, LOS, couleur, direction droite validés.")
	await _dispose(sim)


func _on_death(ship: BlueShip) -> void:
	_deaths += 1
	_check(not ship.alive and ship.health == 0, "BlueShip mort encore actif.")
	ship.take_damage(100)


func _test_enemy_damage() -> void:
	var sim: SpaceSimulation = _empty()
	var ship: BlueShip = sim.ships[0]
	ship.died.connect(_on_death)
	_deaths = 0
	ship.take_damage(0)
	ship.take_damage(-1)
	_check(ship.health == 3, "Santé initiale/dégâts non positifs incorrects.")
	var green: PatrolDrone = _green(sim, Vector3(0, 0, -14))
	var red: Interceptor = _red(sim, Vector3(0, 0, -8))
	for impact: int in range(3):
		_enemy(sim, Vector3(0, 0, -20), Vector3.BACK)
		await _advance(30)
		if impact < 2:
			_check(ship.alive and ship.health == 2 - impact and sim.death_count == 0, "Impact ennemi sans perte d'un HP.")
	_check(_deaths == 1 and sim.death_count == 1 and sim.blue_ship_hits == 3 and sim.statistics.text == "Vaisseaux détruits : 1", "Trois impacts sans mort unique/HUD exact.")
	_check(green.health == 4 and red.health == 4, "Friendly fire ennemi.")
	await _dispose(sim)
	sim = _empty()
	ship = sim.ships[0]
	var rock: SpaceAsteroid = _rock(sim, Vector3(0, 0, -8))
	await _advance(2)
	var before: Transform3D = rock.global_transform
	var bolt: EnemyLaser = _enemy(sim, Vector3(0, 0, -20), Vector3.BACK)
	bolt.projectile_speed = 1200
	await _advance(3)
	_check(not is_instance_valid(bolt) and ship.health == 3 and rock.global_transform == before and sim.enemies_destroyed == 0 and sim.blue_ship_hits == 0, "Tir rouge traversant/modifiant un rocher.")
	bolt = _enemy(sim, Vector3(200, 200, 0), Vector3.FORWARD)
	bolt.lifetime = 0.1
	await _advance(15)
	_check(not is_instance_valid(bolt), "EnemyLaser expiré non supprimé.")
	ship.take_damage(1)
	_check(ship.health == 2 and ship._hit_flash.light_energy > 0.0, "Flash survivable absent.")
	ship._process(0.2)
	_check(ship._hit_flash.light_energy == 0.0, "Flash permanent.")
	print("Dégâts : 3→2→1→0, décès/HUD uniques ; flash, absence de friendly fire, rocher intact et TTL validés.")
	await _dispose(sim)


func _on_dodge_fire(_bolt: BlueLaser, ship: BlueShip) -> void:
	_check(not ship.projectile_avoidance_active, "BlueShip tire pendant l'esquive.")


func _test_dodge() -> void:
	var sim: SpaceSimulation = _empty()
	var ship: BlueShip = sim.ships[0]
	ship.wander_strength = 0
	ship.vertical_wander_strength = 0
	ship.longitudinal_wander_strength = 0
	ship.velocity = Vector3.FORWARD * 10.5
	ship.fired.connect(_on_dodge_fire.bind(ship))
	var green: PatrolDrone = _green(sim, Vector3(0, 0, -40))
	green.velocity = ship.velocity
	await _advance(2)
	var distant: EnemyLaser = _enemy(sim, Vector3(100, 0, -20), Vector3.BACK)
	var outgoing: EnemyLaser = _enemy(sim, Vector3(0, 0, -20), Vector3.FORWARD)
	ship._projectile_avoidance()
	_check(not ship.projectile_avoidance_active, "Réaction à un tir distant ou divergent.")
	distant.queue_free()
	outgoing.queue_free()
	var bolt: EnemyLaser = _enemy(sim, Vector3(0, 0, -28), Vector3.BACK)
	var force: Vector3 = ship._projectile_avoidance()
	var remembered: Vector3 = ship._projectile_directions[bolt]
	_check(ship.projectile_avoidance_active and force.length() > 0 and bolt.position.distance_to(ship.position) > 20, "Danger non anticipé.")
	ship._fire_timer = 0
	ship._update_combat(1)
	_check(ship.combat_target == green and ship.shots_fired == 0, "Tir malgré hostile visible + projectile dangereux.")
	ship.set_physics_process(true)
	var excursion: float = 0
	var observed: bool = false
	for _frame: int in range(40):
		await physics_frame
		excursion = maxf(excursion, Vector2(ship.position.x, ship.position.y).length())
		observed = observed or ship.projectile_avoidance_active
		if is_instance_valid(bolt) and ship._projectile_directions.has(bolt):
			_check(ship._projectile_directions[bolt].dot(remembered) > 0.99, "Direction d'esquive oscillante.")
	_check(observed and excursion > 1 and ship.alive and ship.health == 3, "Esquive sans déplacement fluide avant impact.")
	ship.set_physics_process(false)
	if is_instance_valid(bolt):
		bolt.queue_free()
	await _advance(2)
	ship._projectile_avoidance()
	ship.position = Vector3.ZERO
	ship._visuals.quaternion = Quaternion.IDENTITY
	ship.behavior_state = BlueShip.BehaviorState.NAVIGATION
	ship._fire_timer = 0
	ship._update_combat(1)
	_check(not ship.projectile_avoidance_active and ship.shots_fired > 0 and ship._projectile_directions.is_empty(), "Tir non repris ou référence de bolt conservée.")
	print("Esquive à 28 m : excursion X/Y %.2f m, côté stable, tirs suspendus puis repris." % excursion)
	await _dispose(sim)


func _on_red_destroyed(red: PatrolDrone) -> void:
	_red_destroyed += 1
	_check((red as Interceptor).interceptor_state == Interceptor.InterceptorState.DESTROYED, "Intercepteur sans état final.")
	red.take_damage(100)


func _test_blue_combat() -> void:
	var sim: SpaceSimulation = _empty(2)
	var ship: BlueShip = sim.ships[0]
	sim.ships[1].position.z = -10
	var green: PatrolDrone = _green(sim, Vector3(0, 0, -26))
	var red: Interceptor = _red(sim, Vector3(0, 0, -35))
	red.destroyed.connect(_on_red_destroyed)
	_red_destroyed = 0
	await _advance(2)
	_check(ship._find_combat_target() == green, "Ciblage générique : hostile le plus proche non sélectionné.")
	for _hit: int in range(8):
		ship._update_combat(1)
		await _advance(40)
	_check(not is_instance_valid(green) and not is_instance_valid(red) and sim.drones_destroyed == 1 and sim.interceptors_destroyed == 1 and sim.enemies_destroyed == 2 and _red_destroyed == 1, "BlueLaser ne détruit pas vert et rouge avec score/signal uniques.")
	_check(sim.blue_shots_fired == 8 and sim.hostile_hits == 8 and sim.ships[1].health == 3, "Impact bleu incorrect ou friendly fire.")
	print("Combat générique : 8 tirs/8 impacts, un vert + un rouge détruits, BlueShip intercalé intact.")
	await _dispose(sim)


func _test_populations() -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.0)
	sim.simulation_speed_multiplier = 1.0
	sim.streaming_enabled = false
	sim.combat_enabled = false
	root.add_child(sim)
	for ship: BlueShip in sim.ships:
		ship.set_physics_process(false)
	for level: int in range(1, 4):
		sim.set_difficulty_mode(level)
		await _advance(2)
		_check(sim.drones.size() == level and sim.interceptors.size() == level - 1 and get_nodes_in_group("hostile_agents").size() == level * 2 - 1, "Populations incorrectes au niveau %d." % level)
		for hostile: Node in get_nodes_in_group("hostile_agents"):
			hostile.set_physics_process(false)
		for red: Interceptor in sim.interceptors:
			_check(red.collision_layer == 4 and red.collision_mask == 2 and not red.is_in_group("patrol_drones"), "Couche/groupe rouge incorrect.")
			for ship: BlueShip in sim.ships:
				_check(ship.position.distance_to(red.position) >= 25, "Spawn rouge trop près d'un BlueShip.")
	sim.interceptors[0].take_damage(4)
	await _advance(420)
	_check(sim.interceptors.size() == 1 and sim.interceptors_destroyed == 1, "Respawn rouge avant huit secondes.")
	await _advance(70)
	_check(sim.interceptors.size() == 2 and sim.interceptor_spawn_count == 3 and sim.enemies_destroyed == 1, "Respawn à huit secondes incorrect.")
	sim.set_difficulty_mode(1)
	await _advance(2)
	_check(sim.interceptors.is_empty() and sim.drones.size() == 1 and sim.enemies_destroyed == 1, "Retrait des rouges incorrect ou score indu au niveau 1.")
	print("Populations : verts 1/2/3, rouges 0/1/2 ; spawn sûr, remplacement à 8 s, retraite sans score.")
	await _dispose(sim)


func _test_run(mode: int, seconds: int) -> void:
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(sim)
	HistoricalFixture.configure(sim, 1.0)
	sim.simulation_speed_multiplier = 1.0
	sim.manual_difficulty = mode
	root.add_child(sim)
	var nodes_max: int = get_node_count()
	var dispersion_max: float = 0
	var minimum_pair: float = INF
	var nearest_sum: float = 0
	var samples: int = 0
	var pursuits: int = 0
	var disengagements: int = 0
	var pursuit_counts: Dictionary[int, int] = {}
	var disengage_counts: Dictionary[int, int] = {}
	var cpu_start: int = 0
	var cpu_first: int = 0
	var cpu_last_start: int = 0
	var wall_start: int = Time.get_ticks_usec()
	for frame: int in range(seconds * 60):
		await physics_frame
		if frame == 3600:
			cpu_start = Time.get_ticks_usec()
		if frame == 5399:
			cpu_first = Time.get_ticks_usec() - cpu_start
		if frame == (seconds - 30) * 60:
			cpu_last_start = Time.get_ticks_usec()
		for red: Interceptor in sim.interceptors:
			var id: int = red.get_instance_id()
			pursuits += red.pursuits_started - int(pursuit_counts.get(id, 0))
			disengagements += red.disengagements - int(disengage_counts.get(id, 0))
			pursuit_counts[id] = red.pursuits_started
			disengage_counts[id] = red.disengagements
		if frame % 12 != 0:
			continue
		var center: Vector3 = sim._fleet_center()
		for ship: BlueShip in sim.ships:
			_check(ship.global_position.is_finite() and ship.velocity.z < 0, "BlueShip sans progression/position finie.")
			dispersion_max = maxf(dispersion_max, ship.position.distance_to(center))
			var nearest: float = INF
			for other: BlueShip in sim.ships:
				if other != ship:
					nearest = minf(nearest, ship.position.distance_to(other.position))
			minimum_pair = minf(minimum_pair, nearest)
			if frame > 60 and nearest != INF:
				nearest_sum += nearest
				samples += 1
		nodes_max = maxi(nodes_max, get_node_count())
		_check(sim.living_agent_count + sim.death_count == 10 and sim.drones.size() <= sim.target_drone_count() and sim.interceptors.size() <= sim.target_interceptor_count(), "Comptage/populations incohérents.")
		_check(sim.asteroid_container.active_asteroid_count <= 72 and sim.projectile_container.get_child_count() <= 70 and nodes_max < 1800, "Budget d'objets dépassé.")
		_check(sim.statistics.text == "Vaisseaux détruits : %d" % sim.death_count and sim.get_node("HUD").find_children("*", "Label", true, false).size() == 1, "HUD enrichi pendant M6.")
	await process_frame
	var cpu_last: int = Time.get_ticks_usec() - cpu_last_start
	_check(sim.living_agent_count > 0, "Essaim exterminé dans le parcours M6.")
	_check(sim.blue_ship_hits <= sim.enemy_shots_fired and sim.hostile_hits <= sim.blue_shots_fired and sim.enemies_destroyed == sim.drones_destroyed + sim.interceptors_destroyed, "Métriques combat incohérentes.")
	if mode == 3:
		_check(pursuits > 0 and disengagements > 0 and sim.enemy_shots_fired > 0 and sim.projectile_dodge_count > 0, "Le parcours difficile n'exerce pas poursuite, désengagement, tirs et esquives.")
	var metrics: Dictionary = {
		"mode": "AUTO" if mode == 0 else "MANUEL 3", "seconds": seconds, "seed": sim.simulation_seed,
		"survivors": sim.living_agent_count, "blue_deaths": sim.death_count, "distance_m": sim.distance_travelled,
		"final_level": sim.difficulty_level, "green_active": sim.drones.size(), "green_kills": sim.drones_destroyed,
		"green_deaths_all_causes": sim.drone_death_count, "green_generated": sim.drone_spawn_count, "green_retired": sim.drone_retired_count,
		"red_active": sim.interceptors.size(), "red_kills": sim.interceptors_destroyed,
		"red_deaths_all_causes": sim.interceptor_death_count, "red_generated": sim.interceptor_spawn_count, "red_retired": sim.interceptor_retired_count,
		"blue_shots": sim.blue_shots_fired, "blue_hits": sim.hostile_hits, "red_shots": sim.enemy_shots_fired, "red_hits": sim.blue_ship_hits,
		"dodge_episodes": sim.projectile_dodge_count, "dodge_agent_ticks": sim.projectile_dodge_ticks,
		"pursuits": pursuits, "disengagements": disengagements,
		"asteroids_max": sim.asteroid_container.maximum_active_observed, "asteroids_final": sim.asteroid_container.active_asteroid_count,
		"projectiles_max": sim.maximum_active_projectiles, "nodes_max": nodes_max,
		"spacing_mean_m": nearest_sum / maxi(samples, 1), "spacing_final_m": sim.average_spacing,
		"minimum_pair_m": minimum_pair, "dispersion_max_m": dispersion_max, "dispersion_final_m": sim.dispersion,
		"isolated_final": sim.isolated_agent_count, "cpu_60_90_ms_per_tick": cpu_first / 1800000.0,
		"cpu_last30_ms_per_tick": cpu_last / 1800000.0, "wall_seconds": (Time.get_ticks_usec() - wall_start) / 1000000.0
	}
	_metrics.append(metrics)
	print("M6 METRICS " + JSON.stringify(metrics))
	await _dispose(sim)


func _capture() -> void:
	var sim: SpaceSimulation = _empty(2)
	var red: Interceptor = _red(sim, Vector3(6, 0, -15))
	_green(sim, Vector3(-7, 1, -20))
	red._visuals.rotation.y = PI
	var bolt: EnemyLaser = _enemy(sim, Vector3(3, 0, -7), Vector3.BACK)
	bolt.set_physics_process(false)
	bolt.rotation.y = PI
	sim.ships[0].take_damage(1)
	sim.ships[0].set_process(false)
	sim.camera.set_process(false)
	sim.camera.position = Vector3(23, 18, 30)
	sim.camera.look_at(Vector3(1, 0, -7))
	sim.set_process(false)
	await _advance(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/validation")
	_check(root.get_texture().get_image().save_png("res://.godot/validation/m6_preview.png") == OK, "Capture M6 impossible.")
	await _dispose(sim)
