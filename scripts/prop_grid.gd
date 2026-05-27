extends RefCounted

# Uniform 2D spatial grid for prop lookups across the arena.
# Coordinates are arena-space XZ (range [-arena_half_size, +arena_half_size]).
# Indices stored in cells are positional only -- callers handle prop state
# (e.g. `consumed`) when iterating the returned candidates.

var _cell_size: float = 0.0
var _arena_half_size: float = 0.0
var _cells_per_side: int = 0
var _cells: Array = []


func build(prop_positions: PackedVector2Array, arena_half_size: float, cell_size: float) -> void:
	_arena_half_size = arena_half_size
	_cell_size = max(0.001, cell_size)
	_cells_per_side = int(ceil((2.0 * arena_half_size) / _cell_size)) + 1
	_cells = []
	_cells.resize(_cells_per_side * _cells_per_side)
	for i in range(_cells.size()):
		_cells[i] = PackedInt32Array()
	for idx in range(prop_positions.size()):
		var pos: Vector2 = prop_positions[idx]
		var cell_index := _cell_index_for(pos)
		_cells[cell_index].append(idx)


func query_radius(center: Vector2, radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	if _cells.is_empty() or radius < 0.0:
		return result
	var min_cx := _cell_axis(center.x - radius)
	var max_cx := _cell_axis(center.x + radius)
	var min_cy := _cell_axis(center.y - radius)
	var max_cy := _cell_axis(center.y + radius)
	for cy in range(min_cy, max_cy + 1):
		var row_offset := cy * _cells_per_side
		for cx in range(min_cx, max_cx + 1):
			result.append_array(_cells[row_offset + cx])
	return result


func cells_per_side() -> int:
	return _cells_per_side


func _cell_axis(coord: float) -> int:
	var local := coord + _arena_half_size
	var index := int(floor(local / _cell_size))
	return clamp(index, 0, _cells_per_side - 1)


func _cell_index_for(pos: Vector2) -> int:
	return _cell_axis(pos.y) * _cells_per_side + _cell_axis(pos.x)
