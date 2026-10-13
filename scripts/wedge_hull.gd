extends MeshInstance3D

# Dix points, seize triangles : pointe fine, dos et ventre, largeur croissante.
@export var span: Vector3 = Vector3(2.2, 1.0, 6.6)


func _ready() -> void:
	var points: Array[Vector3] = [
		Vector3(0, 0, -0.5),
		Vector3(0, 0.42, -0.12), Vector3(-0.26, 0, -0.12),
		Vector3(0, -0.4, -0.12), Vector3(0.26, 0, -0.12),
		Vector3(0, 0.5, 0.5), Vector3(-0.5, 0, 0.5),
		Vector3(0, -0.5, 0.5), Vector3(0.5, 0, 0.5), Vector3(0, 0, 0.5)
	]
	var faces: Array[Vector3i] = [
		Vector3i(0,1,2), Vector3i(0,2,3), Vector3i(0,3,4), Vector3i(0,4,1),
		Vector3i(1,5,6), Vector3i(1,6,2), Vector3i(2,6,7), Vector3i(2,7,3),
		Vector3i(3,7,8), Vector3i(3,8,4), Vector3i(4,8,5), Vector3i(4,5,1),
		Vector3i(9,6,5), Vector3i(9,7,6), Vector3i(9,8,7), Vector3i(9,5,8)
	]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Vector3i in faces:
		var a: Vector3 = points[face.x] * span
		var b: Vector3 = points[face.y] * span
		var c: Vector3 = points[face.z] * span
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0) < 0:
			normal = -normal
			var temporary: Vector3 = b
			b = c
			c = temporary
		# Godot attend les faces dans le sens horaire vues de l'extérieur.
		surface.set_normal(normal)
		surface.add_vertex(a)
		surface.add_vertex(c)
		surface.add_vertex(b)
	mesh = surface.commit()
