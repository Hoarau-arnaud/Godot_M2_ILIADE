extends Node3D

static var _material: StandardMaterial3D
static var _shard_mesh: BoxMesh
static var _flash_mesh: SphereMesh


func _ready() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.albedo_color = Color(1.0, 0.42, 0.08)
		_material.emission_enabled = true
		_material.emission = Color(1.0, 0.22, 0.02)
		_material.emission_energy_multiplier = 2.5
		_shard_mesh = BoxMesh.new()
		_shard_mesh.size = Vector3.ONE * 0.38
		_flash_mesh = SphereMesh.new()
		_flash_mesh.radius = 0.5
		_flash_mesh.height = 1.0
		_flash_mesh.radial_segments = 12
		_flash_mesh.rings = 6
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = get_instance_id()
	var tween: Tween = create_tween().set_parallel(true)
	for _index: int in range(10):
		var shard: MeshInstance3D = MeshInstance3D.new()
		shard.mesh = _shard_mesh
		shard.material_override = _material
		add_child(shard)
		var direction: Vector3 = Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0))
		if direction.length_squared() < 0.001:
			direction = Vector3.UP
		direction = direction.normalized() * random.randf_range(2.5, 4.5)
		tween.tween_property(shard, "position", direction, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ONE * 0.01, 0.7)
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.mesh = _flash_mesh
	flash.material_override = _material
	add_child(flash)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.0, 0.15)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.01, 0.45).set_delay(0.15)
	tween.chain().tween_callback(queue_free)
