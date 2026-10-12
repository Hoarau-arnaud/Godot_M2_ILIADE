class_name SpaceAsteroid
extends StaticBody3D

enum SizeCategory { SMALL, MEDIUM, LARGE }

@export var size_category: SizeCategory = SizeCategory.MEDIUM
@export_range(1.0, 7.0, 0.1) var diameter: float = 3.0
@export var shape_seed: int = 1
@export var rotation_speed: float = 0.1

var avoidance_radius: float = 0.0
var _rotation_axis: Vector3 = Vector3.UP
var _spin_factor: float = 1.0
@onready var visuals: Node3D = $Visuals


func _ready() -> void:
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


func _physics_process(delta: float) -> void:
	# Le corps et ses quelques formes convexes tournent ensemble, sans translation.
	rotate(_rotation_axis, rotation_speed * _spin_factor * delta)


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
