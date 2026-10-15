extends "res://tests/validate_presentation_demo.gd"

func geometries() -> void:
	for geometry: int in range(7):
		var sim: SpaceSimulation = modern()
		for index: int in range(sim.ships.size()):
			var blue: BlueShip = sim.ships[index]
			blue.position = Vector3((index % 5 - 2) * 12, (index / 5 - 1) * 12, 0)
			blue.adaptive_threat_response = true
			blue.wander_strength = 0
			blue.vertical_wander_strength = 0
			blue.longitudinal_wander_strength = 0
		var gate: MovingLaserGate = MovingLaserGate.new()
		gate.geometry = geometry as MovingLaserGate.GateGeometry
		gate.variant = MovingLaserGate.Variant.ROTATING_LASER_GRID
		gate.width = 100
		gate.height = 80
		gate.angular_speed_degrees = [-18, 0, 15, -25, 0, 18, -15][geometry]
		gate.initial_tilt_degrees = 20
		gate.position = Vector3(0, 0, -160)
		sim.projectile_container.add_child(gate)
		check(gate.beam_segments.size() >= 4 and gate.beam_segments.size() <= 16 and gate.beam_segments.size() % 2 == 0, "Segments géométrie %d" % geometry)
		var internal: int = gate.safe_points.size() - 4
		check(internal >= 3, "Trois ouvertures internes géométrie %d" % geometry)
		for point: Vector3 in gate.safe_points.slice(0, internal):
			var world: Vector3 = gate.global_transform * point
			check(not gate._swept_beam_contact(world - gate.global_basis.z * 5, world + gate.global_basis.z * 5), "Ouverture touche un beam %d" % geometry)
		var mid: Vector3 = gate.global_transform * ((gate.beam_segments[0] + gate.beam_segments[1]) * 0.5)
		check(gate._swept_beam_contact(mid - gate.global_basis.z * 5, mid + gate.global_basis.z * 5), "Collision beam géométrie %d" % geometry)
		gate.set_battle_width(2)
		check(is_equal_approx(gate.beam_width, 3.2), "Épaisseur réelle grille")
		gate.set_battle_width(1)
		await frames(330)
		check(gate.passage_count >= 3 and gate.passage_count + gate.bypass_count >= 8, "Traversée autonome géométrie %d" % geometry)
		var blue_alive: int = sim.ships.size()
		var probe: BlueShip = sim.ships[0]
		probe.set_physics_process(false)
		gate.initial_tilt_degrees += gate.angular_speed_degrees * gate.age
		gate.angular_speed_degrees = 0
		gate.velocity = Vector3.ZERO
		probe.global_position = gate.global_transform * ((gate.beam_segments[0] + gate.beam_segments[1]) * 0.5)
		gate._previous_blues[probe.get_instance_id()] = probe.global_position
		var damage_before: int = gate.damage_events
		gate._physics_process(0.001)
		check(gate.damage_events == damage_before + 1, "Dégâts réels du beam géométrie %d" % geometry)
		records.append({"test": "geometry", "geometry": MovingLaserGate.GateGeometry.keys()[geometry], "beams": gate.beam_segments.size() / 2, "internal_openings": internal, "passed": gate.passage_count, "bypassed": gate.bypass_count, "damage_events": gate.damage_events, "blue_alive": blue_alive, "beam_damage_verified": true, "rotation": gate.angular_speed_degrees})
		await dispose(sim)


func counters_and_respawns() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	for _index: int in range(5):
		sim.presentation.start_or_next()
	# Compteurs/ajouts isolés : les tirs et rochers du scénario ne doivent pas tuer la fixture.
	sim.presentation._events.clear()
	sim.presentation._grid_at = INF
	sim.combat_enabled = false
	sim.streaming_enabled = false
	sim.asteroid_container.storm_enabled = false
	for node: Node in get_nodes_in_group("combat_hazards") + get_nodes_in_group("hostile_projectiles") + get_nodes_in_group("asteroids"):
		sim.demonstration._disable_entity(node)
		node.queue_free()
	for blue: BlueShip in sim.ships:
		blue.combat_enabled = false
		blue.set_physics_process(false)
	for actor: Node3D in sim.drones + sim.interceptors + sim.capitals:
		actor.set_physics_process(false)
	for actor: Node3D in [sim.drones[0], sim.drones[1], sim.interceptors[0], sim.interceptors[1], sim.capitals[0]]:
		actor.take_damage(100)
	check(sim.enemies_destroyed == 5 and sim.statistics.text.contains("Ennemis abattus : 5"), "Compteur cinq kills / HUD")
	check(sim.drones.size() == 13 and sim.interceptors.size() == 13 and sim.capitals.size() == 5, "Population après cinq kills")
	while sim.presentation.phase_elapsed < 4.2:
		await process_frame
	check(sim.drones.size() == 15 and sim.interceptors.size() == 15 and sim.capitals.size() == 6 and sim.enemies_destroyed == 5, "Respawn / compteur stable")
	for event: Dictionary in sim.presentation.respawn_events:
		check(float(event.delay) >= (2.0 if event.family == "capital" else 0.8) and float(event.delay) <= (4.1 if event.family == "capital" else 1.5), "Délai réel de respawn")
	for family: String in ["patrol", "interceptor", "capital"]:
		sim.presentation.set_setting(family, 0)
	await frames(2)
	check(sim.enemies_destroyed == 5 and sim.drones.is_empty() and sim.interceptors.is_empty() and sim.capitals.is_empty(), "Retraits administratifs / faux kills")
	sim.presentation.reset_battle()
	check(sim.enemies_destroyed == 5, "RESET du labo efface les kills")
	var end: float = sim.presentation.phase_elapsed + 4
	while sim.presentation.phase_elapsed < end:
		await process_frame
	check(sim.drones.size() == 15 and sim.interceptors.size() == 15 and sim.capitals.size() == 6, "Ajouts progressifs")
	sim.presentation.start_or_next()
	check(sim.presentation.state == PresentationDemonstration.State.FINAL_SANDBOX and not paused, "Sandbox final actif")
	sim.presentation.set_setting("fire", 3)
	sim.presentation.set_setting("width", 2)
	sim.presentation.set_setting("grid_width", 2)
	sim.presentation.set_setting("speed", 1.5)
	sim.presentation.set_setting("damage", 2)
	sim.presentation.set_setting("aggression", 2)
	check(sim.interceptors[0].fire_intensity == 3 and sim.interceptors[0].target_detection_radius == 220, "Cadence / agressivité distinctes")
	var shot: EnemyLaser = load("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
	shot.patrol_pulse = true
	sim.projectile_container.add_child(shot)
	sim.presentation.configure_projectile(shot)
	check(shot.battle_radius > 1 and shot.damage == 2 and shot.projectile_speed == 127.5 and is_equal_approx(shot.avoidance_radius, shot.battle_radius + 1.4), "Volume / vitesse / dégâts pulse")
	var shell: ArtilleryProjectile = ArtilleryProjectile.new()
	shell.arcade_signature = true
	sim.projectile_container.add_child(shell)
	sim.presentation.configure_projectile(shell)
	check((shell._shape as CapsuleShape3D).radius == 2.5 and shell.avoidance_radius == 20, "Collision / perception Heavy")
	sim.interceptors.reverse()
	sim.presentation.set_setting("interceptor", 5)
	await frames(2)
	check(sim.interceptors.all(func(actor: Interceptor) -> bool: return int(actor.get_meta("presentation_slot")) < 5), "Réduction après remplacements : mauvais slots conservés")
	var before: int = sim.enemies_destroyed
	sim.presentation.prepare()
	check(sim.enemies_destroyed == 0 and sim.death_count == 0 and before == 5, "R remet deux compteurs à zéro")
	sim.presentation.leave()
	await frames(3)
	check(not is_instance_valid(sim.demo_controls.battle_panel) and sim.statistics.text.count("\n") == 0, "Retour FREE / UI restaurée")
	records.append({"test": "counters_respawns", "combat_kills": 5, "respawns": {"patrol": 2, "interceptor": 2, "capital": 1}, "administrative_kills": 0, "reset_counters": true, "runtime_physical_parameters": true})
	await dispose(sim)


func capital_combat() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	for _index: int in range(5):
		sim.presentation.start_or_next()
	sim.presentation._events.clear()
	sim.presentation._grid_at = INF # Fixture de fenêtre de combat isolée, sans scheduler de grilles.
	sim.presentation.set_setting("patrol", 0)
	sim.presentation.set_setting("interceptor", 0)
	sim.presentation.set_setting("capital", 1)
	sim.presentation.set_setting("density", 0)
	sim.presentation.set_setting("mega", 0)
	await frames(4)
	for node: Node in get_nodes_in_group("combat_hazards") + get_nodes_in_group("hostile_projectiles") + get_nodes_in_group("asteroids"):
		sim.demonstration._disable_entity(node)
		node.queue_free()
	var capital: CapitalShip = sim.capitals[0]
	capital._pending.clear()
	capital.state = CapitalShip.State.OBSERVE
	capital.combat_enabled = false
	capital.begin_presentation_raid(6, 70)
	var before_hits: int = sim.hostile_hits
	var end: float = sim.presentation.phase_elapsed + 10
	while sim.presentation.phase_elapsed < end and sim.enemies_destroyed == 0:
		await process_frame
	check(sim.hostile_hits > before_hits and sim.enemies_destroyed >= 1, "BlueLaser ne peut pas abattre un Capital vulnérable")
	records.append({"test": "capital_combat_opportunity", "blue_shots": sim.blue_shots_fired, "hostile_hits": sim.hostile_hits - before_hits, "capital_kills": sim.capitals_destroyed, "nominal_health": 24})
	sim.presentation.leave()
	await dispose(sim)


func physical_width() -> void:
	for width: float in [1.0, 2.0]:
		var sim: SpaceSimulation = modern(1)
		var blue: BlueShip = sim.ships[0]
		blue.position = Vector3.ZERO
		blue.set_physics_process(false)
		var hostile: PatrolDrone = SpaceSimulation.DRONE_SCENE.instantiate() as PatrolDrone
		hostile.position = Vector3(2.8, 0, -5)
		sim.drone_container.add_child(hostile)
		hostile.set_physics_process(false)
		await frames(2)
		var health_before: int = blue.health
		var shot: EnemyLaser = load("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
		shot.patrol_pulse = true
		shot.flight_direction = Vector3.BACK
		shot.position = Vector3(2.8, 0, -10)
		sim.projectile_container.add_child(shot)
		shot.set_battle_parameters(width, 1, 1)
		await frames(20)
		print("WIDTH TEST %s health=%s -> %s" % [width, health_before, blue.health])
		check((blue.health < health_before) == (width == 2), "Largeur physique pulse sans simple changement visuel")
		check(hostile.health == hostile.max_health, "Friendly fire ennemi")
		var shell: ArtilleryProjectile = ArtilleryProjectile.new()
		shell.arcade_signature = true
		sim.projectile_container.add_child(shell)
		shell.set_battle_parameters(2, 1, 1)
		shell._update_visual()
		check(shell.get_node("Visual").scale.is_equal_approx(Vector3(2, 2, 1)), "Largeur visuelle Heavy perdue pendant son animation")
		await dispose(sim)
	records.append({"test": "physical_width", "narrow_misses": true, "wide_hits": true, "friendly_fire": false, "animated_visual_scale": true})


func single_hull_equivalence() -> void:
	var sim: SpaceSimulation = modern(1)
	var clouds: Array[PackedVector3Array] = []
	for compact: bool in [false, true]:
		var rock: SpaceAsteroid = load("res://scenes/asteroid.tscn").instantiate() as SpaceAsteroid
		rock.diameter = 96
		rock.size_category = SpaceAsteroid.SizeCategory.COLOSSAL
		rock.shape_seed = 20261012
		rock.single_convex_envelope = true
		rock.presentation_skip_unused_shapes = compact
		rock.position.z = -1000
		sim.asteroid_container.add_child(rock)
		for child: Node in rock.get_children():
			if child is CollisionShape3D:
				clouds.append(((child as CollisionShape3D).shape as ConvexPolygonShape3D).points)
	check(clouds.size() == 2 and clouds[1].size() == clouds[0].size(), "Enveloppe différente après suppression des calculs intermédiaires")
	if clouds.size() == 2:
		for x: float in [-1, -0.5, 0, 0.5, 1]:
			for y: float in [-1, -0.5, 0, 0.5, 1]:
				for z: float in [-1, -0.5, 0, 0.5, 1]:
					var direction: Vector3 = Vector3(x, y, z)
					var first: float = -INF
					var second: float = -INF
					for point: Vector3 in clouds[0]:
						first = maxf(first, point.dot(direction))
					for point: Vector3 in clouds[1]:
						second = maxf(second, point.dot(direction))
					check(absf(first - second) < 0.001, "Enveloppe collision modifiée")
		records.append({"test": "convex_equivalence", "before_points": clouds[0].size(), "after_points": clouds[1].size(), "support_directions_verified": 125})
	await dispose(sim)


func _run() -> void:
	await presentation_controls()
	await counters_and_respawns()
	await geometries()
	await capital_combat()
	await physical_width()
	await single_hull_equivalence()
	var file: FileAccess = FileAccess.open("res://.godot/battle_components.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS BATTLE : commandes, compteurs, respawns et sept géométries." if failures == 0 else "FAIL BATTLE")
	quit(0 if failures == 0 else 1)
