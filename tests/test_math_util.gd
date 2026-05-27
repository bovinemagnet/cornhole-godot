extends RefCounted

const MathUtil = preload("res://scripts/math_util.gd")

const EPSILON := 0.0001


func test_radius_from_area_round_trip() -> String:
	var radius := 2.5
	var area := MathUtil.area_from_radius(radius)
	var derived := MathUtil.radius_from_area(area)
	if abs(derived - radius) > EPSILON:
		return "expected %f, got %f" % [radius, derived]
	return ""


func test_radius_from_area_clamps_negative_to_zero() -> String:
	var derived := MathUtil.radius_from_area(-5.0)
	if derived != 0.0:
		return "expected 0.0 for negative area, got %f" % derived
	return ""


func test_distance_to_rotated_rect_inside_returns_zero() -> String:
	var distance := MathUtil.distance_to_rotated_rect(
		Vector2(0.1, 0.1), Vector2.ZERO, Vector2(1.0, 1.0), 0.0
	)
	if distance > EPSILON:
		return "expected 0, got %f" % distance
	return ""


func test_distance_to_rotated_rect_outside_axis_aligned() -> String:
	# Point 1m east of a 2x2 rect centred at origin -> 1.0 away from east edge (half-width 1.0) = 0... wait, 2.0 - 1.0 = 1.0 actually means the point is at the edge. Use 3.0 -> distance 2.0.
	var distance := MathUtil.distance_to_rotated_rect(
		Vector2(3.0, 0.0), Vector2.ZERO, Vector2(1.0, 1.0), 0.0
	)
	if abs(distance - 2.0) > EPSILON:
		return "expected 2.0, got %f" % distance
	return ""


func test_distance_to_rotated_rect_45deg_rotation_changes_inside_test() -> String:
	# Long thin rect 4x0.4 along X. Point at (0, 1.4) is outside when axis-aligned
	# (distance 1.4 - 0.2 = 1.2) but inside when rotated 45deg toward the point.
	var half := Vector2(2.0, 0.2)
	var point := Vector2(1.4, 1.4)
	var axis_aligned := MathUtil.distance_to_rotated_rect(point, Vector2.ZERO, half, 0.0)
	var rotated := MathUtil.distance_to_rotated_rect(point, Vector2.ZERO, half, PI / 4.0)
	if axis_aligned <= EPSILON:
		return "axis-aligned distance should be non-zero, got %f" % axis_aligned
	if rotated > EPSILON:
		return "45-degree rotation should bring point inside, got distance %f" % rotated
	return ""


func test_tier_fit_radius_box_uses_diagonal() -> String:
	# Box with scale (2, _, 1) has half-extents (1, 0.5) and diagonal sqrt(1.25) ≈ 1.1180.
	var fit := MathUtil.tier_fit_radius("box", Vector3(2.0, 1.0, 1.0), 0.0, 0.0)
	var expected := sqrt(1.0 * 1.0 + 0.5 * 0.5)
	if abs(fit - expected) > EPSILON:
		return "expected %f, got %f" % [expected, fit]
	return ""


func test_tier_fit_radius_tree_uses_collision_radius() -> String:
	var fit := MathUtil.tier_fit_radius("tree", Vector3(3.0, 4.0, 3.0), 99.0, 0.75)
	if abs(fit - 0.75) > EPSILON:
		return "expected 0.75 (collision_radius), got %f" % fit
	return ""


func test_tier_fit_radius_default_uses_required_radius() -> String:
	var fit := MathUtil.tier_fit_radius("cylinder", Vector3(1.0, 1.0, 1.0), 1.25, 0.5)
	if abs(fit - 1.25) > EPSILON:
		return "expected 1.25 (required_radius), got %f" % fit
	return ""


func test_area_from_radius_matches_pi_r_squared() -> String:
	var area := MathUtil.area_from_radius(3.0)
	var expected := PI * 9.0
	if abs(area - expected) > EPSILON:
		return "expected %f, got %f" % [expected, area]
	return ""
