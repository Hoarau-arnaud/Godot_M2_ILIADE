class_name FlightTuning
extends RefCounted

# Les tests M1–M12 choisissent explicitement leurs paramètres physiques d'origine.
# Aucun état global : le profil concerne uniquement la fixture passée en argument.
static func legacy_actor(actor: Node) -> void:
	if actor is SpaceSimulation:
		(actor as SpaceSimulation).auto_start_presentation_demo = false
		(actor as SpaceSimulation).legacy_flight_profile = true
		m13_fixture(actor)
	elif actor is BlueShip:
		var blue: BlueShip = actor as BlueShip
		blue.forward_speed = 10.5
		blue.max_side_speed = 9
		blue.acceleration = 12
		blue.evasive_boost_enabled = false
		blue.hostile_projectile_detection_radius = 32
		blue.projectile_prediction_time = 2
		blue.blue_laser_speed = 60
	elif actor is Interceptor:
		var interceptor: Interceptor = actor as Interceptor
		interceptor.forward_speed = 9
		interceptor.max_side_speed = 8
		interceptor.acceleration = 12
		interceptor.pursuit_max_speed = 18
		interceptor.shot_spread_angle = 2
		interceptor.predictive_targeting = false
	elif actor is PatrolDrone:
		if (actor as PatrolDrone).forward_speed >= 12:
			(actor as PatrolDrone).forward_speed = 9.2
		(actor as PatrolDrone).predictive_targeting = false
	elif actor is CapitalShip:
		(actor as CapitalShip).predictive_targeting = false
	elif actor is BlueLaser:
		(actor as BlueLaser).projectile_speed = 60
	elif actor is EnemyLaser:
		(actor as EnemyLaser).projectile_speed = 45


static func m13_fixture(actor: Node) -> void:
	if actor is SpaceSimulation:
		var sim: SpaceSimulation = actor as SpaceSimulation
		sim.arcade_hazards_enabled = false
		sim.threat_choreography_enabled = false
		sim.guided_reinforcements_enabled = false
		sim.stop_on_squadron_extinction = true


static func m14_fixture(actor: Node) -> void:
	if actor is SpaceSimulation:
		(actor as SpaceSimulation).arcade_hazards_enabled = false
