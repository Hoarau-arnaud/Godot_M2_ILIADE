class_name DemoControls
extends CanvasLayer

var panel: PanelContainer
var stars: HBoxContainer
var speed_slider: HSlider
var movement_slider: HSlider
var spacing_slider: HSlider
var reset_button: Button
var _speed_value: Label
var _movement_value: Label
var _spacing_value: Label
var _counts: Dictionary[String, Label] = {}
var minus_buttons: Dictionary[String, Button] = {}
var plus_buttons: Dictionary[String, Button] = {}
var _displayed_level: int = 0


func _ready() -> void:
	layer = 2
	_build_stars()
	_build_panel()
	update_level(1)


func _simulation() -> SpaceSimulation:
	return get_parent() as SpaceSimulation


func _build_stars() -> void:
	stars = HBoxContainer.new()
	stars.name = "DifficultyStars"
	stars.anchor_left = 0.5
	stars.anchor_right = 0.5
	stars.offset_left = -62.0
	stars.offset_right = 62.0
	stars.offset_top = 16.0
	stars.add_theme_constant_override("separation", 8)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stars)
	for index: int in range(3):
		var star: Label = _label("☆")
		star.name = "Star%d" % (index + 1)
		star.add_theme_font_size_override("font_size", 30)
		star.add_theme_color_override("font_shadow_color", Color(0.005, 0.01, 0.025, 0.9))
		star.add_theme_constant_override("shadow_offset_y", 2)
		stars.add_child(star)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "ControlsPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -282.0
	panel.offset_right = -18.0
	panel.offset_top = 18.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _box(Color(0.012, 0.025, 0.065, 0.88), 14))
	var theme: Theme = Theme.new()
	theme.default_font_size = 15
	panel.theme = theme
	panel.gui_input.connect(_panel_input)
	panel.mouse_entered.connect(func() -> void: _simulation().camera.cancel_orbit())
	add_child(panel)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var heading: Label = _label("Contrôles")
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.45, 0.87, 1.0))
	layout.add_child(heading)
	_speed_value = _slider_heading(layout, "Vitesse")
	speed_slider = _slider(layout, "Speed", 0.5, 2.5, 1.5)
	speed_slider.value_changed.connect(func(value: float) -> void: _simulation().set_simulation_speed(value))
	_population_row(layout, "BlueShip")
	_population_row(layout, "PatrolDrone")
	_population_row(layout, "Interceptor")
	_movement_value = _slider_heading(layout, "Mouvement")
	movement_slider = _slider(layout, "Movement", 0.5, 2.0, 1.0)
	movement_slider.value_changed.connect(func(value: float) -> void: _simulation().set_movement_multiplier(value))
	_spacing_value = _slider_heading(layout, "Espacement")
	spacing_slider = _slider(layout, "Spacing", 0.8, 1.4, 1.0)
	spacing_slider.value_changed.connect(func(value: float) -> void: _simulation().set_spacing_multiplier(value))
	reset_button = _button("Reset agents")
	reset_button.name = "ResetAgents"
	reset_button.pressed.connect(func() -> void: _simulation().reset_population_overrides())
	layout.add_child(reset_button)


func _box(color: Color, margin: int = 6) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(float(margin))
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.15, 0.55, 0.72, 0.55)
	return style


func _label(value: String) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.95))
	return label


func _button(value: String) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(30, 30)
	button.add_theme_stylebox_override("normal", _box(Color(0.025, 0.1, 0.17)))
	button.add_theme_stylebox_override("hover", _box(Color(0.05, 0.22, 0.3)))
	button.add_theme_stylebox_override("pressed", _box(Color(0.08, 0.3, 0.4)))
	return button


func _slider_heading(layout: VBoxContainer, title: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = _label(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value: Label = _label("")
	row.add_child(value)
	layout.add_child(row)
	return value


func _slider(layout: VBoxContainer, node_name: String, minimum: float, maximum: float, initial: float) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.name = node_name
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.1
	slider.value = initial
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.custom_minimum_size.y = 18.0
	layout.add_child(slider)
	return slider


func _population_row(layout: VBoxContainer, kind: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = kind + "Count"
	row.add_theme_constant_override("separation", 6)
	var label: Label = _label(kind)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var minus: Button = _button("−")
	minus.name = "Minus"
	minus.pressed.connect(_change_count.bind(kind, -1))
	row.add_child(minus)
	var count: Label = _label("0")
	count.custom_minimum_size.x = 28.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)
	var plus: Button = _button("+")
	plus.name = "Plus"
	plus.pressed.connect(_change_count.bind(kind, 1))
	row.add_child(plus)
	layout.add_child(row)
	_counts[kind] = count
	minus_buttons[kind] = minus
	plus_buttons[kind] = plus


func _change_count(kind: String, amount: int) -> void:
	var simulation: SpaceSimulation = _simulation()
	match kind:
		"BlueShip": simulation.set_ship_count(simulation.target_ship_count + amount)
		"PatrolDrone": simulation.set_drone_count_override(simulation.target_drone_count() + amount)
		"Interceptor": simulation.set_interceptor_count_override(simulation.target_interceptor_count() + amount)


func _panel_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		panel.accept_event()


func update_level(level: int) -> void:
	if level == _displayed_level:
		return
	_displayed_level = clampi(level, 1, 3)
	for index: int in range(3):
		var star: Label = stars.get_child(index) as Label
		var filled: bool = index < _displayed_level
		star.text = "★" if filled else "☆"
		star.add_theme_color_override("font_color", Color(1.0, 0.79, 0.35) if filled else Color(0.32, 0.39, 0.49))


func stars_text() -> String:
	var result: String = ""
	for star: Label in stars.get_children():
		result += star.text
	return result


func refresh(simulation: SpaceSimulation) -> void:
	update_level(simulation.difficulty_level)
	speed_slider.set_value_no_signal(simulation.simulation_speed_multiplier)
	movement_slider.set_value_no_signal(simulation.movement_multiplier)
	spacing_slider.set_value_no_signal(simulation.spacing_multiplier)
	_speed_value.text = "%.1fx" % simulation.simulation_speed_multiplier
	_movement_value.text = "%.1f" % simulation.movement_multiplier
	_spacing_value.text = "%.1f" % simulation.spacing_multiplier
	_set_count("BlueShip", simulation.target_ship_count, 5, 20)
	_set_count("PatrolDrone", simulation.target_drone_count(), 0, 8)
	_set_count("Interceptor", simulation.target_interceptor_count(), 0, 8)


func _set_count(kind: String, value: int, minimum: int, maximum: int) -> void:
	_counts[kind].text = str(value)
	minus_buttons[kind].disabled = value <= minimum
	plus_buttons[kind].disabled = value >= maximum


func toggle_panel() -> void:
	panel.visible = not panel.visible
