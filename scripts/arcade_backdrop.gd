class_name ArcadeBackdrop
extends Node3D

# Silhouettes et flashes décoratifs ; ni body, ni groupe de combat, ni agent.
var flashes: MultiMeshInstance3D

func _ready() -> void:
	var hull: PrismMesh = PrismMesh.new()
	hull.size = Vector3(150, 28, 260)
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.09, 0.2)
	metal.emission_enabled = true
	metal.emission = Color(0.015, 0.01, 0.035)
	hull.material = metal
	var fleet: MultiMeshInstance3D = MultiMeshInstance3D.new()
	fleet.name = "DistantWarSilhouettes"
	fleet.multimesh = MultiMesh.new()
	fleet.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	fleet.multimesh.mesh = hull
	fleet.multimesh.instance_count = 7
	add_child(fleet)
	flashes = MultiMeshInstance3D.new()
	flashes.name = "DistantArtilleryFlashes"
	flashes.multimesh = MultiMesh.new()
	flashes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	flashes.multimesh.use_colors = true
	var spark: SphereMesh = SphereMesh.new()
	spark.radius = 1
	spark.height = 2
	spark.radial_segments = 6
	spark.rings = 3
	var light: StandardMaterial3D = StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.vertex_color_use_as_albedo = true
	light.emission_enabled = true
	light.emission = Color(0.6, 0.1, 0.9)
	light.emission_energy_multiplier = 2
	spark.material = light
	flashes.multimesh.mesh = spark
	flashes.multimesh.instance_count = 14
	add_child(flashes)
	for index: int in range(7):
		var point: Vector3 = Vector3(-1800 + index * 580, 450 + sin(index * 2.4) * 330, -2800 - (index % 3) * 500)
		fleet.multimesh.set_instance_transform(index, Transform3D(Basis.from_euler(Vector3(0.1, index * 0.12, 0.2)), point))
		for side: int in range(2):
			flashes.multimesh.set_instance_color(index * 2 + side, Color(1, 0.3 if side == 0 else 0.6, 0.65))
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "TurquoiseOrbitalRing"
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 5350
	band.outer_radius = 5550
	band.rings = 96
	band.ring_segments = 4
	ring.mesh = band
	ring.position = Vector3(4500, -4700, -10500)
	ring.rotation_degrees = Vector3(27, 15, -18)
	var dust: StandardMaterial3D = StandardMaterial3D.new()
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust.albedo_color = Color(0.15, 0.65, 0.8, 0.14)
	dust.emission_enabled = true
	dust.emission = Color(0.02, 0.1, 0.12)
	ring.material_override = dust
	add_child(ring)


func _process(_delta: float) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	for index: int in range(14):
		var ship_index: int = index / 2
		var point: Vector3 = Vector3(-1800 + ship_index * 580 + (index % 2 * 2 - 1) * 70, 450 + sin(ship_index * 2.4) * 330, -2670 - (ship_index % 3) * 500)
		var intensity: float = pow(maxf(sin(time * 2.3 + index * 2.1), 0), 14)
		flashes.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (3 + intensity * 20)), point))
