extends RefCounted

# Pure deterministic chooser for static prop spawn positions. Same map_seed
# + spawn_algo_version + zones produces the same ordered positions, which
# preserves the future server-authoritative model (clients reproduce the
# layout without per-prop network traffic).

const SEED_NAMESPACE := 100_000
const MAX_ATTEMPTS_PER_PROP := 20


static func choose_static_prop_positions(
	map_seed: int,
	spawn_algo_version: int,
	count: int,
	zones: Array,
	water_regions: Array,
	fallback_half_size: float,
	player_spawn_clearance: float
) -> PackedVector3Array:
	var positions := PackedVector3Array()
	if count <= 0:
		return positions

	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + SEED_NAMESPACE + spawn_algo_version

	for i in range(count):
		var chosen: Vector3 = _pick_one_position(
			rng, zones, water_regions, fallback_half_size, player_spawn_clearance
		)
		positions.append(chosen)

	return positions


static func _pick_one_position(
	rng: RandomNumberGenerator,
	zones: Array,
	water_regions: Array,
	fallback_half_size: float,
	player_spawn_clearance: float
) -> Vector3:
	for attempt in range(MAX_ATTEMPTS_PER_PROP):
		var candidate := _sample_candidate(rng, zones, fallback_half_size)
		if _in_any_water(candidate, water_regions):
			continue
		if player_spawn_clearance > 0.0:
			var d := Vector2(candidate.x, candidate.z).length()
			if d < player_spawn_clearance:
				continue
		return candidate
	# Give up: return the last candidate anyway so count is preserved.
	return _sample_candidate(rng, zones, fallback_half_size)


static func _sample_candidate(rng: RandomNumberGenerator, zones: Array, fallback_half_size: float) -> Vector3:
	if zones.is_empty():
		var inset: float = max(0.0, fallback_half_size - 2.0)
		return Vector3(rng.randf_range(-inset, inset), 0.0, rng.randf_range(-inset, inset))

	var zone: Dictionary = zones[rng.randi() % zones.size()]
	var centre: Vector2 = zone["center"]
	var size: Vector2 = zone["size"]
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	return Vector3(
		centre.x + rng.randf_range(-half_x, half_x),
		0.0,
		centre.y + rng.randf_range(-half_z, half_z)
	)


static func _in_any_water(point: Vector3, water_regions: Array) -> bool:
	for region in water_regions:
		var entry: Dictionary = region
		var centre: Vector2 = entry["center"]
		var size: Vector2 = entry["size"]
		if abs(point.x - centre.x) <= size.x * 0.5 and abs(point.z - centre.y) <= size.y * 0.5:
			return true
	return false
