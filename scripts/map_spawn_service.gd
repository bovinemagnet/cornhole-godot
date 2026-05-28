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
	player_spawn_clearance: float,
	starter_count: int = 0,
	starter_radius: float = 0.0
) -> PackedVector3Array:
	var positions := PackedVector3Array()
	if count <= 0:
		return positions

	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + SEED_NAMESPACE + spawn_algo_version

	# Guarantee a ring of starter props around spawn so no map (regardless of
	# how its zones are authored) leaves the player stranded with nothing
	# edible nearby. starter_count of 0 reproduces the original behaviour
	# exactly, keeping older callers/tests deterministic.
	var effective_starter: int = clamp(starter_count, 0, count)
	for i in range(count):
		var chosen: Vector3
		if i < effective_starter and starter_radius > player_spawn_clearance:
			chosen = _sample_starter_position(rng, water_regions, player_spawn_clearance, starter_radius)
		else:
			chosen = _pick_one_position(
				rng, zones, water_regions, fallback_half_size, player_spawn_clearance
			)
		positions.append(chosen)

	return positions


static func _sample_starter_position(
	rng: RandomNumberGenerator,
	water_regions: Array,
	min_radius: float,
	max_radius: float
) -> Vector3:
	var lo: float = max(min_radius, 1.0)
	var hi: float = max(max_radius, lo + 1.0)
	for attempt in range(MAX_ATTEMPTS_PER_PROP):
		var angle := rng.randf() * TAU
		# Uniform area distribution across the annulus.
		var r := sqrt(rng.randf() * (hi * hi - lo * lo) + lo * lo)
		var candidate := Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		if not _in_any_water(candidate, water_regions):
			return candidate
	# Give up after retries: place on the outer ring away from water bias.
	var fallback_angle := rng.randf() * TAU
	return Vector3(cos(fallback_angle) * hi, 0.0, sin(fallback_angle) * hi)


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
