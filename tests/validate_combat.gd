extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DRONE_SCENE: PackedScene = preload("res://scenes/patrol_drone.tscn")
const ASTEROID_SCENE: PackedScene = preload("res://scenes/asteroid.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/blue_laser.tscn")

var _failures: int = 0
var _destroyed_signals: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture-combat"):
		await _capture_combat()
		quit(0 if _failures == 0 else 1)
		return
	await _test_targeting()
	await _test_safety_priority()
	await _test_line_of_sight()
	await _test_damage_and_replacement()
	await _test_projectile_collisions()
	await _test_cooldowns()
	await _test_navigation_independence()
	await _test_drone_counts()
	await _test_run_90(3)
	await _test_run_90(0)
	print("PASS : fondation combat M5." if _failures == 0 else "FAIL : %d validations combat." % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _advance(frames: int) -> void:
	for _frame: int in range(frames):
		await physics_frame
	await process_frame


func _dispose(simulation: SpaceSimulation) -> void:
	simulation.queue_free()
	await _advance(2)
	for group: String in ["blue_ships", "hostile_agents", "patrol_drones", "interceptors", "asteroids", "blue_lasers", "hostile_projectiles"]:
		_check(get_nodes_in_group(group).is_empty(), "Un objet supprimé reste dans le groupe %s." % group)


# Les fixtures isolent la décision de tir ; les parcours 90 s utilisent la scène normale.
func _empty_scene(count: int = 1) -> SpaceSimulation:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(simulation)
	HistoricalFixture.configure(simulation, 1.0)
	simulation.simulation_speed_multiplier = 1.0
	simulation.ship_count = count
	simulation.streaming_enabled = false
	simulation.drones_enabled = false
	simulation.interceptors_enabled = false
	root.add_child(simulation)
	simulation.set_physics_process(false)
	for index: int in range(simulation.ships.size()):
		var ship: BlueShip = simulation.ships[index]
		ship.position = Vector3(float(index) * 15.0, 0, 0)
		ship.set_physics_process(false)
	return simulation


func _drone(simulation: SpaceSimulation, position_value: Vector3, health_value: int = 4) -> PatrolDrone:
	var drone: PatrolDrone = DRONE_SCENE.instantiate() as PatrolDrone
	FlightTuning.legacy_actor(drone)
	drone.position = position_value
	drone.max_health = health_value
	drone.patrol_anchor = Vector2(position_value.x, position_value.y)
	simulation.drone_container.add_child(drone)
	drone.set_physics_process(false)
	return drone


func _rock(simulation: SpaceSimulation, position_value: Vector3, diameter: float = 6.0) -> SpaceAsteroid:
	var asteroid: SpaceAsteroid = ASTEROID_SCENE.instantiate() as SpaceAsteroid
	FlightTuning.legacy_actor(asteroid)
	asteroid.position = position_value
	asteroid.diameter = diameter
	asteroid.shape_seed = 88
	asteroid.rotation_speed = 0.0
	simulation.asteroid_container.add_child(asteroid)
	return asteroid


func _laser(simulation: SpaceSimulation, position_value: Vector3) -> BlueLaser:
	var laser: BlueLaser = LASER_SCENE.instantiate() as BlueLaser
	FlightTuning.legacy_actor(laser)
	laser.position = position_value
	simulation.projectile_container.add_child(laser)
	simulation._on_ship_fired(laser)
	return laser


func _test_targeting() -> void:
	var simulation: SpaceSimulation = _empty_scene(2)
	var ship: BlueShip = simulation.ships[0]
	simulation.ships[1].position = Vector3(0, 0, -14)
	var front: PatrolDrone = _drone(simulation, Vector3(0, 0, -25))
	_drone(simulation, Vector3(0, 0, 25))
	_drone(simulation, Vector3(25, 0, -10))
	_drone(simulation, Vector3(0, 0, -100))
	var background_rock: SpaceAsteroid = _rock(simulation, Vector3(0, 0, -55))
	await _advance(2)
	_check(ship._find_combat_target() == front, "Le BlueShip ne sélectionne pas l'hostile frontal vivant.")
	ship._fire_timer = 100.0
	ship._update_combat(0.0)
	_check(ship.combat_target == front and ship.combat_state == BlueShip.CombatState.COOLDOWN, "État de combat indépendant absent.")
	front.remove_from_group("hostile_agents")
	_check(ship._find_combat_target() == null, "Un ami, un astéroïde, une cible derrière, latérale ou trop loin est sélectionné.")
	front.add_to_group("hostile_agents")
	front.take_damage(4)
	await _advance(2)
	_check(ship.combat_target == null and ship._find_combat_target() == null, "Une cible détruite reste mémorisée ou sélectionnable.")
	background_rock.position.x = 25.0
	var outside_firing_range: PatrolDrone = _drone(simulation, Vector3(0, 0, -52))
	await _advance(2)
	ship._fire_timer = 0.0
	ship._update_combat(1.0)
	_check(ship.combat_target == outside_firing_range and ship.combat_state == BlueShip.CombatState.TARGET_VISIBLE and ship.shots_fired == 0, "La perception à 60 m et la portée de tir à 44 m ne sont pas distinguées.")
	outside_firing_range.position.z = -30.0
	await _advance(2)
	ship._update_combat(1.0)
	_check(ship.shots_fired == 1, "Le tir ne commence pas lorsque la cible entre à portée.")
	print("Ciblage : frontal hostile accepté ; arrière, latéral, hors portée, détruit, BlueShip et astéroïde ignorés.")
	await _dispose(simulation)


func _test_safety_priority() -> void:
	var simulation: SpaceSimulation = _empty_scene(3)
	var ship: BlueShip = simulation.ships[0]
	var target: PatrolDrone = _drone(simulation, Vector3(0, 0, -32))
	var asteroid: SpaceAsteroid = _rock(simulation, Vector3(6, 0, -18))
	await _advance(2)
	_check(ship._has_clear_line_of_sight(target), "Fixture priorité : le rocher latéral bloque la ligne de vue.")
	ship._update_neighbor_rules()
	ship._update_behavior_state(ship._obstacle_avoidance() * ship.avoidance_weight)
	_check(ship.behavior_state == BlueShip.BehaviorState.AVOIDANCE, "Le danger de la fixture ne déclenche pas l'évitement.")
	ship._fire_timer = 0.0
	ship._update_combat(1.0)
	_check(ship.combat_target == target and ship.shots_fired == 0, "Un chasseur tire pendant un évitement malgré une cible visible.")
	asteroid.position = Vector3(20, 0, 20)
	await _advance(2)
	ship._update_behavior_state(ship._obstacle_avoidance() * ship.avoidance_weight)
	ship._update_combat(1.0)
	_check(ship.behavior_state == BlueShip.BehaviorState.NAVIGATION and ship.shots_fired == 1, "Le tir ne reprend pas après le danger.")
	# Deux voisins symétriques peuvent annuler leur force, mais restent trop proches.
	simulation.ships[1].position = Vector3(5, 0, 0)
	simulation.ships[2].position = Vector3(-5, 0, 0)
	ship._update_neighbor_rules()
	_check(ship.critical_separation_active and ship._critical_separation.length() < 0.001, "Fixture de séparation symétrique incorrecte.")
	ship._update_combat(1.0)
	_check(ship.shots_fired == 1, "Le chasseur tire avec des voisins en zone critique.")
	simulation.ships[1].position = Vector3(15, 0, 0)
	simulation.ships[2].position = Vector3(-15, 0, 0)
	ship._update_neighbor_rules()
	ship._update_combat(1.0)
	_check(not ship.critical_separation_active and ship.shots_fired == 2, "Le tir reste bloqué après la séparation critique.")
	print("Priorité : zéro tir en AVOIDANCE ou en séparation critique, reprise après retour en sécurité.")
	await _dispose(simulation)


func _test_line_of_sight() -> void:
	var simulation: SpaceSimulation = _empty_scene()
	var ship: BlueShip = simulation.ships[0]
	var target: PatrolDrone = _drone(simulation, Vector3(0, 0, -35))
	var asteroid: SpaceAsteroid = _rock(simulation, Vector3(0, 0, -18))
	await _advance(2)
	ship._fire_timer = 0.0
	ship._update_combat(1.0)
	_check(not ship._has_clear_line_of_sight(target) and ship.shots_fired == 0, "Le chasseur tire à travers un rocher.")
	asteroid.position.x = 20.0
	await _advance(2)
	ship._update_combat(1.0)
	_check(ship._has_clear_line_of_sight(target) and ship.shots_fired == 1, "Le chasseur ne tire pas quand la ligne se libère.")
	var projectile: BlueLaser = simulation.projectile_container.get_child(0) as BlueLaser
	_check(projectile.global_position.is_equal_approx(ship._muzzle.global_position), "Le projectile ne part pas du Marker3D Muzzle.")
	_check(projectile.flight_direction.dot(ship._firing_forward()) > 0.999, "Le projectile vise ailleurs que dans l'axe du nez.")
	print("Ligne de vue : rocher bloquant = zéro tir ; ligne libre = tir réel depuis le nez, direction frontale.")
	await _dispose(simulation)


func _on_destroyed(drone: PatrolDrone) -> void:
	_destroyed_signals += 1
	_check(not drone.alive and drone.health == 0 and drone.patrol_state == PatrolDrone.PatrolState.DESTROYED, "Drone encore actif après HP=0.")
	_check(not drone.is_in_group("hostile_agents") and not drone.is_in_group("patrol_drones"), "Drone mort encore dans un groupe.")
	_check(drone.get_parent().get_node_or_null("Explosion") != null, "Explosion absente après destruction par laser.")
	drone.take_damage(999)


func _test_damage_and_replacement() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(simulation)
	HistoricalFixture.configure(simulation, 1.0)
	simulation.simulation_speed_multiplier = 1.0
	simulation.ship_count = 1
	simulation.streaming_enabled = false
	simulation.manual_difficulty = 1
	root.add_child(simulation)
	var ship: BlueShip = simulation.ships[0]
	ship.position = Vector3.ZERO
	ship.set_physics_process(false)
	var target: PatrolDrone = simulation.drones[0]
	target.position = Vector3(0, 0, -24)
	target.set_physics_process(false)
	_destroyed_signals = 0
	target.destroyed.connect(_on_destroyed)
	target.take_damage(0)
	target.take_damage(-1)
	_check(target.health == 4, "HP initiaux ou dégâts non positifs incorrects.")
	await _advance(2)
	for hit_index: int in range(4):
		ship._update_combat(1.0)
		await _advance(30)
		if hit_index < 3:
			_check(is_instance_valid(target) and target.health == 3 - hit_index, "Le laser ne retire pas exactement un HP.")
	_check(_destroyed_signals == 1 and simulation.enemies_destroyed == 1 and simulation.hostile_hits == 4 and simulation.blue_shots_fired == 4, "Destruction, impacts ou score comptés plusieurs fois.")
	_check(simulation.drone_death_count == 1 and simulation.drones.is_empty() and not is_instance_valid(target) and ship.combat_target == null, "Drone détruit encore référencé.")
	_check(simulation.statistics.text == "Vaisseaux détruits : 0" and simulation.death_count == 0 and simulation.living_agent_count == 1, "Détruire un PatrolDrone modifie le compteur de BlueShip détruits.")
	await _advance(270)
	_check(simulation.drones.is_empty(), "Le drone est remplacé avant le délai de 5 secondes.")
	await _advance(45)
	_check(simulation.drones.size() == 1 and simulation.drone_spawn_count == 2 and simulation.enemies_destroyed == 1, "Le remplacement ne respecte pas le niveau facile ou ajoute un score.")
	print("Dégâts : 4 tirs / 4 impacts, HP 4→0, explosion, signal unique, score +1, références nettoyées, remplacement après 5 s.")
	await _dispose(simulation)


func _test_projectile_collisions() -> void:
	var simulation: SpaceSimulation = _empty_scene(2)
	simulation.ships[1].position = Vector3(0, 0, -10)
	var target: PatrolDrone = _drone(simulation, Vector3(0, 0, -22))
	await _advance(2)
	var projectile: BlueLaser = _laser(simulation, Vector3(0, 0, -2.9))
	await _advance(30)
	_check(not is_instance_valid(projectile) and target.health == 3 and simulation.hostile_hits == 1 and simulation.living_agent_count == 2, "Friendly fire ou projectile qui traverse l'hostile.")
	var asteroid: SpaceAsteroid = _rock(simulation, Vector3(0, 0, -6), 1.3)
	await _advance(2)
	var original_transform: Transform3D = asteroid.global_transform
	projectile = _laser(simulation, Vector3(0, 0, -2.9))
	projectile.projectile_speed = 600.0 # Stress de balayage, pas un paramètre du scénario normal.
	await _advance(3)
	_check(not is_instance_valid(projectile) and is_instance_valid(asteroid) and asteroid.global_transform == original_transform and asteroid.diameter == 1.3, "Le laser traverse ou modifie le rocher indestructible.")
	_check(target.health == 3 and simulation.enemies_destroyed == 0 and simulation.hostile_hits == 1, "Un impact rocher ajoute des dégâts ou un score.")
	projectile = _laser(simulation, Vector3(200, 200, 0))
	projectile.lifetime = 0.1
	await _advance(15)
	_check(not is_instance_valid(projectile) and simulation.projectile_container.get_child_count() == 0, "Un laser expiré reste dans le monde.")
	print("Projectile : BlueShip ignoré, hostile touché, rocher intact et sans score, balayage rapide et durée de vie validés.")
	await _dispose(simulation)


func _test_cooldowns() -> void:
	var simulation: SpaceSimulation = _empty_scene(3)
	var timers: Array[float] = []
	for ship: BlueShip in simulation.ships:
		timers.append(ship._fire_timer)
		_check(ship._personal_cooldown >= 0.595 and ship._personal_cooldown <= 0.805, "Cooldown individuel hors plage.")
		_drone(simulation, ship.position + Vector3.FORWARD * 30.0)
	await _advance(2)
	_check(not is_equal_approx(timers[0], timers[1]) and not is_equal_approx(timers[1], timers[2]), "Les tirs initiaux ne sont pas décalés entre individus.")
	var ship: BlueShip = simulation.ships[0]
	ship._update_combat(1.0)
	ship._update_combat(0.01)
	_check(ship.shots_fired == 1 and ship.combat_state == BlueShip.CombatState.COOLDOWN, "Le cooldown n'espace pas les tirs.")
	ship._update_combat(ship._personal_cooldown)
	_check(ship.shots_fired == 2, "Le tir ne reprend pas après le cooldown.")
	print("Cadence : cooldowns 0,595–0,805 s, offsets individuels déterministes et absence de double tir validés.")
	await _dispose(simulation)


func _navigation_signature(combat: bool) -> Dictionary:
	var simulation: SpaceSimulation = _empty_scene()
	var ship: BlueShip = simulation.ships[0]
	ship.combat_enabled = combat
	# Wander doux dans cette comparaison contrôlée : la cible traverse réellement le cône.
	ship.wander_strength = 0.5
	ship.vertical_wander_strength = 0.5
	ship.set_physics_process(true)
	# HP élevés seulement dans cette fixture, pour comparer les forces avec le même danger.
	var drone: PatrolDrone = _drone(simulation, Vector3(0, 0, -25), 100)
	drone.velocity = Vector3.FORWARD * 9.2
	for _frame: int in range(600):
		drone.move_and_collide(drone.velocity / 60.0)
		await physics_frame
	var result: Dictionary = {"position": ship.global_position, "velocity": ship.velocity, "shots": ship.shots_fired}
	await _dispose(simulation)
	return result


func _test_navigation_independence() -> void:
	var without: Dictionary = await _navigation_signature(false)
	var with_combat: Dictionary = await _navigation_signature(true)
	var first_position: Vector3 = without["position"]
	var second_position: Vector3 = with_combat["position"]
	var first_velocity: Vector3 = without["velocity"]
	var second_velocity: Vector3 = with_combat["velocity"]
	_check(first_position.distance_to(second_position) < 0.0001 and first_velocity.distance_to(second_velocity) < 0.0001, "Le combat modifie la navigation pour viser.")
	_check(int(with_combat["shots"]) > 0, "La fixture de comparaison ne produit aucun tir.")
	print("Indépendance combat/navigation : écart position=%.6f m, tirs=%d." % [first_position.distance_to(second_position), int(with_combat["shots"])])


func _test_drone_counts() -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(simulation)
	HistoricalFixture.configure(simulation, 1.0)
	simulation.simulation_speed_multiplier = 1.0
	simulation.interceptors_enabled = false # Effectifs de l'Agent 2 isolés dans cette fixture.
	simulation.streaming_enabled = false
	simulation.combat_enabled = false
	root.add_child(simulation)
	for ship: BlueShip in simulation.ships:
		ship.set_physics_process(false)
	for level: int in range(1, 4):
		simulation.set_difficulty_mode(level)
		await _advance(2)
		_check(simulation.drones.size() == level and get_nodes_in_group("hostile_agents").size() == level, "Population hostile incorrecte pour le niveau %d." % level)
		for drone: PatrolDrone in simulation.drones:
			drone.set_physics_process(false)
	simulation.drones[0].take_damage(4)
	await _advance(2)
	simulation.set_difficulty_mode(1)
	await _advance(330)
	_check(simulation.drones.size() == 1 and simulation.enemies_destroyed == 1, "Remplacement ou retraite du surplus ignore la difficulté active.")
	print("Population : 1/2/3 hostiles, retrait du surplus sans score, remplacement selon le niveau actif validés.")
	await _dispose(simulation)


func _test_run_90(mode: int) -> void:
	var simulation: SpaceSimulation = MAIN_SCENE.instantiate() as SpaceSimulation
	FlightTuning.legacy_actor(simulation)
	HistoricalFixture.configure(simulation, 1.0)
	simulation.simulation_speed_multiplier = 1.0
	simulation.manual_difficulty = mode
	root.add_child(simulation)
	var nearest_sum: float = 0.0
	var nearest_samples: int = 0
	var minimum_pair: float = INF
	var maximum_dispersion: float = 0.0
	var maximum_nodes: int = get_node_count()
	var isolated_names: Dictionary[String, bool] = {}
	for frame: int in range(5400):
		await physics_frame
		var center: Vector3 = simulation._fleet_center()
		for ship: BlueShip in simulation.ships:
			maximum_dispersion = maxf(maximum_dispersion, ship.global_position.distance_to(center))
			_check(ship.velocity.z < 0.0 and ship.global_position.is_finite(), "Un BlueShip cesse de progresser pendant le combat.")
			var nearest: float = INF
			for other: BlueShip in simulation.ships:
				if other != ship:
					nearest = minf(nearest, ship.global_position.distance_to(other.global_position))
			minimum_pair = minf(minimum_pair, nearest)
			if nearest > ship.neighbor_radius:
				isolated_names[str(ship.name)] = true
			if frame > 60 and frame % 12 == 0 and nearest != INF:
				nearest_sum += nearest
				nearest_samples += 1
		if frame % 30 == 0:
			maximum_nodes = maxi(maximum_nodes, get_node_count())
			_check(simulation.drones.size() <= simulation.target_drone_count() and simulation.asteroid_container.active_asteroid_count <= 72 and simulation.projectile_container.get_child_count() <= 70, "Les objets actifs dépassent les budgets pendant le combat.")
			_check(simulation.living_agent_count + simulation.death_count == 10, "Compteurs BlueShip incohérents.")
	await process_frame
	_check(simulation.living_agent_count > 0 and simulation.asteroid_container.removed_configuration_count > 0, "Le groupe ou le streaming ne reste pas actif.")
	_check(simulation.hostile_hits <= simulation.blue_shots_fired and simulation.enemies_destroyed <= simulation.drone_death_count + simulation.interceptor_death_count, "Compteurs de combat incohérents.")
	_check(get_nodes_in_group("hostile_agents").size() == simulation.drones.size() + simulation.interceptors.size() and simulation.maximum_active_projectiles <= 70 and maximum_nodes < 1800, "Hostiles, projectiles ou nœuds s'accumulent.")
	var hit_rate: float = 100.0 * float(simulation.hostile_hits) / float(maxi(simulation.blue_shots_fired, 1))
	print("M5 %s 90 s : distance=%.2f m, difficulté=%d, BlueShip=%d vivants/%d morts, drones actifs=%d, créés=%d, détruits combat=%d, morts toutes causes=%d, tirs=%d, impacts hostiles=%d, réussite approximative=%.2f %%, astéroïdes max=%d, lasers max=%d, espacement moyen=%.2f m, espacement final=%.2f m, minimum paire=%.2f m, dispersion max=%.2f m, dispersion finale=%.2f m, isolés distincts=%d, nœuds max=%d" % ["AUTO" if mode == 0 else "MANUEL 3", simulation.distance_travelled, simulation.difficulty_level, simulation.living_agent_count, simulation.death_count, simulation.drones.size(), simulation.drone_spawn_count, simulation.enemies_destroyed, simulation.drone_death_count, simulation.blue_shots_fired, simulation.hostile_hits, hit_rate, simulation.asteroid_container.maximum_active_observed, simulation.maximum_active_projectiles, nearest_sum / float(maxi(nearest_samples, 1)), simulation.average_spacing, minimum_pair, maximum_dispersion, simulation.dispersion, isolated_names.size(), maximum_nodes])
	await _dispose(simulation)


func _capture_combat() -> void:
	var simulation: SpaceSimulation = _empty_scene(3)
	var target: PatrolDrone = _drone(simulation, Vector3(0, 0, -25))
	simulation.drones.append(target)
	simulation.set_difficulty_mode(3)
	simulation._measure_group(simulation._fleet_center())
	simulation._update_hud()
	await _advance(2)
	var ship: BlueShip = simulation.ships[0]
	ship._fire_timer = 0.0
	ship._update_combat(0.0)
	simulation.camera.toggle_mode()
	simulation.camera._orbit_center = Vector3(4, 0, -10)
	simulation.camera._orbit_distance = 38.0
	simulation.camera._yaw = 0.35
	simulation.camera._pitch = 0.45
	await _advance(8)
	await RenderingServer.frame_post_draw
	_check(DirAccess.make_dir_recursive_absolute("res://.godot/validation") == OK, "Dossier capture combat impossible.")
	var screenshot: Image = root.get_texture().get_image()
	_check(screenshot.save_png("res://.godot/validation/combat.png") == OK, "Capture combat impossible.")
	print("Capture combat contrôlée : res://.godot/validation/combat.png")
	await _dispose(simulation)
