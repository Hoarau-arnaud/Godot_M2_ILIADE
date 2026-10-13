class_name StormRockVisuals
extends Node3D

# Les lobes collidables gardent leurs transforms exacts, mais se dessinent
# dans quatre MultiMesh plutôt que plusieurs centaines de draw calls.
const CAPACITY: int = 768
var _batches: Dictionary[int, MultiMesh] = {}


func _batch(key: int, source: Mesh) -> MultiMesh:
	if _batches.has(key):
		return _batches[key]
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = source
	batch.instance_count = CAPACITY
	batch.visible_instance_count = 0
	var display: MultiMeshInstance3D = MultiMeshInstance3D.new()
	display.multimesh = batch
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	display.material_override = material
	add_child(display)
	_batches[key] = batch
	return batch


func _process(_delta: float) -> void:
	var counts: Dictionary[int, int] = {}
	var inverse: Transform3D = global_transform.affine_inverse()
	for node: Node in get_tree().get_nodes_in_group("asteroids"):
		var rock: SpaceAsteroid = node as SpaceAsteroid
		if not rock.single_convex_envelope or rock.is_queued_for_deletion():
			continue
		for child: Node in rock.visuals.get_children():
			var part: MeshInstance3D = child as MeshInstance3D
			var key: int = part.get_meta("primitive_key")
			var batch: MultiMesh = _batch(key, part.mesh)
			var index: int = counts.get(key, 0)
			if index >= CAPACITY:
				continue
			batch.set_instance_transform(index, inverse * part.global_transform)
			batch.set_instance_color(index, (part.material_override as StandardMaterial3D).albedo_color)
			counts[key] = index + 1
	for key: int in _batches:
		_batches[key].visible_instance_count = counts.get(key, 0)
