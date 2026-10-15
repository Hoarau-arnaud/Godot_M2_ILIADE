extends Node3D

static var _material: StandardMaterial3D
static var _shard_mesh: BoxMesh
static var _flash_mesh: SphereMesh


var effect_scale: float = 1.0
var effect_duration: float = 0.7
var shard_count: int = 10
var flash_strength: float = 2.5
var blue_ship_death: bool = false
var age_real: float = 0
var _shard_batch: MultiMesh
var _shard_rotations: Array[Basis] = []
var _directions: Array[Vector3] = []
var _flash: MeshInstance3D
var _fireball: MeshInstance3D
var _ring: MeshInstance3D
var _ball_material: StandardMaterial3D
var _light: OmniLight3D
static var _white_material: StandardMaterial3D
static var _ring_mesh: TorusMesh


func configure_blue_ship_death() -> void:
	blue_ship_death = true
	effect_scale = 2.8
	effect_duration = 1.2 # Secondes réelles, même à la vitesse de démonstration 2x.
	shard_count = 22
	flash_strength = 8.0


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
	if blue_ship_death:
		_build_blue_death()
		return
	set_process(false)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = get_instance_id()
	var tween: Tween = create_tween().set_parallel(true)
	for _index: int in range(shard_count):
		var shard: MeshInstance3D = MeshInstance3D.new()
		shard.mesh = _shard_mesh
		shard.material_override = _material
		add_child(shard)
		var direction: Vector3 = Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0))
		if direction.length_squared() < 0.001:
			direction = Vector3.UP
		direction = direction.normalized() * random.randf_range(2.5, 4.5)
		tween.tween_property(shard, "position", direction * effect_scale, effect_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ONE * 0.01, effect_duration)
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.mesh = _flash_mesh
	flash.material_override = _material
	add_child(flash)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.0, 0.15)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.01, 0.45).set_delay(0.15)
	tween.chain().tween_callback(queue_free)


func _part(part_name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part


func _build_blue_death() -> void:
	add_to_group("blue_death_explosions")
	if _white_material == null:
		_white_material = _material.duplicate() as StandardMaterial3D
		_white_material.albedo_color = Color(1, 0.94, 0.65)
		_white_material.emission = Color(1, 0.85, 0.4)
		_white_material.emission_energy_multiplier = flash_strength
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.91
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 6
	_flash = _part("WhiteFlash", _flash_mesh, _white_material)
	_ball_material = _material.duplicate() as StandardMaterial3D
	_ball_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fireball = _part("OrangeFireball", _flash_mesh, _ball_material)
	_ring = _part("ShockWave", _ring_mesh, _white_material)
	# Onde orientée vers la caméra ; aucune physique associée.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		_ring.quaternion = Quaternion(Vector3.UP, (camera.global_position - global_position).normalized())
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = get_instance_id()
	_shard_batch = MultiMesh.new()
	_shard_batch.transform_format = MultiMesh.TRANSFORM_3D
	_shard_batch.mesh = _shard_mesh
	_shard_batch.instance_count = shard_count
	var fragments: MultiMeshInstance3D = MultiMeshInstance3D.new()
	fragments.name = "LuminousShards"
	fragments.multimesh = _shard_batch
	fragments.material_override = _material
	fragments.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fragments)
	for index: int in range(shard_count):
		_shard_rotations.append(Basis.from_euler(Vector3(random.randf() * TAU, random.randf() * TAU, random.randf() * TAU)))
		var direction: Vector3 = Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1)).normalized()
		_directions.append(direction * random.randf_range(3.0, 5.0) * effect_scale)
	_light = OmniLight3D.new()
	_light.name = "WarmDeathLight"
	_light.light_color = Color(1, 0.6, 0.15)
	_light.omni_range = 14
	_light.shadow_enabled = false
	add_child(_light)
	_process(0)


func _process(delta: float) -> void:
	if not blue_ship_death:
		return
	age_real += delta / maxf(Engine.time_scale, 0.01)
	var progress: float = clampf(age_real / effect_duration, 0, 1)
	_flash.visible = age_real < 0.16
	_flash.scale = Vector3.ONE * lerpf(0.2, 6.0, clampf(age_real / 0.12, 0, 1))
	_fireball.visible = age_real < 0.7
	var ball: float = sin(clampf(age_real / 0.7, 0, 1) * PI)
	_fireball.scale = Vector3.ONE * maxf(0.01, ball * effect_scale * 1.8)
	_ball_material.albedo_color = Color(1, lerpf(0.5, 0.08, progress), 0.02, clampf(1 - age_real / 0.7, 0, 1))
	_ball_material.emission_energy_multiplier = flash_strength * maxf(0, 1 - age_real / 0.7)
	_ring.visible = age_real < 0.58
	var ring_progress: float = clampf(age_real / 0.5, 0, 1)
	_ring.scale = Vector3(1, maxf(0.02, 1 - ring_progress), 1) * lerpf(1, 4.8, ring_progress)
	var shard_scale: float = effect_scale * lerpf(1, 0.03, progress)
	var travel: float = 1 - pow(1 - progress, 2)
	for index: int in range(shard_count):
		_shard_batch.set_instance_transform(index, Transform3D(_shard_rotations[index].scaled(Vector3.ONE * shard_scale), _directions[index] * travel))
	_light.visible = age_real < 0.3
	_light.light_energy = flash_strength * pow(maxf(0, 1 - age_real / 0.3), 2)
	if age_real >= effect_duration:
		queue_free()
