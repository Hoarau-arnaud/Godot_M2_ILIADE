class_name CombatPrediction
extends RefCounted

# Helpers physiques sans état ni agent supplémentaire.
static func intercept_time(origin: Vector3, position: Vector3, velocity: Vector3, speed: float) -> float:
	var offset: Vector3 = position - origin
	var a: float = velocity.length_squared() - speed * speed
	var b: float = 2 * offset.dot(velocity)
	var c: float = offset.length_squared()
	if absf(a) < 0.001:
		return maxf(-c / b, 0) if absf(b) > 0.001 else offset.length() / maxf(speed, 1)
	var discriminant: float = b * b - 4 * a * c
	if discriminant >= 0:
		var first: float = (-b - sqrt(discriminant)) / (2 * a)
		var second: float = (-b + sqrt(discriminant)) / (2 * a)
		if first > 0 and second > 0:
			return minf(first, second)
		if maxf(first, second) > 0:
			return maxf(first, second)
	return offset.length() / maxf(speed, 1)


static func aim(origin: Vector3, position: Vector3, velocity: Vector3, speed: float) -> Vector3:
	return position + velocity * intercept_time(origin, position, velocity, speed)


static func threat(offset: Vector3, relative_velocity: Vector3, clearance: float, horizon: float, weight: float = 1) -> Dictionary:
	var squared: float = relative_velocity.length_squared()
	if squared < 0.001 or offset.dot(relative_velocity) >= 0:
		return {}
	var time: float = -offset.dot(relative_velocity) / squared
	if time <= 0 or time > horizon:
		return {}
	var miss: float = (offset + relative_velocity * time).length()
	if miss >= clearance:
		return {}
	var score: float = (1 - miss / clearance) * 2 / (time + 0.25)
	score *= weight * (0.8 + minf(relative_velocity.length() / 150, 0.4))
	score *= clampf(1 - offset.length() / 240, 0.55, 1)
	var impact_time: float = maxf(time - sqrt(maxf(clearance * clearance - miss * miss, 0)) / sqrt(squared), 0)
	return {"time": time, "impact_time": impact_time, "miss": miss, "score": score, "relative_velocity": relative_velocity}
