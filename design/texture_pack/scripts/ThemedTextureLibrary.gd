extends RefCounted
class_name ThemedTextureLibrary

static func load_json(path: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        push_error("Could not read JSON: %s" % path)
        return {}
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Invalid JSON: %s" % path)
        return {}
    return parsed

static func load_manifest(base_path: String) -> Dictionary:
    return load_json(base_path.path_join("manifest.json"))

static func load_pack(base_path: String, pack_id: String) -> Dictionary:
    return load_json(base_path.path_join("packs/%s/%s_textures.json" % [pack_id, pack_id]))

static func get_texture_def(pack_data: Dictionary, tex_id: String) -> Dictionary:
    for t in pack_data.get("textures", []):
        if t.get("id", "") == tex_id:
            return t
    return {}
