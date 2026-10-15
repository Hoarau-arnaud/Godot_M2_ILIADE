extends RefCounted

# LUT des seules fonctions UV statiques. Éclairage, géométrie et couleurs restent
# dans les shaders d'origine ; FREE/GUIDED utilisent leur calcul historique.
static var _planet: ImageTexture
static var _nebula: ImageTexture


static func apply(backdrop: Node3D, enabled: bool) -> void:
	if enabled and DisplayServer.get_name() != "headless" and _planet == null:
		_bake()
	for node: Node in backdrop.get_children():
		if not node is MeshInstance3D:
			continue
		var material: ShaderMaterial = (node as MeshInstance3D).material_override as ShaderMaterial
		if material == null:
			continue
		var planet: bool = material.shader == preload("res://materials/planet_surface.gdshader")
		var nebula: bool = material.shader == preload("res://materials/nebula.gdshader")
		if not planet and not nebula:
			continue
		material.set_shader_parameter("presentation_cached", enabled and _planet != null)
		if enabled and _planet != null:
			material.set_shader_parameter("presentation_map", _planet if planet else _nebula)


static func _bake() -> void:
	var planet: Image = Image.create(512, 256, false, Image.FORMAT_RGBA8)
	for y: int in range(256):
		for x: int in range(512):
			var p: Vector2 = Vector2((x + 0.5) / 512.0 * 28, (y + 0.5) / 256.0 * 18)
			var continents: float = sin(p.x + sin(p.y * 1.4) * 2) * cos(p.y + sin(p.x * 0.45))
			var land: float = smoothstep(0.16, 0.5, continents)
			var clouds: float = smoothstep(0.62, 0.9, sin(p.x * 1.7 + p.y * 0.8 + sin(p.y)))
			var relief: float = 0.5 + 0.5 * sin(p.x * 0.65 + sin(p.y * 0.7))
			planet.set_pixel(x, y, Color(land, clouds, relief, 1))
	_planet = ImageTexture.create_from_image(planet)
	var nebula: Image = Image.create(256, 128, false, Image.FORMAT_RGBA8)
	for y: int in range(128):
		for x: int in range(256):
			var point: Vector2 = (Vector2((x + 0.5) / 256.0, (y + 0.5) / 128.0) - Vector2(0.5, 0.5)) * Vector2(2.7, 1.7)
			var cloud: float = exp(-point.dot(point) * 3.5) * (0.65 + 0.35 * sin(point.x * 6 + point.y * 4))
			nebula.set_pixel(x, y, Color(cloud, 0, 0, 1))
	_nebula = ImageTexture.create_from_image(nebula)
