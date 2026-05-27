extends RefCounted


static func area_from_radius(radius: float) -> float:
	return PI * radius * radius


static func radius_from_area(area: float) -> float:
	return sqrt(max(0.0, area) / PI)


static func distance_to_rotated_rect(point: Vector2, rect_center: Vector2, half_extents: Vector2, rotation_y: float) -> float:
	var local_point := point - rect_center
	var cos_y := cos(-rotation_y)
	var sin_y := sin(-rotation_y)
	var rotated_point := Vector2(
		local_point.x * cos_y - local_point.y * sin_y,
		local_point.x * sin_y + local_point.y * cos_y
	)
	var outside_delta := Vector2(
		max(abs(rotated_point.x) - half_extents.x, 0.0),
		max(abs(rotated_point.y) - half_extents.y, 0.0)
	)
	return outside_delta.length()


# Smallest actor radius that can fit a prop of the given shape.
# Box props use their rotated-rect diagonal; trees use their trunk
# collision_radius; everything else uses the authored required_radius.
static func tier_fit_radius(shape: String, scale: Vector3, required_radius: float, collision_radius: float) -> float:
	if shape == "box":
		return Vector2(scale.x * 0.5, scale.z * 0.5).length()
	if shape == "tree":
		return collision_radius
	return required_radius
