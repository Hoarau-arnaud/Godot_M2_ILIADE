class_name PresentationDemonstration
extends Node

# Une horloge et des rendez-vous de scène ; aucun ordre de navigation aux agents.
enum State { INACTIVE, READY, RUNNING, TRANSITION, FINISHED, FINAL_SANDBOX }
const BATTLE_VISUAL_CACHE: Script = preload("res://scripts/battle_visual_cache.gd")
const DURATIONS: Array[float] = [30.0, 30.0, 30.0, 30.0, 30.0]
const TITLES: Array[String] = ["ÉVITEMENT COLLECTIF", "PATROUILLE AUTONOME", "INTERCEPTION", "ARTILLERIE CAPITALE", "ASSAUT FINAL"]
const GUIDED_PHASES: Array[int] = [0, 2, 3, 4, 5]
const TRANSITION_SECONDS: float = 0.5
@export var presentation_seed: int = 20261012
var state: State = State.INACTIVE
var phase_index: int = -1
var phase_elapsed: float = 0
var elapsed_real: float = 0
var user_paused: bool = false
var records: Array[Dictionary] = []
var _transition_elapsed: float = 0
var _events: Array[Array] = []
var _cursor: int = 0
var _sample: Dictionary = {}
var _camera_segment: int = -1
var _guide_seed: int = 0
const DEFAULT_SETTINGS: Dictionary = {"patrol": 15, "interceptor": 15, "capital": 6, "fire": 2.0, "width": 1.0, "grid_width": 1.0, "speed": 1.0, "damage": 1, "density": 1.0, "mega": 1, "aggression": 1.0}
const CHAOS_SETTINGS: Dictionary = {"patrol": 25, "interceptor": 25, "capital": 8, "fire": 3.0, "width": 1.7, "grid_width": 1.8, "speed": 1.3, "damage": 2, "density": 1.6, "mega": 3, "aggression": 2.0}
const LIMITS: Dictionary = {"patrol": [0, 30], "interceptor": [0, 30], "capital": [0, 10], "fire": [0.5, 4.0], "width": [0.5, 3.0], "grid_width": [0.5, 3.0], "speed": [0.5, 2.0], "damage": [1, 3], "density": [0.0, 2.5], "mega": [0, 3], "aggression": [0.5, 3.0]}
const FAMILIES: Array[String] = ["patrol", "interceptor", "capital"]
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var automatic_duration: float = 0
var sandbox_elapsed: float = 0
var total_respawns: Dictionary = {"patrol": 0, "interceptor": 0, "capital": 0}
var respawn_events: Array[Dictionary] = []
var _population_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending_respawns: Array[Dictionary] = []
var _generation: int = 0
var _spawn_serial: int = 0
var _family_stats: Dictionary = {}
var _addition_at: Dictionary = {}
var _lab_attack_at: float = 1
var _lab_attack_cursor: int = 0
var _mega_at: float = 5
var _colossal_at: float = 10
var _raid_at: float = 8
var _raid_cursor: int = 0
var _gate_cursor: int = 0
@onready var simulation: SpaceSimulation = get_parent() as SpaceSimulation
@onready var guide: GuidedDemonstration = get_parent().get_node("GuidedDemonstration") as GuidedDemonstration


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -9
	guide.mode_changed.connect(_mode_changed)


func active() -> bool:
	return state != State.INACTIVE


func _profile(index: int) -> Dictionary:
	return {"storm": index in [0, 4], "rocks": 38 if index == 4 else 0, "rocks_max": 80 if index == 4 else 35, "patrols": 15 if index in [1, 4] else 0, "interceptors": 15 if index in [2, 4] else 0, "capitals": 6 if index in [3, 4] else 0, "fire_intensity": 1.0 if index == 1 else 2.0, "blue_combat": index > 0}


func prepare() -> void:
	if guide.is_staged():
		guide.stop()
	simulation.demo_controls.ensure_battle_panel()
	_guide_seed = guide.demonstration_seed
	guide.demonstration_seed = presentation_seed
	state = State.READY
	user_paused = false
	elapsed_real = 0
	phase_elapsed = 0
	phase_index = 0
	records.clear()
	settings = DEFAULT_SETTINGS.duplicate()
	automatic_duration = 0
	sandbox_elapsed = 0
	_spawn_serial = 0
	_generation += 1
	total_respawns = {"patrol": 0, "interceptor": 0, "capital": 0}
	_pending_respawns.clear()
	respawn_events.clear()
	_reset_population_stats()
	guide.start(_profile(0))
	simulation.space_decor.set_presentation_detail(true)
	for blue: BlueShip in simulation.ships:
		pack_actor(blue, "blue")
	simulation.camera.presentation_shots = true
	simulation.demo_controls.set_phase(-1, "")
	simulation.demo_controls.show_presentation(State.READY)
	_apply_pause()
	_warm_visuals.call_deferred()


func start_or_next() -> void:
	if state == State.READY:
		state = State.RUNNING
		simulation.demo_controls.show_presentation(State.RUNNING)
		_begin_phase(0, false)
		_apply_pause()
	elif state == State.RUNNING:
		_finish_phase(true)
		if phase_index == 4:
			_enter_sandbox()
		else:
			# Le raccourci passe immédiatement ; seules les transitions automatiques attendent.
			_begin_phase(phase_index + 1)
			_apply_pause()
	elif state == State.FINAL_SANDBOX:
		_finish()


func toggle_pause() -> void:
	if state in [State.RUNNING, State.TRANSITION, State.FINAL_SANDBOX]:
		user_paused = not user_paused
		_apply_pause()


func _apply_pause() -> void:
	get_tree().paused = user_paused or state in [State.READY, State.TRANSITION, State.FINISHED]
	simulation.demo_controls.pause_label.visible = user_paused


func leave() -> void:
	guide.stop()


func _mode_changed(new_mode: int) -> void:
	if new_mode == GuidedDemonstration.DemoMode.PRESENTATION:
		return
	if active():
		guide.demonstration_seed = _guide_seed
		simulation.space_decor.set_presentation_detail(false)
		simulation.demo_controls.release_battle_panel()
		_pending_respawns.clear()
		_generation += 1
		state = State.INACTIVE
		user_paused = false
		simulation.demo_controls.show_presentation(State.INACTIVE)


func guided_phase(index: int) -> void:
	var keep_pause: bool = user_paused if active() else get_tree().paused
	if active():
		leave()
	guide.jump_to_phase(index)
	simulation.set_presentation_paused(keep_pause)


func _begin_phase(index: int, rebuild: bool = true) -> void:
	phase_index = index
	phase_elapsed = 0
	_camera_segment = -1
	_cursor = 0
	_generation += 1
	_pending_respawns.clear()
	_population_random.seed = presentation_seed + index * 1709 + 54001
	settings = DEFAULT_SETTINGS.duplicate()
	_reset_population_stats()
	_gate_cursor = 0
	_raid_at = 8
	_raid_cursor = 0
	_lab_attack_at = 1
	_lab_attack_cursor = 0
	_mega_at = 16
	_colossal_at = 24
	if rebuild:
		guide._begin_phase(GUIDED_PHASES[index], simulation._fleet_center(), true, _profile(index))
	guide.phase_elapsed = 0
	_sample = {"phase": index + 1, "title": TITLES[index], "first_events": {}, "boosts_start": simulation.evasive_boost_count, "dispersion_peak": simulation.dispersion, "dispersion_end": simulation.dispersion, "gate_crossings": {}, "events": []}
	match index:
		0: _events = [[0.0, "mega", 1], [8.0, "colossal", 0], [18.0, "fast", 0], [23.0, "fast", 0]]
		1: _events = []
		2: _events = []
		3: _events = [[0.0, "capital", 0], [2.0, "capital", 7], [4.0, "capital", 4], [6.0, "capital", 8], [10.0, "capital", 7], [12.0, "capital", 6], [14.0, "capital", 8], [18.0, "capital", 7], [20.0, "capital", 9], [22.0, "capital", 8], [26.0, "capital", 2]]
		4: _events = [[0.0, "mega", 1], [0.0, "capital", 0], [2.0, "capital", 7], [4.0, "capital", 4], [6.0, "capital", 8], [8.0, "colossal", 0], [10.0, "capital", 7], [12.0, "capital", 6], [14.0, "capital", 8], [18.0, "capital", 7], [20.0, "capital", 9], [22.0, "capital", 8], [26.0, "capital", 2]]
	simulation.camera.presentation_shots = true
	simulation.demo_controls.set_phase(index, TITLES[index], 3.0)
	_apply_settings()
	simulation.demo_controls.battle_panel.visible = index == 4
	_choreograph()


func _process(delta: float) -> void:
	if not active() or user_paused or state in [State.READY, State.FINISHED]:
		return
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	elapsed_real += real_delta
	guide.elapsed_real = elapsed_real
	if state == State.TRANSITION:
		_transition_elapsed += real_delta
		if _transition_elapsed >= TRANSITION_SECONDS:
			state = State.RUNNING
			_begin_phase(phase_index + 1)
			_apply_pause()
		return
	phase_elapsed += real_delta
	guide.phase_elapsed = phase_elapsed
	_choreograph()
	_maintain_populations()
	_update_raids(real_delta)
	if phase_index == 4:
		_boulders()
	if state == State.FINAL_SANDBOX:
		sandbox_elapsed += real_delta
		_lab_attacks()
	guide._register_hazards()
	guide._sample_phase()
	guide._update_markers()
	_observe()
	if state == State.RUNNING and phase_elapsed >= DURATIONS[phase_index]:
		_finish_phase(false)
		if phase_index == 4:
			_enter_sandbox()
		else:
			state = State.TRANSITION
			_transition_elapsed = 0
			_apply_pause()


func _choreograph() -> void:
	while _cursor < _events.size() and phase_elapsed >= float(_events[_cursor][0]):
		var event: Array = _events[_cursor]
		if not _event(str(event[1]), int(event[2])):
			# Un danger principal peut encore finir son passage. Ne jamais le superposer.
			if phase_elapsed < float(event[0]) + 3.0:
				break
		else:
			_sample.events.append({"time": phase_elapsed, "kind": event[1], "pattern": event[2]})
		_cursor += 1
	_update_camera()


func _event(kind: String, pattern: int) -> bool:
	var center: Vector3 = simulation._fleet_center()
	var velocity: Vector3 = Vector3.ZERO
	for blue: BlueShip in simulation.ships:
		velocity += blue.velocity
	velocity /= maxf(simulation.ships.size(), 1)
	var field: ObstacleField = simulation.asteroid_container
	match kind:
		"mega": return true if phase_index == 4 and int(settings.mega) == 0 else field.spawn_mega(center, velocity, pattern, 40, 4)
		"colossal": return true if phase_index == 4 and int(settings.mega) == 0 else field.spawn_colossal(center, velocity, 96, 8) != null
		"fast": field.spawn_fast_crossing(center, true)
		"capital":
			var role: int = {0: 0, 4: 1, 7: 2, 6: 3, 8: 4, 9: 5, 2: 5}[pattern]
			if simulation.capitals.is_empty():
				return false
			var capital: CapitalShip = simulation.capitals[role % simulation.capitals.size()]
			if pattern in [7, 8]:
				var gates: int = 0
				for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
					if node is MovingLaserGate and not node.is_queued_for_deletion():
						gates += 1
				if gates >= 2 or ArtilleryZone.dangerous_count(get_tree()) + 8 > 35:
					return false
				var geometries: Array[int] = [1, 2, 6, 4, 5, 3, 0]
				capital.presentation_gate_geometry = geometries[_gate_cursor % geometries.size()]
				_gate_cursor += 1
			if capital.state == CapitalShip.State.FIRE:
				return false
			capital._transition(CapitalShip.State.PREPARE)
			capital.selected_pattern = pattern as CapitalShip.ArtilleryPattern
			capital.prepare_duration = 0.4 / float(settings.fire)
	return true


func _update_camera() -> void:
	var segment: int = 0
	var shots: Array[int] = []
	match phase_index:
		0:
			segment = 2 if phase_elapsed >= 27 else 1 if phase_elapsed >= 8 else 0
			shots.assign([[1, 0, 11], [5, 8, 5], [5, 3]][segment])
		1: shots = [5, 1, 2]
		2: shots = [0, 11, 5]
		3: shots = [10, 5, 0, 10]
		4: shots = [7, 5, 11, 8, 10]
	if segment == _camera_segment:
		return
	_camera_segment = segment
	simulation.camera.guided_shots = shots
	simulation.camera.cinematic_shot = shots[0] as SimulationCamera.Shot
	simulation.camera._sequence_index = 0
	simulation.camera._shot_time = 0
	simulation.camera._shot_duration = 4.5
	simulation.camera.cinematic_transition_time = 0.8


func _first(key: String, condition: bool) -> void:
	if condition and not _sample.first_events.has(key):
		_sample.first_events[key] = phase_elapsed


func _observe() -> void:
	_sample.dispersion_peak = maxf(_sample.dispersion_peak, simulation.dispersion)
	_sample.dispersion_end = simulation.dispersion
	_first("obstacle", simulation.asteroid_container.mega_generated > 0)
	_first("pulse", simulation.drones.any(func(drone: PatrolDrone) -> bool: return drone.patrol_shots_fired > 0))
	_first("waypoint", simulation.drones.any(func(drone: PatrolDrone) -> bool: return drone.waypoints_selected > 1))
	_first("pursuit", simulation.interceptors.any(func(hostile: Interceptor) -> bool: return hostile.pursuits_started > 0))
	_first("burst", simulation.interceptors.any(func(hostile: Interceptor) -> bool: return hostile.shots_fired > 0))
	_first("disengage", simulation.interceptors.any(func(hostile: Interceptor) -> bool: return hostile.disengagements > 0))
	_first("boost", simulation.evasive_boost_count > int(_sample.boosts_start))
	_first("flash", simulation.capitals.any(func(capital: CapitalShip) -> bool: return capital._flash_time > 0))
	_first("heavy", simulation.capital_salvos[0] > int(guide._phase_sample.salvos_start[0]))
	for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
		if node is MovingLaserGate:
			var gate: MovingLaserGate = node as MovingLaserGate
			var family: String = "Grid" if gate.variant == MovingLaserGate.Variant.ROTATING_LASER_GRID else "Gate"
			if not gate.has_meta("presentation_watch"):
				gate.set_meta("presentation_watch", true)
				_sample["grid_launches"] = int(_sample.get("grid_launches", 0)) + 1
				if not _sample.has("geometries"):
					_sample["geometries"] = {}
				_sample.geometries[MovingLaserGate.GateGeometry.keys()[gate.geometry]] = true
				gate.ship_passed.connect(func(_blue: BlueShip) -> void: _crossed(family, "passed"))
				gate.ship_bypassed.connect(func(_blue: BlueShip) -> void: _crossed(family, "bypassed"))


func _crossed(family: String, outcome: String) -> void:
	if not _sample.gate_crossings.has(family):
		_sample.gate_crossings[family] = {"first_time": phase_elapsed, "passed": 0, "bypassed": 0}
	_sample.gate_crossings[family][outcome] += 1


func _finish_phase(skipped: bool) -> void:
	guide._sample_phase()
	guide._finish_phase()
	var record: Dictionary = guide.phase_results.back().duplicate(true)
	record.merge(_sample, true)
	record.duration = phase_elapsed
	record.skipped = skipped
	record.enemies_destroyed = simulation.enemies_destroyed
	record.enemy_populations = _family_stats.duplicate(true)
	record.boosts = simulation.evasive_boost_count - int(_sample.boosts_start)
	record.erase("boosts_start")
	records.append(record)


func _finish() -> void:
	state = State.FINISHED
	guide.last_duration = elapsed_real
	simulation.demo_controls.set_phase(-1, "")
	simulation.demo_controls.show_presentation(State.FINISHED)
	_apply_pause()


func _enter_sandbox() -> void:
	automatic_duration = elapsed_real
	state = State.FINAL_SANDBOX
	_cursor = _events.size()
	sandbox_elapsed = 0
	_lab_attack_at = 1
	_lab_attack_cursor = 0
	_mega_at = 5
	_colossal_at = 10
	simulation.demo_controls.show_presentation(state)
	simulation.demo_controls.battle_panel.show()
	simulation.demo_controls.battle_panel.call("refresh")
	_apply_pause()


func _reset_population_stats() -> void:
	_family_stats.clear()
	_addition_at.clear()
	for family: String in FAMILIES:
		_family_stats[family] = {"kills": 0, "deaths": 0, "respawns": 0, "spawned": 0, "min": 1000, "max": 0}
		_addition_at[family] = 0.0


func _actors(family: String) -> Array:
	return simulation.drones if family == "patrol" else simulation.interceptors if family == "interceptor" else simulation.capitals


func _target(family: String) -> int:
	return simulation.manual_drone_count_override if family == "patrol" else simulation.manual_interceptor_count_override if family == "interceptor" else simulation.manual_capital_count_override


func configure_actor(actor: Node3D, family: String, slot: int) -> void:
	_spawn_serial += 1
	actor.individual_seed += _spawn_serial * 4001
	actor.set_meta("presentation_slot", slot)
	actor.set_meta("presentation_family", family)
	actor.destroyed.connect(_count_enemy_kill.bind(family, _generation))
	if actor is CapitalShip:
		actor.destroyed.connect(_enemy_destroyed.bind(family, slot, _generation))
	else:
		(actor as PatrolDrone).died.connect(_enemy_destroyed.bind(family, slot, _generation))
	_family_stats[family].spawned += 1
	if actor is CapitalShip:
		var capital: CapitalShip = actor as CapitalShip
		capital.presentation_enabled = true
		capital.presentation_gate_limit = 2
		capital.presentation_grid_width = float(settings.grid_width)
		capital.salvo_started.connect(_capital_pattern)
	else:
		var hostile: PatrolDrone = actor as PatrolDrone
		hostile.dangerous_projectile_limit = 19 if phase_index == 4 else 29 # Réserver seize beams pendant la finale.
		hostile.patrol_firing_cone_degrees = 32
	_configure_actor_settings(actor)


func _configure_actor_settings(actor: Node3D) -> void:
	var base: float = 0.5 if phase_index == 1 else 1.0
	var next_intensity: float = base * float(settings.fire)
	var ratio: float = float(actor.fire_intensity) / next_intensity
	if actor.is_node_ready():
		if actor is Interceptor:
			(actor as Interceptor)._shot_timer *= ratio
		elif actor is PatrolDrone:
			(actor as PatrolDrone)._patrol_fire_timer *= ratio
		elif actor is CapitalShip:
			(actor as CapitalShip).prepare_duration *= ratio
			(actor as CapitalShip).cooldown_duration *= ratio
	actor.fire_intensity = next_intensity
	actor.presentation_projectile_speed = float(settings.speed)
	if actor is Interceptor:
		var hostile: Interceptor = actor as Interceptor
		hostile.target_detection_radius = 80 * float(settings.aggression)
		hostile.max_pursuit_duration = 8 * sqrt(float(settings.aggression))
	elif actor is PatrolDrone:
		(actor as PatrolDrone).patrol_firing_cone_degrees = clampf(32 * sqrt(float(settings.aggression)), 22, 48)
	elif actor is CapitalShip:
		(actor as CapitalShip).presentation_grid_width = float(settings.grid_width)


func _enemy_destroyed(_actor: Node3D, family: String, slot: int, generation: int) -> void:
	if not active() or generation != _generation:
		return
	_family_stats[family].deaths += 1
	var delay: float = _population_random.randf_range(2, 4) if family == "capital" else _population_random.randf_range(0.8, 1.4)
	_pending_respawns.append({"family": family, "slot": slot, "at": phase_elapsed + delay, "died_at": phase_elapsed})


func _spawn_actor(family: String, slot: int) -> void:
	var center: Vector3 = simulation._fleet_center()
	match family:
		"patrol":
			guide._patrol_replacement_serial += 1
			guide._spawn_patrol(center, slot, phase_index == 1 and slot in [0, 4, 10, 14], true)
		"interceptor":
			guide._interceptor_replacement_serial += 1
			guide._spawn_interceptor(center, slot, true)
		"capital": guide._spawn_capital(center, true, slot)


func _retire_actor(family: String, actor: Node3D) -> void:
	match family:
		"patrol": simulation.drones.erase(actor)
		"interceptor": simulation.interceptors.erase(actor)
		"capital": simulation.capitals.erase(actor)
	guide._disable_entity(actor)
	actor.alive = false
	actor.queue_free()


func _slot_exists(family: String, slot: int) -> bool:
	for actor: Node in _actors(family):
		if int(actor.get_meta("presentation_slot", -1)) == slot:
			return true
	return false


func _maintain_populations() -> void:
	for family: String in FAMILIES:
		var target: int = _target(family)
		var occupied: Dictionary = {}
		for actor: Node3D in _actors(family).duplicate():
			var slot: int = int(actor.get_meta("presentation_slot", -1))
			if slot >= target or occupied.has(slot):
				_retire_actor(family, actor)
			else:
				occupied[slot] = true
		for entry: Dictionary in _pending_respawns.duplicate():
			if entry.family != family:
				continue
			var slot: int = int(entry.slot)
			if slot >= target or _slot_exists(family, slot) or _actors(family).size() >= target:
				_pending_respawns.erase(entry)
			elif phase_elapsed >= float(entry.at):
				_spawn_actor(family, slot)
				_pending_respawns.erase(entry)
				_family_stats[family].respawns += 1
				total_respawns[family] += 1
				respawn_events.append({"family": family, "phase": phase_index + 1, "delay": phase_elapsed - float(entry.died_at)})
				if respawn_events.size() > 256:
					respawn_events.pop_front()
		occupied.clear()
		for actor: Node in _actors(family):
			occupied[int(actor.get_meta("presentation_slot", -1))] = true
		for entry: Dictionary in _pending_respawns:
			if entry.family == family:
				occupied[int(entry.slot)] = true
		if _actors(family).size() < target and phase_elapsed >= float(_addition_at[family]):
			for slot: int in range(target):
				if not occupied.has(slot):
					_spawn_actor(family, slot)
					_addition_at[family] = phase_elapsed + (0.45 if family == "capital" else 0.14)
					break
		_family_stats[family].min = mini(_family_stats[family].min, _actors(family).size())
		_family_stats[family].max = maxi(_family_stats[family].max, _actors(family).size())


func set_setting(key: String, value: float) -> void:
	if phase_index != 4 or state not in [State.RUNNING, State.FINAL_SANDBOX]:
		return
	if not LIMITS.has(key):
		return
	value = clampf(value, LIMITS[key][0], LIMITS[key][1])
	settings[key] = int(roundf(value)) if key in ["patrol", "interceptor", "capital", "damage", "mega"] else value
	if key == "mega":
		var clock: float = sandbox_elapsed if state == State.FINAL_SANDBOX else phase_elapsed
		_mega_at = clock + 16.0 / maxi(int(settings.mega), 1)
		_colossal_at = clock + 24.0 / maxi(int(settings.mega), 1)
	_apply_settings()


func reset_battle(chaos: bool = false) -> void:
	if phase_index != 4 or state not in [State.RUNNING, State.FINAL_SANDBOX]:
		return
	settings = CHAOS_SETTINGS.duplicate() if chaos else DEFAULT_SETTINGS.duplicate()
	_apply_settings()


func _apply_settings() -> void:
	if phase_index == 4:
		simulation.manual_drone_count_override = int(settings.patrol)
		simulation.manual_interceptor_count_override = int(settings.interceptor)
		simulation.manual_capital_count_override = int(settings.capital)
		var field: ObstacleField = simulation.asteroid_container
		field.storm_target = mini(roundi(38 * float(settings.density)), 78)
		field.max_active_asteroids = 80
		if is_instance_valid(field._storm_container):
			var small: Array[Node] = []
			for node: Node in field._storm_container.get_children():
				if node is SpaceAsteroid and (node as SpaceAsteroid).diameter < 60 and not node.is_queued_for_deletion():
					small.append(node)
			while small.size() > field.storm_target:
				var rock: Node = small.pop_back()
				guide._disable_entity(rock)
				rock.queue_free()
				field.active_asteroid_count = maxi(field.active_asteroid_count - 1, 0)
				if (rock as SpaceAsteroid).motion_type != SpaceAsteroid.MotionType.STATIC:
					field.active_mobile_count = maxi(field.active_mobile_count - 1, 0)
	for blue: BlueShip in simulation.ships:
		pack_actor(blue, "blue")
	for family: String in FAMILIES:
		for actor: Node3D in _actors(family):
			_configure_actor_settings(actor)
	for node: Node in get_tree().get_nodes_in_group("hostile_projectiles"):
		configure_projectile(node)
	for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
		if node is MovingLaserGate:
			(node as MovingLaserGate).set_battle_width(float(settings.grid_width))
	simulation._update_hud()


func configure_projectile(projectile: Node) -> void:
	if projectile is EnemyLaser:
		(projectile as EnemyLaser).set_battle_parameters(float(settings.width), float(settings.speed), int(settings.damage))
	elif projectile is ArtilleryProjectile:
		(projectile as ArtilleryProjectile).set_battle_parameters(float(settings.width), float(settings.speed), int(settings.damage))


func _capital_pattern(pattern: int) -> void:
	if pattern in [7, 8]:
		_sample["grid_attempts"] = int(_sample.get("grid_attempts", 0)) + 1


func _update_raids(_real_delta: float) -> void:
	if phase_index not in [3, 4] or phase_elapsed < _raid_at or simulation.capitals.is_empty():
		return
	var capital: CapitalShip = simulation.capitals[_raid_cursor % simulation.capitals.size()]
	capital.begin_presentation_raid(_population_random.randf_range(5, 6), _population_random.randf_range(70, 76))
	_raid_cursor += 1
	_raid_at = phase_elapsed + 9


func _lab_attacks() -> void:
	if sandbox_elapsed >= _lab_attack_at:
		var patterns: Array[int] = [7, 0, 8, 4, 7, 6, 8, 9, 7, 2, 8]
		if _event("capital", patterns[_lab_attack_cursor % patterns.size()]):
			_lab_attack_cursor += 1
			_lab_attack_at = sandbox_elapsed + 8 / float(settings.fire)


func _boulders() -> void:
	if int(settings.mega) == 0:
		return
	var clock: float = sandbox_elapsed if state == State.FINAL_SANDBOX else phase_elapsed
	var velocity: Vector3 = Vector3.ZERO
	for blue: BlueShip in simulation.ships:
		velocity += blue.velocity
	velocity /= maxf(simulation.ships.size(), 1)
	if clock >= _mega_at:
		if simulation.asteroid_container.spawn_mega(simulation._fleet_center(), velocity, _lab_attack_cursor % 2, 40, 4):
			_mega_at = clock + 16.0 / int(settings.mega)
	if clock >= _colossal_at:
		if simulation.asteroid_container.spawn_colossal(simulation._fleet_center(), velocity, 96, 8) != null:
			_colossal_at = clock + 24.0 / int(settings.mega)


func finish_battle() -> void:
	if phase_index == 4 and state in [State.RUNNING, State.FINAL_SANDBOX]:
		if state == State.RUNNING:
			_finish_phase(true)
		_finish()


func _count_enemy_kill(_actor: Node3D, family: String, generation: int) -> void:
	if active() and generation == _generation:
		_family_stats[family].kills += 1


func pack_actor(actor: Node3D, family: String) -> void:
	BATTLE_VISUAL_CACHE.pack(actor.get_node("Visuals") as Node3D, family)


func _warm_visuals() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Préchauffer les surfaces derrière READY : uniquement des visuels, aucun body/agent.
	var warm: Node3D = Node3D.new()
	warm.name = "PresentationVisualWarmup"
	add_child(warm)
	var scenes: Array[PackedScene] = [SpaceSimulation.DRONE_SCENE, SpaceSimulation.INTERCEPTOR_SCENE, SpaceSimulation.CAPITAL_SCENE]
	for index: int in range(scenes.size()):
		var sample: Node3D = scenes[index].instantiate() as Node3D
		var visual: Node3D = sample.get_node("Visuals") as Node3D
		sample.remove_child(visual)
		sample.free()
		warm.add_child(visual)
		BATTLE_VISUAL_CACHE.pack(visual, FAMILIES[index])
		visual.global_position = simulation.camera.global_position - simulation.camera.global_basis.z * 4
		visual.scale = Vector3.ONE * 0.0015
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if is_instance_valid(warm):
		warm.queue_free()
