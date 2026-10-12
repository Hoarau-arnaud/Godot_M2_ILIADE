class_name SimulationCamera
extends Camera3D

signal mode_changed(free_camera: bool)

enum Mode { FOLLOW, FREE }

@export var follow_speed: float = 3.0
@export var pan_speed: float = 24.0
@export var orbit_sensitivity: float = 0.006
@export var minimum_zoom_distance: float = 6.0
@export var maximum_zoom_distance: float = 220.0

var mode: Mode = Mode.FOLLOW
var _group_center: Vector3 = Vector3.ZERO
var _group_spread: float = 0.0
var _orbit_center: Vector3 = Vector3.ZERO
var _orbit_distance: float = 42.0
var _yaw: float = 0.0
var _pitch: float = 0.3
var _dragging: bool = false


func initialize_view(center: Vector3) -> void:
	_group_center = center
	global_position = center + Vector3(10.0, 16.0, 42.0)
	look_at(center + Vector3.FORWARD * 8.0, Vector3.UP)


func observe_group(center: Vector3, spread: float, delta: float) -> void:
	_group_center = center
	_group_spread = spread
	if mode == Mode.FOLLOW:
		var distance: float = 42.0 + maxf(spread - 14.0, 0.0) * 1.3
		var desired_position: Vector3 = center + Vector3(10.0, 16.0 + distance * 0.04, distance)
		global_position = global_position.lerp(desired_position, 1.0 - exp(-maxf(follow_speed, 0.0) * delta))
		look_at(center + Vector3.FORWARD * 8.0, Vector3.UP)
	else:
		_pan(delta)
		_apply_orbit()


func toggle_mode() -> void:
	_dragging = false
	if mode == Mode.FOLLOW:
		mode = Mode.FREE
		_orbit_center = _group_center + Vector3.FORWARD * 8.0
		_read_orbit_from_current_view()
	else:
		mode = Mode.FOLLOW
		recenter()
	mode_changed.emit(mode == Mode.FREE)


func recenter() -> void:
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("camera_toggle"):
		toggle_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_recenter"):
		recenter()
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
