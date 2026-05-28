extends RefCounted

const MapCatalog = preload("res://scripts/map_catalog.gd")


func _stub_catalog(pack_id: String, pack_name: String, maps: Array) -> Dictionary:
	return {"pack_id": pack_id, "name": pack_name, "maps": maps}


func test_parse_catalog_returns_option_per_valid_map() -> String:
	var catalog := _stub_catalog("test_pack", "Test Pack", [
		{"id": "alpha", "name": "Alpha Map", "seed": 1001},
		{"id": "beta", "name": "Beta Map", "seed": 1002},
	])
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	if options.size() != 2:
		return "expected 2 options, got %d" % options.size()
	return ""


func test_parse_catalog_option_has_required_fields() -> String:
	var catalog := _stub_catalog("test_pack", "Test Pack", [
		{"id": "alpha", "name": "Alpha Map", "seed": 1001},
	])
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	var option: Dictionary = options[0]
	for key in ["id", "name", "label", "seed", "catalog_path"]:
		if not option.has(key):
			return "missing key %s" % key
	if String(option["id"]) != "test_pack/alpha":
		return "expected id 'test_pack/alpha', got %s" % String(option["id"])
	if String(option["label"]) != "Test Pack: Alpha Map":
		return "expected label 'Test Pack: Alpha Map', got %s" % String(option["label"])
	if int(option["seed"]) != 1001:
		return "expected seed 1001, got %d" % int(option["seed"])
	if String(option["catalog_path"]) != "res://stub.json":
		return "expected catalog_path 'res://stub.json', got %s" % String(option["catalog_path"])
	return ""


func test_parse_catalog_skips_entry_missing_id() -> String:
	var catalog := _stub_catalog("test_pack", "Test Pack", [
		{"name": "Anonymous", "seed": 1001},
		{"id": "ok", "name": "Ok Map", "seed": 1002},
	])
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	if options.size() != 1:
		return "expected 1 option, got %d" % options.size()
	if String(options[0]["id"]) != "test_pack/ok":
		return "expected the surviving entry to be 'test_pack/ok'"
	return ""


func test_parse_catalog_skips_entry_missing_seed() -> String:
	var catalog := _stub_catalog("test_pack", "Test Pack", [
		{"id": "no_seed", "name": "No Seed"},
		{"id": "ok", "name": "Ok Map", "seed": 1002},
	])
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	if options.size() != 1:
		return "expected 1 option, got %d" % options.size()
	return ""


func test_parse_catalog_skips_entry_missing_name() -> String:
	var catalog := _stub_catalog("test_pack", "Test Pack", [
		{"id": "no_name", "seed": 1001},
		{"id": "ok", "name": "Ok Map", "seed": 1002},
	])
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	if options.size() != 1:
		return "expected 1 option, got %d" % options.size()
	return ""


func test_parse_catalog_falls_back_to_pack_id_when_pack_name_missing() -> String:
	var catalog := {"pack_id": "bare_pack", "maps": [
		{"id": "alpha", "name": "Alpha Map", "seed": 1001},
	]}
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	var label := String(options[0]["label"])
	if not label.begins_with("Bare Pack") and not label.begins_with("bare_pack"):
		return "expected label to start with a pack-id fallback, got %s" % label
	return ""


func test_parse_catalog_skips_non_dictionary_map_entries() -> String:
	var catalog := _stub_catalog("test_pack", "Test Pack", [
		"not a dict",
		42,
		{"id": "ok", "name": "Ok Map", "seed": 1002},
	])
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	if options.size() != 1:
		return "expected 1 option, got %d" % options.size()
	return ""


func test_parse_catalog_handles_empty_or_invalid_input() -> String:
	var empty: Array = MapCatalog.parse_catalog({}, "res://stub.json")
	if empty.size() != 0:
		return "expected empty for empty dict, got %d" % empty.size()
	var no_maps: Array = MapCatalog.parse_catalog({"pack_id": "x", "maps": "not an array"}, "res://stub.json")
	if no_maps.size() != 0:
		return "expected empty when maps is not an array, got %d" % no_maps.size()
	return ""


func test_parse_catalog_includes_difficulty_when_present() -> String:
	var catalog := _stub_catalog("test_pack", "Test Pack", [
		{"id": "alpha", "name": "Alpha", "seed": 1001, "difficulty": 4},
		{"id": "beta", "name": "Beta", "seed": 1002},
	])
	var options: Array = MapCatalog.parse_catalog(catalog, "res://stub.json")
	if int(options[0]["difficulty"]) != 4:
		return "expected difficulty 4, got %s" % str(options[0]["difficulty"])
	if int(options[1]["difficulty"]) != 0:
		return "expected default difficulty 0 when missing, got %s" % str(options[1]["difficulty"])
	if not String(options[0]["label"]).contains("diff 4"):
		return "expected difficulty in label, got %s" % String(options[0]["label"])
	return ""


func test_load_all_loads_real_catalogs() -> String:
	var paths := PackedStringArray([
		"res://resources/maps/map_catalog.json",
		"res://resources/maps/kitty_land/kitty_land_catalog.json",
		"res://resources/maps/candy_land/candy_land_catalog.json",
		"res://resources/maps/robot_land/robot_land_catalog.json",
		"res://resources/maps/bunny_land/bunny_land_catalog.json",
		"res://resources/maps/dino_land/dino_land_catalog.json",
	])
	var options: Array = MapCatalog.load_all(paths)
	if options.size() < 6:
		return "expected at least one map per pack (>=6 options), got %d" % options.size()
	for option in options:
		var opt: Dictionary = option
		if not opt.has("id") or not opt.has("seed") or not opt.has("label"):
			return "every option must carry id/seed/label, missing in %s" % str(opt)
	return ""


func test_load_all_skips_missing_optional_pack() -> String:
	var paths := PackedStringArray([
		"res://resources/maps/map_catalog.json",
		"res://resources/maps/does_not_exist/missing_catalog.json",
	])
	var options: Array = MapCatalog.load_all(paths)
	# Should still return the base options without crashing.
	if options.size() == 0:
		return "expected base catalog to still load when an optional pack is missing"
	return ""


func test_load_all_drops_duplicate_full_ids() -> String:
	# Both real catalogs and a duplicate of the same file path should not
	# produce double entries for the same option id.
	var paths := PackedStringArray([
		"res://resources/maps/map_catalog.json",
		"res://resources/maps/map_catalog.json",
	])
	var options: Array = MapCatalog.load_all(paths)
	var seen: Dictionary = {}
	for option in options:
		var id := String(option["id"])
		if seen.has(id):
			return "duplicate id slipped through: %s" % id
		seen[id] = true
	return ""
