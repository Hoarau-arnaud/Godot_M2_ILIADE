class_name CombatMeshCache
extends RefCounted

# Géométrie immuable par famille : une surface/draw call par projectile complexe.
# Les formes de collision restent sur le body d'origine.
static var _meshes: Dictionary[int, ArrayMesh] = {}
static var _material: ShaderMaterial


static func has_signature(kind: int) -> bool:
	return _meshes.has(kind)


static func prepare_signatures(arcade: bool = false) -> void:
	for kind: int in [0, 1, 2, 3, 4, 5, 6, 9]:
		if has_signature(kind + (20 if arcade else 0)):
			continue
		# Construction avant le combat ; aucun body n'entre dans l'arbre ou ses groupes.
		var sample: ArtilleryProjectile = ArtilleryProjectile.new()
		sample.kind = kind as ArtilleryProjectile.Kind
		sample.arcade_signature = arcade
		sample._build_visual()
		sample.free()


static func merge_parts(visual: Node3D, kind: int) -> void:
	if not _meshes.has(kind):
		var builder: SurfaceTool = SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child: Node in visual.get_children():
			var part: MeshInstance3D = child as MeshInstance3D
			if part == null:
				continue
			var color: Color = (part.material_override as StandardMaterial3D).albedo_color
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index: int in range(indices.size() if not indices.is_empty() else vertices.size()):
				var shaded: Color = color
				if kind >= 20:
					var face: int = index / 3 * 3
					var first: Vector3 = part.transform * vertices[indices[face] if not indices.is_empty() else face]
					var second: Vector3 = part.transform * vertices[indices[face + 1] if not indices.is_empty() else face + 1]
					var third: Vector3 = part.transform * vertices[indices[face + 2] if not indices.is_empty() else face + 2]
					var normal: Vector3 = (second - first).cross(third - first).normalized()
					var light: float = 0.62 + 0.38 * maxf(normal.dot(Vector3(0.4, 0.7, -0.3).normalized()), 0)
					shaded = Color(color.r * light, color.g * light, color.b * light, color.a)
				builder.set_color(shaded)
				builder.add_vertex(part.transform * vertices[indices[index] if not indices.is_empty() else index])
		var mesh: ArrayMesh = builder.commit()
		if _material == null:
			_material = ShaderMaterial.new()
			var shader: Shader = Shader.new()
			shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = COLOR.rgb; EMISSION = COLOR.rgb * 2.5; }"
			_material.shader = shader
		mesh.surface_set_material(0, _material)
		_meshes[kind] = mesh
	for child: Node in visual.get_children():
		visual.remove_child(child)
		child.free()
	var packed: MeshInstance3D = MeshInstance3D.new()
	packed.name = "PackedWeaponSignature"
	packed.mesh = _meshes[kind]
	visual.add_child(packed)
