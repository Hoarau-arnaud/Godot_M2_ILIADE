extends Node3D


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.42, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.22, 0.02)
	material.emission_energy_multiplier = 2.5
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = get_instance_id()
	var tween: Tween = create_tween().set_parallel(true)
	for _index: int in range(10):
		var shard: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3.ONE * 0.38
		shard.mesh = mesh
		shard.material_override = material
		add_child(shard)
		var direction: Vector3 = Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0))
		if direction.length_squared() < 0.001:
			direction = Vector3.UP
		direction = direction.normalized() * random.randf_range(2.5, 4.5)
		tween.tween_property(shard, "position", direction, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ONE * 0.01, 0.7)
	var flash: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	flash.mesh = sphere
	flash.material_override = material
	add_child(flash)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.0, 0.15)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.01, 0.45).set_delay(0.15)
	tween.chain().tween_callback(queue_free)
