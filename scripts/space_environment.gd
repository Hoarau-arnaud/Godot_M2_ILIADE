class_name SpaceEnvironment
extends Node3D

@export_range(100, 1200, 1) var star_count: int = 650

const LAYER_EXTENTS: Array[Vector3] = [Vector3(1300, 850, 1800), Vector3(340, 220, 850), Vector3(85, 60, 260)]
const STAR_RADII: Array[float] = [0.6, 0.22, 0.09]

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _star_layers: Array[MultiMeshInstance3D] = []
var _star_positions: Array[PackedVector3Array] = []
var _star_sizes: Array[PackedFloat32Array] = []


func _ready() -> void:
	_random.seed = 7421
	var far_count: int = int(float(star_count) * 0.62)
	var mid_count: int = int(float(star_count) * 0.3)
	_create_star_layer(0, far_count)
	_create_star_layer(1, mid_count)
	_create_star_layer(2, star_count - far_count - mid_count)
	_add_planet(Vector3(-260.0, 150.0, -1250.0), 100.0, Color(0.09, 0.2, 0.36))
	_add_planet(Vector3(400.0, -180.0, -1600.0), 65.0, Color(0.3, 0.14, 0.08))
	_add_planet(Vector3(-115.0, 135.0, -1160.0), 18.0, Color(0.3, 0.33, 0.4))
	_create_nebula()


func _create_star_layer(layer: int, count: int) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = STAR_RADII[layer]
	mesh.height = STAR_RADII[layer] * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.75, 0.86, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.7, 0.83, 1.0)
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	var stars: MultiMeshInstance3D = MultiMeshInstance3D.new()
	stars.name = "StarLayer_%d" % layer
	var multi_mesh: MultiMesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = count
	stars.multimesh = multi_mesh
	add_child(stars)
	_star_layers.append(stars)
	var positions: PackedVector3Array = PackedVector3Array()
	var sizes: PackedFloat32Array = PackedFloat32Array()
	var extent: Vector3 = LAYER_EXTENTS[layer]
	for index: int in range(count):
		var star_position: Vector3 = Vector3(_random.randf_range(-extent.x, extent.x), _random.randf_range(-extent.y, extent.y), _random.randf_range(-extent.z, extent.z * 0.25))
		var size_value: float = _random.randf_range(0.55, 1.8)
		positions.append(star_position)
		sizes.append(size_value)
		multi_mesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size_value), star_position))
	_star_positions.append(positions)
	_star_sizes.append(sizes)


func recycle_stars(center: Vector3) -> void:
	for layer: int in range(_star_layers.size()):
		var extent: Vector3 = LAYER_EXTENTS[layer]
		var positions: PackedVector3Array = _star_positions[layer]
		for index: int in range(positions.size()):
			var star_position: Vector3 = positions[index]
			var relative: Vector3 = star_position - center
			if absf(relative.x) <= extent.x and absf(relative.y) <= extent.y and relative.z >= -extent.z and relative.z <= extent.z * 0.25:
				continue
			# Le recyclage fonctionne aussi après un déplacement libre en arrière ou sur les côtés.
			star_position = center + Vector3(
				wrapf(relative.x, -extent.x, extent.x),
				wrapf(relative.y, -extent.y, extent.y),
				wrapf(relative.z, -extent.z, extent.z * 0.25)
			)
			positions[index] = star_position
			_star_layers[layer].multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _star_sizes[layer][index]), star_position))
		_star_positions[layer] = positions


func _add_planet(planet_position: Vector3, radius: float, color: Color) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	var planet: MeshInstance3D = MeshInstance3D.new()
	planet.mesh = mesh
	planet.material_override = material
	planet.position = planet_position
	planet.name = "DecorativePlanet"
	add_child(planet)
	if radius > 50.0:
		var atmosphere: MeshInstance3D = MeshInstance3D.new()
		atmosphere.mesh = mesh
		atmosphere.scale = Vector3.ONE * 1.025
		var haze: StandardMaterial3D = StandardMaterial3D.new()
		haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		haze.albedo_color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.1)
		atmosphere.material_override = haze
		planet.add_child(atmosphere)


func _create_nebula() -> void:
	var nebula: MeshInstance3D = MeshInstance3D.new()
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(1500.0, 700.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://materials/nebula.gdshader")
	nebula.mesh = mesh
	nebula.material_override = material
	nebula.position = Vector3(250.0, 100.0, -2200.0)
	nebula.name = "DistantNebula"
	add_child(nebula)
