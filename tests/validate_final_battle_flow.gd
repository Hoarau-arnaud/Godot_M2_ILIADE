extends "res://tests/validate_battle_lab.gd"

class LaserTarget extends StaticBody3D:
	var alive: bool = true
	var health: int = 10
	func take_damage(amount: int) -> void:
		health -= amount


func click_button(button: Button) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true) # Coordonnées du viewport, indépendantes du scaling de fenêtre.
	await process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	event.button_mask = 0
	root.push_input(event, true)
	await process_frame


func startup_and_jump() -> void:
	var original_msaa: Viewport.MSAA = root.msaa_3d
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	var free_physics: int = Engine.physics_ticks_per_second
	await frames(6)
	check(sim.presentation.state == PresentationDemonstration.State.READY and paused, "Play ne démarre pas sur READY")
	check(not sim.demonstration.is_guided() and sim.demo_controls.presentation_final.visible, "Ancienne démo ou bouton finale absent")
	check(Engine.physics_ticks_per_second == 90 and root.msaa_3d == Viewport.MSAA_2X, "Réglages performance Presentation")
	check(sim.demo_controls.presentation_title.text == "DÉMO SOUTENANCE", "Titre au Play")
	var started: int = Time.get_ticks_usec()
	await click_button(sim.demo_controls.presentation_final)
	check(sim.presentation.phase_index == 4 and sim.presentation.phase_elapsed < 0.1 and sim.demo_controls.battle_panel.visible and not paused, "Jump READY / Battle Lab immédiat")
	check(sim.demo_controls.battle_panel.get("sliders").size() == 11, "Onze réglages Battle Lab")
	if [sim.drones.size(), sim.interceptors.size(), sim.capitals.size()] != [15, 15, 6]:
		print("JUMP POP ",[sim.drones.size(), sim.interceptors.size(), sim.capitals.size()], " stats ",sim.presentation._family_stats)
	check([sim.drones.size(), sim.interceptors.size(), sim.capitals.size()] == [15, 15, 6], "Jump populations")
	check(sim.enemies_destroyed == 0 and sim.death_count == 0, "Jump READY faux compteurs")
	check(Time.get_ticks_usec() - started < 2000000, "Jump >2 secondes")
	sim.presentation.prepare()
	sim.presentation.start_or_next()
	sim.presentation.start_or_next()
	check(sim.demo_controls.final_shortcut.visible, "Bouton finale P1–P4 absent")
	sim.drones[0].take_damage(100)
	var kills: int = sim.enemies_destroyed
	sim.demo_controls.final_shortcut.pressed.emit()
	check(sim.enemies_destroyed == kills and kills == 1, "Nettoyage jump crée/efface des kills")
	check(get_nodes_in_group("combat_hazards").is_empty() and get_nodes_in_group("hostile_projectiles").is_empty(), "Jump hazards résiduels")
	sim.presentation.leave()
	check(root.msaa_3d == original_msaa and Engine.physics_ticks_per_second == free_physics, "Réglages libres non restaurés")
	await frames(2)
	presentation_key(KEY_F1)
	await frames(2)
	check(not sim.demonstration.is_guided(), "Ancienne démo encore exposée par F1")
	presentation_key(KEY_F8)
	await frames(2)
	check(sim.presentation.phase_index == 4 and sim.presentation.state == PresentationDemonstration.State.RUNNING, "F8")
	sim.presentation.leave()
	await dispose(sim)
	records.append({"test": "startup_jump", "startup_ready": true, "jump_ready_under_2s": true, "jump_preserves_real_kills": true, "F8": true, "guided_internal": true})


func administrative_recycling() -> void:
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	sim.presentation.jump_to_final()
	var kills: int = sim.enemies_destroyed
	var deaths: Dictionary = sim.presentation.total_respawns.duplicate()
	for family: String in ["patrol", "interceptor"]:
		var actor: PatrolDrone = sim.presentation._actors(family)[0]
		actor.global_position = sim._fleet_center() + Vector3(2000, 0, 0)
		var id: int = actor.get_instance_id()
		actor.set_meta("battle_outside", 3.1)
		sim.presentation._update_battle_zone(0.1)
		check(sim.presentation._actors(family).all(func(item: Node) -> bool: return item.get_instance_id() != id), "Recyclage administratif " + family)
		check(sim.presentation.administrative_recycles[family] == 1, "Compteur recyclage " + family)
	var outgoing: EnemyLaser = load("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
	var incoming: EnemyLaser = load("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
	sim.projectile_container.add_child(outgoing)
	sim.projectile_container.add_child(incoming)
	outgoing.position = sim._fleet_center() + Vector3(0, 0, 300)
	incoming.position = sim._fleet_center() + Vector3(0, 0, -300)
	outgoing.flight_direction = Vector3.BACK
	incoming.flight_direction = Vector3.BACK
	sim.presentation._cleanup_battle_projectiles()
	check(outgoing.is_queued_for_deletion() and not incoming.is_queued_for_deletion(), "Nettoyage conserve les tirs entrants")
	check(sim.enemies_destroyed == kills and sim.presentation.total_respawns == deaths, "Recyclage faux kill/respawn de mort")
	sim.presentation.leave()
	await dispose(sim)
	records.append({"test": "administrative_recycling", "patrol": true, "interceptor": true, "kills": 0, "death_respawns": 0, "offscreen_only": true})


func blue_width() -> void:
	for case: String in ["inside", "outside", "asteroid", "friendly"]:
		var sim: SpaceSimulation = modern(1)
		sim.ships[0].set_physics_process(false)
		sim.ships[0].position = Vector3(0, 0, -2)
		var target: LaserTarget = LaserTarget.new()
		target.collision_layer = 4
		target.collision_mask = 0
		target.add_to_group("hostile_agents")
		var shape: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.5
		shape.shape = sphere
		target.add_child(shape)
		sim.add_child(target)
		target.position = Vector3(1.0 if case == "inside" else 1.4 if case == "outside" else 0.0, 0, -10)
		if case == "asteroid":
			var blocker: StaticBody3D = StaticBody3D.new()
			blocker.collision_layer = 2
			var block_shape: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(8, 8, 1)
			block_shape.shape = box
			blocker.add_child(block_shape)
			sim.add_child(blocker)
			blocker.position.z = -5
		await frames(2)
		var health: int = sim.ships[0].health
		var ray: Dictionary = sim.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0, 0, -30), 4))
		if case in ["inside", "outside"]:
			check(ray.is_empty(), "Fixture ancien rayon devrait rater")
		var shot: BlueLaser = load("res://scenes/blue_laser.tscn").instantiate() as BlueLaser
		shot.projectile_speed = 3000 # Traverse toute la fixture en un seul tick.
		sim.projectile_container.add_child(shot)
		await frames(5)
		check((target.health == 9) == (case in ["inside", "friendly"]), "Swept Blue " + case)
		check(sim.ships[0].health == health, "Friendly fire Blue")
		await dispose(sim)
	for pulse: bool in [false, true]:
		var sim: SpaceSimulation = modern(1)
		for width: float in [1.0, 2.0]:
			var shot: EnemyLaser = load("res://scenes/enemy_laser.tscn").instantiate() as EnemyLaser
			shot.patrol_pulse = pulse
			sim.projectile_container.add_child(shot)
			shot.set_battle_parameters(width, 1, 1)
			var base: float = 1.5 if pulse else 1.75
			check(is_equal_approx(shot.battle_radius, (0.65 if pulse else 0.22) * base * width), "Nouvelle hitbox rouge/verte")
			check(shot.scale.is_equal_approx(Vector3(base * width, base * width, 1)), "Nouvelle largeur visuelle")
			check(is_equal_approx(shot.avoidance_radius, shot.battle_radius + 1.4), "Nouvelle perception")
		await dispose(sim)
	records.append({"test": "laser_width", "blue_old_ray_misses_new_sphere_hits": true, "outside_misses": true, "asteroid_blocks": true, "no_friendly_fire": true, "high_speed_no_tunneling": true, "blue_hit_radius": 0.7, "red_base": 1.75, "green_base": 1.5, "slider_doubles_all": true})


func battle_measure(sim: SpaceSimulation, duration: float, label: String, native: bool) -> Dictionary:
	var data: Dictionary = {"test": label, "distances": {"patrol": [], "interceptor": []}, "near": {"patrol": 0, "interceptor": 0}, "samples": {"patrol": 0, "interceptor": 0}, "majority_near_samples": {"patrol": 0, "interceptor": 0}, "distance_frames": 0, "actors": {"patrol": {}, "interceptor": {}}, "grid_types": {"Gate": 0, "Grid": 0}, "geometries": {}, "grids_max": 0, "nodes_max": 0, "hostile_projectiles_max": 0, "combat_hazards_max": 0, "dangerous_max": 0, "fps_windows": [], "target_seeds": {}}
	var watched: Dictionary = {}
	var frames_count: int = 0
	var window_count: int = 0
	var start_clock: float = sim.presentation.phase_elapsed
	var start: int = Time.get_ticks_usec()
	var window_start: int = start
	var sample_at: float = 0
	while sim.presentation.phase_elapsed - start_clock < duration:
		await process_frame
		frames_count += 1
		window_count += 1
		var now: int = Time.get_ticks_usec()
		if now - window_start >= 1000000:
			data.fps_windows.append(float(window_count) * 1000000 / (now - window_start))
			window_count = 0
			window_start = now
		var grids: int = 0
		for node: Node in get_nodes_in_group("combat_hazards"):
			if node is MovingLaserGate:
				grids += 1
				var id: int = node.get_instance_id()
				if not watched.has(id):
					watched[id] = true
					var family: String = "Gate" if node.variant == 0 else "Grid"
					data.grid_types[family] += 1
					data.geometries[MovingLaserGate.GateGeometry.keys()[node.geometry]] = true
					node.ship_passed.connect(func(_blue: BlueShip) -> void: data["passed"] = int(data.get("passed", 0)) + 1)
					node.ship_bypassed.connect(func(_blue: BlueShip) -> void: data["bypassed"] = int(data.get("bypassed", 0)) + 1)
		data.grids_max = maxi(data.grids_max, grids)
		data.nodes_max = maxi(data.nodes_max, get_node_count())
		data.hostile_projectiles_max = maxi(data.hostile_projectiles_max, get_nodes_in_group("hostile_projectiles").size())
		data.combat_hazards_max = maxi(data.combat_hazards_max, get_nodes_in_group("combat_hazards").size())
		data.dangerous_max = maxi(data.dangerous_max, ArtilleryZone.dangerous_count(self))
		var relative_time: float = sim.presentation.phase_elapsed - start_clock
		var center: Vector3 = sim._fleet_center()
		for family: String in ["patrol", "interceptor"]:
			for actor: PatrolDrone in sim.presentation._actors(family):
				var id: int = actor.get_instance_id()
				if not data.actors[family].has(id):
					data.actors[family][id] = {"slot": actor.get_meta("presentation_slot"), "spawn": relative_time, "spawn_distance": actor.global_position.distance_to(center), "pursuit": -1.0, "shot": -1.0, "disengage": false}
				var entry: Dictionary = data.actors[family][id]
				if (actor.shots_fired if actor is Interceptor else actor.patrol_shots_fired) > 0 and float(entry.shot) < 0:
					entry.shot = relative_time - float(entry.spawn)
				if actor is Interceptor:
					if actor.pursuits_started > 0 and float(entry.pursuit) < 0:
						entry.pursuit = relative_time - float(entry.spawn)
					entry.disengage = entry.disengage or actor.disengagements > 0
					if is_instance_valid(actor.target):
						data.target_seeds[actor.target.individual_seed] = true
		if relative_time >= sample_at:
			data.distance_frames += 1
			for family: String in ["patrol", "interceptor"]:
				var close_count: int = 0
				var population: Array = sim.presentation._actors(family)
				for actor: Node3D in population:
					var distance: float = actor.global_position.distance_to(center)
					data.distances[family].append(distance)
					data.samples[family] += 1
					if distance < 100:
						data.near[family] += 1
						close_count += 1
				if close_count >= population.size() * 0.8:
					data.majority_near_samples[family] += 1
			sample_at = relative_time + 0.1
	var elapsed: float = float(Time.get_ticks_usec() - start) / 1000000
	data.fps_mean = frames_count / elapsed
	data.fps_min_1s = data.fps_windows.min() if not data.fps_windows.is_empty() else 0
	data.wall_seconds = elapsed
	data.duration = sim.presentation.phase_elapsed - start_clock
	data.window_pixels = DisplayServer.window_get_size() if native else Vector2i.ZERO
	data.render_pixels = root.get_texture().get_size() if native else Vector2i.ZERO
	data.msaa_3d = root.msaa_3d
	data.physics_rate = Engine.physics_ticks_per_second
	for family: String in ["patrol", "interceptor"]:
		var distances: Array = data.distances[family]
		distances.sort()
		var sum: float = 0
		for distance: float in distances:
			sum += distance
		data[family + "_distance_mean"] = sum / maxf(distances.size(), 1)
		data[family + "_distance_median"] = distances[distances.size() / 2] if not distances.is_empty() else 0
		data[family + "_distance_max"] = distances.back() if not distances.is_empty() else 0
		data[family + "_near_percent"] = 100.0 * int(data.near[family]) / maxf(data.samples[family], 1)
		data[family + "_majority_time_percent"] = 100.0 * int(data.majority_near_samples[family]) / maxf(data.distance_frames, 1)
		for behavior: String in ["shot", "pursuit", "disengage"]:
			var slots: Dictionary = {}
			for entry: Dictionary in data.actors[family].values():
				if (bool(entry.disengage) if behavior == "disengage" else float(entry[behavior]) >= 0):
					slots[int(entry.slot)] = true
			data[family + "_" + behavior + "_slots"] = slots.size()
	for family: String in ["patrol", "interceptor"]:
		var initial: Dictionary = {}
		for entry: Dictionary in data.actors[family].values():
			var slot: int = int(entry.slot)
			if not initial.has(slot) or float(entry.spawn) < float(initial[slot].spawn):
				initial[slot] = entry
		for behavior: String in ["shot", "pursuit", "disengage"]:
			var count: int = 0
			for entry: Dictionary in initial.values():
				if (bool(entry.disengage) if behavior == "disengage" else float(entry[behavior]) >= 0):
					count += 1
			data[family + "_initial_" + behavior] = count
	data.erase("distances")
	data.recycles = sim.presentation.administrative_recycles.duplicate()
	data.kills = sim.enemies_destroyed
	data.deaths = sim.death_count
	records.append(data)
	print("MEASURE ", JSON.stringify(data))
	return data


func measured_battles(native: bool) -> void:
	if native:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = Vector2i(1920, 1080)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	var sim: SpaceSimulation = modern()
	sim.presentation.prepare()
	var warmup: int = Time.get_ticks_usec()
	while native and Time.get_ticks_usec() - warmup < 2000000:
		await process_frame
	if native:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		await frames(4)
	sim.presentation.state = PresentationDemonstration.State.RUNNING
	sim.presentation._begin_phase(3)
	sim.presentation._apply_pause()
	var p4: Dictionary = await battle_measure(sim, 30, "P4", native)
	check(p4.grid_types.Gate + p4.grid_types.Grid >= 17, "P4 pas 18 grilles réelles")
	# La transition automatique vers P5 a déjà préparé les nouveaux agents ; reprendre à t=0.
	sim.presentation.jump_to_final()
	var p5: Dictionary = await battle_measure(sim, 30, "P5", native)
	check(p5.grid_types.Gate + p5.grid_types.Grid >= 17, "P5 pas 18 grilles réelles")
	check(p5.patrol_initial_shot >= 12, "Moins de 12/15 Patrol tirent")
	check(p5.interceptor_initial_pursuit >= 12 and p5.interceptor_initial_shot >= 12, "Moins de 12/15 Interceptor engagent")
	check(p5.patrol_near_percent >= 80 and p5.interceptor_near_percent >= 80, "Combat final trop loin")
	check(p5.patrol_majority_time_percent > 50 and p5.interceptor_majority_time_percent > 50, "80% proches pendant la majorité de P5")
	check(p5.target_seeds.size() >= 3, "Cibles finales non réparties")
	if sim.presentation.state != PresentationDemonstration.State.FINAL_SANDBOX:
		sim.presentation.start_or_next()
	var before: int = sim.enemies_destroyed
	sim.presentation.set_setting("patrol", 25)
	var patrol_added: Dictionary = await battle_measure(sim, 5, "slider_patrol", native)
	sim.presentation.set_setting("interceptor", 25)
	var interceptor_added: Dictionary = await battle_measure(sim, 6, "slider_interceptor", native)
	for family: String in ["patrol", "interceptor"]:
		var result: Dictionary = patrol_added if family == "patrol" else interceptor_added
		var additions: Array = []
		var added_slots: Dictionary = {}
		for entry: Dictionary in result.actors[family].values():
			if int(entry.slot) >= 15 and not added_slots.has(int(entry.slot)):
				added_slots[int(entry.slot)] = true
				additions.append(entry)
		check(additions.size() >= 10, "Slider dix nouveaux " + family)
		for entry: Dictionary in additions:
			check(float(entry.spawn_distance) < 110, "Spawn slider trop loin " + family)
			if family == "interceptor":
				check(float(entry.pursuit) >= 0 and float(entry.pursuit) < 2, "Acquisition slider >2s")
				check(float(entry.shot) >= 0 and float(entry.shot) < 4, "Première rafale slider >4s")
	check(sim.enemies_destroyed >= before, "Slider remet le score à zéro")
	sim.presentation.reset_battle(true)
	var chaos: Dictionary = await battle_measure(sim, 30, "CHAOS", native)
	for record: Dictionary in [p4, p5, chaos]:
		check(record.grids_max <= 4 and record.dangerous_max <= 48, "Budget nouvelles grilles")
		if native:
			check(record.fps_min_1s > 60, "FPS " + str(record.test) + " sous 60")
	sim.presentation.finish_battle()
	sim.presentation.leave()
	await dispose(sim)


func capture_flow() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/validation")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1920,1080)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	var sim: SpaceSimulation = MAIN.instantiate() as SpaceSimulation
	root.add_child(sim)
	await frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/final_flow_ready.png")
	sim.demo_controls.presentation_final.pressed.emit()
	while sim.presentation.phase_elapsed < 1:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/final_flow_jump.png")
	while sim.presentation.phase_elapsed < 6:
		await process_frame
	sim.presentation.toggle_pause()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/final_flow_battle.png")
	sim.presentation.leave()
	await dispose(sim)


func _run() -> void:
	var native: bool = OS.get_cmdline_user_args().has("--native")
	if OS.get_cmdline_user_args().has("--capture"):
		await capture_flow()
		quit(0 if failures == 0 else 1)
		return
	if not native:
		await startup_and_jump()
		await blue_width()
		await administrative_recycling()
	if not OS.get_cmdline_user_args().has("--unit"):
		await measured_battles(native)
	var file: FileAccess = FileAccess.open("res://.godot/final_battle_flow_" + ("native" if native else "headless") + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("PASS FINAL FLOW" if failures == 0 else "FAIL FINAL FLOW")
	quit(0 if failures == 0 else 1)
