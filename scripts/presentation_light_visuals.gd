extends Node3D

# Regrouper les pièces lumineuses des unités légères en conservant leurs matériaux
# et leurs poses exactes. Les moteurs continuent d'être animés par chaque agent.
const CAPACITY: int = 128
var _entries: Array[Dictionary] = []
var _batches: Dictionary = {}


func _ready() -> void:
	process_priority = 100


func register_actor(actor: PatrolDrone) -> void:
	if actor.has_meta("presentation_lights_packed"):
		return
	actor.set_meta("presentation_lights_packed", true)
	var visual: Node3D = actor.get_node("Visuals") as Node3D
	for child: Node in visual.get_children():
		if not child is MeshInstance3D:
			continue
		var part: MeshInstance3D = child as MeshInstance3D
		var material: StandardMaterial3D = part.get_active_material(0) as StandardMaterial3D
		if material == null or not material.emission_enabled or not part.visible:
			continue
		var key: String = str(part.mesh.get_rid().get_id()) + ":" + str(material.get_rid().get_id())
		if not _batches.has(key):
			var batch: MultiMesh = MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.mesh = part.mesh
			batch.instance_count = CAPACITY
			batch.visible_instance_count = 0
			var display: MultiMeshInstance3D = MultiMeshInstance3D.new()
			display.multimesh = batch
			display.material_override = material
			add_child(display)
			_batches[key] = batch
		_entries.append({"actor": actor, "visual": visual, "part": part, "key": key})
		part.hide()


func _process(_delta: float) -> void:
	var counts: Dictionary = {}
	var inverse: Transform3D = global_transform.affine_inverse()
	for index: int in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		if not is_instance_valid(entry.actor) or entry.actor.is_queued_for_deletion():
			_entries.remove_at(index)
			continue
		if not entry.actor.alive or not entry.visual.is_visible_in_tree():
			continue
		var slot: int = int(counts.get(entry.key, 0))
		if slot >= CAPACITY:
			continue
		(_batches[entry.key] as MultiMesh).set_instance_transform(slot, inverse * (entry.part as Node3D).global_transform)
		counts[entry.key] = slot + 1
	for key: String in _batches:
		(_batches[key] as MultiMesh).visible_instance_count = int(counts.get(key, 0))
