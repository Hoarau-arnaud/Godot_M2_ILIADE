class_name SpaceAsteroid
extends AnimatableBody3D

enum SizeCategory { SMALL, MEDIUM, LARGE }
enum MotionType { STATIC, LINEAR, DIAGONAL, VERTICAL_SWEEP, CIRCULAR, ARC }

@export var size_category: SizeCategory = SizeCategory.MEDIUM
@export_range(1.0, 7.0, 0.1) var diameter: float = 3.0
@export var shape_seed: int = 1
@export var rotation_speed: float = 0.1
@export_category("Trajectoire environnementale")
@export var motion_type: MotionType = MotionType.STATIC
@export var motion_velocity: Vector3 = Vector3(6, 0, 0)
@export var motion_duration: float = 14.0
@export var motion_start_delay: float = 0.0
@export var motion_amplitude: Vector2 = Vector2(18, 12)
@export var motion_period: float = 18.0
@export var motion_phase: float = 0.0
@export var orbit_axis_u: Vector3 = Vector3.RIGHT
@export var orbit_axis_v: Vector3 = Vector3.UP

var avoidance_radius: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var motion_elapsed: float = 0.0
var motion_center: Vector3 = Vector3.ZERO
var _rotation_axis: Vector3 = Vector3.UP
var _spin_factor: float = 1.0
@onready var visuals: Node3D = $Visuals


func _ready() -> void:
	process_physics_priority = -20
	# Placer le début de trajectoire immédiatement, avant les contrôles de spawn.
	sync_to_physics = false
	motion_center = position
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = shape_seed
	var radius: float = maxf(diameter * 0.5, 0.1)
	_rotation_axis = Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0), random.randf_range(-1.0, 1.0))
	_rotation_axis = _rotation_axis.normalized() if _rotation_axis.length_squared() > 0.001 else Vector3.UP
	_spin_factor = random.randf_range(0.55, 1.2)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var palette: Array[Color] = [Color(0.3, 0.34, 0.39), Color(0.52, 0.5, 0.46), Color(0.38, 0.29, 0.23)]
	material.albedo_color = palette[absi(shape_seed) % palette.size()] * random.randf_range(0.85, 1.1)
	material.albedo_color.a = 1.0
	material.roughness = 0.96
	var core_scale: Vector3 = Vector3(random.randf_range(0.65, 0.94), random.randf_range(0.5, 0.86), random.randf_range(0.65, 0.94)) * radius
	_add_lobe(Vector3.ZERO, core_scale, Vector3.ZERO, material, false)
	var lobe_count: int = 1 + int(size_category)
	for index: int in range(lobe_count):
		var angle: float = TAU * float(index) / float(lobe_count) + random.randf_range(-0.45, 0.45)
		var offset: Vector3 = Vector3(cos(angle), random.randf_range(-0.65, 0.65), sin(angle)).normalized() * radius * 0.5
		var lobe_scale: Vector3 = Vector3(random.randf_range(0.3, 0.5), random.randf_range(0.28, 0.46), random.randf_range(0.3, 0.5)) * radius
		var lobe_rotation: Vector3 = Vector3(random.randf_range(-PI, PI), random.randf_range(-PI, PI), random.randf_range(-PI, PI))
		var lobe_material: StandardMaterial3D = material.duplicate() as StandardMaterial3D
		lobe_material.albedo_color *= random.randf_range(0.85, 1.08)
		lobe_material.albedo_color.a = 1.0
		_add_lobe(offset, lobe_scale, lobe_rotation, lobe_material, size_category == SizeCategory.LARGE and index % 2 == 0)
	if motion_type != MotionType.STATIC:
		position = motion_center + trajectory_offset(0.0)
		velocity = trajectory_velocity(0.0)
	# Le script travaille déjà dans _physics_process : pas de seconde synchronisation
	# qui restaurerait une ancienne pose lisible par les perceptions locales.


func _physics_process(delta: float) -> void:
	motion_elapsed += delta
	var next_position: Vector3 = position
	if motion_type != MotionType.STATIC:
		next_position = motion_center + trajectory_offset(motion_elapsed)
		velocity = trajectory_velocity(motion_elapsed)
		var parent_3d: Node3D = get_parent_node_3d()
		if parent_3d != null:
			velocity = parent_3d.global_basis * velocity
	else:
		velocity = Vector3.ZERO
	# Le corps et ses formes convexes suivent la même trajectoire et la même rotation.
	# Une seule écriture au pas physique pour garder rotation et position cohérentes.
	transform = Transform3D(basis.rotated(_rotation_axis, rotation_speed * _spin_factor * delta), next_position)


func trajectory_offset(time: float) -> Vector3:
	var elapsed: float = maxf(time - motion_start_delay, 0.0)
	if motion_type == MotionType.STATIC:
		return Vector3.ZERO
	if motion_type == MotionType.CIRCULAR:
		var angle: float = motion_phase + TAU * elapsed / maxf(motion_period, 1.0)
		return orbit_axis_u * motion_amplitude.x * cos(angle) + orbit_axis_v * motion_amplitude.y * sin(angle)
	var phase: float = fposmod(elapsed / maxf(motion_duration, 1.0), 2.0)
	var progress: float = phase if phase <= 1.0 else 2.0 - phase
	var offset: Vector3 = motion_velocity * motion_duration * (progress - 0.5)
	if motion_type == MotionType.ARC:
		offset += orbit_axis_v * motion_amplitude.y * sin(TAU * progress)
	return offset


func trajectory_velocity(time: float) -> Vector3:
	if motion_type == MotionType.STATIC or time < motion_start_delay:
		return Vector3.ZERO
	var elapsed: float = time - motion_start_delay
	if motion_type == MotionType.CIRCULAR:
		var frequency: float = TAU / maxf(motion_period, 1.0)
		var angle: float = motion_phase + frequency * elapsed
		return (-orbit_axis_u * motion_amplitude.x * sin(angle) + orbit_axis_v * motion_amplitude.y * cos(angle)) * frequency
	var phase: float = fposmod(elapsed / maxf(motion_duration, 1.0), 2.0)
	var progress: float = phase if phase <= 1.0 else 2.0 - phase
	var travel_sign: float = 1.0 if phase < 1.0 else -1.0
	var result: Vector3 = motion_velocity
	if motion_type == MotionType.ARC:
		result += orbit_axis_v * motion_amplitude.y * TAU / maxf(motion_duration, 1.0) * cos(TAU * progress)
	return result * travel_sign


func motion_depth_margin() -> float:
	if motion_type == MotionType.STATIC:
		return 0.0
	if motion_type == MotionType.CIRCULAR:
		return absf(orbit_axis_u.z) * motion_amplitude.x + absf(orbit_axis_v.z) * motion_amplitude.y
	return absf(motion_velocity.z) * motion_duration * 0.5 + (absf(orbit_axis_v.z) * motion_amplitude.y if motion_type == MotionType.ARC else 0.0)


func _add_lobe(offset: Vector3, lobe_scale: Vector3, lobe_rotation: Vector3, material: StandardMaterial3D, blocky: bool) -> void:
	var primitive: PrimitiveMesh
	if blocky:
		var block: BoxMesh = BoxMesh.new()
		block.size = Vector3(1.6, 1.8, 1.6)
		primitive = block
	else:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 7 + int(size_category)
		sphere.rings = 4
		primitive = sphere
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = primitive
	mesh_instance.material_override = material
	mesh_instance.position = offset
	mesh_instance.rotation = lobe_rotation
	mesh_instance.scale = lobe_scale
	visuals.add_child(mesh_instance)
	# Les points de collision suivent la même déformation que la primitive visible.
	var convex: ConvexPolygonShape3D = primitive.create_convex_shape()
	var points: PackedVector3Array = convex.points
	var lobe_basis: Basis = Basis.from_euler(lobe_rotation)
	for index: int in range(points.size()):
		points[index] = lobe_basis * (points[index] * lobe_scale)
		avoidance_radius = maxf(avoidance_radius, (offset + points[index]).length())
	convex.points = points
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = convex
	collision.position = offset
	add_child(collision)
