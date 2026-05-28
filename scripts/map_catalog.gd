extends RefCounted

# Loads map-pack catalog JSON files and produces selector options. Pure
# parsing is exposed via `parse_catalog` so it can be unit-tested without
# touching the filesystem; `load_all` is the IO entrypoint that the menu
# wires use. Options are: { id, name, label, seed, catalog_path }.


static func parse_catalog(catalog: Dictionary, catalog_path: String) -> Array:
	var options: Array = []
	if catalog.is_empty():
		return options

	var maps_value: Variant = catalog.get("maps", [])
	if typeof(maps_value) != TYPE_ARRAY:
		push_warning("Map catalog has no maps array: %s" % catalog_path)
		return options
	var maps: Array = maps_value

	var pack_id := String(catalog.get("pack_id", catalog_path.get_base_dir().get_file()))
	var pack_name := String(catalog.get("name", ""))
	if pack_name.is_empty():
		pack_name = "Base Maps" if catalog_path.ends_with("/map_catalog.json") else pack_id.capitalize()

	for map_data in maps:
		if typeof(map_data) != TYPE_DICTIONARY:
			continue
		var map_dictionary: Dictionary = map_data

		if not map_dictionary.has("id"):
			push_warning("Map catalog entry missing id in %s" % catalog_path)
			continue
		if not map_dictionary.has("name"):
			push_warning("Map catalog entry missing name in %s" % catalog_path)
			continue
		if not map_dictionary.has("seed"):
			push_warning("Map catalog entry missing seed in %s" % catalog_path)
			continue

		var map_id := String(map_dictionary["id"])
		var map_name := String(map_dictionary["name"])
		var option_id := "%s/%s" % [pack_id, map_id]
		options.append({
			"id": option_id,
			"name": map_name,
			"label": "%s: %s" % [pack_name, map_name],
			"seed": int(map_dictionary["seed"]),
			"catalog_path": catalog_path,
		})

	return options


static func load_all(catalog_paths: PackedStringArray) -> Array:
	var aggregated: Array = []
	var seen_ids: Dictionary = {}

	for path in catalog_paths:
		if not FileAccess.file_exists(path):
			continue

		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			push_warning("Unable to read map catalog: %s" % path)
			continue

		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("Map catalog is not a dictionary: %s" % path)
			continue

		for option in parse_catalog(parsed, path):
			var opt: Dictionary = option
			var id := String(opt["id"])
			if seen_ids.has(id):
				push_warning("Duplicate map id '%s' from %s — dropping later occurrence" % [id, path])
				continue
			seen_ids[id] = true
			aggregated.append(opt)

	return aggregated
