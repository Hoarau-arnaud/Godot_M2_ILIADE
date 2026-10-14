class_name PresentationDemonstration
extends Node

# Une horloge et des rendez-vous de scène ; aucun ordre de navigation aux agents.
enum State { INACTIVE, READY, RUNNING, TRANSITION, FINISHED }
const DURATIONS: Array[float] = [35.0, 30.0, 35.0, 55.0, 75.0]
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
@onready var simulation: SpaceSimulation = get_parent() as SpaceSimulation
@onready var guide: GuidedDemonstration = get_parent().get_node("GuidedDemonstration") as GuidedDemonstration


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -9
	guide.mode_changed.connect(_mode_changed)


func active() -> bool:
	return state != State.INACTIVE


func _profile(index: int) -> Dictionary:
	return {"storm": index in [0, 4], "rocks": 38 if index == 4 else 0, "rocks_max": 50 if index == 4 else 35, "patrols": 15 if index == 1 else 4 if index == 4 else 0, "interceptors": 15 if index == 2 else 4 if index == 4 else 0, "capitals": 6 if index == 3 else 3 if index == 4 else 0, "fire_intensity": 0.5 if index == 1 else 1.0}


func prepare() -> void:
	if guide.is_staged():
		guide.stop()
	_guide_seed = guide.demonstration_seed
	guide.demonstration_seed = presentation_seed
	state = State.READY
	user_paused = false
	elapsed_real = 0
	phase_elapsed = 0
	phase_index = 0
	records.clear()
	guide.start(_profile(0))
	simulation.camera.presentation_shots = true
	simulation.demo_controls.set_phase(-1, "")
	simulation.demo_controls.show_presentation(State.READY)
	_apply_pause()


func start_or_next() -> void:
	if state == State.READY:
		state = State.RUNNING
		simulation.demo_controls.show_presentation(State.RUNNING)
		_begin_phase(0, false)
		_apply_pause()
	elif state == State.RUNNING:
		_finish_phase(true)
		if phase_index == 4:
			_finish()
		else:
			# Le raccourci passe immédiatement ; seules les transitions automatiques attendent.
			_begin_phase(phase_index + 1)
			_apply_pause()


func toggle_pause() -> void:
	if state in [State.RUNNING, State.TRANSITION]:
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
	if rebuild:
		guide._begin_phase(GUIDED_PHASES[index], simulation._fleet_center(), true, _profile(index))
	guide.phase_elapsed = 0
	_sample = {"phase": index + 1, "title": TITLES[index], "first_events": {}, "boosts_start": simulation.evasive_boost_count, "dispersion_peak": simulation.dispersion, "dispersion_end": simulation.dispersion, "gate_crossings": {}, "events": []}
	match index:
		0: _events = [[0.0, "mega", 1], [8.0, "colossal", 0], [18.0, "fast", 0], [23.0, "fast", 0]]
		1: _events = []
		2: _events = []
		3: _events = [[0.0, "capital", 0], [7.0, "capital", 4], [14.0, "capital", 7], [25.0, "capital", 6], [32.0, "capital", 8], [44.0, "capital", 9], [48.0, "capital", 2]]
		4: _events = [[0.0, "mega", 1], [0.0, "capital", 0], [16.0, "capital", 4], [24.0, "capital", 9], [30.0, "colossal", 0], [40.0, "mega", 0], [45.0, "capital", 7], [55.0, "capital", 8], [62.0, "capital", 4]]
	simulation.camera.presentation_shots = true
	simulation.demo_controls.set_phase(index, TITLES[index], 3.0)
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
	if phase_index in [2, 4]:
		guide._maintain_arcade_interceptors()
	if phase_index == 4:
		guide._maintain_arcade_patrols()
	guide._register_hazards()
	guide._sample_phase()
	guide._update_markers()
	_observe()
	if phase_elapsed >= DURATIONS[phase_index]:
		_finish_phase(false)
		if phase_index == 4:
			_finish()
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
		"mega": return field.spawn_mega(center, velocity, pattern, 40, 4)
		"colossal": return field.spawn_colossal(center, velocity, 96, 8) != null
		"fast": field.spawn_fast_crossing(center, true)
		"capital":
			var role: int = 2 if pattern in [7, 8, 2] else 1 if pattern in [6, 9] else 0
			if phase_index == 3:
				role = {0: 0, 4: 1, 7: 2, 6: 3, 8: 4, 9: 5, 2: 5}[pattern]
			if role >= simulation.capitals.size():
				return false
			var capital: CapitalShip = simulation.capitals[role]
			if capital.state == CapitalShip.State.FIRE:
				return false
			capital._transition(CapitalShip.State.PREPARE)
			capital.selected_pattern = pattern as CapitalShip.ArtilleryPattern
			capital.prepare_duration = 0.2
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
		3:
			segment = 5 if phase_elapsed >= 52 else 4 if phase_elapsed >= 44 else 3 if phase_elapsed >= 32 else 2 if phase_elapsed >= 25 else 1 if phase_elapsed >= 14 else 0
			shots.assign([[10, 0, 10], [5, 10], [8, 10], [5, 10], [7, 10], [10]][segment])
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
	record.boosts = simulation.evasive_boost_count - int(_sample.boosts_start)
	record.erase("boosts_start")
	records.append(record)


func _finish() -> void:
	state = State.FINISHED
	guide.last_duration = elapsed_real
	simulation.demo_controls.set_phase(-1, "")
	simulation.demo_controls.show_presentation(State.FINISHED)
	_apply_pause()
