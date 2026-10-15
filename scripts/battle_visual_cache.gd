extends RefCounted

# Une surface commune par silhouette statique ; moteurs, flashes et collisions restent intacts.
static var meshes: Dictionary = {}
static var material: StandardMaterial3D

static func pack(visual: Node3D, family: String) -> void:
	if visual.has_node("PresentationHull"):
		return
	var parts: Array[MeshInstance3D] = []
	for child: Node in visual.get_children():
		if not child is MeshInstance3D:
			continue
		var part: MeshInstance3D = child as MeshInstance3D
		var source: Material = part.get_active_material(0)
		if source is StandardMaterial3D and (source as StandardMaterial3D).emission_enabled:
			continue
		if part.name.contains("Exhaust") or part.name.contains("Plume") or part.name.contains("Charge"):
			continue
		parts.append(part)
	if parts.is_empty():
		return
	if not meshes.has(family):
		var builder: SurfaceTool = SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in parts:
			var source: Material = part.get_active_material(0)
			var color: Color = (source as StandardMaterial3D).albedo_color if source is StandardMaterial3D else Color(0.3, 0.3, 0.4)
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var basis: Basis = part.transform.basis.inverse().transposed()
			for index: int in range(indices.size() if not indices.is_empty() else vertices.size()):
				var vertex: int = indices[index] if not indices.is_empty() else index
				builder.set_color(color)
				builder.set_normal((basis * normals[vertex]).normalized() if normals.size() > vertex else Vector3.UP)
				builder.add_vertex(part.transform * vertices[vertex])
		var mesh: ArrayMesh = builder.commit()
		if material == null:
			material = StandardMaterial3D.new()
			material.vertex_color_use_as_albedo = true
			material.roughness = 0.96
		mesh.surface_set_material(0, material)
		meshes[family] = mesh
	for part: MeshInstance3D in parts:
		part.hide()
	var packed: MeshInstance3D = MeshInstance3D.new()
	packed.name = "PresentationHull"
	packed.mesh = meshes[family]
	visual.add_child(packed)
