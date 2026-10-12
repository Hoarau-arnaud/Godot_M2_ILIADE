class_name MobileAvoidance
extends RefCounted


# Position et vitesse relatives uniquement : aucune connaissance globale du monde.
static func approach(offset: Vector3, relative_velocity: Vector3, horizon: float) -> Vector2:
	var time: float = 0.0
	if relative_velocity.length_squared() > 0.001:
		time = clampf(-offset.dot(relative_velocity) / relative_velocity.length_squared(), 0.0, maxf(horizon, 0.0))
	return Vector2(time, (offset + relative_velocity * time).length())


static func direction(offset: Vector3, relative_velocity: Vector3, time: float, fallback: Vector3) -> Vector3:
	var future: Vector3 = offset + relative_velocity * time
	var away: Vector3 = Vector3(-future.x, -future.y, 0.0)
	return away.normalized() if away.length_squared() > 0.04 else fallback


static func steering(offset: Vector3, relative_velocity: Vector3, time: float, clearance: float, side: Vector3) -> Vector3:
	var future: Vector3 = offset + relative_velocity * time
	var remaining: float = clearance - Vector3(-future.x, -future.y, 0.0).dot(side)
	return side * clampf(remaining / maxf(time, 0.4), 0.0, 3.0)
