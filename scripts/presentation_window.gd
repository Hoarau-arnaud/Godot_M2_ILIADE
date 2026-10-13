class_name PresentationWindow
extends Node

signal fullscreen_changed(enabled: bool)

var _windowed_size: Vector2i = Vector2i(1280, 720)
var _windowed_position: Vector2i = Vector2i.ZERO
var _windowed_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
var _borderless: bool = false


func is_fullscreen() -> bool:
	return DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func toggle_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not is_fullscreen():
		_windowed_size = DisplayServer.window_get_size()
		_windowed_position = DisplayServer.window_get_position()
		_windowed_mode = DisplayServer.window_get_mode()
		_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(_windowed_mode)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _borderless)
		if _windowed_mode == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_size(_windowed_size)
			DisplayServer.window_set_position(_windowed_position)
	fullscreen_changed.emit(is_fullscreen())
