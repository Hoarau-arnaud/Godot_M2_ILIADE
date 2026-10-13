class_name SpaceEnvironment
extends Node3D

@export_range(100, 1200, 1) var star_count: int = 650
@export_range(0, 96, 1) var streak_count: int = 48

const LAYER_EXTENTS: Array[Vector3] = [Vector3(1300, 850, 1800), Vector3(340, 220, 850), Vector3(85, 60, 260)]
const STAR_RADII: Array[float] = [0.6, 0.22, 0.09]

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _star_layers: Array[MultiMeshInstance3D] = []
var _star_positions: Array[PackedVector3Array] = []
var _star_sizes: Array[PackedFloat32Array] = []
var _streaks: MultiMeshInstance3D
var _streak_positions: PackedVector3Array = PackedVector3Array()
var _streak_lengths: PackedFloat32Array = PackedFloat32Array()
var _debris: MultiMeshInstance3D
var _debris_points: PackedVector3Array = PackedVector3Array()
var _debris_bases: Array[Basis] = []
var _backdrop: Node3D
var guided_speed_effect: float = 1
var streak_length_multiplier: float = 1.0


func _ready() -> void:
	_random.seed = 7421
	var far_count: int = int(float(star_count) * 0.62)
	var mid_count: int = int(float(star_count) * 0.3)
	_create_star_layer(0, far_count)
	_create_star_layer(1, mid_count)
	_create_star_layer(2, star_count - far_count - mid_count)
	_create_streaks()
	_backdrop = Node3D.new()
	_backdrop.name = "DistantBackdrop"
	add_child(_backdrop)
	_add_planet(Vector3(4500, -4700, -10500), 4800, Color(0.07, 0.15, 0.29))
	_add_planet(Vector3(-1900, 850, -9800), 160, Color(0.28, 0.12, 0.065))
	_add_planet(Vector3(2000, 950, -9300), 440, Color(0.18, 0.1, 0.29))
	_add_planet(Vector3(-400, 950, -7200), 100, Color(0.3, 0.33, 0.4))
	_create_nebula("VioletNebula", Vector3(2000, 650, -10000), Vector2(7000, 3500), Color(0.08, 0.05, 0.22), Color(0.28, 0.06, 0.3), 0.3)
	_create_nebula("CyanNebula", Vector3(-1900, -500, -8500), Vector2(5200, 2800), Color(0.015, 0.07, 0.16), Color(0.04, 0.2, 0.26), 0.24)
	_create_nebula("GalaxyBand", Vector3(0, 1100, -14000), Vector2(13000, 1500), Color(0.08, 0.1, 0.19), Color(0.24, 0.09, 0.26), 0.25)
	_create_distant_stars()
	_create_orbital_debris()
	_create_near_debris()


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


func recycle_stars(center: Vector3, delta: float = 0.0, demo_pace: float = 1.0, fleet_velocity: Vector3 = Vector3.ZERO) -> void:
	for layer: int in range(_star_layers.size()):
		var extent: Vector3 = LAYER_EXTENTS[layer]
		var positions: PackedVector3Array = _star_positions[layer]
		for index: int in range(positions.size()):
			var star_position: Vector3 = positions[index]
			# Le proche défile plus vite ; le lointain garde sa parallaxe naturelle.
			star_position.z += ([0.0, 4.0, 18.0][layer] as float) * guided_speed_effect * delta
			var relative: Vector3 = star_position - center
			if absf(relative.x) <= extent.x and absf(relative.y) <= extent.y and relative.z >= -extent.z and relative.z <= extent.z * 0.25:
				if layer > 0 and delta > 0:
					positions[index] = star_position
					_star_layers[layer].multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _star_sizes[layer][index]), star_position))
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
	_update_streaks(center, delta, demo_pace, fleet_velocity)
	for index: int in range(_debris_points.size()):
		var relative: Vector3 = _debris_points[index] - center
		var point: Vector3 = center + Vector3(wrapf(relative.x, -200, 200), wrapf(relative.y, -135, 135), wrapf(relative.z + delta * 3, -600, 140))
		_debris_points[index] = point
		_debris.multimesh.set_instance_transform(index, Transform3D(_debris_bases[index], point))
	# Ciel lointain sans collision : profondeur constante, légère parallaxe X/Y.
	_backdrop.position = Vector3(center.x * 0.08, center.y * 0.08, center.z)


func _create_streaks() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.5, 0.75, 0.9, 0.35)
	material.emission_enabled = true
	material.emission = Color(0.16, 0.34, 0.45)
	mesh.material = material
	_streaks = MultiMeshInstance3D.new()
	_streaks.name = "NearStarStreaks"
	_streaks.multimesh = MultiMesh.new()
	_streaks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_streaks.multimesh.mesh = mesh
	_streaks.multimesh.instance_count = streak_count
	add_child(_streaks)
	for index: int in range(streak_count):
		var point: Vector3 = Vector3(_random.randf_range(-75, 75), _random.randf_range(-48, 48), _random.randf_range(-160, 60))
		_streak_positions.append(point)
		_streak_lengths.append(_random.randf_range(1.2, 3.0))
		_streaks.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, point))


func _update_streaks(center: Vector3, delta: float, demo_pace: float, fleet_velocity: Vector3) -> void:
	streak_length_multiplier = clampf(1.0 + maxf(demo_pace - 1.0, 0.0) * 0.75 + fleet_velocity.length() / 35.0, 1.0, 2.5) * guided_speed_effect
	var drift: Vector3 = -fleet_velocity.normalized() if fleet_velocity.length_squared() > 0.01 else Vector3.BACK
	var alignment: Basis = Basis.looking_at(-drift, Vector3.UP)
	for index: int in range(_streak_positions.size()):
		var point: Vector3 = _streak_positions[index] + drift * (32.0 + fleet_velocity.length() * 0.8) * guided_speed_effect * delta
		var relative: Vector3 = point - center
		point = center + Vector3(wrapf(relative.x, -75, 75), wrapf(relative.y, -48, 48), wrapf(relative.z, -160, 60))
		_streak_positions[index] = point
		_streaks.multimesh.set_instance_transform(index, Transform3D(alignment.scaled(Vector3(1, 1, _streak_lengths[index] * streak_length_multiplier)), point))


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
	if radius > 1000:
		planet.name = "NearbyPlanet"
		var surface: ShaderMaterial = ShaderMaterial.new()
		surface.shader = preload("res://materials/planet_surface.gdshader")
		planet.material_override = surface
	_backdrop.add_child(planet)
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
		if radius > 1000:
			atmosphere.name = "AtmosphericHalo"
			haze.albedo_color = Color(0.12, 0.42, 0.68, 0.085)
			haze.emission_enabled = true
			haze.emission = Color(0.015, 0.07, 0.12)


func _create_orbital_debris() -> void:
	# Une seule MultiMesh : anneau décoratif sans body, perception ou collision.
	var debris: MultiMeshInstance3D = MultiMeshInstance3D.new()
	debris.name = "OrbitalDebrisBand"
	var rock: SphereMesh = SphereMesh.new()
	rock.radius = 1
	rock.height = 2
	rock.radial_segments = 6
	rock.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.27, 0.34)
	material.roughness = 1
	rock.material = material
	debris.multimesh = MultiMesh.new()
	debris.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	debris.multimesh.mesh = rock
	debris.multimesh.instance_count = 360
	_backdrop.add_child(debris)
	for index: int in range(360):
		var angle: float = _random.randf_range(-1.25, 1.1)
		var radius: float = _random.randf_range(5500, 6000)
		var point: Vector3 = Vector3(4500, -4700, -10500) + Vector3(sin(angle) * radius, cos(angle) * radius * 0.72, cos(angle) * radius * 0.45)
		point += Vector3(_random.randf_range(-100, 100), _random.randf_range(-100, 100), _random.randf_range(-120, 120))
		var size_value: float = _random.randf_range(7, 25)
		debris.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(size_value, size_value * 0.7, size_value * 0.85)), point))


func _create_nebula(label: String, point: Vector3, dimensions: Vector2, first: Color, second: Color, alpha: float) -> void:
	var nebula: MeshInstance3D = MeshInstance3D.new()
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = dimensions
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://materials/nebula.gdshader")
	material.set_shader_parameter("cloud_color_a", first)
	material.set_shader_parameter("cloud_color_b", second)
	material.set_shader_parameter("opacity", alpha)
	nebula.mesh = mesh
	nebula.material_override = material
	nebula.position = point
	nebula.name = label
	if label == "GalaxyBand":
		nebula.rotation.z = -0.2
	_backdrop.add_child(nebula)


func _create_distant_stars() -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 8.0
	mesh.height = 16.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.3, 0.35, 0.5)
	mesh.material = material
	var cluster: MultiMeshInstance3D = MultiMeshInstance3D.new()
	cluster.name = "DistantStarClusters"
	cluster.multimesh = MultiMesh.new()
	cluster.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cluster.multimesh.use_colors = true
	cluster.multimesh.mesh = mesh
	cluster.multimesh.instance_count = 120
	_backdrop.add_child(cluster)
	var centers: Array[Vector3] = [Vector3(-2400, 1300, -9200), Vector3(2600, -1500, -8300), Vector3(600, 1800, -7400)]
	var colors: Array[Color] = [Color(0.5, 0.4, 0.7), Color(0.8, 0.52, 0.3), Color(0.4, 0.65, 0.75)]
	for index: int in range(120):
		var section: int = index / 40
		var point: Vector3 = centers[section] + Vector3(_random.randfn(0, 340), _random.randfn(0, 130), _random.randfn(0, 250))
		cluster.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _random.randf_range(0.5, 1.2)), point))
		cluster.multimesh.set_instance_color(index, colors[section])
	var sun: MeshInstance3D = MeshInstance3D.new()
	var sun_mesh: SphereMesh = SphereMesh.new()
	sun_mesh.radius = 80
	sun_mesh.height = 160
	sun_mesh.radial_segments = 16
	sun_mesh.rings = 8
	sun.mesh = sun_mesh
	var glow: StandardMaterial3D = material.duplicate() as StandardMaterial3D
	glow.albedo_color = Color(1.0, 0.65, 0.28)
	glow.emission = Color(1.0, 0.43, 0.12)
	glow.emission_energy_multiplier = 2.0
	sun.material_override = glow
	sun.position = Vector3(-1700, -850, -8500)
	sun.name = "DistantSun"
	_backdrop.add_child(sun)


func _create_near_debris() -> void:
	_debris = MultiMeshInstance3D.new()
	_debris.name = "SurroundingOrbitalDebris"
	_debris.multimesh = MultiMesh.new()
	_debris.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var rock: SphereMesh = SphereMesh.new()
	rock.radius = 1
	rock.height = 2
	rock.radial_segments = 6
	rock.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.38, 0.48)
	material.roughness = 1
	rock.material = material
	_debris.multimesh.mesh = rock
	_debris.multimesh.instance_count = 1000
	add_child(_debris)
	for index: int in range(1000):
		var point: Vector3 = Vector3(_random.randf_range(-200, 200), _random.randf_range(-135, 135), _random.randf_range(-600, 140))
		# Éviter que le décor sans collision masque la simulation proche.
		if absf(point.x) < 65 and absf(point.y) < 45:
			point.x += 95 if point.x > 0 else -95
		var size_value: float = _random.randf_range(0.3, 3.5)
		var orientation: Basis = Basis.from_euler(Vector3(_random.randf(), _random.randf(), _random.randf()) * TAU).scaled(Vector3(size_value, size_value * 0.6, size_value * 0.8))
		_debris_points.append(point)
		_debris_bases.append(orientation)
		_debris.multimesh.set_instance_transform(index, Transform3D(orientation, point))
