extends RefCounted

# Pure deterministic spawn data for moving cars. Same `map_seed`, route count,
# and route_lengths produce the same ordered list of spawn dictionaries.
# IDs are taken from a dedicated range (MOVING_PROP_ID_BASE..) so they never
# collide with static prop IDs and can be used as-is in a future networked
# `ObjectConsumed { object_kind, object_id }` event.

const MOVING_PROP_ID_BASE := 10000
const SPAWN_ALGO_VERSION := 1
const SEED_NAMESPACE := 910_000


static func make_spawns(
	map_seed: int,
	count: int,
	route_lengths: PackedFloat32Array,
	speed_min: float,
	speed_max: float
) -> Array:
	var spawns: Array = []
	if count <= 0 or route_lengths.size() == 0:
		return spawns

	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + SEED_NAMESPACE + SPAWN_ALGO_VERSION

	var safe_min: float = min(speed_min, speed_max)
	var safe_max: float = max(speed_min, speed_max)

	for i in range(count):
		var route_id := rng.randi() % route_lengths.size()
		var route_length := float(route_lengths[route_id])
		var phase_offset := rng.randf() * route_length
		var speed := rng.randf_range(safe_min, safe_max)
		spawns.append({
			"id": MOVING_PROP_ID_BASE + i,
			"route_id": route_id,
			"phase_offset": phase_offset,
			"speed": speed,
		})

	return spawns
