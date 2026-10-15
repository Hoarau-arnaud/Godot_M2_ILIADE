extends PanelContainer

# Interface propre à PRESENTATION ; aucune connexion aux contrôles FREE.
var controller: Node
var sliders: Dictionary = {}
var values: Dictionary = {}
var counters: Label
var status: Label
var _refresh_at: float = 0
const ROWS: Array[Array] = [["patrol", "Drones verts", 0, 30, 1], ["interceptor", "Intercepteurs", 0, 30, 1], ["capital", "Vaisseaux capitaux", 0, 10, 1], ["fire", "Fréquence tirs ennemis", 0.5, 4, 0.1], ["width", "Largeur projectiles", 0.5, 3, 0.1], ["grid_width", "Épaisseur grilles", 0.5, 3, 0.1], ["speed", "Vitesse projectiles", 0.5, 2, 0.1], ["damage", "Dégâts ennemis", 1, 3, 1], ["density", "Densité astéroïdes", 0, 2.5, 0.1], ["mega", "Mega / Colossal", 0, 3, 1], ["aggression", "Agressivité", 0.5, 3, 0.1]]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "BattleControls"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.005, 0.02, 0.05, 0.88)
	style.border_color = Color(0.2, 0.58, 0.74, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 6)
	scroll.add_child(layout)
	var title: Label = Label.new()
	title.text = "LABORATOIRE DE BATAILLE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.45, 0.88, 1))
	layout.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	layout.add_child(status)
	counters = Label.new()
	counters.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counters.add_theme_font_size_override("font_size", 14)
	layout.add_child(counters)
	for row: Array in ROWS:
		var line: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = row[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		line.add_child(label)
		var value: Label = Label.new()
		value.add_theme_font_size_override("font_size", 14)
		line.add_child(value)
		values[row[0]] = value
		layout.add_child(line)
		var slider: HSlider = HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.custom_minimum_size.y = 21
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(_changed.bind(str(row[0])))
		layout.add_child(slider)
		sliders[row[0]] = slider
	var buttons: HBoxContainer = HBoxContainer.new()
	for caption: String in ["RESET", "CHAOS", "TERMINER"]:
		var button: Button = Button.new()
		button.text = caption
		button.name = caption
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 34
		button.pressed.connect(_button.bind(caption))
		buttons.add_child(button)
	layout.add_child(buttons)
	get_viewport().size_changed.connect(_fit)
	_fit()
	hide()

func _fit() -> void:
	position = Vector2(12, 110)
	size = Vector2(300, maxf(250, get_viewport().get_visible_rect().size.y - 128))

func _changed(value: float, key: String) -> void:
	if is_instance_valid(controller):
		controller.call("set_setting", key, value)
		refresh()

func _button(caption: String) -> void:
	if caption == "TERMINER":
		controller.call("finish_battle")
	else:
		controller.call("reset_battle", caption == "CHAOS")
	refresh()

func refresh() -> void:
	if not is_instance_valid(controller):
		return
	var settings: Dictionary = controller.get("settings")
	for key: String in sliders:
		(sliders[key] as HSlider).set_value_no_signal(float(settings[key]))
		(values[key] as Label).text = str(int(settings[key])) if key in ["patrol", "interceptor", "capital", "damage", "mega"] else "%.1f×" % float(settings[key])
	var sim: SpaceSimulation = controller.get_parent() as SpaceSimulation
	counters.text = "Blue actifs : %d   ·   Ennemis actifs : %d\nBlue détruits : %d   ·   Ennemis abattus : %d" % [sim.ships.size(), sim.drones.size() + sim.interceptors.size() + sim.capitals.size(), sim.death_count, sim.enemies_destroyed]
	status.text = "Finale interactive · ESPACE pour terminer" if int(controller.get("state")) == 5 else "Finale automatique · 30 secondes"

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_at -= delta / maxf(Engine.time_scale, 0.01)
	if _refresh_at <= 0:
		_refresh_at = 0.2
		refresh()
