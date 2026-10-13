extends Node

# Instrument externe aux agents : aucun ordre ni force de navigation.
var simulation: SpaceSimulation
var drive_study_clock: bool = false
var stop_simulated_seconds: float = 0
var phases: Dictionary[int, Dictionary] = {}
var _timer: float = 0
var _last_states: Dictionary = {}
var _peaks: Dictionary = {}
const INTERCEPTOR_STATES: Array[String] = ["PATROL", "PURSUIT", "DISENGAGE", "AVOIDING", "DESTROYED"]
const CAPITAL_STATES: Array[String] = ["ENTRY", "OBSERVE", "PREPARE", "FIRE", "COOLDOWN", "REPOSITION", "AVOIDING", "DESTROYED"]

func _ready() -> void:
	process_priority = 100

func _physics_process(delta: float) -> void:
	if drive_study_clock:
		simulation.demonstration._process(delta)
	_monitor_actors()
	_timer += delta
	if _timer >= 0.05:
		_timer = 0
		sample()
	if stop_simulated_seconds > 0 and simulation.elapsed_simulation_time >= stop_simulated_seconds - 0.000001:
		sample()
		simulation.set_presentation_paused(true)

func _data() -> Dictionary:
	var phase: int = simulation.demonstration.phase_index
	if not phases.has(phase):
		phases[phase] = {"samples": 0, "spacing_sum": 0.0, "dispersion_before": 0.0, "dispersion_max": 0.0, "dispersion_final": 0.0, "xy_max": 0.0, "obstacle_reaction_samples": 0, "regrouping_samples": 0, "nodes_max": 0, "projectiles_max": 0, "asteroids_max": 0, "transitions": {}}
	return phases[phase]

func _counter(data: Dictionary, id: int, output: StringName, value: int) -> void:
	if not _peaks.has(id):
		_peaks[id] = {}
	var previous: Dictionary = _peaks[id]
	data[output] = int(data.get(output, 0)) + maxi(value - int(previous.get(output, 0)), 0)
	previous[output] = value

func _transition(data: Dictionary, node: Node, state: int, names: Array[String], family: String) -> void:
	var id: int = node.get_instance_id()
	if _last_states.has(id) and int(_last_states[id]) != state:
		var label: String = family + ":" + names[int(_last_states[id])] + "→" + names[state]
		data.transitions[label] = int(data.transitions.get(label, 0)) + 1
	_last_states[id] = state

func sample() -> void:
	var data: Dictionary = _data()
	var center: Vector3 = simulation._fleet_center()
	simulation._measure_group(center)
	if int(data.samples) == 0:
		data.dispersion_before = simulation.dispersion
	data.samples += 1
	data.spacing_sum += simulation.average_spacing
	data.dispersion_max = maxf(data.dispersion_max, simulation.dispersion)
	data.dispersion_final = simulation.dispersion
	data.spacing_final = simulation.average_spacing
	data.isolated_final = simulation.isolated_agent_count
	data.xy_max = maxf(data.xy_max, Vector2(center.x, center.y).length())
	data.nodes_max = maxi(data.nodes_max, get_tree().get_node_count())
	data.projectiles_max = maxi(data.projectiles_max, ArtilleryZone.dangerous_count(get_tree()))
	data.asteroids_max = maxi(data.asteroids_max, get_tree().get_nodes_in_group("asteroids").size())
	for blue: BlueShip in simulation.ships:
		if not blue._threats.is_empty():
			data.obstacle_reaction_samples += 1
		if blue.behavior_state == BlueShip.BehaviorState.REGROUPING:
			data.regrouping_samples += 1

func _monitor_actors() -> void:
	var data: Dictionary = _data()
	for drone: PatrolDrone in simulation.drones:
		var id: int = drone.get_instance_id()
		_counter(data, id, &"waypoints", drone.waypoints_selected)
		_counter(data, id, &"patrol_routes", drone.routes_completed)
		_counter(data, id, &"patrol_shots", drone.patrol_shots_fired)
	for hostile: Interceptor in simulation.interceptors:
		var id: int = hostile.get_instance_id()
		_counter(data, id, &"pursuits", hostile.pursuits_started)
		_counter(data, id, &"bursts", hostile.bursts_started)
		_counter(data, id, &"disengagements", hostile.disengagements)
		_counter(data, id, &"interceptor_shots", hostile.shots_fired)
		_transition(data, hostile, hostile._mission_state, INTERCEPTOR_STATES, "Interceptor")
	for capital: CapitalShip in simulation.capitals:
		_transition(data, capital, capital.state, CAPITAL_STATES, "Capital")

func result() -> Dictionary:
	sample()
	var data: Dictionary = phases[simulation.demonstration.phase_index].duplicate(true)
	data.spacing_mean = data.spacing_sum / maxf(data.samples, 1)
	data.erase("spacing_sum")
	data.merge({"deaths": simulation.death_count, "death_causes": simulation.death_causes.duplicate(), "reinforcements": simulation.reinforcement_count, "blue_alive": simulation.ships.size(), "boosts": simulation.evasive_boost_count, "targeted": simulation.targeted_projectile_count, "impacts": simulation.combat_impacts, "megas": simulation.asteroid_container.mega_generated, "colossals": simulation.asteroid_container.colossal_generated}, true)
	data.rock_reactions = int(simulation.weapon_metrics.get("Small", {}).get("reactions", 0)) + int(simulation.weapon_metrics.get("Mega", {}).get("reactions", 0))
	return data
