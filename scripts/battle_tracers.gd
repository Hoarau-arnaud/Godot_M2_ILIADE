class_name BattleTracers
extends MultiMeshInstance3D

# Pool purement visuel : 1 Node, 768 instances, aucun body ou dégât.
const CAPACITY: int = 768
var emitted: int = 0
var maximum_active: int = 0
var active_count: int = 0
var rate: float = 30
var background_only: bool = false
var _credit: float = 0
var _cursor: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _lifetimes: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_random.seed = 27183
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var mesh_shape: BoxMesh = BoxMesh.new()
	mesh_shape.size = Vector3(0.28, 0.28, 10)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(1, 0.24, 0.08)
	material.emission_energy_multiplier = 3
	mesh_shape.material = material
	multimesh.mesh = mesh_shape
	multimesh.instance_count = CAPACITY
	_positions.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_lifetimes.resize(CAPACITY)
	for index: int in range(CAPACITY):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))


func _process(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	var capitals: Array[Node] = get_tree().get_nodes_in_group("capital_ships")
	var ships: Array[Node] = get_tree().get_nodes_in_group("blue_ships")
	if not capitals.is_empty() and not ships.is_empty():
		_credit += real_delta * rate
		while _credit >= 1:
			_credit -= 1
			var capital: CapitalShip = capitals[_random.randi_range(0, capitals.size() - 1)] as CapitalShip
			if not capital.combat_enabled:
				continue
			var target_ship: BlueShip = ships[_random.randi_range(0, ships.size() - 1)] as BlueShip
			var origin: Vector3 = capital.global_position + CapitalShip.LAUNCHERS[_cursor % 2]
			var aim: Vector3 = target_ship.global_position + target_ship.velocity * 9 + Vector3(_random.randf_range(-65, 65), _random.randf_range(-45, 45), 0)
			_positions[_cursor] = origin
			_velocities[_cursor] = (aim - origin).normalized() * _random.randf_range(35, 55)
			_lifetimes[_cursor] = 3.0 if background_only else 11
			multimesh.set_instance_color(_cursor, Color(1, _random.randf_range(0.12, 0.65), _random.randf_range(0.05, 0.6)))
			_cursor = (_cursor + 1) % CAPACITY
			emitted += 1
	active_count = 0
	for index: int in range(CAPACITY):
		if _lifetimes[index] <= 0:
			continue
		_lifetimes[index] -= delta
		_positions[index] += _velocities[index] * delta
		var alignment: Basis = Basis.looking_at(-_velocities[index].normalized(), Vector3.UP)
		multimesh.set_instance_transform(index, Transform3D(alignment if _lifetimes[index] > 0 else Basis.IDENTITY.scaled(Vector3.ZERO), _positions[index]))
		active_count += int(_lifetimes[index] > 0)
	maximum_active = maxi(maximum_active, active_count)
