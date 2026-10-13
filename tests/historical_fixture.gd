class_name HistoricalFixture
extends RefCounted

# Isoler les régressions SMA/combat du nouveau décor M8 et des valeurs de démonstration.
# Les nouvelles configurations sont exercées séparément par validate_cinematic.gd.
static func configure(simulation: SpaceSimulation, speed: float = 1.0) -> void:
	simulation.simulation_speed_multiplier = speed
	simulation.movement_multiplier = 1.0
	var field: ObstacleField = simulation.get_node("Asteroids") as ObstacleField
	field.cinematic_patterns_enabled = false
	field.moving_asteroids_enabled = false
	field.horizontal_spread = 38.0
	field.vertical_spread = 26.0
	field.max_active_asteroids = 72
