class_name SimulationCamera
extends Camera3D

var action_observation_enabled: bool = false
var _action_shot: Shot = Shot.CHASE
var _action_hold: float = 0

func _observe_primary_action(fallback: Shot) -> Shot:
	for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
		if node is MovingLaserGate:
			var gate: MovingLaserGate = node as MovingLaserGate
			var until: float = gate.crossing_time(_group_center, group_velocity)
			if until >= 0 and until < 7:
				return Shot.REAR_CLOSE if until < 2 else Shot.WIDE
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		var offset: Vector3 = rock.global_position - _group_center
		if rock.diameter >= 60 and offset.length() < 280:
			return Shot.UNDER_FLEET
		if rock.diameter >= 20 and offset.length() < 170 and offset.dot(rock.velocity - group_velocity) < 0:
			return Shot.TOP_DOWN if rock.mega_trajectory == SpaceAsteroid.MegaTrajectory.MEGA_VERTICAL else Shot.SIDE_FAST
	for node: Node in get_tree().get_nodes_in_group("combat_hazards"):
		var zone: ArtilleryZone = node as ArtilleryZone
		if zone.kind == ArtilleryZone.Kind.BOMB and zone.delay - zone.age < 3:
			return Shot.TOP_DOWN
	for node: Node in get_tree().get_nodes_in_group("artillery_projectiles"):
		var projectile: ArtilleryProjectile = node as ArtilleryProjectile
		if projectile.targeted and projectile.global_position.distance_to(_group_center) < 110:
			return Shot.REAR_CLOSE
	return Shot.WIDE if _group_spread > 55 else fallback

signal mode_changed(free_camera: bool)
signal camera_mode_changed(new_mode: int)

enum Mode { FOLLOW, FREE, CINEMATIC }
enum Shot { CHASE, SIDE_LEFT, SIDE_RIGHT, HIGH, LOW_CLOSE, WIDE, FRONT_FLYBY, REAR_CLOSE, TOP_DOWN, UNDER_FLEET, WIDE_ARTILLERY, SIDE_FAST }

@export var follow_speed: float = 3.0
@export var pan_speed: float = 24.0
@export var orbit_sensitivity: float = 0.006
@export var minimum_zoom_distance: float = 6.0
@export var maximum_zoom_distance: float = 220.0
@export_category("Cinématique")
@export var cinematic_transition_time: float = 2.0
@export var cinematic_obstacle_avoidance: bool = true
@export var cinematic_shake_enabled: bool = false
@export var cinematic_shake_amplitude: float = 0.06

var cinematic_shot: Shot = Shot.CHASE
var shot_changes: int = 0
var shot_history: Array[int] = []
var group_velocity: Vector3 = Vector3.ZERO
var capital_preparing: bool = false
var capital_focus: Vector3 = Vector3.ZERO
var boost_fov_extra: float = 0
var presentation_shots: bool = false
var guided_spectacle: bool = false
var guided_lock: bool = false
var guided_shots: Array[int] = []
var _capital_composition: Vector3 = Vector3.ZERO
var _demo_pace: float = 1.0
var _cine_random: RandomNumberGenerator = RandomNumberGenerator.new()
var _cine_time: float = 0.0
var _shot_time: float = 0.0
var _shot_duration: float = 8.0
var _sequence_index: int = 0
var _cine_offset: Vector3 = Vector3(10, 18, 52)
var _agent_positions: Array[Vector3] = []
var _action_intensity: float = 0.0
var _normal_fov: float = 58.0
var _current_shot_offset: Vector3 = Vector3(14, 18, 52)
var _previous_shot_offset: Vector3 = Vector3(14, 18, 52)
var _last_effective_shot: int = -1
var _transition_elapsed: float = 0.0

var mode: Mode = Mode.FOLLOW
var _group_center: Vector3 = Vector3.ZERO
var _group_spread: float = 0.0
var _orbit_center: Vector3 = Vector3.ZERO
var _orbit_distance: float = 42.0
var _yaw: float = 0.0
var _pitch: float = 0.3
var _dragging: bool = false


func initialize_view(center: Vector3, seed_value: int = 1) -> void:
	_group_center = center
	_normal_fov = fov
	_cine_random.seed = seed_value + 124091
	_shot_duration = _cine_random.randf_range(3.5, 5.5) if presentation_shots else _cine_random.randf_range(3.5, 6.0) if guided_spectacle else _cine_random.randf_range(6.0, 12.0)
	global_position = center + Vector3(10.0, 16.0, 42.0)
	look_at(center + Vector3.FORWARD * 8.0, Vector3.UP)


func observe_group(center: Vector3, spread: float, delta: float, positions: Array[Vector3] = [], intensity: float = 0.0, mean_velocity: Vector3 = Vector3.ZERO, demo_pace: float = 1.0) -> void:
	_group_center = center
	_group_spread = spread
	_agent_positions = positions
	_action_intensity = clampf(intensity, 0.0, 1.0)
	group_velocity = group_velocity.lerp(mean_velocity, 1.0 - exp(-2.0 * delta / maxf(Engine.time_scale, 0.01)))
	_demo_pace = demo_pace
	if mode == Mode.FOLLOW:
		fov = lerpf(fov, _normal_fov, 1.0 - exp(-3.0 * delta))
		var distance: float = 42.0 + maxf(spread - 14.0, 0.0) * 1.3
		var desired_position: Vector3 = center + Vector3(10.0, 16.0 + distance * 0.04, distance)
		global_position = global_position.lerp(desired_position, 1.0 - exp(-maxf(follow_speed, 0.0) * delta))
		look_at(center + Vector3.FORWARD * 8.0, Vector3.UP)
	elif mode == Mode.FREE:
		_pan(delta / maxf(Engine.time_scale, 0.01))
		_apply_orbit()
	else:
		_update_cinematic(delta / maxf(Engine.time_scale, 0.01))


func toggle_mode() -> void:
	set_mode(Mode.FOLLOW if mode == Mode.FREE else Mode.FREE)


func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	_dragging = false
	var previous_mode: Mode = mode
	mode = new_mode
	if mode == Mode.FREE:
		_orbit_center = _group_center + Vector3.FORWARD * 8.0
		_read_orbit_from_current_view()
	elif mode == Mode.CINEMATIC:
		_cine_offset = global_position - _group_center
		_current_shot_offset = global_position - (_group_center + Vector3.FORWARD * 8.0)
		_last_effective_shot = -1
		_shot_time = 0.0
		shot_history.append(cinematic_shot)
		if shot_history.size() > 64:
			shot_history.pop_front()
	else:
		if previous_mode != Mode.CINEMATIC:
			fov = _normal_fov
			recenter()
	mode_changed.emit(mode == Mode.FREE)
	camera_mode_changed.emit(mode)


func toggle_cinematic() -> void:
	set_mode(Mode.FOLLOW if mode == Mode.CINEMATIC else Mode.CINEMATIC)


func recenter() -> void:
	if mode == Mode.CINEMATIC:
		# Reprendre un plan derrière le groupe par la transition, sans saut de caméra.
		cinematic_shot = Shot.CHASE
		_sequence_index = 0
		_shot_time = 0.0
		return
	var distance: float = 42.0 + maxf(_group_spread - 14.0, 0.0) * 1.3
	global_position = _group_center + Vector3(10.0, 16.0 + distance * 0.04, distance)
	look_at(_group_center + Vector3.FORWARD * 8.0, Vector3.UP)
	_orbit_center = _group_center + Vector3.FORWARD * 8.0
	_read_orbit_from_current_view()


func _read_orbit_from_current_view() -> void:
	var offset: Vector3 = global_position - _orbit_center
	_orbit_distance = maxf(offset.length(), 0.1)
	_yaw = atan2(offset.x, offset.z)
	_pitch = asin(clampf(offset.y / _orbit_distance, -1.0, 1.0))


func _update_cinematic(delta: float) -> void:
	_cine_time += delta
	_shot_time += delta
	if _shot_time >= _shot_duration:
		var sequence: Array[int] = [Shot.CHASE, Shot.SIDE_LEFT, Shot.HIGH, Shot.SIDE_RIGHT, Shot.LOW_CLOSE, Shot.WIDE]
		if not guided_shots.is_empty():
			sequence = guided_shots
		_sequence_index = (_sequence_index + 1) % sequence.size()
		cinematic_shot = sequence[_sequence_index] as Shot
		_shot_time = 0.0
		_shot_duration = _cine_random.randf_range(3.5, 5.5) if presentation_shots else _cine_random.randf_range(3.5, 6.0) if guided_spectacle else _cine_random.randf_range(6.0, 12.0)
		shot_changes += 1
		shot_history.append(cinematic_shot)
		if shot_history.size() > 64:
			shot_history.pop_front()
	var effective_shot: Shot = Shot.WIDE if _group_spread > 45.0 and not guided_spectacle else cinematic_shot
	if action_observation_enabled:
		_action_hold = maxf(_action_hold - delta, 0)
		var observed: Shot = _observe_primary_action(effective_shot)
		if observed != _action_shot and _action_hold <= 0:
			_action_shot = observed
			_action_hold = 0.8
		effective_shot = _action_shot
	var offsets: Array[Vector3] = [Vector3(14, 18, 52), Vector3(-55, 16, 28), Vector3(55, 14, 28), Vector3(8, 52, 38), Vector3(-18, -6, 37), Vector3(10, 34, 78), Vector3(-8, 12, -62), Vector3(5, 8, 35), Vector3(12, 80, 48), Vector3(-10, -50, 48), Vector3(10, 25, 95), Vector3(-65, 12, 22)]
	if effective_shot != _last_effective_shot:
		_previous_shot_offset = _current_shot_offset
		_transition_elapsed = 0.0
		_last_effective_shot = effective_shot
	_transition_elapsed += delta
	var progress: float = clampf(_transition_elapsed / maxf(cinematic_transition_time, 0.5), 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	_current_shot_offset = _previous_shot_offset.lerp(offsets[effective_shot], eased)
	var fields: Array[float] = [57.0, 60.0, 60.0, 58.0, 61.0, 65.0, 64.0, 62.0, 64.0, 62.0, 65.0, 63.0]
	var side_speed: float = Vector2(group_velocity.x, group_velocity.y).length()
	var desired_fov: float = clampf(fields[effective_shot] + _action_intensity * 3.0 + maxf(_demo_pace - 1.0, 0.0) * 1.7 + side_speed * 0.2 + sin(_cine_time * 0.13) * 0.7 + boost_fov_extra, 54, 71)
	var blending: float = 1.0 - exp(-3.0 * delta / maxf(cinematic_transition_time, 0.5))
	fov = lerpf(fov, desired_fov, blending)
	var offset: Vector3 = _current_shot_offset * (1.0 - _action_intensity * 0.04)
	offset += Vector3(sin(_cine_time * 0.23) * 3.0, sin(_cine_time * 0.19) * 1.8, cos(_cine_time * 0.17) * 2.5)
	var lead_lag: float = sin(_cine_time * 0.35) * 3.5 * clampf(-group_velocity.z / 10.5, 0.0, 1.2)
	offset += Vector3(-group_velocity.x * 1.2, group_velocity.y * 0.7, lead_lag)
	var target: Vector3 = _group_center + Vector3(group_velocity.x * 0.65, group_velocity.y * 0.5, -8.0)
	var composition: Vector3 = Vector3.ZERO
	if capital_preparing and _group_spread < 40 and not is_position_behind(capital_focus):
		var screen: Vector2 = unproject_position(capital_focus)
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if Rect2(Vector2.ZERO, viewport_size).grow(-30).has_point(screen):
			composition = (capital_focus - _group_center).limit_length(4)
	_capital_composition = _capital_composition.lerp(composition, 1 - exp(-1.5 * delta))
	target += _capital_composition
	var direction: Vector3 = offset.normalized()
	var desired_position: Vector3 = target + direction * maxf(offset.length(), _framing_distance(target, direction))
	if cinematic_obstacle_avoidance:
		desired_position = _clear_camera_position(desired_position)
	_cine_offset = _cine_offset.lerp(desired_position - _group_center, blending)
	var position_candidate: Vector3 = _group_center + _cine_offset
	if cinematic_obstacle_avoidance:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, position_candidate, 2)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			position_candidate = hit["position"] + hit["normal"] * 0.8
		position_candidate = _clear_camera_position(position_candidate, 0.8)
		_cine_offset = position_candidate - _group_center
	global_position = position_candidate
	var desired_basis: Basis = Basis.looking_at((target - global_position).normalized(), Vector3.UP)
	var roll: float = clampf(deg_to_rad(-group_velocity.x * 0.65) + sin(_cine_time * 0.11) * (0.018 + _action_intensity * 0.008), deg_to_rad(-4.0), deg_to_rad(4.0))
	desired_basis = desired_basis.rotated(-desired_basis.z, roll)
	# Garder le barycentre dans l'axe pendant la translation déjà interpolée.
	quaternion = quaternion.slerp(desired_basis.get_rotation_quaternion(), 1.0 - exp(-5.0 * delta))
	if cinematic_shake_enabled:
		global_position += global_basis.x * sin(_cine_time * 29.0) * cinematic_shake_amplitude * _action_intensity


func _framing_distance(target: Vector3, direction: Vector3) -> float:
	var view: Basis = Basis.looking_at(-direction, Vector3.UP)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tangent_y: float = tan(deg_to_rad(fov * 0.5)) * 0.75
	var tangent_x: float = tangent_y * viewport_size.x / maxf(viewport_size.y, 1.0)
	var distance: float = 30.0
	var framing_points: Array[Vector3] = _agent_positions
	if action_observation_enabled:
		var nearby: Array[Vector3] = []
		for point: Vector3 in _agent_positions:
			if point.distance_to(_group_center) < 110:
				nearby.append(point)
		if nearby.size() >= 10:
			framing_points = nearby
	for point: Vector3 in framing_points:
		var relative: Vector3 = point - target
		var depth: float = relative.dot(direction)
		distance = maxf(distance, depth + (absf(relative.dot(view.x)) + 5.0) / maxf(tangent_x, 0.1))
		distance = maxf(distance, depth + (absf(relative.dot(view.y)) + 3.0) / maxf(tangent_y, 0.1))
	return distance


func _clear_camera_position(point: Vector3, margin: float = 4.0) -> Vector3:
	var result: Vector3 = point
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var asteroid: SpaceAsteroid = node as SpaceAsteroid
		var away: Vector3 = result - asteroid.global_position
		var clearance: float = asteroid.avoidance_radius + margin
		if away.length() < clearance:
			result = asteroid.global_position + (away.normalized() if away.length_squared() > 0.001 else Vector3.BACK) * clearance
	return result


func _apply_orbit() -> void:
	var offset: Vector3 = Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _orbit_distance
	global_position = _orbit_center + offset
	look_at(_orbit_center, Vector3.UP)


func _pan(delta: float) -> void:
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
	var right: Vector3 = forward.cross(Vector3.UP)
	var movement: Vector3 = (
		right * Input.get_axis("camera_left", "camera_right")
		+ forward * Input.get_axis("camera_backward", "camera_forward")
		+ Vector3.UP * Input.get_axis("camera_down", "camera_up")
	)
	_orbit_center += movement.limit_length(1.0) * maxf(pan_speed, 0.0) * delta


func cancel_orbit() -> void:
	_dragging = false


func _input(event: InputEvent) -> void:
	# Même une release consommée par un slider termine une orbite commencée dans l'espace.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if guided_lock:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("camera_toggle"):
		toggle_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_recenter"):
		recenter()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_cinematic"):
		toggle_cinematic()
		get_viewport().set_input_as_handled()
	elif mode == Mode.FREE:
		_handle_free_input(event)


func _handle_free_input(event: InputEvent) -> void:
	if event.is_action("camera_orbit"):
		_dragging = event.is_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_zoom_in"):
		_orbit_distance = clampf(_orbit_distance * 0.86, minimum_zoom_distance, maximum_zoom_distance)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_zoom_out"):
		_orbit_distance = clampf(_orbit_distance / 0.86, minimum_zoom_distance, maximum_zoom_distance)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var movement: Vector2 = event.screen_relative
		_yaw -= movement.x * orbit_sensitivity
		_pitch = clampf(_pitch + movement.y * orbit_sensitivity, -1.3, 1.3)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging = false
