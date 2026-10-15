class_name DemoControls
extends CanvasLayer

const BATTLE_CONTROLS: Script = preload("res://scripts/battle_controls.gd")
var battle_panel: PanelContainer
var presentation_panel: Control
var presentation_title: Label
var presentation_detail: Label
var presentation_keys: Label
var presentation_final: Button
var final_shortcut: Button
var presentation_start: Button
var presentation_replay: Button
var presentation_free: Button
var presentation_button: Button
var game_over_panel: Control
var replay_button: Button
var panel: PanelContainer
var stars: HBoxContainer
var speed_slider: HSlider
var movement_slider: HSlider
var spacing_slider: HSlider
var density_slider: HSlider
var intensity_slider: HSlider
var _density_value: Label
var _intensity_value: Label
var reset_button: Button
var help_panel: PanelContainer
var fullscreen_button: Button
var cinematic_button: Button
var action_button: Button
var normal_button: Button
var free_button: Button
var restart_demo_button: Button
var phase_panel: PanelContainer
var phase_label: Label
var _phase_fade: Tween
var _speed_value: Label
var _movement_value: Label
var _spacing_value: Label
var _counts: Dictionary[String, Label] = {}
var minus_buttons: Dictionary[String, Button] = {}
var plus_buttons: Dictionary[String, Button] = {}
var _displayed_level: int = 0
var pause_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 2
	_build_stars()
	_build_panel()
	_build_help()
	_build_phase_label()
	_build_game_over()
	_build_pause_label()
	_build_presentation()
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	update_level(1)


func _simulation() -> SpaceSimulation:
	return get_parent() as SpaceSimulation


func _fit_panel() -> void:
	panel.offset_bottom = minf(760, get_viewport().get_visible_rect().size.y - 18)


func _build_pause_label() -> void:
	pause_label = _label("PAUSE")
	pause_label.name = "PresentationPause"
	pause_label.anchor_left = 0.5
	pause_label.anchor_right = 0.5
	pause_label.offset_left = -80
	pause_label.offset_right = 80
	pause_label.offset_top = 108
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.add_theme_font_size_override("font_size", 20)
	pause_label.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	pause_label.hide()
	add_child(pause_label)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	var sim: SpaceSimulation = _simulation()
	if key == KEY_F8:
		sim.presentation.jump_to_final()
	elif key == KEY_F7:
		sim.presentation.prepare()
	elif sim.presentation.active() and key == KEY_SPACE:
		sim.presentation.start_or_next()
	elif sim.presentation.active() and key == KEY_R:
		sim.presentation.prepare()
	elif sim.presentation.active() and key in [KEY_D, KEY_ESCAPE]:
		sim.presentation.leave()
	elif key in [KEY_P, KEY_PAUSE]:
		if sim.presentation.active():
			sim.presentation.toggle_pause()
		else:
			sim.set_presentation_paused(not get_tree().paused)
	elif get_tree().paused and event.is_action_pressed("guided_demo_toggle"):
		sim.demonstration.stop()
	elif get_tree().paused and event.is_action_pressed("demo_panel_toggle"):
		toggle_panel()
	elif get_tree().paused and event.is_action_pressed("camera_help_toggle"):
		toggle_help()
	elif get_tree().paused and event.is_action_pressed("presentation_fullscreen"):
		sim.presentation_window.toggle_fullscreen()
	else:
		return
	get_viewport().set_input_as_handled()


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
	layout.add_theme_constant_override("separation", 4)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	var heading: Label = _label("Contrôles")
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.45, 0.87, 1.0))
	layout.add_child(heading)
	var modes: HBoxContainer = HBoxContainer.new()
	free_button = _button("Simulation libre")
	free_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	free_button.pressed.connect(func() -> void: _simulation().demonstration.stop())
	modes.add_child(free_button)
	layout.add_child(modes)
	presentation_button = _button("Démo soutenance — F7")
	presentation_button.pressed.connect(func() -> void: _simulation().presentation.prepare())
	layout.add_child(presentation_button)
	restart_demo_button = _button("Recommencer démo")
	restart_demo_button.pressed.connect(func() -> void: _simulation().presentation.prepare())
	layout.add_child(restart_demo_button)
	_speed_value = _slider_heading(layout, "Vitesse")
	speed_slider = _slider(layout, "Speed", 0.5, 2.5, 1.5)
	speed_slider.value_changed.connect(func(value: float) -> void: _simulation().set_simulation_speed(value))
	_population_row(layout, "BlueShip")
	_population_row(layout, "PatrolDrone")
	_population_row(layout, "Interceptor")
	_population_row(layout, "Capital Ship")
	_movement_value = _slider_heading(layout, "Mouvement")
	movement_slider = _slider(layout, "Movement", 0.5, 2.0, 1.0)
	movement_slider.value_changed.connect(func(value: float) -> void: _simulation().set_movement_multiplier(value))
	_spacing_value = _slider_heading(layout, "Espacement")
	spacing_slider = _slider(layout, "Spacing", 0.8, 1.4, 1.0)
	spacing_slider.value_changed.connect(func(value: float) -> void: _simulation().set_spacing_multiplier(value))
	_density_value = _slider_heading(layout, "Densité rochers")
	density_slider = _slider(layout, "Density", 0.5, 2.5, 1.0)
	density_slider.value_changed.connect(func(value: float) -> void: _simulation().set_rock_density(value))
	_intensity_value = _slider_heading(layout, "Intensité tirs")
	intensity_slider = _slider(layout, "Intensity", 0.5, 3.0, 1.0)
	intensity_slider.value_changed.connect(func(value: float) -> void: _simulation().set_fire_intensity(value))
	reset_button = _button("Reset agents")
	reset_button.name = "ResetAgents"
	reset_button.pressed.connect(func() -> void: _simulation().reset_population_overrides())
	layout.add_child(reset_button)
	fullscreen_button = _button("Plein écran")
	fullscreen_button.toggle_mode = true
	fullscreen_button.pressed.connect(func() -> void: _simulation().presentation_window.toggle_fullscreen())
	layout.add_child(fullscreen_button)
	cinematic_button = _button("Caméra cinématique")
	cinematic_button.toggle_mode = true
	cinematic_button.pressed.connect(func() -> void: _simulation().camera.toggle_cinematic())
	layout.add_child(cinematic_button)
	var presets: HBoxContainer = HBoxContainer.new()
	action_button = _button("Mode spectacle")
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_button.pressed.connect(func() -> void: _simulation().apply_action_preset())
	presets.add_child(action_button)
	normal_button = _button("Normal")
	normal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	normal_button.pressed.connect(func() -> void: _simulation().apply_normal_preset())
	presets.add_child(normal_button)
	layout.add_child(presets)


func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.name = "CameraHelp"
	help_panel.anchor_top = 1.0
	help_panel.anchor_bottom = 1.0
	help_panel.offset_left = 18.0
	help_panel.offset_bottom = -18.0
	help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_panel.add_theme_stylebox_override("panel", _box(Color(0.012, 0.025, 0.065, 0.75), 10))
	add_child(help_panel)
	var label: Label = _label("D / Échap : Simulation libre\nF7 : Démo soutenance · ESPACE : Départ / Suite\nR : Recommencer · Échap : Retour libre\nF8 : Aller à la finale    P / Pause : Pause\nF : Suivi / Libre    C : Cinématique\nClic droit + souris : Orbite (Libre)\nMolette : Zoom (Libre)\nFlèches / W / Z / S / A / Q : Déplacer\nPageUp / E : Monter · PageDown : Descendre\nG / Home : Recentrer\nF11 / Alt+Entrée : Plein écran\nTAB : Réglages    H : Aide")
	label.add_theme_font_size_override("font_size", 13)
	help_panel.add_child(label)


func _box(color: Color, margin: int = 6) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(float(margin))
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.15, 0.55, 0.72, 0.55)
	return style


func _build_phase_label() -> void:
	phase_panel = PanelContainer.new()
	phase_panel.name = "GuidedPhase"
	phase_panel.anchor_left = 0.5
	phase_panel.anchor_right = 0.5
	phase_panel.offset_left = -280
	phase_panel.offset_right = 280
	phase_panel.offset_top = 60
	phase_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_panel.add_theme_stylebox_override("panel", _box(Color(0.015, 0.025, 0.055, 0.65), 8))
	phase_label = _label("")
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 16)
	phase_panel.add_child(phase_label)
	add_child(phase_panel)
	phase_panel.hide()


func set_phase(index: int, title: String, hold_seconds: float = 0) -> void:
	if is_instance_valid(_phase_fade):
		_phase_fade.kill()
	phase_panel.visible = index >= 0
	phase_label.text = "PHASE %d — %s" % [index + 1, title] if index >= 0 else ""
	phase_panel.modulate.a = 0 if index >= 0 else 1
	if index >= 0:
		_phase_fade = create_tween()
		_phase_fade.set_ignore_time_scale(true)
		_phase_fade.tween_property(phase_panel, "modulate:a", 1.0, 0.2 if hold_seconds > 0 else 0.7)
		if hold_seconds > 0:
			_phase_fade.tween_interval(hold_seconds - 0.7)
			_phase_fade.tween_property(phase_panel, "modulate:a", 0.0, 0.5)
			_phase_fade.tween_callback(phase_panel.hide)


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
		"Capital Ship": simulation.set_capital_count_override(simulation.target_capital_count() + amount)


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
	density_slider.set_value_no_signal(simulation.rock_density)
	intensity_slider.set_value_no_signal(simulation.fire_intensity)
	_density_value.text = "%.1f" % simulation.rock_density
	_intensity_value.text = "%.1f" % simulation.fire_intensity
	_speed_value.text = "%.1fx" % simulation.simulation_speed_multiplier
	_movement_value.text = "%.1f" % simulation.movement_multiplier
	_spacing_value.text = "%.1f" % simulation.spacing_multiplier
	_set_count("BlueShip", simulation.target_ship_count, 5, 20)
	_set_count("PatrolDrone", simulation.target_drone_count(), 0, 8)
	_set_count("Interceptor", simulation.target_interceptor_count(), 0, 8)
	_set_count("Capital Ship", simulation.target_capital_count(), 0, 1)
	cinematic_button.set_pressed_no_signal(simulation.camera.mode == SimulationCamera.Mode.CINEMATIC)
	fullscreen_button.set_pressed_no_signal(simulation.presentation_window.is_fullscreen())
	var guided: bool = simulation.demonstration.is_staged()
	free_button.disabled = not guided
	restart_demo_button.disabled = not guided
	speed_slider.editable = not guided
	movement_slider.editable = not guided
	spacing_slider.editable = not guided
	density_slider.editable = not guided
	intensity_slider.editable = not guided
	reset_button.disabled = guided
	action_button.disabled = guided
	normal_button.disabled = guided
	cinematic_button.disabled = guided
	if guided:
		for button: Button in minus_buttons.values():
			button.disabled = true
		for button: Button in plus_buttons.values():
			button.disabled = true


func _set_count(kind: String, value: int, minimum: int, maximum: int) -> void:
	_counts[kind].text = "%d/1" % value if kind == "Capital Ship" and not _simulation().demonstration.is_staged() else str(value)
	minus_buttons[kind].disabled = value <= minimum
	plus_buttons[kind].disabled = value >= maximum


func toggle_panel() -> void:
	panel.visible = not panel.visible


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func _build_game_over() -> void:
	game_over_panel = Control.new()
	game_over_panel.name = "SquadronDestroyed"
	add_child(game_over_panel)
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.04, 0.8)
	game_over_panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	game_over_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	center.add_child(layout)
	var title: Label = _label("ESCADRON DÉTRUIT")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	layout.add_child(title)
	replay_button = _button("REJOUER")
	replay_button.name = "Replay"
	replay_button.focus_mode = Control.FOCUS_ALL
	replay_button.custom_minimum_size = Vector2(420, 72)
	replay_button.add_theme_font_size_override("font_size", 28)
	replay_button.pressed.connect(func() -> void: _simulation().demonstration.restart())
	layout.add_child(replay_button)
	var free: Button = _button("Simulation libre")
	free.custom_minimum_size.y = 42
	free.pressed.connect(func() -> void: _simulation().demonstration.stop())
	layout.add_child(free)
	game_over_panel.hide()


func show_game_over(enabled: bool) -> void:
	game_over_panel.visible = enabled
	if enabled:
		panel.hide()
		help_panel.hide()
		phase_panel.hide()
		replay_button.grab_focus()


func _build_presentation() -> void:
	presentation_panel = Control.new()
	presentation_panel.name = "PresentationScreen"
	add_child(presentation_panel)
	presentation_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.04, 0.72)
	presentation_panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	presentation_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	center.add_child(layout)
	presentation_title = _label("")
	presentation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presentation_title.add_theme_font_size_override("font_size", 34)
	layout.add_child(presentation_title)
	presentation_detail = _label("")
	presentation_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presentation_detail.add_theme_font_size_override("font_size", 22)
	layout.add_child(presentation_detail)
	presentation_start = _button("ESPACE — Démarrer")
	presentation_start.custom_minimum_size = Vector2(440, 58)
	presentation_start.add_theme_font_size_override("font_size", 24)
	presentation_start.pressed.connect(func() -> void: _simulation().presentation.start_or_next())
	layout.add_child(presentation_start)
	presentation_final = _button("ALLER À LA FINALE")
	presentation_final.custom_minimum_size = Vector2(440, 58)
	presentation_final.add_theme_font_size_override("font_size", 24)
	presentation_final.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	presentation_final.pressed.connect(func() -> void: _simulation().presentation.jump_to_final())
	layout.add_child(presentation_final)
	final_shortcut = _button("ALLER À LA FINALE · F8")
	final_shortcut.anchor_left = 1
	final_shortcut.anchor_right = 1
	final_shortcut.offset_left = -276
	final_shortcut.offset_right = -18
	final_shortcut.offset_top = 18
	final_shortcut.offset_bottom = 56
	final_shortcut.pressed.connect(func() -> void: _simulation().presentation.jump_to_final())
	final_shortcut.hide()
	add_child(final_shortcut)
	presentation_replay = _button("REJOUER — R")
	presentation_replay.custom_minimum_size.y = 58
	presentation_replay.add_theme_font_size_override("font_size", 24)
	presentation_replay.pressed.connect(func() -> void: _simulation().presentation.prepare())
	layout.add_child(presentation_replay)
	presentation_free = _button("SIMULATION LIBRE — D / Échap")
	presentation_free.custom_minimum_size.y = 42
	presentation_free.pressed.connect(func() -> void: _simulation().presentation.leave())
	layout.add_child(presentation_free)
	presentation_keys = _label("")
	presentation_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(presentation_keys)
	presentation_panel.hide()


func show_presentation(state: int) -> void:
	var ready: bool = state == PresentationDemonstration.State.READY
	var finished: bool = state == PresentationDemonstration.State.FINISHED
	presentation_panel.visible = ready or finished
	presentation_start.visible = ready
	presentation_final.visible = ready
	refresh_final_shortcut()
	presentation_replay.visible = finished
	presentation_keys.text = "P : pause   ·   ESPACE : phase suivante   ·   R : recommencer" if ready else "R : rejouer   ·   D / Échap : simulation libre"
	presentation_title.text = "DÉMO SOUTENANCE" if ready else "FIN DE LA DÉMONSTRATION"
	presentation_detail.text = "5 phases de 30 secondes, puis laboratoire interactif\nESPACE pour démarrer · F8 pour aller à la finale" if ready else "Vaisseaux bleus détruits : %d\nEnnemis abattus : %d" % [_simulation().death_count, _simulation().enemies_destroyed]
	if state in [PresentationDemonstration.State.INACTIVE, PresentationDemonstration.State.READY, PresentationDemonstration.State.FINISHED]:
		if is_instance_valid(battle_panel):
			battle_panel.hide()
	if ready or finished:
		panel.hide()
		help_panel.hide()
		phase_panel.hide()


func ensure_battle_panel() -> void:
	if is_instance_valid(battle_panel):
		return
	battle_panel = BATTLE_CONTROLS.new() as PanelContainer
	battle_panel.set("controller", get_parent().get_node("PresentationDemonstration"))
	add_child(battle_panel)


func release_battle_panel() -> void:
	if is_instance_valid(battle_panel):
		battle_panel.queue_free()
	battle_panel = null


func refresh_final_shortcut() -> void:
	var controller: PresentationDemonstration = _simulation().presentation
	final_shortcut.visible = controller.state == PresentationDemonstration.State.RUNNING and controller.phase_index < 4
