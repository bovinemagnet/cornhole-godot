extends RefCounted

# Turns a texture definition into a Godot Material. Standard textures become
# StandardMaterial3D; water/conveyor/emissive textures become ShaderMaterial
# using the bundled shaders. Materials are cached by albedo path + shader so
# repeated regions reuse one resource (the spec's perf guidance).

const ThemedTextureLibrary = preload("res://scripts/themed_textures/themed_texture_library.gd")

const SHADER_WATER := preload("res://assets/themed_textures/shaders/ScrollingWater.gdshader")
const SHADER_CONVEYOR := preload("res://assets/themed_textures/shaders/ConveyorScroll.gdshader")
const SHADER_EMISSIVE := preload("res://assets/themed_textures/shaders/EmissivePulse.gdshader")

static var _cache: Dictionary = {}


# Returns a Material for the texture definition, or null when the texture
# cannot be loaded so callers can fall back to a flat colour material.
static func material_for(texture_def: Dictionary) -> Material:
	if texture_def.is_empty():
		return null
	var path := ThemedTextureLibrary.texture_path(texture_def)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	var material_meta: Dictionary = texture_def.get("material", {})
	var shader_name := String(material_meta.get("shader", "standard"))
	var cache_key := "%s|%s" % [path, shader_name]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var texture: Texture2D = load(path)
	if not texture:
		return null

	var uv_scale := _to_vector2(material_meta.get("uv_scale", [2.0, 2.0]))
	var material: Material = _build(shader_name, texture, uv_scale, material_meta)
	_cache[cache_key] = material
	return material


static func clear_cache() -> void:
	_cache.clear()


static func _build(shader_name: String, texture: Texture2D, uv_scale: Vector2, meta: Dictionary) -> Material:
	match shader_name:
		"scrolling_water":
			return _shader_material(SHADER_WATER, texture, uv_scale)
		"conveyor_scroll":
			return _shader_material(SHADER_CONVEYOR, texture, uv_scale)
		"emissive_pulse":
			return _shader_material(SHADER_EMISSIVE, texture, uv_scale)
		_:
			return _standard_material(texture, uv_scale, meta)


static func _shader_material(shader: Shader, texture: Texture2D, uv_scale: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("albedo_tex", texture)
	material.set_shader_parameter("uv_scale", uv_scale)
	return material


static func _standard_material(texture: Texture2D, uv_scale: Vector2, meta: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = float(meta.get("roughness", 0.85))
	material.metallic = float(meta.get("metallic", 0.0))
	material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	return material


static func _to_vector2(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(2.0, 2.0)
