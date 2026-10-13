extends Node3D

var charge_material: StandardMaterial3D
var engines: Array[MeshInstance3D] = []
var charge_nodes: Array[MeshInstance3D] = []


func _material(color: Color, emission: float = 0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.65
	material.roughness = 0.45
	if emission > 0:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _part(mesh: Mesh, material: Material, offset: Vector3, title: String) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = title
	part.mesh = mesh
	part.material_override = material
	part.position = offset
	add_child(part)
	return part


func _box(size: Vector3, material: Material, offset: Vector3, title: String) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _part(mesh, material, offset, title)


func _ready() -> void:
	var hull: StandardMaterial3D = _material(Color(0.17, 0.13, 0.25))
	var plate: StandardMaterial3D = _material(Color(0.3, 0.24, 0.38))
	var dark: StandardMaterial3D = _material(Color(0.065, 0.055, 0.10))
	var orange: StandardMaterial3D = _material(Color(1, 0.32, 0.06), 2.5)
	var violet: StandardMaterial3D = _material(Color(0.68, 0.13, 1), 3)
	charge_material = _material(Color(1, 0.08, 0.2), 0.2)
	charge_material.emission_enabled = true
	charge_material.emission = Color(1, 0.08, 0.2)
	charge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var wedge: MeshInstance3D = MeshInstance3D.new()
	wedge.set_script(preload("res://scripts/wedge_hull.gd"))
	wedge.set("span", Vector3(18, 14, 66))
	wedge.material_override = hull
	wedge.name = "MassiveHull"
	add_child(wedge)
	_box(Vector3(16, 8, 48), hull, Vector3(0, -1, 3), "Keel")
	_box(Vector3(22, 10, 8), plate, Vector3(0, 0, 29), "SternArmor")
	_box(Vector3(10, 12, 18), plate, Vector3(0, 9, 1), "Bridge")
	_box(Vector3(12, 1.3, 20), dark, Vector3(0, 15, 1), "BridgeRoof")
	_box(Vector3(9, 1.2, 0.6), orange, Vector3(0, 12, 10.3), "BridgeWindows")
	for side: int in [-1, 1]:
		_box(Vector3(23, 4.8, 16), hull, Vector3(side * 20.5, -1, 4), "ArtilleryArm")
		_box(Vector3(8, 7, 31), plate, Vector3(side * 26, -1, 2), "OuterHull")
		for index: int in range(4):
			_box(Vector3(7.5, 0.8, 6), plate, Vector3(side * 26, 3, -8 + index * 7), "HullSection")
			_box(Vector3(0.4, 0.5, 4), orange, Vector3(side * 30.2, 1, -8 + index * 7), "RunningLight")
		for index: int in range(3):
			var z: float = -12 + index * 13
			_box(Vector3(4.2, 2, 4.5), dark, Vector3(side * 8, 6, z), "Battery")
			_box(Vector3(1.3, 1.3, 7), plate, Vector3(side * 8, 7, z + 4), "GunBarrel")
		for index: int in range(2):
			var x: float = side * (10 + index * 13)
			var engine: CylinderMesh = CylinderMesh.new()
			engine.top_radius = 3.2
			engine.bottom_radius = 3.2
			engine.height = 5
			engine.radial_segments = 12
			_part(engine, dark, Vector3(x, -1, 27), "EngineHousing").rotation_degrees.x = 90
			var flame: CylinderMesh = CylinderMesh.new()
			flame.top_radius = 0.15
			flame.bottom_radius = 2.6
			flame.height = 12
			flame.radial_segments = 10
			var exhaust: MeshInstance3D = _part(flame, violet, Vector3(x, -1, 34), "EnginePlume")
			exhaust.rotation_degrees.x = 90
			engines.append(exhaust)
		_box(Vector3(6, 3, 5), dark, Vector3(side * 23, 5, 14), "SalvoLauncher")
		for index: int in range(3):
			charge_nodes.append(_box(Vector3(1.1, 1.1, 0.6), charge_material, Vector3(side * 23 + (index - 1) * 1.6, 5.5, 16.8), "LauncherCharge"))
	charge_nodes.append(_box(Vector3(4, 2, 0.6), charge_material, Vector3(0, 4, 33.1), "HeavyCharge"))
	for index: int in range(4):
		_box(Vector3(10, 1, 6), plate, Vector3(0, 6, -22 + index * 12), "DorsalPlate")


func show_charge(progress: float, time: float, alive: bool) -> void:
	charge_material.emission_energy_multiplier = 0.15 + progress * (2.5 + 0.7 * sin(time * 15)) if alive else 0
	charge_material.albedo_color = Color(1, 0.08 + progress * 0.35, 0.2)
	for engine: MeshInstance3D in engines:
		engine.visible = alive
		engine.scale.y = 0.9 + 0.12 * sin(time * 3)
